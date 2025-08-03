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
    var lastRequestContentLength: Int = 0
    
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
    
    func consumeProcessedRequest() {
        guard let headersEndIndex = headersEndIndex else { return }
        
        // Calculate total request size (headers + body)
        // Use the saved content length instead of re-parsing headers
        let contentLength = self.lastRequestContentLength
        let headerLength = buffer.distance(from: buffer.startIndex, to: headersEndIndex)
        let totalRequestSize = headerLength + contentLength
        
        // Remove processed request from buffer
        if totalRequestSize <= buffer.count {
            buffer.removeFirst(totalRequestSize)
        } else {
            // If we don't have enough data, remove what we have
            buffer.removeAll()
        }
        
        // Reset state for next request
        state = .readingHeaders
        self.headersEndIndex = nil
        self.lastRequestContentLength = 0
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
        ServerConfig.remove()
    }

    private func processCompleteHTTPRequest(requestLine: String, headers: [String: String], body: String, connection: NWConnection) async {

        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 3 else {
            Log.server.error("❌ HTTPServer: Invalid request line format: \(components)")
            await sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }

        let (method, path) = (components[0], components[1])
        let bodySize = body.data(using: .utf8)?.count ?? 0

        Log.server.info("🌐 HTTPServer: Request - method: '\(method)', path: '\(path)', body size: \(bodySize) bytes")

        switch (method, path) {
        case ("POST", "/"):
            await handleJSONRPC(body: body, connection: connection, bodySize: bodySize)

        case ("GET", "/health"):
            await sendHTTPResponse(
                connection: connection,
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: #"{"status":"healthy","port":\#(resolvedPort ?? requestedPort)}"#
            )

        case ("GET", let p) where p.hasPrefix("/images/"):
            await handleImageRequest(path: p, connection: connection)

        default:
            await sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }

    private func handleJSONRPC(body: String, connection: NWConnection, bodySize: Int) async {
        // Log.server.info("🌐 HTTPServer: JSON-RPC processing started")

        do {
            // Check for empty body before attempting any parsing
            guard !body.isEmpty else {
                Log.server.error("❌ HTTPServer: Request body is empty")
                throw JSONRPCError.emptyRequest
            }

            guard let bodyData = body.data(using: .utf8) else {
                Log.server.error("❌ HTTPServer: Failed to convert body to UTF-8 data")
                throw JSONRPCError.parseError
            }

            // Try to parse as JSON first to see what fails
            do {
                _ = try JSONSerialization.jsonObject(with: bodyData, options: [])
            } catch {
                Log.server.error("❌ HTTPServer: JSON parsing failed: \(error)")
                throw JSONRPCError.parseError
            }

            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: bodyData)

            guard request.jsonrpc == "2.0" else { throw JSONRPCError.invalidRequest }

            Log.server.info("🌐 HTTPServer: Decoded JSON-RPC request: 🟢 \(request.method)")

            // Delegate to the central handler with HTTP transport type
            if let response = await mcpRequestHandler.handle(
                request: request,
                transport: .http,
                requestBody: body,
                bodySize: bodySize
            ) {
                // It was a regular request, send the JSON-RPC response
                await sendJSONRPCResponse(response, connection: connection)
            } else {
                // It was a notification (handle returned nil)
                // MCP spec says send no JSON-RPC response and HTTP should return 202
                await sendHTTPResponse(connection: connection, statusCode: 202, body: "")
            }

        } catch let error as JSONRPCError {
            let errorResponse = JSONRPCResponse(error: error, id: nil)
            await sendJSONRPCResponse(errorResponse, connection: connection)
        } catch let error as DecodingError {
            Log.server.error("❌ HTTPServer: \(error.localizedDescription)")
            let parseErrorResponse = JSONRPCResponse(error: .parseError, id: nil)
            await sendJSONRPCResponse(parseErrorResponse, connection: connection)
        } catch {
            let internalErrorResponse = JSONRPCResponse(error: .internalError, id: nil)
            await sendJSONRPCResponse(internalErrorResponse, connection: connection)
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
                        Log.server.error("❌ HTTPServer: Connection error: \(error.localizedDescription)")
                        connection.cancel()
                        return
                    }
                    
                    if let data = data, !data.isEmpty {
                        // Log.server.info("🌐 HTTPServer: Received data chunk: \(data.count) bytes")
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

                // Save content length for later use in consumeProcessedRequest
                connectionState.lastRequestContentLength = contentLength

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
                // Log.server.info("🌐 HTTPServer: Processing complete HTTP request")
                await processCompleteHTTPRequest(
                    requestLine: request.requestLine,
                    headers: request.headers,
                    body: request.body,
                    connection: connection
                )
                
                // Remove processed request from buffer and reset state for next request
                connectionState.consumeProcessedRequest()
                
                // Check if there's another request in the buffer to process
                await tryProcessBufferedRequest(connectionState, connection: connection)
            } else {
                Log.server.error("❌ HTTPServer: Failed to extract complete request")
                await sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
                // Don't consume the request if extraction failed - may need to close connection
                connection.cancel()
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
            Log.server.info("🚀 HTTPServer: Started on \(self.host):\(port!)")
            if let port {
                await mcpRequestHandler.update(port: port) // Update the handler with the resolved port
            }
            ActivityLog.shared.updateServerStatus(online: true)
            do {
                try ServerConfig.write(host: host, port: resolvedPort ?? requestedPort)
                Log.server.info("📝 HTTPServer: Config saved: \(ServerConfig.getConfigFilePath())")
            } catch {
                Log.server.error("❌ HTTPServer: Failed to write server config: \(error.localizedDescription)")
            }

        case .failed(let error):
            isRunning = false
            lastError = "Server failed: \(error.localizedDescription)"
            Log.server.error("❌ HTTPServer: \(error.localizedDescription)")
            ActivityLog.shared.updateServerStatus(online: false)

        case .cancelled:
            resolvedPort = nil
            isRunning = false
            Log.server.info("🛑 HTTPServer: Stopped")
            ActivityLog.shared.updateServerStatus(online: false)

        default:
            break
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

    // MARK: - HTTP & JSON Helpers

    private func sendHTTPResponse(connection: NWConnection, statusCode: Int, headers: [String: String] = [:], body: String) async {
        var responseString = "HTTP/1.1 \(statusCode) \(httpStatusMessage(statusCode))\r\n"
        responseString += "Content-Length: \(body.utf8.count)\r\n"
        for (key, value) in headers {
            responseString += "\(key): \(value)\r\n"
        }
        responseString += "\r\n\(body)"

        if let data = responseString.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    private func sendHTTPResponse(connection: NWConnection, statusCode: Int, headers: [String: String] = [:], bodyData: Data) async {
        var responseString = "HTTP/1.1 \(statusCode) \(httpStatusMessage(statusCode))\r\n"
        responseString += "Content-Length: \(bodyData.count)\r\n"
        for (key, value) in headers {
            responseString += "\(key): \(value)\r\n"
        }
        responseString += "\r\n"

        var data = responseString.data(using: .utf8) ?? Data()
        data.append(bodyData)

        connection.send(content: data, completion: .contentProcessed { _ in })
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
}
