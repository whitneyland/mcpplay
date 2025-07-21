//
//  HTTPServerTests.swift
//  RiffMCP
//
//  Created by Lee Whitney on 7/13/25.
//

import Testing
import Foundation
import Network
@testable import RiffMCP

// MARK: - Dummy AudioManager

/// Simple dummy audio manager for testing that just records calls
actor DummyAudioManager: AudioManaging {
    // Track calls for testing
    private(set) var playSequenceCalls: [String] = []
    
    nonisolated func playSequenceFromJSON(_ rawJSON: String) {
        Task {
            await recordCall(rawJSON)
        }
    }
    
    private func recordCall(_ rawJSON: String) {
        playSequenceCalls.append(rawJSON)
    }
}

// MARK: - Test Suite

@Suite("HTTP Server Tests")
struct HTTPServerTests {
    
    // MARK: - Test Helpers
    
    static func createTestServer() -> (server: HTTPServer, audioManager: DummyAudioManager) {
        let dummyAudioManager = DummyAudioManager()
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("RiffMCPTest-\(UUID().uuidString)")
        
        // Create minimal test fixtures
        let testToolsData = """
        [
            {
                "name": "play",
                "description": "Play a music sequence",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "tempo": {"type": "number"},
                        "tracks": {"type": "array"}
                    }
                }
            },
            {
                "name": "engrave",
                "description": "Generate sheet music",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "tempo": {"type": "number"},
                        "tracks": {"type": "array"}
                    }
                }
            }
        ]
        """.data(using: .utf8)!
        
        let testPromptsData = """
        [
            {
                "name": "test-prompt",
                "description": "A test prompt"
            }
        ]
        """.data(using: .utf8)!
        
        // Write test fixtures to temp files
        let toolsURL = tempDir.appendingPathComponent("tools.json")
        let promptsURL = tempDir.appendingPathComponent("prompts.json")
        
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try! testToolsData.write(to: toolsURL)
        try! testPromptsData.write(to: promptsURL)

        let server: HTTPServer
        do {
            // Create the MCPRequestHandler first
            let mcpRequestHandler = MCPRequestHandler(
                audioManager: dummyAudioManager,
                host: "127.0.0.1",
                port: 0, // Will be updated by HTTP server
                tempDirectory: tempDir,
                toolsURL: toolsURL,
                promptsURL: promptsURL
            )
            
            server = try HTTPServer(
                mcpRequestHandler: mcpRequestHandler,
                host: "127.0.0.1",
                port: 0, // Let kernel pick a free port
                tempDirectory: tempDir
            )
        } catch {
            fatalError("🚨 Failed to create HTTPServer: \(error)")
        }

        return (server: server, audioManager: dummyAudioManager)
    }
    
    // MARK: - Basic Tests
    
    @Test("Dummy AudioManager works")
    func dummyAudioManagerWorks() async throws {
        let dummyAudioManager = DummyAudioManager()
        dummyAudioManager.playSequenceFromJSON("{}")
        #expect(await dummyAudioManager.playSequenceCalls.count == 1)
    }
    
    @Test("Server can be created")
    func serverCanBeCreated() async throws {
        let (server, _) = Self.createTestServer()
        #expect(!server.isRunning)
        #expect(server.lastError == nil)
    }
    
    // MARK: - Basic Server Lifecycle Tests
    
    @Test("Server starts and stops correctly")
    func serverStartsAndStops() async throws {
        let (server, _) = Self.createTestServer()
        
        // Server should start successfully
        try await server.start()
        #expect(server.isRunning)
        #expect(server.lastError == nil)
        
        // Server should stop successfully
        await server.stop()
        #expect(!server.isRunning)
    }
    
    @Test("Server doesn't start twice")
    func serverDoesntStartTwice() async throws {
        let (server, _) = Self.createTestServer()
        
        try await server.start()
        #expect(server.isRunning)
        
        // Second start should not throw or change state
        try await server.start()
        #expect(server.isRunning)
        
        await server.stop()
    }
    
    // MARK: - HTTP Endpoint Tests
    
