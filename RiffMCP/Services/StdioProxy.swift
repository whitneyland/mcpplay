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
    static func runAsProxyAndExitIfNeeded() -> Never {

        // Check for existing server first
        if let config = findRunningServer() {
            startProxyAndExit(port: config.port) // This call is `-> Never`
        }

        // If we reach here, no server is running. Launch the GUI app and wait for it.
        Log.server.info("🚀 StdioProxy: No server running, launching GUI app...")

        do {
            // This function is designed to either throw an error or call
            // a `Never`-returning function (`startProxyAndExit`) internally.
            // It should never return control to this point.
            try launchGUIAppAndWait()
        } catch {
            // If launchGUIAppAndWait throws, we log the error and exit.
            Log.server.error("❌ StdioProxy: Failed to launch GUI app: \(error.localizedDescription)")
            exit(1) // This call is `-> Never`
        }

        // The logic of launchGUIAppAndWait dictates that we should never reach this point.
        fatalError("StdioProxy: runAsProxyAndExitIfNeeded reached an unreachable state. Terminating.")
    }

    mutating func runBlocking() throws {
        // Log.server.info("🔄 StdioProxy: Starting proxy loop…")

        var sawFirstRequest = false
        let idle: TimeInterval = 0.05

        while true {
            do {
                // ── header ──
                if let hdr = try StdioIO.readHeader(from: stdin) {
                    clientFormat = hdr.format                        // Capture client format
                    // ── body ──
                    let json = try StdioIO.readBody(from: stdin, length: hdr.length)
                    sawFirstRequest = true
                    try forwardRequestSync(data: json)
                    continue
                }

                // clean EOF (nil) before first request → just wait
                if sawFirstRequest { break }
                Thread.sleep(forTimeInterval: idle)

            } catch StdioError.unexpectedEndOfStream,        // <-- here
                    ProxyError.unexpectedEndOfStream {       // fd variant
                if sawFirstRequest { break }                 // normal shutdown
                Thread.sleep(forTimeInterval: idle)          // still waiting
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

        Log.server.info("🔄 Proxy sending POST to URL: \(url), \(data.count) bytes")
//        Log.server.info("🔄 Proxy request headers: \(request.allHTTPHeaderFields ?? [:])")
//        Log.server.info("🔄 Proxy request body size: \(request.httpBody?.count ?? 0)")
//        if let bodyString = request.httpBody.flatMap({ String(data: $0, encoding: .utf8) }) {
//            Log.server.info("🔄 Proxy request body content: '\(bodyString)'")
//        }

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Data, Error>?
        var httpStatus: Int?

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
            httpStatus = httpResponse.statusCode

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

        // MPC/JSON-RPC say must return nothing in the case of notifications (which return HTTP 202)
        if httpStatus == 202 {
            Log.server.info("StdioProxy: send no response for notifications.")
            return
        }

        switch result! {
        case .success(let responseData):
            try write(data: responseData)
        case .failure(let error):
            Log.server.error("StdioProxy: forwarding error: \(error.localizedDescription)")
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
        try StdioIO.write(data, to: stdout, using: clientFormat)
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
        
        // Get the current app bundle path
        let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        
        Log.server.info("🚀 StdioProxy: Launching GUI app via LaunchServices at: \(bundleURL.path)")
        

        let runningApp: NSRunningApplication
        do {
            // Launch via LaunchServices to avoid sandbox termination
            // Use the synchronous launchApplication method for compatibility
            runningApp = try NSWorkspace.shared.launchApplication(at: bundleURL, options: [.newInstance, .andHide], configuration: [:])
            let childPID = runningApp.processIdentifier
            Log.server.info("🚀 Launched GUI via LaunchServices — pid \(childPID)")
        } catch {
            throw ProxyError.launchError("Failed to launch GUI app via LaunchServices: \(error.localizedDescription)")
        }


        // Enter discovery loop with 15-second timeout
        let startTime = Date()
        let timeout: TimeInterval = 15.0
        let checkInterval: TimeInterval = 0.25

        Log.server.info("🔍 StdioProxy: Entering discovery loop (timeout: \(timeout)s)")
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Check for server config
            if let config = findRunningServer() {
                Log.server.info("✅ StdioProxy: Found config during discovery - port: \(config.port), pid: \(config.pid)")
                startProxyAndExit(port: config.port)
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
    
    /// Return a live `ServerConfig` if the GUI server is confirmed running.
    private static func findRunningServer() -> ServerConfigUtils.ServerConfig? {

        // 1. read file
        guard let cfg = ServerConfigUtils.readServerConfig() else {
            return nil
        }
        // Log.server.info("📄 StdioProxy: config says port \(cfg.port), pid \(cfg.pid)")

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
        
        var proxy = StdioProxy(port: port)        // was let
        
        do {
            try proxy.runBlocking()                   // now mutating
        } catch {
            Log.server.error("StdioProxy: exit (1): \(error.localizedDescription)")
            exit(1)
        }
        
        // After the stdin stream from the LLM client closes, the loop will end.
        // We must exit the proxy process cleanly.
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
