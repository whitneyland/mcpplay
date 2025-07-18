//
//  StdioProxy.swift
//  RiffMCP
//
//  Created by Claude on 7/18/2025.
//

import Foundation
import Darwin

/// A lightweight bridge to forward stdio JSON-RPC calls to a running HTTPServer instance.
///
/// This proxy enables LLM clients to connect via stdio to an already-running GUI app instance
/// by detecting if a server is running and forwarding requests via HTTP.
struct StdioProxy {
    private let port: UInt16
    private let session: URLSession
    private let stdinFd: Int32
    private let stdout: FileHandle

    init(port: UInt16) {
        self.port = port
        self.stdinFd = STDIN_FILENO
        self.stdout = .standardOutput
        
        // Use a simple URLSession for making the local HTTP requests
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpMaximumConnectionsPerHost = 1  // Force single connection
        self.session = URLSession(configuration: config)
    }

    /// The main entry point for --stdio mode. This function NEVER returns normally.
    /// 
    /// Behavior:
    /// 1. If a server is running: Becomes a proxy to it, then calls exit(0)
    /// 2. If no server found: Launches GUI app, waits for it, becomes proxy, then calls exit(0)
    /// 3. If any error occurs: Calls exit(1)
    /// 
    /// - Returns: Bool (dummy return to satisfy compiler - this code path is never reached)
    /// - Warning: This function always terminates the process via exit()
    @discardableResult
    static func runAsProxyAndExitIfNeeded() -> Bool {
        Log.server.info("🔍 StdioProxy: Checking for running server...")
        
        // Check for existing server first
        if let config = findRunningServer() {
            startProxyAndExit(port: config.port)
        }
        
        // If we reach here, no server is running. Launch the GUI app and wait for it.
        Log.server.info("🚀 StdioProxy: No server running, launching GUI app...")
        
        do {
            try launchGUIAppAndWait()
        } catch {
            Log.server.error("Failed to launch GUI app: \(error.localizedDescription)")
            exit(1)
        }
        
        // UNREACHABLE: This line should never execute because launchGUIAppAndWait() calls exit()
        // The return value exists only to satisfy the compiler
        return true
    }


    /// Runs the proxy loop, blocking the current thread until stdin is closed.
    func runBlocking() throws {
        Log.server.info("🔄 Starting stdio proxy loop...")
        
        readLoop: while true {
            let contentLength: Int
            do {
                // Returns nil on clean EOF before any header bytes
                guard let len = try StdioIO.readHeader(fd: stdinFd) else {
                    Log.server.info("📤 EOF before header (clean disconnect); proxy shutting down.")
                    break readLoop
                }
                contentLength = len
            } catch {
                Log.server.error("Header read failed: \(error)")
                throw error
            }

            do {
                let jsonData = try StdioIO.readBody(fd: stdinFd, length: contentLength)
                try forwardRequestSync(data: jsonData)
            } catch {
                Log.server.error("Body read failed (expected \(contentLength) bytes): \(error)")
                throw error
            }
        }
    }
    
    // Forward the request via HTTP synchronously
    private func forwardRequestSync(data: Data) throws {
        let url = URL(string: "http://127.0.0.1:\(port)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("close", forHTTPHeaderField: "Connection")
        
        Log.server.info("🔄 Proxy sending: \(data.count) bytes")

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Data, Error>?

        session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                result = .failure(error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                result = .failure(ProxyError.invalidHTTPResponse("No HTTP response"))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Map HTTP status codes to appropriate JSON-RPC errors
                let jsonRpcError: JSONRPCError
                if (400...499).contains(httpResponse.statusCode) {
                    jsonRpcError = .invalidRequest
                } else if (500...599).contains(httpResponse.statusCode) {
                    jsonRpcError = .serverError("Server error (HTTP \(httpResponse.statusCode))")
                } else {
                    jsonRpcError = .internalError
                }
                result = .failure(ProxyError.httpError(httpResponse.statusCode, jsonRpcError))
                return
            }
            
            guard let data = data else {
                result = .failure(ProxyError.invalidHTTPResponse("No response data"))
                return
            }
            
            result = .success(data)
        }.resume()

        semaphore.wait()
        
        switch result! {
        case .success(let responseData):
            try write(data: responseData)
        case .failure(let error):
            Log.server.error("Proxy forwarding error: \(error.localizedDescription)")
            // Send a JSON-RPC error response back to the client with correct ID
            let requestId = extractRequestId(from: data)
            
            // Use appropriate JSON-RPC error based on the error type
            let jsonRpcError: JSONRPCError
            if case .httpError(_, let specificError) = error as? ProxyError {
                jsonRpcError = specificError
            } else {
                jsonRpcError = .internalError
            }
            
            let errorResponse = JSONRPCResponse(error: jsonRpcError, id: requestId)
            if let errorData = try? JSONEncoder().encode(errorResponse) {
                try write(data: errorData)
            }
        }
    }
    