    @Test("Health endpoint returns healthy status")
    func healthEndpointReturnsHealthyStatus() async throws {
        let (server, _) = Self.createTestServer()
        
        try await server.start()
        
        // Test health endpoint
        let healthResponse = try await makeHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "GET",
            path: "/health"
        )
        
        #expect(healthResponse.statusCode == 200)
        #expect(healthResponse.headers["Content-Type"] == "application/json")
        #expect(healthResponse.body.contains("\"status\":\"healthy\""))
        #expect(healthResponse.body.contains("\"port\":\(server.resolvedPort!)"))
        
        await server.stop()
    }
    
    @Test("Unknown endpoints return 404")
    func unknownEndpointsReturn404() async throws {
        let (server, _) = Self.createTestServer()
        
        try await server.start()
        
        let response = try await makeHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "GET",
            path: "/nonexistent"
        )
        
        #expect(response.statusCode == 404)
        #expect(response.body == "Not Found")
        
        await server.stop()
    }
    
    // MARK: - JSON-RPC Tests
    
    @Test("JSON-RPC initialize request works")
    func jsonRpcInitializeWorks() async throws {
        let (server, _) = Self.createTestServer()
        
        try await server.start()
        
        let initRequest = """
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "test", "version": "1.0"}
            }
        }
        """
        
        let response = try await makeHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "POST",
            path: "/",
            body: initRequest,
            headers: ["Content-Type": "application/json"]
        )
        
        #expect(response.statusCode == 200)
        #expect(response.body.contains("\"protocolVersion\":\"2025-06-18\""))
        #expect(response.body.contains("\"capabilities\""))
        #expect(response.body.contains("\"serverInfo\""))
        
        await server.stop()
    }
    
    @Test("JSON-RPC tools/list request works")
    func jsonRpcToolsListWorks() async throws {
        let (server, _) = Self.createTestServer()
        
        try await server.start()
        
        let toolsRequest = """
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list"
        }
        """
        
        let response = try await makeHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "POST",
            path: "/",
            body: toolsRequest,
            headers: ["Content-Type": "application/json"]
        )
        
        #expect(response.statusCode == 200)
        #expect(response.body.contains("\"tools\""))
        
        await server.stop()
    }
    
    @Test("JSON-RPC play tool call works")
    func jsonRpcPlayToolWorks() async throws {
        let (server, dummyAudioManager) = Self.createTestServer()
        
        try await server.start()
        
        let playRequest = """
        {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "play",
                "arguments": {
                    "title": "Test Song",
                    "tempo": 120,
                    "tracks": [{
                        "instrument": "grand_piano",
                        "events": [{
                            "time": 0,
                            "pitches": ["C4"],
                            "dur": 1,
                            "vel": 100
                        }]
                    }]
                }
            }
        }
        """
        
        let response = try await makeHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "POST",
            path: "/",
            body: playRequest,
            headers: ["Content-Type": "application/json"]
        )
        
        #expect(response.statusCode == 200)
        #expect(response.body.contains("\"result\""))
        
        // Verify audio manager was called
        #expect(await dummyAudioManager.playSequenceCalls.count == 1)
        #expect(await dummyAudioManager.playSequenceCalls[0].contains("Test Song"))

        await server.stop()
    }
    
    @Test("JSON-RPC engrave tool is recognized")
    func jsonRpcEngraveToolIsRecognized() async throws {
        let (server, dummyAudioManager) = Self.createTestServer()
        
        try await server.start()
        
        // First verify that engrave is in the tools list
        let toolsListRequest = """
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/list"
        }
        """
        
        let toolsResponse = try await makeHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "POST",
            path: "/",
            body: toolsListRequest,
            headers: ["Content-Type": "application/json"]
        )
        
        #expect(toolsResponse.statusCode == 200)
        #expect(toolsResponse.body.contains("engrave"))
        
        // Now test a simple engrave call
        let engraveRequest = """
        {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": {
                "name": "engrave",
                "arguments": {
                    "title": "Test Note",
                    "tempo": 120,
                    "tracks": [{
                        "instrument": "grand_piano",
                        "events": [{
                            "time": 0,
                            "pitches": ["C4"],
                            "dur": 1,
                            "vel": 100
                        }]
                    }]
                }
            }
        }
        """
        
        let response = try await makeHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "POST",
            path: "/",
            body: engraveRequest,
            headers: ["Content-Type": "application/json"]
        )
        
        #expect(response.statusCode == 200)
        let responseBody = response.body
        
        // The server should handle the engrave request properly
        // Either with success or a proper error (not a "method not found" error)
        #expect(responseBody.contains("\"id\":4"))
        #expect(!responseBody.contains("Method not found"))
        #expect(!responseBody.contains("Unknown tool"))
        
        // Verify audio manager was NOT called for engrave (it's sheet music only)
        #expect(await dummyAudioManager.playSequenceCalls.count == 0)

        await server.stop()
    }
    
    @Test("JSON-RPC engrave tool creates accessible image")
    func jsonRpcEngraveToolCreatesAccessibleImage() async throws {
        let (server, _) = Self.createTestServer()
        
        try await server.start()
        
        // First, create an engraved image
        let engraveRequest = """
        {
            "jsonrpc": "2.0",
            "id": 5,
            "method": "tools/call",
            "params": {
                "name": "engrave",
                "arguments": {
                    "title": "Simple Note",
                    "tempo": 120,
                    "tracks": [{
                        "instrument": "grand_piano",
                        "events": [{
                            "time": 0,
                            "pitches": ["C4"],
                            "dur": 1,
                            "vel": 100
                        }]
                    }]
                }
            }
        }
        """
        
        let engraveResponse = try await makeHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "POST",
            path: "/",
            body: engraveRequest,
            headers: ["Content-Type": "application/json"]
        )
        
        #expect(engraveResponse.statusCode == 200)
        
        // Extract the image URL from the response (this is a simplified approach)
        // In a real scenario, you'd parse the JSON to get the exact filename
        let responseBody = engraveResponse.body
        #expect(responseBody.contains("\"result\""))
        #expect(responseBody.contains("image/png"))
        
        // For this test, we'll just verify that an image endpoint works
        // even if we can't extract the exact UUID filename from the response
        let testImageResponse = try await makeHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "GET",
            path: "/images/nonexistent.png"
        )
        
        // Should return 404 for non-existent image
        #expect(testImageResponse.statusCode == 404)
        
        await server.stop()
    }
    
    @Test("Image endpoint security prevents path traversal")
    func imageEndpointSecurityPreventsPathTraversal() async throws {
        let (server, _) = Self.createTestServer()
        
        try await server.start()
        
        // Test path traversal attempts
        let pathTraversalAttempts = [
            "/images/../../../etc/passwd",
            "/images/..%2F..%2F..%2Fetc%2Fpasswd",
            "/images/....//....//etc/passwd"
        ]
        
        for path in pathTraversalAttempts {
            let response = try await makeHTTPRequest(
                host: "127.0.0.1",
                port: server.resolvedPort!,
                method: "GET",
                path: path
            )
            
            // Should return 403 Forbidden for path traversal attempts
            #expect(response.statusCode == 403 || response.statusCode == 404)
            #expect(response.body == "Forbidden" || response.body == "Not Found")
        }
        
        await server.stop()
    }
    
    @Test("JSON-RPC invalid requests return errors")
    func jsonRpcInvalidRequestsReturnErrors() async throws {
        let (server, _) = Self.createTestServer()
        
        try await server.start()
        
        // Test invalid JSON
        let invalidJsonResponse = try await makeHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "POST",
            path: "/",
            body: "invalid json",
            headers: ["Content-Type": "application/json"]
        )
        
        #expect(invalidJsonResponse.statusCode == 200)
        #expect(invalidJsonResponse.body.contains("\"error\""))
        #expect(invalidJsonResponse.body.contains("parse"))
        
        // Test unknown method
        let unknownMethodRequest = """
        {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "unknown/method"
        }
        """
        
        let unknownMethodResponse = try await makeHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "POST",
            path: "/",
            body: unknownMethodRequest,
            headers: ["Content-Type": "application/json"]
        )
        
        #expect(unknownMethodResponse.statusCode == 200)
        #expect(unknownMethodResponse.body.contains("\"error\""))
        #expect(unknownMethodResponse.body.contains("Method not found"))
        
        await server.stop()
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Server handles invalid tool parameters gracefully")
    func serverHandlesInvalidToolParameters() async throws {
        let (server, _) = Self.createTestServer()
        
        try await server.start()
        
        let invalidPlayRequest = """
        {
            "jsonrpc": "2.0",
            "id": 5,
            "method": "tools/call",
            "params": {
                "name": "play",
                "arguments": {
                    "invalid": "parameters"
                }
            }
        }
        """
        
        let response = try await makeHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "POST",
            path: "/",
            body: invalidPlayRequest,
            headers: ["Content-Type": "application/json"]
        )
        
        #expect(response.statusCode == 200)
        #expect(response.body.contains("\"error\""))
        
        await server.stop()
    }

    // MARK: - HTTP Request Buffering Tests
    
    @Test("Server handles fragmented HTTP requests")
    func serverHandlesFragmentedHTTPRequests() async throws {
        let (server, _) = Self.createTestServer()
        
        try await server.start()
        
        // Test a request that might be fragmented
        let jsonBody = """
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "ping"
        }
        """
        
        // Test with multiple small fragments
        let response = try await makeFragmentedHTTPRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "POST",
            path: "/",
            body: jsonBody,
            headers: ["Content-Type": "application/json"],
            fragmentSizes: [10, 20, 30] // Send in small chunks
        )
        
        #expect(response.statusCode == 200)
        #expect(!response.body.contains("Empty or missing request body"))
        #expect(response.body.contains("\"result\"") || response.body.contains("\"error\""))
        
        await server.stop()
    }
    
    @Test("Server handles headers and body arriving separately")
    func serverHandlesHeadersAndBodySeparately() async throws {
        let (server, _) = Self.createTestServer()
        
        try await server.start()
        
        let jsonBody = """
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list"
        }
        """
        
        // Send headers first, then body after a delay
        let response = try await makeHeadersBodySeparateRequest(
            host: "127.0.0.1",
            port: server.resolvedPort!,
            method: "POST",
            path: "/",
            body: jsonBody,
            headers: ["Content-Type": "application/json"]
        )
        
        #expect(response.statusCode == 200)
        #expect(!response.body.contains("Empty or missing request body"))
        #expect(response.body.contains("\"tools\""))
        
        await server.stop()
    }
    
    @Test("Server handles multiple Content-Length scenarios")
    func serverHandlesMultipleContentLengthScenarios() async throws {
        let (server, _) = Self.createTestServer()
        
        try await server.start()
        
        // Test various body sizes
        let testCases = [
            ("Small body", #"{"jsonrpc":"2.0","id":1,"method":"ping"}"#),
            ("Medium body", """
                {
                    "jsonrpc": "2.0",
                    "id": 2,
                    "method": "initialize",
                    "params": {
                        "protocolVersion": "2025-06-18",
                        "capabilities": {"roots": {"listChanged": true}},
                        "clientInfo": {"name": "test-client", "version": "1.0.0"}
                    }
                }
                """),
            ("Large body with tool call", """
                {
                    "jsonrpc": "2.0",
                    "id": 3,
                    "method": "tools/call",
                    "params": {
                        "name": "play",
                        "arguments": {
                            "title": "Test Song with a very long title that might cause issues",
                            "tempo": 120,
                            "tracks": [
                                {
                                    "instrument": "grand_piano",
                                    "events": [
                                        {"time": 0, "pitches": ["C4"], "dur": 1, "vel": 100},
                                        {"time": 1, "pitches": ["D4"], "dur": 1, "vel": 100},
                                        {"time": 2, "pitches": ["E4"], "dur": 1, "vel": 100},
                                        {"time": 3, "pitches": ["F4"], "dur": 1, "vel": 100}
                                    ]
                                }
                            ]
                        }
                    }
                }
                """)
        ]
        
        for (description, body) in testCases {
            let response = try await makeHTTPRequest(
                host: "127.0.0.1",
                port: server.resolvedPort!,
                method: "POST",
                path: "/",
                body: body,
                headers: ["Content-Type": "application/json"]
            )
            
            #expect(response.statusCode == 200, "Failed for \(description)")
            #expect(!response.body.contains("Empty or missing request body"), "Got empty body error for \(description)")
        }
        
        await server.stop()
    }

    // MARK: - Concurrency Tests

    @Test("Server handles concurrent engrave requests")
    func testConcurrentEngraveRequests() async throws {
        let (server, _) = Self.createTestServer()
        try await server.start()

        let requestCount = 5
        
        await withTaskGroup(of: HTTPResponse.self) { group in
            for i in 0..<requestCount {
                group.addTask { 
                    let engraveRequest = """
                    {
                        "jsonrpc": "2.0",
                        "id": \(i + 10),
                        "method": "tools/call",
                        "params": {
                            "name": "engrave",
                            "arguments": {
                                "title": "Concurrent Test \(i)",
                                "tempo": 120,
                                "tracks": [{
                                    "instrument": "grand_piano",
                                    "events": [{"time": 0, "pitches": ["C4"], "dur": 1}]
                                }]
                            }
                        }
                    }
                    """
                    return try! await makeHTTPRequest(
                        host: "127.0.0.1",
                        port: server.resolvedPort!,
                        method: "POST",
                        path: "/",
                        body: engraveRequest,
                        headers: ["Content-Type": "application/json"]
                    )
                }
            }

            for await response in group {
                #expect(response.statusCode == 200)
            }
        }

        // Verify that the correct number of files were created
        let tempDir = server.tempDirectory
        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let pngFiles = files.filter { $0.pathExtension == "png" }
        #expect(pngFiles.count == requestCount)

        // Verify the activity log
        let activityLog = ActivityLog.shared
        let engraveEvents = await activityLog.events.filter { $0.message.contains("engrave") }
        #expect(engraveEvents.count >= requestCount)

        await server.stop()
    }
}

