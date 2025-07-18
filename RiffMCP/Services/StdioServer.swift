//
//  StdioServer.swift
//  RiffMCP
//
//  Created by Gemini on 7/17/2025.
//

import Foundation

/// A server that listens for and responds to MCP requests on standard input/output.
///
/// This class implements the standard I/O transport layer for the Model Context Protocol.
/// It reads `Content-Length` prefixed JSON-RPC messages from `stdin`, delegates them
/// to the shared `MCPRequestHandler`, and writes the resulting responses back to `stdout`.
class StdioServer: @unchecked Sendable {

    private let mcpRequestHandler: MCPRequestHandler
    private var stdin: FileHandle
    private var stdout: FileHandle
    private var readingTask: Task<Void, Never>?

    init(mcpRequestHandler: MCPRequestHandler) {
        self.mcpRequestHandler = mcpRequestHandler
        self.stdin = FileHandle.standardInput
        self.stdout = FileHandle.standardOutput
    }

    /// Starts the server's listening loop in a background task.
    func start() {
        Log.server.info("🚀 StdioServer starting...")
        readingTask = Task.detached(priority: .userInitiated) {
            await self.listenForMessages()
        }
    }

    /// Stops the server by canceling its listening task.
    func stop() {
        Log.server.info("🛑 StdioServer stopping...")
        readingTask?.cancel()
    }

    private func listenForMessages() async {
        while !Task.isCancelled {
            do {
                if let contentLength = try await readHeader() {
                    let jsonData = try await readMessage(byteCount: contentLength)
                    await process(jsonData: jsonData)
                }
            } catch {
                Log.server.error("❌ Stdio error: \(error.localizedDescription). Shutting down stdio listener.")
                break // Exit the loop on error
            }
        }
        Log.server.info("Stdio listener task finished.")
    }

    /// Reads the `Content-Length` header to determine the size of the incoming JSON message.
    private func readHeader() async throws -> Int? {
        let terminator = Data([0x0D, 0x0A, 0x0D, 0x0A])   // \r\n\r\n
        var headerData = Data()

        // Read from stdin until we see the terminator
        while !headerData.contains(terminator) {
            guard let chunk = try stdin.read(upToCount: 4096), !chunk.isEmpty else {
                return nil // EOF or error
            }
            headerData.append(chunk)
        }

        guard let headerString = String(data: headerData, encoding: .ascii) else {
            throw StdioError.invalidHeader("Could not decode header.")
        }

        let lines = headerString.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\r\n")
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 && parts[0].lowercased() == "content-length" {
                if let length = Int(parts[1]) {
                    return length
                }
            }
        }
        throw StdioError.invalidHeader("Content-Length not found.")
    }

    /// Reads the specified number of bytes from stdin to get the JSON message body.
    private func readMessage(byteCount: Int) async throws -> Data {
        var body = Data()
        body.reserveCapacity(byteCount)

        while body.count < byteCount {
            let need = byteCount - body.count
            guard let chunk = try stdin.read(upToCount: need), !chunk.isEmpty else {
                throw StdioError.unexpectedEndOfStream
            }
            body.append(chunk)
        }
        return body
    }

    /// Processes the received JSON data, sends it to the handler, and writes the response.
    private func process(jsonData: Data) async {
        do {
            let request = try JSONDecoder().decode(JSONRPCRequest.self, from: jsonData)
            let requestBody = String(data: jsonData, encoding: .utf8) ?? ""
            let response = await mcpRequestHandler.handle(
                request: request,
                transport: .stdio,
                requestBody: requestBody,
                bodySize: jsonData.count
            )
            try await write(response: response)
        } catch {
            Log.server.error("❌ Failed to decode or handle stdio request: \(error.localizedDescription)")
            let errorResponse = JSONRPCResponse(error: .parseError, id: nil)
            try? await write(response: errorResponse)
        }
    }

    /// Writes a JSON-RPC response to stdout, prefixed with the required `Content-Length` header.
    private func write(response: JSONRPCResponse) async throws {
        let responseData = try JSONEncoder().encode(response)
        let headerString = "Content-Length: \(responseData.count)\r\n\r\n"
        guard let headerData = headerString.data(using: .utf8) else {
            throw StdioError.responseEncodingError
        }

        try stdout.write(contentsOf: headerData)
        try stdout.write(contentsOf: responseData)
    }
}

enum StdioError: Error, LocalizedError {
    case invalidHeader(String)
    case unexpectedEndOfStream
    case incompleteMessage
    case responseEncodingError

    var errorDescription: String? {
        switch self {
        case .invalidHeader(let reason): return "Invalid Stdio Header: \(reason)"
        case .unexpectedEndOfStream: return "Unexpected end of input stream."
        case .incompleteMessage: return "Incomplete message received."
        case .responseEncodingError: return "Failed to encode response for writing."
        }
    }
}
