//
//  HTTPServer.swift
//  RiffMCP
//
//  Simple HTTP server to handle Model Context Protocol requests.
//  This class is a thin transport layer that delegates all logic to the MCPRequestHandler.
//

import Foundation
import Network

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
        try? await removeConfigFile()
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) async {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task {
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
            try? await writeConfigFile()

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
        let bodySize = body.data(using: .utf8)?.count ?? 0

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
            Log.io.error("❌ Could not read image file: \(fileURL.path, privacy: .public). Error: \(error.localizedDescription, privacy: .public)")
            await sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }

    // MARK: - JSON-RPC Handler

    private func handleJSONRPC(body: String, connection: NWConnection, bodySize: Int) async {
        let jsonRpcStartTime = Date()
        Log.server.info("📄 JSON-RPC processing started")

        do {
            guard let bodyData = body.data(using: .utf8) else { throw JSONRPCError.parseError }
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: bodyData)
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
        } catch is DecodingError {
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

    private func getConfigFilePath() -> URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return supportDir.appendingPathComponent("RiffMCP/server.json")
    }

    private func writeConfigFile() async throws {
        let configPath = getConfigFilePath()
        try FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        let config: [String: Any] = ["port": resolvedPort ?? requestedPort, "host": host, "status": "running", "pid": ProcessInfo.processInfo.processIdentifier]
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
}