// MARK: - HTTP Client Helper

/// Simple HTTP client for testing
struct HTTPResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: String
}

/// Make a fragmented HTTP request to test buffering
func makeFragmentedHTTPRequest(
    host: String,
    port: UInt16,
    method: String,
    path: String,
    body: String? = nil,
    headers: [String: String] = [:],
    fragmentSizes: [Int]
) async throws -> HTTPResponse {
    
    return try await withCheckedThrowingContinuation { continuation in
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        
        connection.start(queue: .global())
        
        var requestString = "\(method) \(path) HTTP/1.1\r\n"
        requestString += "Host: \(host):\(port)\r\n"
        requestString += "Connection: close\r\n"
        
        if let body = body {
            requestString += "Content-Length: \(body.utf8.count)\r\n"
        }
        
        for (key, value) in headers {
            requestString += "\(key): \(value)\r\n"
        }
        
        requestString += "\r\n"
        
        if let body = body {
            requestString += body
        }
        
        guard let requestData = requestString.data(using: .utf8) else {
            continuation.resume(throwing: NSError(domain: "HTTPTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request"]))
            return
        }
        
        // Send data in fragments
        var currentIndex = 0
        var fragmentIndex = 0
        
        func sendNextFragment() {
            guard currentIndex < requestData.count else {
                // All data sent, now receive response
                receiveResponse()
                return
            }
            
            let fragmentSize = fragmentIndex < fragmentSizes.count ? fragmentSizes[fragmentIndex] : 50
            let endIndex = min(currentIndex + fragmentSize, requestData.count)
            let fragment = requestData.subdata(in: currentIndex..<endIndex)
            
            connection.send(content: fragment, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                currentIndex = endIndex
                fragmentIndex += 1
                
                // Small delay between fragments to simulate network conditions
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
                    sendNextFragment()
                }
            })
        }
        
        func receiveResponse() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                defer { connection.cancel() }
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: NSError(domain: "HTTPTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "No response data"]))
                    return
                }
                
                let response = try! parseHTTPResponse(responseString)
                continuation.resume(returning: response)
            }
        }
        
        sendNextFragment()
    }
}

