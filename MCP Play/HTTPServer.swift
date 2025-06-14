//
//  HTTPServer.swift
//  MCP Play
//
//  Modern Foundation-based HTTP server with Swift 6.0 concurrency
//

import Foundation
import Network

// MARK: - JSON-RPC Models

struct JSONRPCRequest: Codable, Sendable {
    let jsonrpc: String
    let method: String
    let params: JSONValue?
    let id: JSONValue?
}

struct JSONRPCResponse: Codable, Sendable {
    let jsonrpc: String
    let result: JSONValue?
    let error: JSONRPCError?
    let id: JSONValue?

    init(result: JSONValue?, id: JSONValue?) {
        self.jsonrpc = "2.0"
        self.result = result
        self.error = nil
        self.id = id
    }

    init(error: JSONRPCError, id: JSONValue?) {
        self.jsonrpc = "2.0"
        self.result = nil
        self.error = error
        self.id = id
    }
}

struct JSONRPCError: Codable, Sendable, Error {
    let code: Int
    let message: String

    static let parseError = JSONRPCError(code: -32700, message: "Parse error")
    static let invalidRequest = JSONRPCError(code: -32600, message: "Invalid Request")
    static let methodNotFound = JSONRPCError(code: -32601, message: "Method not found")
    static let invalidParams = JSONRPCError(code: -32602, message: "Invalid params")
    static let internalError = JSONRPCError(code: -32603, message: "Internal error")

    static func serverError(_ message: String) -> JSONRPCError {
        return JSONRPCError(code: -32000, message: message)
    }
}

// MARK: - JSON Value Type

enum JSONValue: Codable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        do { self = .bool(try container.decode(Bool.self)); return } catch { }
        do { self = .int(try container.decode(Int.self)); return } catch { }
        do { self = .double(try container.decode(Double.self)); return } catch { }
        do { self = .string(try container.decode(String.self)); return } catch { }
        do { self = .array(try container.decode([JSONValue].self)); return } catch { }
        do {
            self = .object(try container.decode([String: JSONValue].self))
        } catch {
            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Value could not be decoded as any of the supported JSON primitives.", underlyingError: error))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }

    // Helper properties to access underlying values
    var stringValue: String? { if case .string(let v) = self { return v }; return nil }
    var intValue: Int? { if case .int(let v) = self { return v }; return nil }
    var doubleValue: Double? {
        if case .double(let v) = self { return v }
        if case .int(let v) = self { return Double(v) }
        return nil
    }
    var arrayValue: [JSONValue]? { if case .array(let v) = self { return v }; return nil }
    var objectValue: [String: JSONValue]? { if case .object(let v) = self { return v }; return nil }
}

// MARK: - MCP & HTTP Models

struct MCPContentItem: Codable, Sendable { let type: String; let text: String }
struct MCPResult: Codable, Sendable { let content: [MCPContentItem] }
struct MCPTool: Codable, Sendable { let name: String; let description: String; let inputSchema: [String: JSONValue] }
struct MCPToolsResult: Codable, Sendable { let tools: [MCPTool] }
struct MCPInitializeResult: Codable, Sendable { let protocolVersion: String; let capabilities: MCPCapabilities; let serverInfo: MCPServerInfo }
struct MCPCapabilities: Codable, Sendable { let tools: [String: JSONValue] }
struct MCPServerInfo: Codable, Sendable { let name: String; let version: String }
struct PlayNoteRequest: Codable, Sendable { let pitch: String; let duration: Double?; let velocity: Int? }
struct PlayNoteResponse: Codable, Sendable { let status: String; let pitch: String; let duration: Double; let velocity: Int }

// MARK: - HTTP Server

@MainActor
class HTTPServer: ObservableObject {
    private var listener: NWListener?
    private let port: UInt16 = 3001
    private let host = "127.0.0.1"
    private let audioManager: AudioManager

