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
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, 
                DecodingError.Context(codingPath: decoder.codingPath, 
                                    debugDescription: "Invalid JSON value"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
    
    // Helper accessors
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }
    
    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        if case .int(let value) = self { return Double(value) }
        return nil
    }
    
    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }
    
    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }
}

// MARK: - MCP Response Models

struct MCPContentItem: Codable, Sendable {
    let type: String
    let text: String
}

struct MCPResult: Codable, Sendable {
    let content: [MCPContentItem]
}

struct MCPTool: Codable, Sendable {
    let name: String
    let description: String
    let inputSchema: [String: JSONValue]
}

struct MCPToolsResult: Codable, Sendable {
    let tools: [MCPTool]
}

struct MCPInitializeResult: Codable, Sendable {
    let protocolVersion: String
    let capabilities: MCPCapabilities
    let serverInfo: MCPServerInfo
}

struct MCPCapabilities: Codable, Sendable {
    let tools: [String: JSONValue]
}

struct MCPServerInfo: Codable, Sendable {
    let name: String
    let version: String
}

struct PlayNoteRequest: Codable, Sendable {
    let pitch: String
    let duration: Double?
    let velocity: Int?
}

struct PlayNoteResponse: Codable, Sendable {
    let status: String
    let pitch: String
    let duration: Double
    let velocity: Int
}

// MARK: - HTTP Server