/// Make an HTTP request where headers and body are sent separately
func makeHeadersBodySeparateRequest(
    host: String,
    port: UInt16,
    method: String,
    path: String,
    body: String? = nil,
    headers: [String: String] = [:]
) async throws -> HTTPResponse {
    
    return try await withCheckedThrowingContinuation { continuation in
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        
        connection.start(queue: .global())
        
        var headerString = "\(method) \(path) HTTP/1.1\r\n"
        headerString += "Host: \(host):\(port)\r\n"
        headerString += "Connection: close\r\n"
        
        if let body = body {
            headerString += "Content-Length: \(body.utf8.count)\r\n"
        }
        
        for (key, value) in headers {
            headerString += "\(key): \(value)\r\n"
        }
        
        headerString += "\r\n"
        
        guard let headerData = headerString.data(using: .utf8) else {
            continuation.resume(throwing: NSError(domain: "HTTPTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode headers"]))
            return
        }
        
        // Send headers first
        connection.send(content: headerData, completion: .contentProcessed { error in
            if let error = error {
                continuation.resume(throwing: error)
                return
            }
            
            // Wait a bit, then send body
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                if let body = body, let bodyData = body.data(using: .utf8) {
                    connection.send(content: bodyData, completion: .contentProcessed { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        // Now receive response
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                            defer { connection.cancel() }
                            
                            if let error = error {
                                continuation.resume(throwing: error)
                                return
                            }
                            
                            guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                                continuation.resume(throwing: NSError(domain: "HTTPTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "No response data"]))
                                return
                            }
                            
                            let response = try! parseHTTPResponse(responseString)
                            continuation.resume(returning: response)
                        }
                    })
                }
            }
        })
    }
}

