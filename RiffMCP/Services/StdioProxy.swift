//
//  StdioProxy.swift
//  RiffMCP
//
//  Created by Claude on 7/18/2025.
//

import Foundation
import Darwin
import AppKit

/// A lightweight bridge to forward stdio JSON-RPC calls to a running HTTPServer instance.
///
/// This proxy enables LLM clients to connect via stdio to an already-running GUI app instance
/// by detecting if a server is running and forwarding requests via HTTP.
struct StdioProxy {
    private let port: UInt16
    private let session: URLSession
    private let stdin: FileHandle
    private let stdout: FileHandle
    private var clientFormat: StdioIO.ProtocolFormat = .newlineDelimited

    init(port: UInt16) {
        self.port = port
        // Use standard FileHandle.standardInput 
        self.stdin = .standardInput
        self.stdout = .standardOutput
        
        // Use a simple URLSession for making the local HTTP requests
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpMaximumConnectionsPerHost = 1  // Force single connection
        self.session = URLSession(configuration: config)
    }

    /// Main entry point for --stdio mode. This function NEVER returns.
    ///
    /// Behavior:
    ///   1. If a server is running: Becomes a proxy to it, then calls exit(0)
    ///   2. If no server found: Launches GUI app, waits for it, becomes proxy, then calls exit(0)
    ///   3. If any error occurs: Calls exit(1)
    ///
    /// - Warning: This function always terminates the process via exit()
    static func runStdioMode() -> Never {

        // Check for existing server first
        switch ServerProcess.checkForExistingGUIInstance() {
        case .found(let port, _):
            runProxyForever(port: port) // This call is `-> Never`
        case .noConfigFile:
            Log.server.info("🚀 StdioProxy: runStdioMode - No server config, launching GUI app...")
        case .processNotRunning:
            Log.server.info("🚀 StdioProxy: runStdioMode - pid not running, launching GUI app...")
        }

        do {
            // This function is designed to either throw an error or call
            // a `Never`-returning function (`runProxyForever`) internally.
            // It should never return control to this point.
            try launchGUIAppAndWait()
        } catch {
            // If launchGUIAppAndWait throws, we log the error and exit.
            Log.server.error("❌ StdioProxy: Failed to launch GUI app: \(error.localizedDescription)")
            exit(1) // This call is `-> Never`
        }

        // The logic of launchGUIAppAndWait dictates that we should never reach this point.
        fatalError("💀 StdioProxy: runAsProxyAndExitIfNeeded reached an unreachable state. Terminating.")
    }

    mutating func runBlocking() async throws {
        var sawFirstRequest = false
        let idle: UInt64 = 50_000_000 // 0.05s in ns

        while true {
            do {
                if let hdr = try StdioIO.readHeader(from: stdin) {
                    clientFormat = hdr.format
                    let json = try StdioIO.readBody(from: stdin, length: hdr.length)
                    sawFirstRequest = true
                    try await forwardRequest(data: json)
                    continue
                }

                if sawFirstRequest { break }
                try await Task.sleep(nanoseconds: idle)

            } catch StdioError.unexpectedEndOfStream,
                    ProxyError.unexpectedEndOfStream {
                if sawFirstRequest { break }
                try await Task.sleep(nanoseconds: idle)
            }
        }
    }