@MainActor
class HTTPServer: ObservableObject {
    private var listener: NWListener?
    private let port: UInt16 = 27272
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
            guard let listener = listener else {
                throw NSError(domain: "HTTPServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create listener"])
            }
            
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    await self?.handleConnection(connection)
                }
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
        
        // Read HTTP request
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
        guard let requestLine = lines.first else {
            await sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 3 else {
            await sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }
        
        let method = components[0]
        let path = components[1]
        
        // Find request body
        var body = ""
        if let bodyStartIndex = httpString.range(of: "\r\n\r\n")?.upperBound {
            body = String(httpString[bodyStartIndex...])
        }
        
        // Route request
        switch (method, path) {
        case ("POST", "/"):
            await handleJSONRPC(body: body, connection: connection)
        case ("POST", "/play_note"):
            await handlePlayNote(body: body, connection: connection)
        case ("GET", "/health"):
            await sendHTTPResponse(connection: connection, statusCode: 200, 
                                 headers: ["Content-Type": "application/json"],
                                 body: #"{"status":"healthy","port":\#(port)}"#)
        default:
            await sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }
    
    // MARK: - JSON-RPC Handler
    
    private func handleJSONRPC(body: String, connection: NWConnection) async {
        do {
            guard let bodyData = body.data(using: .utf8) else {
                throw JSONRPCError.parseError
            }
            
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: bodyData)
            
            guard request.jsonrpc == "2.0" else {
                let response = JSONRPCResponse(error: .invalidRequest, id: request.id)
                await sendJSONRPCResponse(response, connection: connection)
                return
            }
            
            let response: JSONRPCResponse
            
            switch request.method {
            case "initialize":
                response = try handleInitialize(request)
                
            case "notifications/initialized":
                // MCP initialized notification - no response needed for notifications
                // Send HTTP 200 but no JSON-RPC response for notifications
                await sendHTTPResponse(connection: connection, statusCode: 200, body: "")
                return
                
            case "tools/list":
                let tools = getToolDefinitions()
                let result = MCPToolsResult(tools: tools)
                let jsonValue = try encodeToJSONValue(result)
                response = JSONRPCResponse(result: jsonValue, id: request.id)
                
            case "tools/call":
                response = try await handleToolCall(request)
                
            case "resources/list":
                // Return empty resources list
                let emptyResult = ["resources": JSONValue.array([])]
                let jsonValue = JSONValue.object(emptyResult)
                response = JSONRPCResponse(result: jsonValue, id: request.id)
                
            case "prompts/list":
                // Return empty prompts list  
                let emptyResult = ["prompts": JSONValue.array([])]
                let jsonValue = JSONValue.object(emptyResult)
                response = JSONRPCResponse(result: jsonValue, id: request.id)
                
            default:
                response = JSONRPCResponse(error: .methodNotFound, id: request.id)
            }
            
            await sendJSONRPCResponse(response, connection: connection)
            
        } catch {
            let errorResponse = JSONRPCResponse(error: .parseError, id: nil)
            await sendJSONRPCResponse(errorResponse, connection: connection)
        }
    }
    
    private func handleInitialize(_ request: JSONRPCRequest) throws -> JSONRPCResponse {
        let initResult = MCPInitializeResult(
            protocolVersion: "2024-11-05",
            capabilities: MCPCapabilities(tools: [:]),
            serverInfo: MCPServerInfo(name: "mcp-play-http", version: "1.0.0")
        )
        
        let jsonValue = try encodeToJSONValue(initResult)
        return JSONRPCResponse(result: jsonValue, id: request.id)
    }
    
    private func handleToolCall(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        guard let params = request.params?.objectValue,
              let toolName = params["name"]?.stringValue else {
            return JSONRPCResponse(error: .invalidParams, id: request.id)
        }
        
        let arguments = params["arguments"]?.objectValue ?? [:]
        
        do {
            let result = try await callTool(name: toolName, arguments: arguments)
            let jsonValue = try encodeToJSONValue(result)
            return JSONRPCResponse(result: jsonValue, id: request.id)
        } catch let error as JSONRPCError {
            return JSONRPCResponse(error: error, id: request.id)
        } catch {
            let serverError = JSONRPCError.serverError("Tool execution failed: \(error.localizedDescription)")
            return JSONRPCResponse(error: serverError, id: request.id)
        }
    }
    
    // MARK: - Tool Implementations
    
    private func callTool(name: String, arguments: [String: JSONValue]) async throws -> MCPResult {
        switch name {
        case "play_sequence":
            return try await handlePlaySequence(arguments)
        case "list_instruments":
            return handleListInstruments()
        case "stop":
            return handleStop()
        default:
            throw JSONRPCError.serverError("Unknown tool: \(name)")
        }
    }
    
    private func handlePlaySequence(_ arguments: [String: JSONValue]) async throws -> MCPResult {
        // Validate sequence structure
        guard !arguments.isEmpty else {
            throw JSONRPCError.invalidParams
        }
        
        guard let tempo = arguments["tempo"]?.doubleValue else {
            throw JSONRPCError.serverError("Invalid sequence: tempo must be a number")
        }
        
        guard let tracksArray = arguments["tracks"]?.arrayValue, !tracksArray.isEmpty else {
            throw JSONRPCError.serverError("Invalid sequence: tracks must be a non-empty array")
        }
        
        // Validate instruments
        let validInstruments = getValidInstrumentNames()
        
        // Convert to dictionary for AudioManager
        var sequence: [String: Any] = [:]
        sequence["version"] = arguments["version"]?.intValue ?? 1
        sequence["title"] = arguments["title"]?.stringValue
        sequence["tempo"] = tempo
        
        var tracks: [[String: Any]] = []
        for (index, track) in tracksArray.enumerated() {
            guard let trackObj = track.objectValue else {
                throw JSONRPCError.serverError("Invalid track \(index): must be an object")
            }
            
            var trackDict: [String: Any] = [:]
            let instrument = trackObj["instrument"]?.stringValue ?? "acoustic_grand_piano"
            
            if !validInstruments.contains(instrument) {
                throw JSONRPCError.serverError("Invalid track \(index): instrument \"\(instrument)\" is not available. Use list_instruments tool to see valid options.")
            }
            
            trackDict["instrument"] = instrument
            trackDict["name"] = trackObj["name"]?.stringValue
            
            guard let eventsArray = trackObj["events"]?.arrayValue else {
                throw JSONRPCError.serverError("Invalid track \(index): events must be an array")
            }
            
            var events: [[String: Any]] = []
            for event in eventsArray {
                guard let eventObj = event.objectValue else { continue }
                
                var eventDict: [String: Any] = [:]
                eventDict["time"] = eventObj["time"]?.doubleValue ?? 0.0
                eventDict["duration"] = eventObj["duration"]?.doubleValue ?? 1.0
                eventDict["velocity"] = eventObj["velocity"]?.intValue ?? 100
                
                if let pitchesArray = eventObj["pitches"]?.arrayValue {
                    let pitches = pitchesArray.compactMap { pitch -> String? in
                        if let stringPitch = pitch.stringValue {
                            return stringPitch
                        } else if let intPitch = pitch.intValue {
                            return String(intPitch)
                        }
                        return nil
                    }
                    eventDict["pitches"] = pitches
                }
                
                events.append(eventDict)
            }
            
            trackDict["events"] = events
            tracks.append(trackDict)
        }
        
        sequence["tracks"] = tracks
        
        // Convert to JSON and play using existing AudioManager
        let jsonData = try JSONSerialization.data(withJSONObject: sequence)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw JSONRPCError.serverError("Failed to serialize sequence")
        }
        
        // Call AudioManager on main actor
        audioManager.playSequenceFromJSON(jsonString)
        
        // Generate summary
        let totalEvents = tracks.reduce(0) { sum, track in
            if let events = track["events"] as? [Any] {
                return sum + events.count
            }
            return sum
        }
        
        let summary = "Playing music sequence at \(Int(tempo)) BPM with \(totalEvents) event\(totalEvents == 1 ? "" : "s")" +
                     (tracks.count > 1 ? " across \(tracks.count) tracks" : "")
        
        return MCPResult(content: [MCPContentItem(type: "text", text: summary)])
    }
    
    private func handleListInstruments() -> MCPResult {
        let instruments = getInstrumentsData()
        var output = "Available Instruments:\n\n"
        
        for (category, categoryInstruments) in instruments {
            output += "**\(category):**\n"
            for instrument in categoryInstruments {
                output += "- \(instrument.name) (\(instrument.display))\n"
            }
            output += "\n"
        }
        
        output += "Use the instrument 'name' (left side) in your track definitions."
        
        return MCPResult(content: [MCPContentItem(type: "text", text: output)])
    }
    
    private func handleStop() -> MCPResult {
        audioManager.stopSequence()
        return MCPResult(content: [MCPContentItem(type: "text", text: "Stopped playback")])
    }
    
    // MARK: - Simple Note Endpoint
    
    private func handlePlayNote(body: String, connection: NWConnection) async {
        do {
            guard let bodyData = body.data(using: .utf8) else {
                await sendHTTPResponse(connection: connection, statusCode: 400, body: "Invalid JSON")
                return
            }
            
            let noteReq = try JSONDecoder().decode(PlayNoteRequest.self, from: bodyData)
            let duration = noteReq.duration ?? 1.0
            let velocity = noteReq.velocity ?? 100
            
            // Convert pitch to MIDI
            let midiNote = NoteNameConverter.toMIDI(noteReq.pitch)
            
            // Play note using AudioManager
            audioManager.playNote(midiNote: UInt8(midiNote))
            
            // Schedule note stop
            Task {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await MainActor.run {
                    audioManager.stopNote(midiNote: UInt8(midiNote))
                }
            }
            
            let response = PlayNoteResponse(
                status: "playing",
                pitch: noteReq.pitch,
                duration: duration,
                velocity: velocity
            )
            
            let responseData = try JSONEncoder().encode(response)
            let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
            
            await sendHTTPResponse(connection: connection, statusCode: 200,
                                 headers: ["Content-Type": "application/json"],
                                 body: responseString)
            
        } catch {
            await sendHTTPResponse(connection: connection, statusCode: 400, 
                                 body: "Invalid request: \(error.localizedDescription)")
        }
    }
    
    // MARK: - HTTP Response Helpers
    
    private func sendHTTPResponse(connection: NWConnection, statusCode: Int, 
                                headers: [String: String] = [:], body: String) async {
        var response = "HTTP/1.1 \(statusCode) \(httpStatusMessage(statusCode))\r\n"
        response += "Content-Length: \(body.utf8.count)\r\n"
        response += "Connection: close\r\n"
        
        for (key, value) in headers {
            response += "\(key): \(value)\r\n"
        }
        
        response += "\r\n\(body)"
        
        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { _ in
                connection.cancel()
            })
        } else {
            connection.cancel()
        }
    }
    
    private func sendJSONRPCResponse(_ response: JSONRPCResponse, connection: NWConnection) async {
        do {
            let responseData = try JSONEncoder().encode(response)
            let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
            
            await sendHTTPResponse(connection: connection, statusCode: 200,
                                 headers: ["Content-Type": "application/json"],
                                 body: responseString)
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
    
    // MARK: - Configuration File
    
    private func getConfigFilePath() -> URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory,
                                                in: .userDomainMask).first!
        let appSupportDir = supportDir.appendingPathComponent("MCP Play")
        return appSupportDir.appendingPathComponent("server.json")
    }
    
    private func writeConfigFile() async throws {
        let configPath = getConfigFilePath()
        let configDir = configPath.deletingLastPathComponent()
        
        // Create directory if needed
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        let config = [
            "port": port,
            "host": host,
            "status": "running",
            "pid": ProcessInfo.processInfo.processIdentifier
        ] as [String : Any]
        
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
    
    // MARK: - JSON Encoding Helper
    
    private func encodeToJSONValue<T: Codable>(_ value: T) throws -> JSONValue {
        let data = try JSONEncoder().encode(value)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        return try convertToJSONValue(jsonObject)
    }
    
    private func convertToJSONValue(_ object: Any) throws -> JSONValue {
        switch object {
        case is NSNull:
            return .null
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            let jsonArray = try array.map { try convertToJSONValue($0) }
            return .array(jsonArray)
        case let dict as [String: Any]:
            var jsonDict: [String: JSONValue] = [:]
            for (key, value) in dict {
                jsonDict[key] = try convertToJSONValue(value)
            }
            return .object(jsonDict)
        default:
            throw JSONRPCError.serverError("Unsupported JSON type")
        }
    }
}