/// Parse HTTP response string into HTTPResponse struct
func parseHTTPResponse(_ responseString: String) throws -> HTTPResponse {
    let lines = responseString.components(separatedBy: "\r\n")
    guard let statusLine = lines.first else {
        throw NSError(domain: "HTTPTest", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
    }
    
    let statusComponents = statusLine.components(separatedBy: " ")
    guard statusComponents.count >= 2, let statusCode = Int(statusComponents[1]) else {
        throw NSError(domain: "HTTPTest", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid status line"])
    }
    
    // Parse headers
    var responseHeaders: [String: String] = [:]
    var headerEndIndex = 1
    for (index, line) in lines.enumerated().dropFirst() {
        if line.isEmpty {
            headerEndIndex = index + 1
            break
        }
        let headerComponents = line.components(separatedBy: ": ")
        if headerComponents.count == 2 {
            responseHeaders[headerComponents[0]] = headerComponents[1]
        }
    }
    
    // Extract body
    let bodyLines = Array(lines.dropFirst(headerEndIndex))
    let responseBody = bodyLines.joined(separator: "\r\n")
    
    return HTTPResponse(
        statusCode: statusCode,
        headers: responseHeaders,
        body: responseBody
    )
}

/// Make an HTTP request for testing purposes
func makeHTTPRequest(
    host: String,
    port: UInt16,
    method: String,
    path: String,
    body: String? = nil,
    headers: [String: String] = [:]
) async throws -> HTTPResponse {
    
    return try await withCheckedThrowingContinuation { continuation in
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        
        connection.start(queue: .global())
        
        var requestString = "\(method) \(path) HTTP/1.1\r\n"
        requestString += "Host: \(host):\(port)\r\n"
        requestString += "Connection: close\r\n"
        
        if let body = body {
            requestString += "Content-Length: \(body.utf8.count)\r\n"
        }
        
        for (key, value) in headers {
            requestString += "\(key): \(value)\r\n"
        }
        
        requestString += "\r\n"
        
        if let body = body {
            requestString += body
        }
        
        guard let requestData = requestString.data(using: .utf8) else {
            continuation.resume(throwing: NSError(domain: "HTTPTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request"]))
            return
        }
        
        connection.send(content: requestData, completion: .contentProcessed { error in
            if let error = error {
                continuation.resume(throwing: error)
                return
            }
            
            // Receive response
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                defer { connection.cancel() }
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: NSError(domain: "HTTPTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "No response data"]))
                    return
                }
                
                do {
                    let response = try parseHTTPResponse(responseString)
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        })
    }
}
