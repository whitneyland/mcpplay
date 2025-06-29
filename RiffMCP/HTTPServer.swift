//
//  HTTPServer.swift
//  RiffMCP
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
struct PlayNoteRequest: Codable, Sendable { let pitch: String; let dur: Double?; let vel: Int? }
struct PlayNoteResponse: Codable, Sendable { let status: String; let pitch: String; let dur: Double; let vel: Int }

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
                        ActivityLog.shared.updateServerStatus(online: true)
                        ActivityLog.shared.add(message: "Server listening on port \(self?.port ?? 0)", type: .success)
                        try? await self?.writeConfigFile()
                    case .failed(let error):
                        self?.lastError = "Server failed: \(error.localizedDescription)"
                        self?.isRunning = false
                        print("❌ HTTP Server failed: \(error.localizedDescription)")
                        ActivityLog.shared.updateServerStatus(online: false)
                        ActivityLog.shared.add(message: "Server failed: \(error.localizedDescription)", type: .error)
                    case .cancelled:
                        self?.isRunning = false
                        print("🛑 HTTP Server stopped")
                        ActivityLog.shared.updateServerStatus(online: false)
                        ActivityLog.shared.add(message: "Server stopped", type: .success)
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
        let requestStartTime = Date()
        Util.logLatency("🌐", "HTTP request received")
        
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
        
        // Extract User-Agent from headers
        let userAgent = lines.first(where: { $0.lowercased().starts(with: "user-agent:") })?
            .components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces) ?? "Unknown"
        let bodySize = body.data(using: .utf8)?.count ?? 0

        Util.logLatency("🚦", "Request routing - \(method) \(path)", since: requestStartTime)

        switch (method, path) {
        case ("POST", "/"): await handleJSONRPC(body: body, connection: connection, userAgent: userAgent, bodySize: bodySize)
        case ("POST", "/play_note"): await handlePlayNote(body: body, connection: connection)
        case ("GET", "/health"): await sendHTTPResponse(connection: connection, statusCode: 200, headers: ["Content-Type": "application/json"], body: #"{"status":"healthy","port":\#(port)}"#)
        default: await sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }

    // MARK: - JSON-RPC Handler

    private func handleJSONRPC(body: String, connection: NWConnection, userAgent: String, bodySize: Int) async {
        let jsonRpcStartTime = Date()
        Util.logLatency("📄", "JSON-RPC processing started")
        
        do {
            guard let bodyData = body.data(using: .utf8) else { throw JSONRPCError.parseError }
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: bodyData)
            guard request.jsonrpc == "2.0" else { throw JSONRPCError.invalidRequest }
            
            // Detailed logging
            var toolNameDetail = ""
            if request.method == "tools/call",
               let params = request.params,
               let name = params.objectValue?["name"]?.stringValue {
                toolNameDetail = " - \(name)"
            }
            
            let eventType: ActivityEvent.EventType
            switch request.method {
            case "notifications/initialized": eventType = .notification
            case "tools/list": eventType = .toolsList
            case "tools/call": eventType = .toolsCall
            case "resources/list": eventType = .resourcesList
            case "prompts/list": eventType = .promptsList
            default: eventType = .request
            }
            
            ActivityLog.shared.add(message: "POST /\(request.method)\(toolNameDetail) (\(bodySize) bytes)", type: eventType, requestData: body)

            Util.logLatency("🔍", "JSON-RPC parsed - method: \(request.method)", since: jsonRpcStartTime)

            let response: JSONRPCResponse
            switch request.method {
            case "initialize":
                let initResult = MCPInitializeResult(protocolVersion: "2024-11-05", capabilities: MCPCapabilities(tools: [:]), serverInfo: MCPServerInfo(name: "riff", version: "1.0.0"))
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
            
            // Update the last event with response data
            do {
                let responseData = try JSONEncoder().encode(response)
                if let responseString = String(data: responseData, encoding: .utf8) {
                    ActivityLog.shared.updateLastEventWithResponse(responseString)
                }
            } catch {
                print("Failed to encode response for logging: \(error)")
            }
        } catch let error as JSONRPCError {
            let errorResponse = JSONRPCResponse(error: error, id: nil)
            await sendJSONRPCResponse(errorResponse, connection: connection)
            
            // Update with error response
            do {
                let responseData = try JSONEncoder().encode(errorResponse)
                if let responseString = String(data: responseData, encoding: .utf8) {
                    ActivityLog.shared.updateLastEventWithResponse(responseString)
                }
            } catch {
                print("Failed to encode error response for logging: \(error)")
            }
        } catch is DecodingError {
            let parseErrorResponse = JSONRPCResponse(error: .parseError, id: nil)
            await sendJSONRPCResponse(parseErrorResponse, connection: connection)
            
            // Update with parse error response
            do {
                let responseData = try JSONEncoder().encode(parseErrorResponse)
                if let responseString = String(data: responseData, encoding: .utf8) {
                    ActivityLog.shared.updateLastEventWithResponse(responseString)
                }
            } catch {
                print("Failed to encode parse error response for logging: \(error)")
            }
        } catch {
            let internalErrorResponse = JSONRPCResponse(error: .internalError, id: nil)
            await sendJSONRPCResponse(internalErrorResponse, connection: connection)
            
            // Update with internal error response
            do {
                let responseData = try JSONEncoder().encode(internalErrorResponse)
                if let responseString = String(data: responseData, encoding: .utf8) {
                    ActivityLog.shared.updateLastEventWithResponse(responseString)
                }
            } catch {
                print("Failed to encode internal error response for logging: \(error)")
            }
        }
    }

    private func handleToolCall(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        let toolCallStartTime = Date()
        Util.logLatency("🔧", "Tool call processing started")
        
        guard let params = request.params, let toolName = params.objectValue?["name"]?.stringValue else {
            return JSONRPCResponse(error: .invalidParams, id: request.id)
        }
        
        Util.logLatency("🎯", "Tool identified: \(toolName)", since: toolCallStartTime)

        do {
            let result: MCPResult
            let arguments = params.objectValue?["arguments"] ?? .object([:])
            
            let data = try JSONEncoder().encode(arguments)
            let decoder = JSONDecoder()

            switch toolName {
            case "play":
                let sequenceDecodeStart = Date()
                let sequence = try decoder.decode(MusicSequence.self, from: data)
                Util.logLatency("🎼", "Sequence decoded", since: sequenceDecodeStart)
                result = try await handlePlaySequence(sequence: sequence)
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
        let playSequenceStartTime = Date()
        Util.logLatency("🎵", "handlePlaySequence started")
        
        let validInstruments = Instruments.getInstrumentNames()
        for track in sequence.tracks where !validInstruments.contains(track.instrument) {
            throw JSONRPCError.serverError("Invalid instrument \"\(track.instrument)\". Check the instrument enum in the schema for valid options.")
        }
        
        Util.logLatency("✅", "Instrument validation completed", since: playSequenceStartTime)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let jsonData = try encoder.encode(sequence)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw JSONRPCError.serverError("Failed to serialize sequence for audio manager.")
        }
        
        Util.logLatency("📝", "Sequence serialized")
        
        Util.logLatency("🎶", "Calling AudioManager.playSequenceFromJSON")
        audioManager.playSequenceFromJSON(jsonString)

        let totalEvents = sequence.tracks.reduce(0) { $0 + $1.events.count }
        let summary = "Playing \(sequence.title ?? "") at \(Int(sequence.tempo)) BPM with \(totalEvents) event\(totalEvents == 1 ? "" : "s")."

        ActivityLog.shared.add(message: "Play \(sequence.title ?? "") with \(totalEvents) notes for \(sequence.tracks.first?.instrument ?? "instrument")", type: .generation, sequenceData: jsonString)

        return MCPResult(content: [MCPContentItem(type: "text", text: summary)])
    }



    // MARK: - Simple Note Endpoint

    private func handlePlayNote(body: String, connection: NWConnection) async {
        do {
            guard let bodyData = body.data(using: .utf8) else { throw URLError(.badServerResponse) }
            let noteReq = try JSONDecoder().decode(PlayNoteRequest.self, from: bodyData)
            let duration = noteReq.dur ?? 1.0
            let velocity = noteReq.vel ?? 100
            let midiNote = NoteNameConverter.toMIDI(noteReq.pitch)
            audioManager.playNote(midiNote: UInt8(midiNote))
            Task {
                try? await Task.sleep(for: .seconds(duration))
                await MainActor.run { audioManager.stopNote(midiNote: UInt8(midiNote)) }
            }
            let response = PlayNoteResponse(status: "playing", pitch: noteReq.pitch, dur: duration, vel: velocity)
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(value)
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
        // Load tool definitions from clean JSON file instead of ugly Swift code
        guard let toolsURL = Bundle.main.url(forResource: "tools", withExtension: "json"),
              let toolsData = try? Data(contentsOf: toolsURL),
              let toolsArray = try? JSONSerialization.jsonObject(with: toolsData) as? [[String: Any]] else {
            print("❌ Failed to load tools.json, falling back to empty array")
            return []
        }
        
        return toolsArray.compactMap { toolDict in
            guard let name = toolDict["name"] as? String,
                  let description = toolDict["description"] as? String,
                  let inputSchema = toolDict["inputSchema"] as? [String: Any] else {
                return nil
            }
            
            // Convert the inputSchema dictionary to JSONValue
            do {
                let schemaData = try JSONSerialization.data(withJSONObject: inputSchema)
                let jsonValue = try JSONDecoder().decode(JSONValue.self, from: schemaData)
                return MCPTool(name: name, description: description, inputSchema: jsonValue.objectValue ?? [:])
            } catch {
                print("❌ Failed to parse inputSchema for tool \(name): \(error)")
                return nil
            }
        }
    }
}