    @Published var isRunning = false
    @Published var lastError: String?

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
    }

    func start() async throws {
        guard !isRunning else { return }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = false

        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            guard let listener = listener else { throw NSError(domain: "HTTPServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create listener"]) }

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in await self?.handleConnection(connection) }
            }

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        print("🚀 HTTP Server started on \(self?.host ?? "127.0.0.1"):\(self?.port ?? 27272)")
                        try? await self?.writeConfigFile()
                    case .failed(let error):
                        self?.lastError = "Server failed: \(error.localizedDescription)"
                        self?.isRunning = false
                        print("❌ HTTP Server failed: \(error.localizedDescription)")
                    case .cancelled:
                        self?.isRunning = false
                        print("🛑 HTTP Server stopped")
                    default:
                        break
                    }
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
        } catch {
            lastError = "Failed to start server: \(error.localizedDescription)"
            throw error
        }
    }

    func stop() async {
        listener?.cancel()
        listener = nil
        isRunning = false
        try? await removeConfigFile()
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) async {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                if let data = data, !data.isEmpty {
                    await self?.processHTTPRequest(data, connection: connection)
                } else if let error = error {
                    print("❌ Connection error: \(error)")
                }
                if isComplete {
                    connection.cancel()
                }
            }
        }
    }

    private func processHTTPRequest(_ data: Data, connection: NWConnection) async {
        guard let httpString = String(data: data, encoding: .utf8) else {
            await sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        let lines = httpString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, let bodyStartIndex = httpString.range(of: "\r\n\r\n")?.upperBound else {
            await sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 3 else {
            await sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }

        let (method, path, body) = (components[0], components[1], String(httpString[bodyStartIndex...]))

        switch (method, path) {
        case ("POST", "/"): await handleJSONRPC(body: body, connection: connection)
        case ("POST", "/play_note"): await handlePlayNote(body: body, connection: connection)
        case ("GET", "/health"): await sendHTTPResponse(connection: connection, statusCode: 200, headers: ["Content-Type": "application/json"], body: #"{"status":"healthy","port":\#(port)}"#)
        default: await sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }

    // MARK: - JSON-RPC Handler

    private func handleJSONRPC(body: String, connection: NWConnection) async {
        do {
            guard let bodyData = body.data(using: .utf8) else { throw JSONRPCError.parseError }
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: bodyData)
            guard request.jsonrpc == "2.0" else { throw JSONRPCError.invalidRequest }

            let response: JSONRPCResponse
            switch request.method {
            case "initialize":
                let initResult = MCPInitializeResult(protocolVersion: "2024-11-05", capabilities: MCPCapabilities(tools: [:]), serverInfo: MCPServerInfo(name: "mcp-play-http", version: "1.0.0"))
                response = JSONRPCResponse(result: try encodeToJSONValue(initResult), id: request.id)
            case "notifications/initialized":
                await sendHTTPResponse(connection: connection, statusCode: 200, body: "")
                return
            case "tools/list":
                let result = MCPToolsResult(tools: getToolDefinitions())
                response = JSONRPCResponse(result: try encodeToJSONValue(result), id: request.id)
            case "tools/call":
                response = try await handleToolCall(request)
            case "resources/list":
                response = JSONRPCResponse(result: .object(["resources": .array([])]), id: request.id)
            case "prompts/list":
                response = JSONRPCResponse(result: .object(["prompts": .array([])]), id: request.id)
            default:
                response = JSONRPCResponse(error: .methodNotFound, id: request.id)
            }
            await sendJSONRPCResponse(response, connection: connection)
        } catch let error as JSONRPCError {
            await sendJSONRPCResponse(JSONRPCResponse(error: error, id: nil), connection: connection)
        } catch is DecodingError {
            await sendJSONRPCResponse(JSONRPCResponse(error: .parseError, id: nil), connection: connection)
        } catch {
            await sendJSONRPCResponse(JSONRPCResponse(error: .internalError, id: nil), connection: connection)
        }
    }

    private func handleToolCall(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        guard let params = request.params, let toolName = params.objectValue?["name"]?.stringValue else {
            return JSONRPCResponse(error: .invalidParams, id: request.id)
        }

        do {
            let result: MCPResult
            let arguments = params.objectValue?["arguments"] ?? .object([:])
            let data = try JSONEncoder().encode(arguments)
            let decoder = JSONDecoder()

            switch toolName {
            case "play_sequence":
                let sequence = try decoder.decode(MusicSequence.self, from: data)
                result = try await handlePlaySequence(sequence: sequence)
            case "list_instruments":
                result = handleListInstruments()
            case "stop":
                result = handleStop()
            default:
                throw JSONRPCError.serverError("Unknown tool: \(toolName)")
            }
            return JSONRPCResponse(result: try encodeToJSONValue(result), id: request.id)
        } catch is DecodingError {
             return JSONRPCResponse(error: .invalidParams, id: request.id)
        } catch let error as JSONRPCError {
            return JSONRPCResponse(error: error, id: request.id)
        } catch {
            let serverError = JSONRPCError.serverError("Tool execution failed: \(error.localizedDescription)")
            return JSONRPCResponse(error: serverError, id: request.id)
        }
    }

    // MARK: - Tool Implementations

    private func handlePlaySequence(sequence: MusicSequence) async throws -> MCPResult {
        let validInstruments = getValidInstrumentNames()
        for track in sequence.tracks where !validInstruments.contains(track.instrument) {
            throw JSONRPCError.serverError("Invalid instrument \"\(track.instrument)\". Use list_instruments for options.")
        }

        var sequenceDict: [String: Any] = [:]
        sequenceDict["version"] = sequence.version
        sequenceDict["title"] = sequence.title
        sequenceDict["tempo"] = sequence.tempo

        sequenceDict["tracks"] = sequence.tracks.map { track -> [String: Any] in
            var trackDict: [String: Any] = ["instrument": track.instrument, "name": track.name]
            trackDict["events"] = track.events.map { event -> [String: Any] in
                return [
                    "time": event.time,
                    "duration": event.duration,
                    "velocity": event.velocity ?? 100,
                    "pitches": event.pitches.map { String($0.midiValue) }
                ]
            }
            return trackDict
        }

        let jsonData = try JSONSerialization.data(withJSONObject: sequenceDict)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw JSONRPCError.serverError("Failed to serialize sequence for audio manager.")
        }
        audioManager.playSequenceFromJSON(jsonString)

        let totalEvents = sequence.tracks.reduce(0) { $0 + $1.events.count }
        let summary = "Playing music sequence at \(Int(sequence.tempo)) BPM with \(totalEvents) event\(totalEvents == 1 ? "" : "s")."
        return MCPResult(content: [MCPContentItem(type: "text", text: summary)])
    }

    private func handleListInstruments() -> MCPResult {
        let instruments = getInstrumentsData()
        var output = "Available Instruments:\n\n"
        let categories = instruments.map { category, list in
            "**\(category):**\n" + list.map { "- \($0.name) (\($0.display))" }.joined(separator: "\n")
        }.joined(separator: "\n\n")
        output += categories
        output += "\n\nUse the instrument 'name' (left side) in your track definitions."
        return MCPResult(content: [MCPContentItem(type: "text", text: output)])
    }

    private func handleStop() -> MCPResult {
        audioManager.stopSequence()
        return MCPResult(content: [MCPContentItem(type: "text", text: "Stopped playback")])
    }

    // MARK: - Simple Note Endpoint

    private func handlePlayNote(body: String, connection: NWConnection) async {
        do {
            guard let bodyData = body.data(using: .utf8) else { throw URLError(.badServerResponse) }
            let noteReq = try JSONDecoder().decode(PlayNoteRequest.self, from: bodyData)
            let duration = noteReq.duration ?? 1.0
            let velocity = noteReq.velocity ?? 100
            let midiNote = NoteNameConverter.toMIDI(noteReq.pitch)
            audioManager.playNote(midiNote: UInt8(midiNote))
            Task {
                try? await Task.sleep(for: .seconds(duration))
                await MainActor.run { audioManager.stopNote(midiNote: UInt8(midiNote)) }
            }
            let response = PlayNoteResponse(status: "playing", pitch: noteReq.pitch, duration: duration, velocity: velocity)
            let responseData = try JSONEncoder().encode(response)
            let responseBody = String(data: responseData, encoding: .utf8) ?? "{}"
            await sendHTTPResponse(connection: connection, statusCode: 200, headers: ["Content-Type": "application/json"], body: responseBody)
        } catch {
            await sendHTTPResponse(connection: connection, statusCode: 400, body: "Invalid request: \(error.localizedDescription)")
        }
    }

    // MARK: - HTTP & JSON Helpers

    private func sendHTTPResponse(connection: NWConnection, statusCode: Int, headers: [String: String] = [:], body: String) async {
        var responseString = "HTTP/1.1 \(statusCode) \(httpStatusMessage(statusCode))\r\n"
        responseString += "Connection: close\r\n"
        responseString += "Content-Length: \(body.utf8.count)\r\n"
        for (key, value) in headers {
            responseString += "\(key): \(value)\r\n"
        }
        responseString += "\r\n\(body)"

        if let data = responseString.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
        } else {
            connection.cancel()
        }
    }

    private func sendJSONRPCResponse(_ response: JSONRPCResponse, connection: NWConnection) async {
        do {
            let responseData = try JSONEncoder().encode(response)
            let responseBody = String(data: responseData, encoding: .utf8) ?? "{}"
            await sendHTTPResponse(connection: connection, statusCode: 200, headers: ["Content-Type": "application/json"], body: responseBody)
        } catch {
            await sendHTTPResponse(connection: connection, statusCode: 500, body: "Internal Server Error")
        }
    }

    private func httpStatusMessage(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }

    private func encodeToJSONValue<T: Codable>(_ value: T) throws -> JSONValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    // MARK: - Configuration File

    private func getConfigFilePath() -> URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return supportDir.appendingPathComponent("MCP Play/server.json")
    }

    private func writeConfigFile() async throws {
        let configPath = getConfigFilePath()
        try FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        let config: [String: Any] = ["port": port, "host": host, "status": "running", "pid": ProcessInfo.processInfo.processIdentifier]
        let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try jsonData.write(to: configPath)
        print("📝 Config written to: \(configPath.path)")
    }

    private func removeConfigFile() async throws {
        let configPath = getConfigFilePath()
        if FileManager.default.fileExists(atPath: configPath.path) {
            try FileManager.default.removeItem(at: configPath)
        }
    }

    // MARK: - Tool Definitions & Instruments Data

    private func getToolDefinitions() -> [MCPTool] {
        return [
            MCPTool(
                name: "play_sequence",
                description: "Play a music sequence from JSON data",
                inputSchema: [
                    "type": .string("object"),
                    "properties": .object([
                        "tempo": .object([
                            "type": .string("number"),
                            "description": .string("BPM (beats per minute)")
                        ]),
                        "tracks": .object([
                            "type": .string("array"),
                            "description": .string("Array of track objects"),
                            "items": .object([
                                "type": .string("object"),
                                "properties": .object([
                                    "instrument": .object([
                                        "type": .string("string"),
                                        "description": .string("Instrument name (e.g., 'acoustic_grand_piano')")
                                    ]),
                                    "events": .object([
                                        "type": .string("array"),
                                        "description": .string("Array of musical events"),
                                        "items": .object([
                                            "type": .string("object"),
                                            "properties": .object([
                                                "time": .object(["type": .string("number")]),
                                                "pitches": .object(["type": .string("array"), "items": .object(["oneOf": .array([.object(["type": .string("number")]), .object(["type": .string("string")])])])]),
                                                "duration": .object(["type": .string("number")]),
                                                "velocity": .object(["type": .string("number")])
                                            ]),
                                            "required": .array([.string("time"), .string("pitches"), .string("duration")])
                                        ])
                                    ])
                                ]),
                                "required": .array([.string("events")])
                            ])
                        ])
                    ]),
                    "required": .array([.string("tempo"), .string("tracks")])
                ]
            ),
            MCPTool(
                name: "list_instruments",
                description: "List all available instruments",
                inputSchema: ["type": .string("object"), "properties": .object([:])]
            ),
            MCPTool(
                name: "stop",
                description: "Stop any currently playing music",
                inputSchema: ["type": .string("object"), "properties": .object([:])]
            )
        ]
    }

    private func getInstrumentsData() -> [String: [(name: String, display: String)]] {
        return [
            "Piano": [("acoustic_grand_piano", "Acoustic Grand Piano"), ("bright_acoustic_piano", "Bright Acoustic Piano"), ("electric_grand_piano", "Electric Grand Piano"), ("honky_tonk_piano", "Honky Tonk Piano"), ("electric_piano_1", "Electric Piano 1"), ("electric_piano_2", "Electric Piano 2"), ("harpsichord", "Harpsichord"), ("clavinet", "Clavinet")],
            "Percussion": [("celesta", "Celesta"), ("glockenspiel", "Glockenspiel"), ("music_box", "Music Box"), ("vibraphone", "Vibraphone"), ("marimba", "Marimba"), ("xylophone", "Xylophone"), ("tubular_bells", "Tubular Bells"), ("dulcimer", "Dulcimer")],
            "Organ": [("drawbar_organ", "Drawbar Organ"), ("percussive_organ", "Percussive Organ"), ("rock_organ", "Rock Organ"), ("church_organ", "Church Organ"), ("reed_organ", "Reed Organ"), ("accordion", "Accordion"), ("harmonica", "Harmonica"), ("tango_accordion", "Tango Accordion")],
            "Guitar": [("acoustic_guitar_nylon", "Acoustic Guitar (Nylon)"), ("acoustic_guitar_steel", "Acoustic Guitar (Steel)"), ("electric_guitar_jazz", "Electric Guitar (Jazz)"), ("electric_guitar_clean", "Electric Guitar (Clean)"), ("electric_guitar_muted", "Electric Guitar (Muted)"), ("overdriven_guitar", "Overdriven Guitar"), ("distortion_guitar", "Distortion Guitar"), ("guitar_harmonics", "Guitar Harmonics")],
            "Bass": [("acoustic_bass", "Acoustic Bass"), ("electric_bass_finger", "Electric Bass (Finger)"), ("electric_bass_pick", "Electric Bass (Pick)"), ("fretless_bass", "Fretless Bass"), ("slap_bass_1", "Slap Bass 1"), ("slap_bass_2", "Slap Bass 2"), ("synth_bass_1", "Synth Bass 1"), ("synth_bass_2", "Synth Bass 2")],
            "Strings": [("violin", "Violin"), ("viola", "Viola"), ("cello", "Cello"), ("contrabass", "Contrabass"), ("tremolo_strings", "Tremolo Strings"), ("pizzicato_strings", "Pizzicato Strings"), ("orchestral_harp", "Orchestral Harp"), ("timpani", "Timpani"), ("string_ensemble_1", "String Ensemble 1"), ("string_ensemble_2", "String Ensemble 2"), ("synth_strings_1", "Synth Strings 1"), ("synth_strings_2", "Synth Strings 2")],
            "Brass": [("trumpet", "Trumpet"), ("trombone", "Trombone"), ("tuba", "Tuba"), ("muted_trumpet", "Muted Trumpet"), ("french_horn", "French Horn"), ("brass_section", "Brass Section"), ("synth_brass_1", "Synth Brass 1"), ("synth_brass_2", "Synth Brass 2")],
            "Woodwinds": [("soprano_sax", "Soprano Sax"), ("alto_sax", "Alto Sax"), ("tenor_sax", "Tenor Sax"), ("baritone_sax", "Baritone Sax"), ("oboe", "Oboe"), ("english_horn", "English Horn"), ("bassoon", "Bassoon"), ("clarinet", "Clarinet"), ("piccolo", "Piccolo"), ("flute", "Flute"), ("recorder", "Recorder"), ("pan_flute", "Pan Flute"), ("blown_bottle", "Blown Bottle"), ("shakuhachi", "Shakuhachi"), ("whistle", "Whistle"), ("ocarina", "Ocarina")],
            "Choir": [("choir_aahs", "Choir Aahs"), ("voice_oohs", "Voice Oohs"), ("synth_voice", "Synth Voice"), ("orchestra_hit", "Orchestra Hit")]
        ]
    }

    private func getValidInstrumentNames() -> [String] {
        return getInstrumentsData().values.flatMap { category in category.map { $0.name } }
    }
}