    // Forward the request via HTTP (async, no semaphore, no captured mutation)
    private func forwardRequest(data: Data) async throws {
        let url = URL(string: "http://127.0.0.1:\(port)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("close", forHTTPHeaderField: "Connection")

        Log.server.info("🔄 StdioProxy: Sending POST to URL: \(url), \(data.count) bytes")

        do {
            let (body, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ProxyError.invalidHTTPResponse("No HTTP response")
            }

            // MCP/JSON-RPC: notifications → no response body (HTTP 202)
            if http.statusCode == 202 {
                Log.server.info("🔄 StdioProxy: Send no response for notifications.")
                return
            }

            guard (200...299).contains(http.statusCode) else {
                let jsonRpcError: JSONRPCError = {
                    if (400...499).contains(http.statusCode) { return .invalidRequest }
                    if (500...599).contains(http.statusCode) { return .serverError("Server error (HTTP \(http.statusCode))") }
                    return .internalError
                }()

                // Emit JSON-RPC error back to client (preserves current behavior)
                let requestId = extractRequestId(from: data)
                let errorResponse = JSONRPCResponse(error: jsonRpcError, id: requestId)
                if let errorData = try? JSONEncoder().encode(errorResponse) {
                    try write(data: errorData)
                }
                return
            }

            try write(data: body)
        } catch {
            // Network/other error → JSON-RPC internalError
            Log.server.error("❌ StdioProxy: Forwarding error: \(error.localizedDescription)")
            let requestId = extractRequestId(from: data)
            let errorResponse = JSONRPCResponse(error: .internalError, id: requestId)
            if let errorData = try? JSONEncoder().encode(errorResponse) {
                try write(data: errorData)
            }
        }
    }

    // Writes a full JSON-RPC response to stdout
    private func write(data: Data) throws {
        try StdioIO.write(data, to: stdout, using: clientFormat)
    }
    
    /// Launches the GUI app and waits for it to start, then becomes a proxy.
    /// This implements the "Launch and Discover" logic from the design spec.
    private static func launchGUIAppAndWait() throws {
        // Atomically create a launch lock file to prevent race conditions
        // between multiple concurrent --stdio invocations
        let lockPath = ServerConfig.getConfigFilePath().appendingPathExtension("launching")
        let lockData = "launching".data(using: .utf8)!
        
        guard FileManager.default.createFile(atPath: lockPath.path, contents: lockData, attributes: nil) else {
            // Another process is already launching - wait for it to complete
            Log.server.info("🔒 StdioProxy: Another process is launching GUI, waiting for it to complete...")
            
            // Wait for the other process to complete launch (up to 15 seconds)
            let startTime = Date()
            let timeout: TimeInterval = 15.0
            let checkInterval: TimeInterval = 0.25

            while Date().timeIntervalSince(startTime) < timeout {
                // Check if server config appears (launch succeeded)
                switch ServerProcess.checkForExistingGUIInstance() {
                case .found(let port, _):
                    Log.server.info("✅ StdioProxy: Other process completed launch successfully")
                    // Clean up our lock attempt
                    try? FileManager.default.removeItem(at: lockPath)
                    runProxyForever(port: port)
                case .noConfigFile, .processNotRunning:
                    break // Continue waiting
                }
                
                // Check if lock file disappeared (launch failed)
                if !FileManager.default.fileExists(atPath: lockPath.path) {
                    Log.server.error("❌ StdioProxy: Other process launch failed, retrying...")
                    return try launchGUIAppAndWait()
                }
                
                Thread.sleep(forTimeInterval: checkInterval)
            }
            
            // Timeout - clean up stale lock and retry
            try? FileManager.default.removeItem(at: lockPath)
            throw ProxyError.launchError("Timeout waiting for other process to launch GUI")
        }
        
        // We successfully created the lock file - we're responsible for launching
        defer {
            // Clean up lock file when we're done (success or failure)
            try? FileManager.default.removeItem(at: lockPath)
        }
        
        let runningApp = try ServerProcess.startAppGUI()

        // Enter discovery loop with 15-second timeout
        let startTime = Date()
        let timeout: TimeInterval = 15.0
        let checkInterval: TimeInterval = 0.25

        Log.server.info("🔍 StdioProxy: Entering discovery loop (timeout: \(timeout)s)")
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Check for server config
            switch ServerProcess.checkForExistingGUIInstance() {
            case .found(let port, let pid):
                Log.server.info("✅ StdioProxy: Found config during discovery - port: \(port), pid: \(pid)")
                runProxyForever(port: port)
            case .noConfigFile, .processNotRunning:
                break // Continue discovery loop
            }

            if runningApp.isTerminated {
                Log.server.error("❌ StdioProxy: GUI process \(runningApp.processIdentifier) terminated unexpectedly")
                exit(1)
            }
            // Wait before checking again
            Thread.sleep(forTimeInterval: checkInterval)
        }
        
        // If we reach here, the timeout was reached
        let elapsed = Date().timeIntervalSince(startTime)
        Log.server.error("❌ StdioProxy: Discovery timeout after \(elapsed)s - GUI app failed to start")
        exit(1)
    }

    // MARK: - Helper Functions

    /// Spins up a stdio→HTTP proxy and blocks forever.
    /// - Note: This function never returns; it terminates the process via `exit()`
    ///         when the proxy loop ends or encounters a fatal error.
    private static func runProxyForever(port: UInt16) -> Never {
        Log.server.info("🔄 StdioProxy: Starting proxy to forward to port \(port)")

        var proxy = StdioProxy(port: port)

        Task {
            do {
                try await proxy.runBlocking()
                exit(0)
            } catch {
                Log.server.error("❌ StdioProxy: exit (1): \(error.localizedDescription)")
                exit(1)
            }
        }
        // Keep the process alive for the async task; never returns.
        dispatchMain()
    }
    
    /// Extracts the request ID from JSON-RPC data for proper error responses
    /// - Parameter data: The JSON-RPC request data
    /// - Returns: The request ID if found, nil otherwise
    private func extractRequestId(from data: Data) -> JSONValue? {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let id = json?["id"] {
                // Convert various ID types to JSONValue
                if let stringId = id as? String {
                    return .string(stringId)
                } else if let intId = id as? Int {
                    return .int(intId)
                } else if let doubleId = id as? Double {
                    return .double(doubleId)
                } else if id is NSNull {
                    return .null
                }
            }
        } catch {
            Log.server.error("❌ StdioProxy: Failed to extract request ID: \(error.localizedDescription)")
        }
        return nil
    }
}

enum ProxyError: Error, LocalizedError {
    case invalidHeader(String)
    case unexpectedEndOfStream
    case invalidHTTPResponse(String)
    case httpError(Int, JSONRPCError)
    case responseEncodingError
    case stdinReadError(String)
    case launchError(String)

    var errorDescription: String? {
        switch self {
        case .invalidHeader(let reason): 
            return "Invalid Stdio Header: \(reason)"
        case .unexpectedEndOfStream: 
            return "Unexpected end of input stream."
        case .invalidHTTPResponse(let reason): 
            return "Invalid HTTP response: \(reason)"
        case .httpError(let statusCode, let jsonRpcError):
            return "HTTP \(statusCode): \(jsonRpcError.message)"
        case .responseEncodingError: 
            return "Failed to encode response for writing."
        case .stdinReadError(let reason):
            return "Stdin read error: \(reason)"
        case .launchError(let reason):
            return "Launch error: \(reason)"
        }
    }
}
