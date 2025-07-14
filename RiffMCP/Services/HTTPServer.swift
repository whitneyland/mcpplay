//
//  HTTPServer.swift
//  RiffMCP
//
//  Simple HTTP server to handle Model Context Protocol requests
//

import Foundation
import Network

@MainActor
class HTTPServer: ObservableObject {
    private var listener: NWListener?
    private let port: UInt16 = 3001
    private let host = "127.0.0.1"
    private let audioManager: AudioManager
    private let tempDirectory: URL
    private var cachedTools: [MCPTool]?
    private var cachedPrompts: [MCPPrompt]?

    @Published var isRunning = false
    @Published var lastError: String?

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        // Use app's container directory for sandboxed apps
        let containerURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.tempDirectory = containerURL.appendingPathComponent("RiffMCP/SheetMusic")
    }

    func start() async throws {
        guard !isRunning else { return }

        // Create temp directory for PNG files
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Clean up old PNG files on startup
        cleanupOldPNGFiles()

        // Pre-warm the tool and prompt definition caches
        _ = getToolDefinitions()
        _ = getPromptDefinitions()

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
                        Log.server.info("🚀 HTTP Server started on \(self?.host ?? "127.0.0.1", privacy: .public):\(self?.port ?? 27272, privacy: .public)")
                        ActivityLog.shared.updateServerStatus(online: true)
                        ActivityLog.shared.add(message: "Server listening on port \(self?.port ?? 0)", type: .success)
                        try? await self?.writeConfigFile()
                    case .failed(let error):
                        self?.lastError = "Server failed: \(error.localizedDescription)"
                        self?.isRunning = false
                        Log.server.error("❌ HTTP Server failed: \(error.localizedDescription, privacy: .public)")
                        ActivityLog.shared.updateServerStatus(online: false)
                        ActivityLog.shared.add(message: "Server failed: \(error.localizedDescription)", type: .error)
                    case .cancelled:
                        self?.isRunning = false
                        Log.server.info("🛑 HTTP Server stopped")
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
                    Log.server.error("❌ Connection error: \(error.localizedDescription, privacy: .public)")
                }
                if isComplete {
                    connection.cancel()
                }
            }
        }
    }

    private func processHTTPRequest(_ data: Data, connection: NWConnection) async {
        let requestStartTime = Date()
        Log.server.info("🌐 HTTP request received")

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

        Log.server.latency("🚦 Request routing - \(method) \(path)", since: requestStartTime)

        switch (method, path) {
        case ("POST", "/"): await handleJSONRPC(body: body, connection: connection, userAgent: userAgent, bodySize: bodySize)
        case ("GET", "/health"): await sendHTTPResponse(connection: connection, statusCode: 200, headers: ["Content-Type": "application/json"], body: #"{"status":"healthy","port":\#(port)}"#)
        case ("GET", let p) where p.starts(with: "/images/"): await handleImageRequest(path: p, connection: connection)
        default: await sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }

    private func handleImageRequest(path: String, connection: NWConnection) async {
        // 1. Extract filename from path
        let filename = URL(fileURLWithPath: path).lastPathComponent

        // 2. Construct the full, safe file path
        let fileURL = tempDirectory.appendingPathComponent(filename)

        // 3. SECURITY CHECK: Ensure the resolved path is still inside our temp directory.
        guard fileURL.path.hasPrefix(tempDirectory.path) else {
            await sendHTTPResponse(connection: connection, statusCode: 403, body: "Forbidden")
            return
        }

        // 4. Read file and send response
        do {
            let fileData = try Data(contentsOf: fileURL)
            await sendHTTPResponse(connection: connection, statusCode: 200, headers: ["Content-Type": "image/png"], bodyData: fileData)
        } catch {
            Log.io.error("❌ Could not read image file: \(fileURL.path, privacy: .public). Error: \(error.localizedDescription, privacy: .public)")
            await sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }

    // MARK: - JSON-RPC Handler

    private func handleJSONRPC(body: String, connection: NWConnection, userAgent: String, bodySize: Int) async {
        let jsonRpcStartTime = Date()
        Log.server.info("📄 JSON-RPC processing started")

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

            Log.server.latency("🔍 JSON-RPC parsed - method: \(request.method)", since: jsonRpcStartTime)

            let response: JSONRPCResponse
            switch request.method {
            case "initialize":
                let capabilities = MCPCapabilities(tools: ["listChanged": .bool(true)], prompts: ["listChanged": .bool(true)], resources: ["listChanged": .bool(true)])
                let initResult = MCPInitializeResult(protocolVersion: "2024-11-05", capabilities: capabilities, serverInfo: MCPServerInfo(name: "riff", version: "1.0.0"))
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
            case "resources/read":
                response = try await handleResourceRead(request)
            case "prompts/list":
                let result = MCPPromptsResult(prompts: getPromptDefinitions())
                response = JSONRPCResponse(result: try encodeToJSONValue(result), id: request.id)
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
                Log.server.error("Failed to encode response for logging: \(error.localizedDescription, privacy: .public)")
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
                Log.server.error("Failed to encode error response for logging: \(error.localizedDescription, privacy: .public)")
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
                Log.server.error("Failed to encode parse error response for logging: \(error.localizedDescription, privacy: .public)")
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
                Log.server.error("Failed to encode internal error response for logging: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func handleToolCall(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        let toolCallStartTime = Date()
        Log.server.info("🔧 Tool call processing started")

        guard let params = request.params, let toolName = params.objectValue?["name"]?.stringValue else {
            return JSONRPCResponse(error: .invalidParams, id: request.id)
        }

        Log.server.latency("🎯 Tool identified: \(toolName)", since: toolCallStartTime)

        do {
            let result: MCPResult
            let arguments = params.objectValue?["arguments"] ?? .object([:])

            let data = try JSONEncoder().encode(arguments)
            let decoder = JSONDecoder()

            switch toolName {
            case "play":
                let sequenceDecodeStart = Date()
                let sequence = try decoder.decode(MusicSequence.self, from: data)
                Log.server.latency("🎼 Sequence decoded", since: sequenceDecodeStart)
                result = try await handlePlaySequence(sequence: sequence)
            case "engrave":
                let sequence = try decoder.decode(MusicSequence.self, from: data)
                result = try await handleEngraveSequence(sequence: sequence)
            default:
                throw JSONRPCError.serverError("Unknown tool: \(toolName)")
            }
            return JSONRPCResponse(result: try encodeToJSONValue(result), id: request.id)
        } catch let error as DecodingError {
            Log.server.error("Decoding error: \(error.localizedDescription, privacy: .public)")
            switch error {
            case .typeMismatch(let type, let context):
                Log.server.error("Type mismatch for type \(type, privacy: .public) at \(context.codingPath, privacy: .public): \(context.debugDescription, privacy: .public)")
            case .valueNotFound(let type, let context):
                Log.server.error("Value of type \(type, privacy: .public) not found at \(context.codingPath, privacy: .public): \(context.debugDescription, privacy: .public)")
            case .keyNotFound(let key, let context):
                Log.server.error("Key '\(key.stringValue, privacy: .public)' not found at \(context.codingPath, privacy: .public): \(context.debugDescription, privacy: .public)")
            case .dataCorrupted(let context):
                Log.server.error("Data corrupted at \(context.codingPath, privacy: .public): \(context.debugDescription, privacy: .public)")
            @unknown default:
                Log.server.error("Unknown decoding error: \(error.localizedDescription, privacy: .public)")
            }
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
        Log.server.info("🎵 handlePlaySequence started")

        let validInstruments = Instruments.getInstrumentNames()
        for track in sequence.tracks where !validInstruments.contains(track.instrument) {
            throw JSONRPCError.serverError("Invalid instrument \"\(track.instrument)\". Check the instrument enum in the schema for valid options.")
        }

        Log.server.latency("✅ Instrument validation completed", since: playSequenceStartTime)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let jsonData = try encoder.encode(sequence)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw JSONRPCError.serverError("Failed to serialize sequence for audio manager.")
        }

        Log.server.info("📝 Sequence serialized")

        Log.server.info("🎶 Calling AudioManager.playSequenceFromJSON")
        audioManager.playSequenceFromJSON(jsonString)

        let totalEvents = sequence.tracks.reduce(0) { $0 + $1.events.count }
        let summary = "Playing \(sequence.title ?? "") at \(Int(sequence.tempo)) BPM with \(totalEvents) event\(totalEvents == 1 ? "" : "s")."

        var titleWith = ""
        if let title = sequence.title {
            titleWith = title + " with"
        }
        var forInstrument = ""
        if let insturment = sequence.tracks.first?.instrument {
            forInstrument = " for \(insturment)"
        }
        ActivityLog.shared.add(message: "Play \(titleWith) \(totalEvents) notes\(forInstrument)", type: .generation, sequenceData: jsonString)

        return MCPResult(content: [.text(summary)])
    }

    private func handleEngraveSequence(sequence: MusicSequence) async throws -> MCPResult {
        Log.server.info("🎼 handleEngraveSequence started")

        // 1. Validate instruments
        Log.server.info("✅ Starting instrument validation")
        let validInstruments = Instruments.getInstrumentNames()
        for track in sequence.tracks where !validInstruments.contains(track.instrument) {
            throw JSONRPCError.serverError("Invalid instrument \"\(track.instrument)\". Check the instrument enum in the schema for valid options.")
        }
        Log.server.info("✅ Instrument validation completed")

        // 2. Convert sequence to MEI -> SVG -> PNG
        do {
            let sequenceData = try JSONEncoder().encode(sequence)
            Log.server.info("🔄 JSON encoding completed")

            let meiXML = try JSONToMEIConverter.convert(from: sequenceData)
            Log.io.info("🎵 MEI conversion completed")

            guard let svgString = Verovio.svg(from: meiXML) else {
                Log.io.error("❌ Verovio.svgFromMEI returned nil")
                throw JSONRPCError.serverError("Failed to generate SVG from MEI.")
            }
            Log.io.info("🖼️ SVG generation completed")

            let pngData = try await SVGToPNGRenderer.renderToPNG(svgString: svgString)
            Log.io.info("🖼️ PNG rendering completed")

            // 3. Save PNG to temp directory
            let pngUUID = UUID().uuidString
            let pngFileName = "\(pngUUID).png"
            let pngURL = tempDirectory.appendingPathComponent(pngFileName)
            try pngData.write(to: pngURL)
            let resourceURI = "http://\(host):\(port)/images/\(pngFileName)"

            Log.io.info("PNG saved to disk")

            // 4. Make .png Base-64 (Claude still needs type:"image")
            let base64PNG   = pngData.base64EncodedString()
            let imageItem   = MCPContentItem.image(
                data:     base64PNG,
                mimeType: "image/png"
            )

            Log.io.info(" Image link points to: \(resourceURI, privacy: .public)")
            Log.io.info(" PNG file saved at: \(pngURL.path, privacy: .public)")

            // 6. Log the activity
            if let jsonString = String(data: sequenceData, encoding: .utf8) {
                ActivityLog.shared.add(message: "Engrave \(sequence.title ?? "Untitled")", type: .generation, sequenceData: jsonString)
            }
            Log.server.info("✅ engraveSequence completed successfully")

            // 7. Return the result
            return MCPResult(content: [imageItem])
//            return MCPResult(content: [imageItem, markdownLink])

        } catch let error as JSONRPCError {
            Log.server.error("❌ JSONRPCError in handleEngraveSequence: \(error.message, privacy: .public)")
            throw error
        } catch {
            Log.server.error("❌ Unexpected error in handleEngraveSequence: \(error.localizedDescription, privacy: .public)")
            throw JSONRPCError.serverError("Engraving failed: \(error.localizedDescription)")
        }
    }

    private func handleResourceRead(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        guard let params = request.params, let uri = params.objectValue?["uri"]?.stringValue else {
            return JSONRPCResponse(error: .invalidParams, id: request.id)
        }

        // Extract file path from URI
        guard uri.hasPrefix("file://") else {
            return JSONRPCResponse(error: .serverError("Unsupported URI scheme"), id: request.id)
        }

        let filePath = String(uri.dropFirst(7)) // Remove "file://" prefix
        let fileURL = URL(fileURLWithPath: filePath)

        // Verify file is in our temp directory for security
        guard fileURL.path.hasPrefix(tempDirectory.path) else {
            return JSONRPCResponse(error: .serverError("Access denied"), id: request.id)
        }

        do {
            let fileData = try Data(contentsOf: fileURL)
            let base64Data = fileData.base64EncodedString()

            let result: [String: JSONValue] = [
                "contents": .array([
                    .object([
                        "uri": .string(uri),
                        "mimeType": .string("image/png"),
                        "blob": .string(base64Data)
                    ])
                ])
            ]

            return JSONRPCResponse(result: .object(result), id: request.id)
        } catch {
            return JSONRPCResponse(error: .serverError("Failed to read resource: \(error.localizedDescription)"), id: request.id)
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

    private func sendHTTPResponse(connection: NWConnection, statusCode: Int, headers: [String: String] = [:], bodyData: Data) async {
        var responseString = "HTTP/1.1 \(statusCode) \(httpStatusMessage(statusCode))\r\n"
        responseString += "Connection: close\r\n"
        responseString += "Content-Length: \(bodyData.count)\r\n"
        for (key, value) in headers {
            responseString += "\(key): \(value)\r\n"
        }
        responseString += "\r\n"

        var data = responseString.data(using: .utf8) ?? Data()
        data.append(bodyData)

        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
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

    // MARK: - PNG Cleanup

    private func cleanupOldPNGFiles() {
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey], options: [])

            let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago

            for fileURL in files {
                guard fileURL.pathExtension == "png" else { continue }

                let attributes = try fileURL.resourceValues(forKeys: [.creationDateKey])
                if let creationDate = attributes.creationDate, creationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    Log.io.info("🗑️ Cleaned up old PNG file: \(fileURL.lastPathComponent, privacy: .public)")
                }
            }
        } catch {
            Log.io.error("⚠️ Failed to cleanup old PNG files: \(error.localizedDescription, privacy: .public)")
        }
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
        Log.server.info("📝 Config written to: \(configPath.path, privacy: .public)")
    }

    private func removeConfigFile() async throws {
        let configPath = getConfigFilePath()
        if FileManager.default.fileExists(atPath: configPath.path) {
            try FileManager.default.removeItem(at: configPath)
        }
    }

    // MARK: - Tool & Prompt Definitions

    private func getPromptDefinitions() -> [MCPPrompt] {
        if let cachedPrompts = cachedPrompts {
            return cachedPrompts
        }

        // Load prompt definitions from prompts.json file
        guard let promptsURL = Bundle.main.url(forResource: "prompts", withExtension: "json", subdirectory: "mcp"),
              let promptsData = try? Data(contentsOf: promptsURL),
              let promptsArray = try? JSONSerialization.jsonObject(with: promptsData) as? [[String: Any]] else {
            Log.server.error("❌ Failed to load prompts.json, falling back to empty array")
            return []
        }

        let prompts = promptsArray.compactMap { MCPPrompt(from: $0) }
        self.cachedPrompts = prompts
        return prompts
    }

    private func getToolDefinitions() -> [MCPTool] {
        if let cachedTools = cachedTools {
            return cachedTools
        }

        // Load tool definitions from clean JSON file instead of ugly Swift code
        guard let toolsURL = Bundle.main.url(forResource: "tools", withExtension: "json", subdirectory: "MCP"),
              let toolsData = try? Data(contentsOf: toolsURL),
              let toolsArray = try? JSONSerialization.jsonObject(with: toolsData) as? [[String: Any]] else {
            Log.server.error("❌ Failed to load tools.json, falling back to empty array")
            return []
        }

        let tools = toolsArray.compactMap { MCPTool(from: $0) }
        self.cachedTools = tools
        return tools
    }
}
