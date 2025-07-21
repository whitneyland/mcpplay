//
//  HTTPServer.swift
//  RiffMCP
//
//  Simple HTTP server to handle Model Context Protocol requests.
//  This class is a thin transport layer that delegates all logic to the MCPRequestHandler.
//

import Foundation
import Network

// MARK: - Connection State Management

private class ConnectionState: @unchecked Sendable {
    enum ParsingState: Equatable {
        case readingHeaders
        case readingBody(expectedLength: Int)
        case complete
    }
    
    var buffer = Data()
    var state: ParsingState = .readingHeaders
    var headersEndIndex: Data.Index?
    
    func appendData(_ data: Data) {
        buffer.append(data)
    }
    
    func tryParseHeaders() -> [String: String]? {
        guard state == .readingHeaders else { return nil }
        
        // Look for end of headers marker
        let headerTerminator = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n
        guard let terminatorRange = buffer.range(of: headerTerminator) else {
            return nil // Headers not complete yet
        }
        
        headersEndIndex = terminatorRange.upperBound
        
        // Parse headers
        let headerData = buffer.prefix(upTo: terminatorRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            return nil
        }
        
        var headers: [String: String] = [:]
        let lines = headerString.components(separatedBy: "\r\n")
        
        for line in lines.dropFirst() { // Skip request line
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        
        return headers
    }
    
    func hasCompleteBody(expectedLength: Int) -> Bool {
        guard let headersEndIndex = headersEndIndex else { return false }
        let bodyData = buffer.suffix(from: headersEndIndex)
        return bodyData.count >= expectedLength
    }
    
    func extractCompleteRequest() -> (requestLine: String, headers: [String: String], body: String)? {
        guard let headersEndIndex = headersEndIndex else { return nil }
        
        let headerData = buffer.prefix(upTo: headersEndIndex.advanced(by: -4)) // Exclude \r\n\r\n
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }
        
        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        
        let bodyData = buffer.suffix(from: headersEndIndex)
        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyString = String(data: bodyData.prefix(contentLength), encoding: .utf8) ?? ""
        
        return (requestLine: requestLine, headers: headers, body: bodyString)
    }
}

class HTTPServer: ObservableObject, @unchecked Sendable {

    static let defaultHost = "127.0.0.1"
    static let defaultPort: UInt16 = 3001
    
    private let listener: NWListener
    private let requestedPort: UInt16
    private let host: String
    private let mcpRequestHandler: MCPRequestHandler
    internal let tempDirectory: URL

    @Published var isRunning = false
    @Published var lastError: String?
    private(set) var resolvedPort: UInt16?

    static var defaultTempDir: URL {
        let containerURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return containerURL.appendingPathComponent("RiffMCP/SheetMusic")
    }
    
    var baseURL: URL? {
        guard let port = resolvedPort else { return nil }
        return URL(string: "http://\(host):\(port)")
    }

    init(
        mcpRequestHandler: MCPRequestHandler,
        host: String = HTTPServer.defaultHost,
        port: UInt16 = HTTPServer.defaultPort,
        tempDirectory: URL? = nil
    ) throws {
        self.mcpRequestHandler = mcpRequestHandler
        self.host = host
        self.requestedPort = port
        self.tempDirectory = tempDirectory ?? Self.defaultTempDir

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer       = false

        self.listener = try NWListener(
            using: parameters,
            on: NWEndpoint.Port(rawValue: port)!
        )

        self.listener.newConnectionHandler = { [weak self] conn in
            Task { await self?.handleConnection(conn) }
        }
        self.listener.stateUpdateHandler = { [weak self] state in
            Task { @Sendable [weak self] in await self?.handleStateChange(state) }
        }
    }

    func start() async throws {
        guard !isRunning else { return }

        listener.start(queue: .global(qos: .userInitiated))
    }