    // Writes a full JSON-RPC response to stdout
    private func write(data: Data) throws {
        try StdioIO.write(data, to: stdout)
    }
    
    /// Launches the GUI app and waits for it to start, then becomes a proxy.
    /// This implements the "Launch and Discover" logic from the design spec.
    private static func launchGUIAppAndWait() throws {
        // Atomically create a launch lock file to prevent race conditions
        // between multiple concurrent --stdio invocations
        let lockPath = ServerConfigUtils.getConfigFilePath().appendingPathExtension("launching")
        let lockData = "launching".data(using: .utf8)!
        
        guard FileManager.default.createFile(atPath: lockPath.path, contents: lockData, attributes: nil) else {
            // Another process is already launching - wait for it to complete
            Log.server.info("🔒 StdioProxy: Another process is launching GUI, waiting for it to complete...")
            
            // Wait for the other process to complete launch (up to 15 seconds)
            let startTime = Date()
            let timeout: TimeInterval = 15.0
            let checkInterval: TimeInterval = 0.2
            
            while Date().timeIntervalSince(startTime) < timeout {
                // Check if server config appears (launch succeeded)
                if let config = findRunningServer() {
                    Log.server.info("✅ StdioProxy: Other process completed launch successfully")
                    // Clean up our lock attempt
                    try? FileManager.default.removeItem(at: lockPath)
                    startProxyAndExit(port: config.port)
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
        
        // Get the current app bundle path and construct path to executable
        let appPath = Bundle.main.bundlePath
        let executablePath = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/MacOS/RiffMCP")
        
        Log.server.info("🚀 StdioProxy: Launching GUI app at: \(executablePath.path)")
        
        // Launch the GUI app directly (avoiding /usr/bin/open to prevent Apple Events issues)
        let process = Process()
        process.executableURL = executablePath
        process.arguments = []
        
        do {
            try process.run()
        } catch {
            throw ProxyError.launchError("Failed to launch GUI app: \(error.localizedDescription)")
        }
        
        // Enter discovery loop with 15-second timeout
        let startTime = Date()
        let timeout: TimeInterval = 15.0
        let checkInterval: TimeInterval = 0.2
        
        Log.server.info("🔍 StdioProxy: Entering discovery loop (timeout: \(timeout)s)")
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Check for server config
            if let config = findRunningServer() {
                Log.server.info("✅ StdioProxy: Found config during discovery - port: \(config.port), pid: \(config.pid)")
                startProxyAndExit(port: config.port)
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
    
    /// Return a live `ServerConfig` if the GUI server is confirmed running.
    private static func findRunningServer() -> ServerConfigUtils.ServerConfig? {

        // 1. read file
        guard let cfg = ServerConfigUtils.readServerConfig() else {
            Log.server.info("❌ StdioProxy: no server.json found")
            return nil
        }
        Log.server.info("📄 StdioProxy: config says port \(cfg.port), pid \(cfg.pid)")

        // 2. verify PID alive
        guard ServerConfigUtils.isProcessRunning(pid: cfg.pid) else {
            Log.server.info("⚠️  StdioProxy: process \(cfg.pid) is dead – removing stale server.json")
            try? FileManager.default.removeItem(at: ServerConfigUtils.getConfigFilePath())
            return nil
        }

        // 3. success
        Log.server.info("✅ StdioProxy: process \(cfg.pid) is running; using existing server")
        return cfg
    }

    /// Starts the proxy and exits the process (never returns)
    /// - Parameter port: The port to proxy to
    private static func startProxyAndExit(port: UInt16) -> Never {
        Log.server.info("🔄 StdioProxy: Starting proxy to forward to port \(port)")
        
        let proxy = StdioProxy(port: port)
        
        do {
            try proxy.runBlocking()
        } catch {
            Log.server.error("Proxy error, exit (1): \(error.localizedDescription)")
            exit(1)
        }
        
        // After the stdin stream from the LLM client closes, the loop will end.
        // We must exit the proxy process cleanly.
        Log.server.error("Proxy exit (0)")
        exit(0)
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
            Log.server.error("Failed to extract request ID: \(error.localizedDescription)")
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