// MARK: - Tool Definitions & Instruments Data

extension HTTPServer {
    private func getToolDefinitions() -> [MCPTool] {
        return [
            MCPTool(
                name: "play_sequence",
                description: "Play a music sequence directly from JSON data",
                inputSchema: [
                    "type": .string("object"),
                    "properties": .object([
                        "version": .object([
                            "type": .string("number"),
                            "description": .string("Schema version (always use 1)")
                        ]),
                        "title": .object([
                            "type": .string("string"),
                            "description": .string("Optional title for the sequence")
                        ]),
                        "tempo": .object([
                            "type": .string("number"),
                            "description": .string("BPM (beats per minute), typically 60-200")
                        ]),
                        "tracks": .object([
                            "type": .string("array"),
                            "description": .string("Array of track objects"),
                            "items": .object([
                                "type": .string("object"),
                                "properties": .object([
                                    "instrument": .object([
                                        "type": .string("string"),
                                        "description": .string("Instrument name (e.g., \"acoustic_grand_piano\", \"string_ensemble_1\")")
                                    ]),
                                    "name": .object([
                                        "type": .string("string"),
                                        "description": .string("Optional track name or description")
                                    ]),
                                    "events": .object([
                                        "type": .string("array"),
                                        "description": .string("Array of musical events for this track"),
                                        "items": .object([
                                            "type": .string("object"),
                                            "properties": .object([
                                                "time": .object([
                                                    "type": .string("number"),
                                                    "description": .string("Start time in beats (0.0, 1.0, 2.5, etc.)")
                                                ]),
                                                "pitches": .object([
                                                    "type": .string("array"),
                                                    "description": .string("MIDI numbers (0-127) or note names like \"C4\", \"F#3\""),
                                                    "items": .object([
                                                        "oneOf": .array([
                                                            .object(["type": .string("number")]),
                                                            .object(["type": .string("string")])
                                                        ])
                                                    ])
                                                ]),
                                                "duration": .object([
                                                    "type": .string("number"),
                                                    "description": .string("Length in beats (1.0 = quarter note, 0.5 = eighth note)")
                                                ]),
                                                "velocity": .object([
                                                    "type": .string("number"),
                                                    "description": .string("Volume 0-127 (optional, defaults to 100)")
                                                ])
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
                description: "List all available instruments organized by category",
                inputSchema: [
                    "type": .string("object"),
                    "properties": .object([:])
                ]
            ),
            MCPTool(
                name: "stop",
                description: "Stop any currently playing music",
                inputSchema: [
                    "type": .string("object"),
                    "properties": .object([:])
                ]
            )
        ]
    }
    
    private func getInstrumentsData() -> [String: [(name: String, display: String)]] {
        return [
            "Piano": [
                (name: "acoustic_grand_piano", display: "Acoustic Grand Piano"),
                (name: "bright_acoustic_piano", display: "Bright Acoustic Piano"),
                (name: "electric_grand_piano", display: "Electric Grand Piano"),
                (name: "honky_tonk_piano", display: "Honky Tonk Piano"),
                (name: "electric_piano_1", display: "Electric Piano 1"),
                (name: "electric_piano_2", display: "Electric Piano 2"),
                (name: "harpsichord", display: "Harpsichord"),
                (name: "clavinet", display: "Clavinet")
            ],
            "Percussion": [
                (name: "celesta", display: "Celesta"),
                (name: "glockenspiel", display: "Glockenspiel"),
                (name: "music_box", display: "Music Box"),
                (name: "vibraphone", display: "Vibraphone"),
                (name: "marimba", display: "Marimba"),
                (name: "xylophone", display: "Xylophone"),
                (name: "tubular_bells", display: "Tubular Bells"),
                (name: "dulcimer", display: "Dulcimer")
            ],
            "Organ": [
                (name: "drawbar_organ", display: "Drawbar Organ"),
                (name: "percussive_organ", display: "Percussive Organ"),
                (name: "rock_organ", display: "Rock Organ"),
                (name: "church_organ", display: "Church Organ"),
                (name: "reed_organ", display: "Reed Organ"),
                (name: "accordion", display: "Accordion"),
                (name: "harmonica", display: "Harmonica"),
                (name: "tango_accordion", display: "Tango Accordion")
            ],
            "Guitar": [
                (name: "acoustic_guitar_nylon", display: "Acoustic Guitar (Nylon)"),
                (name: "acoustic_guitar_steel", display: "Acoustic Guitar (Steel)"),
                (name: "electric_guitar_jazz", display: "Electric Guitar (Jazz)"),
                (name: "electric_guitar_clean", display: "Electric Guitar (Clean)"),
                (name: "electric_guitar_muted", display: "Electric Guitar (Muted)"),
                (name: "overdriven_guitar", display: "Overdriven Guitar"),
                (name: "distortion_guitar", display: "Distortion Guitar"),
                (name: "guitar_harmonics", display: "Guitar Harmonics")
            ],
            "Bass": [
                (name: "acoustic_bass", display: "Acoustic Bass"),
                (name: "electric_bass_finger", display: "Electric Bass (Finger)"),
                (name: "electric_bass_pick", display: "Electric Bass (Pick)"),
                (name: "fretless_bass", display: "Fretless Bass"),
                (name: "slap_bass_1", display: "Slap Bass 1"),
                (name: "slap_bass_2", display: "Slap Bass 2"),
                (name: "synth_bass_1", display: "Synth Bass 1"),
                (name: "synth_bass_2", display: "Synth Bass 2")
            ],
            "Strings": [
                (name: "violin", display: "Violin"),
                (name: "viola", display: "Viola"),
                (name: "cello", display: "Cello"),
                (name: "contrabass", display: "Contrabass"),
                (name: "tremolo_strings", display: "Tremolo Strings"),
                (name: "pizzicato_strings", display: "Pizzicato Strings"),
                (name: "orchestral_harp", display: "Orchestral Harp"),
                (name: "timpani", display: "Timpani"),
                (name: "string_ensemble_1", display: "String Ensemble 1"),
                (name: "string_ensemble_2", display: "String Ensemble 2"),
                (name: "synth_strings_1", display: "Synth Strings 1"),
                (name: "synth_strings_2", display: "Synth Strings 2")
            ],
            "Brass": [
                (name: "trumpet", display: "Trumpet"),
                (name: "trombone", display: "Trombone"),
                (name: "tuba", display: "Tuba"),
                (name: "muted_trumpet", display: "Muted Trumpet"),
                (name: "french_horn", display: "French Horn"),
                (name: "brass_section", display: "Brass Section"),
                (name: "synth_brass_1", display: "Synth Brass 1"),
                (name: "synth_brass_2", display: "Synth Brass 2")
            ],
            "Woodwinds": [
                (name: "soprano_sax", display: "Soprano Sax"),
                (name: "alto_sax", display: "Alto Sax"),
                (name: "tenor_sax", display: "Tenor Sax"),
                (name: "baritone_sax", display: "Baritone Sax"),
                (name: "oboe", display: "Oboe"),
                (name: "english_horn", display: "English Horn"),
                (name: "bassoon", display: "Bassoon"),
                (name: "clarinet", display: "Clarinet"),
                (name: "piccolo", display: "Piccolo"),
                (name: "flute", display: "Flute"),
                (name: "recorder", display: "Recorder"),
                (name: "pan_flute", display: "Pan Flute"),
                (name: "blown_bottle", display: "Blown Bottle"),
                (name: "shakuhachi", display: "Shakuhachi"),
                (name: "whistle", display: "Whistle"),
                (name: "ocarina", display: "Ocarina")
            ],
            "Choir": [
                (name: "choir_aahs", display: "Choir Aahs"),
                (name: "voice_oohs", display: "Voice Oohs"),
                (name: "synth_voice", display: "Synth Voice"),
                (name: "orchestra_hit", display: "Orchestra Hit")
            ]
        ]
    }
    
    private func getValidInstrumentNames() -> [String] {
        let instruments = getInstrumentsData()
        return instruments.values.flatMap { categoryInstruments in
            categoryInstruments.map { $0.name }
        }
    }
}