    func stop() async {
        listener.cancel()
        resolvedPort = nil
        await MainActor.run {
            isRunning = false
        }
        do {
            try await removeConfigFile()
        } catch {
            Log.server.error("❌ Failed to remove server config: \(error.localizedDescription)")
        }
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) async {
        connection.start(queue: .global(qos: .userInitiated))
        
        let connectionState = ConnectionState()
        
        @Sendable func receiveLoop() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                Task {
                    guard let self = self else { return }
                    
                    if let error = error {
                        Log.server.error("❌ Connection error: \(error.localizedDescription)")
                        connection.cancel()
                        return
                    }
                    
                    if let data = data, !data.isEmpty {
                        Log.server.info("🌐 Received data chunk: \(data.count) bytes")
                        connectionState.appendData(data)
                        
                        // Try to process the request if we have enough data
                        await self.tryProcessBufferedRequest(connectionState, connection: connection)
                    }
                    
                    if isComplete {
                        connection.cancel()
                        return
                    }
                    
                    // Continue receiving more data
                    receiveLoop()
                }
            }
        }
        
        receiveLoop()
    }
    
    private func tryProcessBufferedRequest(_ connectionState: ConnectionState, connection: NWConnection) async {
        switch connectionState.state {
        case .readingHeaders:
            // Try to parse headers
            if let headers = connectionState.tryParseHeaders() {
                let contentLength = Int(headers["content-length"] ?? "0") ?? 0
                Log.server.info("🌐 Headers parsed, Content-Length: \(contentLength)")
                
                if contentLength == 0 {
                    // No body expected, process immediately
                    connectionState.state = .complete
                } else {
                    // Expect a body of the specified length
                    connectionState.state = .readingBody(expectedLength: contentLength)
                }
                
                // Check if we can process now
                await tryProcessBufferedRequest(connectionState, connection: connection)
            }
            
        case .readingBody(let expectedLength):
            // Check if we have the complete body
            if connectionState.hasCompleteBody(expectedLength: expectedLength) {
                connectionState.state = .complete
                await tryProcessBufferedRequest(connectionState, connection: connection)
            }
            
        case .complete:
            // Process the complete request
            if let request = connectionState.extractCompleteRequest() {
                Log.server.info("🌐 Processing complete HTTP request")
                await processCompleteHTTPRequest(
                    requestLine: request.requestLine,
                    headers: request.headers,
                    body: request.body,
                    connection: connection
                )
            } else {
                Log.server.error("🌐 Failed to extract complete request")
                await sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            }
        }
    }

    @MainActor  // Sync state changes on MainActor for UI updates
    private func handleStateChange(_ state: NWListener.State) async {
        switch state {
        case .ready:
            let port = listener.port?.rawValue
            resolvedPort = port
            isRunning = true
            lastError = nil
            Log.server.info("🚀 HTTP Server started on \(self.host):\(port!)")
            if let port {
                await mcpRequestHandler.update(port: port) // Update the handler with the resolved port
            }
            ActivityLog.shared.updateServerStatus(online: true)
            do {
                try await writeConfigFile()
            } catch {
                Log.server.error("❌ Failed to write server config: \(error.localizedDescription)")
            }

        case .failed(let error):
            isRunning = false
            lastError = "Server failed: \(error.localizedDescription)"
            Log.server.error("❌ \(error.localizedDescription)")
            ActivityLog.shared.updateServerStatus(online: false)

        case .cancelled:
            resolvedPort = nil
            isRunning = false
            Log.server.info("🛑 HTTP Server stopped")
            ActivityLog.shared.updateServerStatus(online: false)

        default:
            break
        }
    }

    private func processCompleteHTTPRequest(requestLine: String, headers: [String: String], body: String, connection: NWConnection) async {
        let requestStartTime = Date()
        Log.server.info("🌐 Processing complete HTTP request")

        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 3 else {
            Log.server.error("🌐 Invalid request line format: \(components)")
            await sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }

        let (method, path) = (components[0], components[1])
        let bodySize = body.data(using: .utf8)?.count ?? 0

        Log.server.info("🔄 HTTP parsed - method: '\(method)', path: '\(path)', body size: \(bodySize) bytes")
        Log.server.info("🔄 Body content: '\(body)'")
        Log.server.latency("🚦 Request routing - \(method) \(path)", since: requestStartTime)

        switch (method, path) {
        case ("POST", "/"): await handleJSONRPC(body: body, connection: connection, bodySize: bodySize)
        case ("GET", "/health"): await sendHTTPResponse(connection: connection, statusCode: 200, headers: ["Content-Type": "application/json"], body: #"{"status":"healthy","port":\#(resolvedPort ?? requestedPort)}"#)
        case ("GET", let p) where p.starts(with: "/images/"): await handleImageRequest(path: p, connection: connection)
        default: await sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }

    private func handleImageRequest(path: String, connection: NWConnection) async {
        let filename = URL(fileURLWithPath: path).lastPathComponent
        let fileURL = tempDirectory.appendingPathComponent(filename)

        guard fileURL.path.hasPrefix(tempDirectory.path) else {
            await sendHTTPResponse(connection: connection, statusCode: 403, body: "Forbidden")
            return
        }

        do {
            let fileData = try Data(contentsOf: fileURL)
            await sendHTTPResponse(connection: connection, statusCode: 200, headers: ["Content-Type": "image/png"], bodyData: fileData)
        } catch {
            Log.io.error("❌ Could not read image file: \(fileURL.path). Error: \(error.localizedDescription)")
            await sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }

    // MARK: - JSON-RPC Handler

    private func handleJSONRPC(body: String, connection: NWConnection, bodySize: Int) async {
        let jsonRpcStartTime = Date()
        Log.server.info("📄 JSON-RPC processing started")

        do {
            Log.server.info("📄 Raw body string: '\(body)'")
            Log.server.info("📄 Body length: \(body.count) characters")
            Log.server.info("📄 Body bytes: \(Array(body.utf8))")
            
            // Check for empty body before attempting any parsing
            guard !body.isEmpty else {
                Log.server.error("📄 Request body is empty")
                throw JSONRPCError.emptyRequest
            }
            
            guard let bodyData = body.data(using: .utf8) else {
                Log.server.error("📄 Failed to convert body to UTF-8 data")
                throw JSONRPCError.parseError
            }
            Log.server.info("📄 Body data: \(bodyData.count) bytes")
            Log.server.info("📄 Body data hex: \(bodyData.map { String(format: "%02x", $0) }.joined(separator: " "))")
            
            // Try to parse as JSON first to see what fails
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: bodyData, options: [])
                Log.server.info("📄 JSON parsing successful, object: \(jsonObject)")
            } catch {
                Log.server.error("📄 JSON parsing failed: \(error)")
                throw JSONRPCError.parseError
            }
            
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: bodyData)
            Log.server.info("📄 Successfully decoded JSON-RPC request: \(request.method)")
            guard request.jsonrpc == "2.0" else { throw JSONRPCError.invalidRequest }

            Log.server.latency("🔍 JSON-RPC parsed - method: \(request.method)", since: jsonRpcStartTime)

            // Delegate to the central handler with HTTP transport type
            let response = await mcpRequestHandler.handle(
                request: request,
                transport: .http,
                requestBody: body,
                bodySize: bodySize
            )
            
            // The `initialized` notification is special; it's one-way and requires an immediate empty HTTP response.
            if request.method == "notifications/initialized" {
                await sendHTTPResponse(connection: connection, statusCode: 200, body: "")
                return
            }

            await sendJSONRPCResponse(response, connection: connection)

        } catch let error as JSONRPCError {
            let errorResponse = JSONRPCResponse(error: error, id: nil)
            await sendJSONRPCResponse(errorResponse, connection: connection)
        } catch let error as DecodingError {
            Log.server.error(error.localizedDescription)
            let parseErrorResponse = JSONRPCResponse(error: .parseError, id: nil)
            await sendJSONRPCResponse(parseErrorResponse, connection: connection)
        } catch {
            let internalErrorResponse = JSONRPCResponse(error: .internalError, id: nil)
            await sendJSONRPCResponse(internalErrorResponse, connection: connection)
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
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }

    // MARK: - Configuration File

    private func writeConfigFile() async throws {
        let configPath = ServerConfigUtils.getConfigFilePath()
        try FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let instanceUUID = UUID().uuidString
        let config: [String: Any] = [
            "port": resolvedPort ?? requestedPort,
            "host": host,
            "status": "running",
            "pid": ProcessInfo.processInfo.processIdentifier,
            "instance": instanceUUID,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try jsonData.write(to: configPath, options: .atomic)
        Log.server.info("📝 Config written to: \(configPath.path)")

        // Sanity-check the write
        guard let echo = ServerConfigUtils.readServerConfig(), echo.instance == instanceUUID else {
            throw NSError(domain: "RiffMCP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Server config write verification failed"])
        }
    }

    private func removeConfigFile() async throws {
        let configPath = ServerConfigUtils.getConfigFilePath()
        if FileManager.default.fileExists(atPath: configPath.path) {
            try FileManager.default.removeItem(at: configPath)
        }
    }
}
