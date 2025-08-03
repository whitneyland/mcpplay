
//
//  MCPRequestHandler.swift
//  RiffMCP
//
//  Created by Gemini on 7/17/2025.
//

import Foundation

/// An actor responsible for handling all core Model Context Protocol (MCP) logic.
///
/// This actor is the central authority for processing JSON-RPC requests. It manages application state,
/// such as the score store and tool/prompt definition caches, in a thread-safe manner. By isolating the
/// business logic from the transport layer (e.g., HTTP or stdio), it allows multiple concurrent listeners
/// to safely use the same underlying functionality.
actor MCPRequestHandler {

    // MARK: - Dependencies & State

    nonisolated private let audioManager: AudioManaging
    private let tempDirectory: URL
    private let toolsURL: URL?
    private let promptsURL: URL?
    private let host: String
    private var port: UInt16

    private var cachedTools: [MCPTool]?
    private var cachedPrompts: [MCPPrompt]?
    private let scoreStore = ScoreStore()
    private var clientInitialized = false

    // MARK: - Initialization

    init(
        audioManager: AudioManaging,
        host: String,
        port: UInt16,
        tempDirectory: URL,
        toolsURL: URL? = Bundle.main.url(forResource: "tools", withExtension: "json", subdirectory: "MCP"),
        promptsURL: URL? = Bundle.main.url(forResource: "prompts", withExtension: "json", subdirectory: "mcp")
    ) {
        self.audioManager = audioManager
        self.host = host
        self.port = port
        self.tempDirectory = tempDirectory
        self.toolsURL = toolsURL
        self.promptsURL = promptsURL

        // Tool and prompt definitions will be cached on first use
        
        // Set up PNG management
        setupPNGManagement()
    }
    
    /// Updates the port number. This is useful if the HTTP server's port is resolved at runtime.
    func update(port: UInt16) {
        self.port = port
    }

    // MARK: - Main Request Handler

    /// Primary entry point for all incoming JSON-RPC requests.
    /// Routes the request to the appropriate handler based on its method.
    /// 
    func handle(request: JSONRPCRequest, transport: ActivityEvent.TransportType, requestBody: String? = nil, bodySize: Int? = nil) async -> JSONRPCResponse? {

        // Log.server.info("⚡️ JSON-RPC Handler: method - \(request.method)")

        // Log the activity
        if let requestBody = requestBody {
            logActivity(for: request, transport: transport, body: requestBody, bodySize: bodySize ?? 0)
        }

        // Handle notifications (requests without an id)
        if request.id == nil {
            switch request.method {
            case "notifications/initialized":
                self.clientInitialized = true
                Log.server.info("🤝 JSON-RPC Handler: Client initialized.")
            default:
                Log.server.info("📄 JSON-RPC Handler: Received notification: \(request.method)")
            }
            // Return nil to signal that no JSON-RPC response should be sent
            return nil
        }

        do {
            let response: JSONRPCResponse
            switch request.method {

            case "ping":
                // MCP spec says receiver MUST respond promptly to ping with an empty response
                response = JSONRPCResponse(result: .object([:]), id: request.id)

            case "initialize":
                let capabilities = MCPCapabilities(
                        tools: ["listChanged": .bool(false)],
                        prompts: ["listChanged": .bool(false)],
                        resources: ["listChanged": .bool(false)])
                let initResult = MCPInitializeResult(
                        protocolVersion: "2025-06-18",
                        capabilities: capabilities,
                        serverInfo: MCPServerInfo(name: AppInfo.serverName, version: AppInfo.version))
                response = JSONRPCResponse(result: try encodeToJSONValue(initResult), id: request.id)
            

            case "tools/list":
                let result = MCPToolsResult(tools: getToolDefinitions())
                response = JSONRPCResponse(result: try encodeToJSONValue(result), id: request.id)

            case "tools/call":
                response = try await handleToolCall(request)

            case "resources/list":
                response = JSONRPCResponse(result: .object(["resources": .array([])]), id: request.id)

            case "resources/templates/list":
                response = JSONRPCResponse(result: .object(["resourceTemplates": .array([])]), id: request.id)

            case "resources/read":
                response = try await handleResourceRead(request)

            case "prompts/list":
                // let result = MCPPromptsResult(prompts: getPromptDefinitions())
                let result = MCPPromptsResult(prompts: [])
                response = JSONRPCResponse(result: try encodeToJSONValue(result), id: request.id)

            default:
                response = JSONRPCResponse(error: .methodNotFound, id: request.id)
            }

            // Log the response
            logActivity(response)
            
            return response
        } catch let error as JSONRPCError {
            return JSONRPCResponse(error: error, id: request.id)
        } catch {
            Log.server.error("❌ JSON-RPC Handler: Unhandled error in request: \(error.localizedDescription)")
            return JSONRPCResponse(error: .internalError, id: request.id)
        }
    }

    // MARK: - Tool Implementations

    private func handleToolCall(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {

        guard let params = request.params, let toolName = params.objectValue?["name"]?.stringValue else {
            throw JSONRPCError.invalidParams
        }

        Log.server.info("🎯 JSON-RPC Handler: Tool identified - \(toolName)")

        do {
            let result: MCPResult
            let arguments = params.objectValue?["arguments"] ?? .object([:])

            let data = try JSONEncoder().encode(arguments)
            let decoder = JSONDecoder()

            switch toolName {
            case "play":
                let sequence = try decoder.decode(MusicSequence.self, from: data)
                result = try await handlePlaySequence(sequence: sequence)
            case "engrave":
                let input = try decoder.decode(EngraveInput.self, from: data)
                result = try await handleEngraveSequence(input: input)
            default:
                throw JSONRPCError.serverError("Unknown tool: \(toolName)")
            }
            return JSONRPCResponse(result: try encodeToJSONValue(result), id: request.id)
        } catch is DecodingError {
            throw JSONRPCError.invalidParams
        } catch let error as JSONRPCError {
            throw error
        } catch {
            throw JSONRPCError.serverError("Tool execution failed: \(error.localizedDescription)")
        }
    }

    private func handlePlaySequence(sequence: MusicSequence) async throws -> MCPResult {
        let validInstruments = Instruments.getInstrumentNames()
        for track in sequence.tracks where !validInstruments.contains(track.instrument) {
            throw JSONRPCError.serverError("Invalid instrument \"\(track.instrument)\".")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let jsonData = try encoder.encode(sequence)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw JSONRPCError.serverError("Failed to serialize sequence for audio manager.")
        }

        await audioManager.playSequenceFromJSON(jsonString)

        let scoreId = UUID().uuidString
        await scoreStore.put(scoreId, sequence)

        let totalEvents = sequence.tracks.reduce(0) { $0 + $1.events.count }
        let summary = "Playing \(sequence.title ?? "Untitled") at \(Int(sequence.tempo)) BPM with \(totalEvents) event\(totalEvents == 1 ? "" : "s"). "

        return MCPResult(content: [
            .text(summary),
            .text("Score ID: \(scoreId)")
        ])
    }

    private func handleEngraveSequence(input: EngraveInput) async throws -> MCPResult {
        let sequence: MusicSequence
        if let tempo = input.tempo, let tracks = input.tracks {
            sequence = MusicSequence(title: input.title, tempo: tempo, tracks: tracks)
        } else if let id = input.score_id {
            guard let cached = await scoreStore.get(id) else {
                throw JSONRPCError.serverError("Score ID '\(id)' not found")
            }
            sequence = cached
        } else {
            guard let cached = await scoreStore.get(nil) else {
                throw JSONRPCError.serverError("No score available. Either provide notes or play a sequence first.")
            }
            sequence = cached
        }

        let validInstruments = Instruments.getInstrumentNames()
        for track in sequence.tracks where !validInstruments.contains(track.instrument) {
            throw JSONRPCError.serverError("Invalid instrument \"\(track.instrument)\".")
        }

        let sequenceData = try JSONEncoder().encode(sequence)
        let meiXML = try JSONToMEIConverter.convert(from: sequenceData)
        guard let svgString = await Verovio.svg(from: meiXML) else {
            throw JSONRPCError.serverError("Failed to generate SVG from MEI.")
        }
        let pngData = try await SVGToPNGRenderer.renderToPNG(svgString: svgString)

        let pngUUID = UUID().uuidString
        let pngFileName = "\(pngUUID).png"
        let pngURL = tempDirectory.appendingPathComponent(pngFileName)
        try pngData.write(to: pngURL)
        
        let resourceURI = "http://\(host):\(port)/images/\(pngFileName)"
        Log.io.info("🖼️ JSON-RPC Handler: Image resource URI - \(resourceURI)")

        let base64PNG = pngData.base64EncodedString()
        let imageItem = MCPContentItem.image(data: base64PNG, mimeType: "image/png")

        return MCPResult(content: [imageItem])
    }

    private func handleResourceRead(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        guard let params = request.params, let uri = params.objectValue?["uri"]?.stringValue else {
            throw JSONRPCError.invalidParams
        }
        guard uri.hasPrefix("file://") else {
            throw JSONRPCError.serverError("Unsupported URI scheme")
        }

        let filePath = String(uri.dropFirst(7))
        let fileURL = URL(fileURLWithPath: filePath)

        guard fileURL.path.hasPrefix(tempDirectory.path) else {
            throw JSONRPCError.serverError("Access denied to resource.")
        }

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
    }

    // MARK: - Definition Loading

    private func getPromptDefinitions() -> [MCPPrompt] {
        if let cachedPrompts = cachedPrompts {
            return cachedPrompts
        }
        guard let promptsURL = promptsURL,
              let promptsData = try? Data(contentsOf: promptsURL),
              let promptsArray = try? JSONSerialization.jsonObject(with: promptsData) as? [[String: Any]] else {
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
        guard let toolsURL = toolsURL,
              let toolsData = try? Data(contentsOf: toolsURL),
              let toolsArray = try? JSONSerialization.jsonObject(with: toolsData) as? [[String: Any]] else {
            return []
        }
        let tools = toolsArray.compactMap { MCPTool(from: $0) }
        self.cachedTools = tools
        return tools
    }
    
    // MARK: - PNG Management
    
    private nonisolated func setupPNGManagement() {
        do {
            // Create temp directory for PNG files
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            
            // Clean up old PNG files on startup
            cleanupOldPNGFiles()
        } catch {
            Log.io.error("❌ JSON-RPC Handler: Failed to setup PNG management - \(error.localizedDescription)")
        }
    }
    
    private nonisolated func cleanupOldPNGFiles() {
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey], options: [])

            let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago

            for fileURL in files {
                guard fileURL.pathExtension == "png" else { continue }

                let attributes = try fileURL.resourceValues(forKeys: [.creationDateKey])
                if let creationDate = attributes.creationDate, creationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    Log.io.info("🗑️ JSON-RPC Handler: Cleaned up old PNG file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            Log.io.error("❌ JSON-RPC Handler: Failed to cleanup old PNG files: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Activity Logging
    
    private nonisolated func logActivity(for request: JSONRPCRequest, transport: ActivityEvent.TransportType, body: String, bodySize: Int) {
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
        
        let message: String
        switch transport {
        case .http:
            message = "POST /\(request.method)\(toolNameDetail) (\(bodySize) bytes)"
        case .stdio:
            message = "STDIO \(request.method)\(toolNameDetail) (\(bodySize) bytes)"
        }

        // Extract client info for initialize requests
        let clientInfo = Self.extractClientInfo(from: request)
        if let clientInfo {
            Log.server.info("🤝 JSON-RPC Handler: Client initializing: 🟡 \(clientInfo)")
        }

        Task { @MainActor in
            ActivityLog.shared.add(
                message: message,
                type: eventType,
                transport: transport,
                requestData: body,
                clientInfo: clientInfo
            )
        }
    }

    private nonisolated func logActivity(_ response: JSONRPCResponse) {
        Task { @MainActor in
            do {
                let responseData = try JSONEncoder().encode(response)
                if let responseString = String(data: responseData, encoding: .utf8) {
                    ActivityLog.shared.updateLastEventWithResponse(responseString)
                }
            } catch {
                Log.server.error("❌ JSON-RPC Handler: Failed to encode activity log: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func encodeToJSONValue<T: Codable>(_ value: T) throws -> JSONValue {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}

extension MCPRequestHandler {
    /// Returns "`<client name> v<version>`" for an `initialize` request, or `nil`.
    static func extractClientInfo(from request: JSONRPCRequest) -> String? {
        guard request.method == "initialize",
              case let .object(params)?  = request.params,
              case let .object(client)?  = params["clientInfo"],
              case let .string(name)?    = client["name"] else {
            return nil
        }

        let version: String
        if case let .string(v)? = client["version"] {
            version = v
        } else {
            version = "unknown"
        }
        return "\(name) v\(version)"
    }
}
