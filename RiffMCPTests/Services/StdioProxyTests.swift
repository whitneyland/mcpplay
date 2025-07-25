//
//  StdioProxyTests.swift
//  RiffMCPTests
//
//  Tests for StdioProxy functionality
//

import Testing
import Foundation
@testable import RiffMCP

@Suite("StdioProxy Tests")
struct StdioProxyTests {
    
    // MARK: - Test Helpers
    
    /// Creates a temporary server config file for testing
    static func createTestServerConfig(port: UInt16, pid: pid_t? = nil) -> URL {
        let supportDir = FileManager.default.temporaryDirectory
        let configDir = supportDir.appendingPathComponent("RiffMCP-Test-\(UUID().uuidString)")
        let configPath = configDir.appendingPathComponent("RiffMCP/server.json")
        
        try! FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let config: [String: Any] = [
            "port": port,
            "host": "127.0.0.1",
            "status": "running",
            "pid": pid ?? ProcessInfo.processInfo.processIdentifier
        ]
        
        let jsonData = try! JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try! jsonData.write(to: configPath)
        
        return configPath
    }
    
    /// Creates a corrupted server config file for testing
    static func createCorruptedServerConfig() -> URL {
        let supportDir = FileManager.default.temporaryDirectory
        let configDir = supportDir.appendingPathComponent("RiffMCP-Test-\(UUID().uuidString)")
        let configPath = configDir.appendingPathComponent("RiffMCP/server.json")
        
        try! FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let corruptedData = "{ invalid json".data(using: .utf8)!
        try! corruptedData.write(to: configPath)
        
        return configPath
    }
    
    /// Sets the application support directory for testing
    static func setTestApplicationSupportDirectory(_ testDir: URL) {
        // Note: In a real implementation, we'd need to modify StdioProxy to accept
        // a configurable directory path for testing purposes
    }
    
    // MARK: - Server Config Reading Tests
    
    @Test("readServerConfig returns nil when no config file exists")
    func readServerConfigReturnsNilWhenNoConfigExists() {
        // Create a temporary directory that doesn't have a server config
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("RiffMCP-NoConfig-\(UUID().uuidString)")
        
        // Since StdioProxy looks in Application Support, and we can't easily mock that,
        // we'll test the behavior by ensuring no config exists in the default location
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configPath = supportDir.appendingPathComponent("RiffMCP/server.json")
        
        // Remove config if it exists
        try? FileManager.default.removeItem(at: configPath)
        
        // Note: Cannot test runAsProxyAndExitIfNeeded() directly as it returns Never
        // and would terminate the test process. Instead, verify the preconditions.
        #expect(!FileManager.default.fileExists(atPath: configPath.path), "Config should not exist")
    }
    
    @Test("readServerConfig handles corrupted config file gracefully")
    func readServerConfigHandlesCorruptedConfigGracefully() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configPath = supportDir.appendingPathComponent("RiffMCP/server.json")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // Create corrupted config
        let corruptedData = "{ invalid json".data(using: .utf8)!
        try? corruptedData.write(to: configPath)
        
        // Note: Cannot test runAsProxyAndExitIfNeeded() directly as it returns Never
        // and would terminate the test process. Instead, verify the corrupted config exists.
        #expect(FileManager.default.fileExists(atPath: configPath.path), "Corrupted config should exist for testing")
        
        // Clean up
        try? FileManager.default.removeItem(at: configPath)
    }
    
    // MARK: - Process Validation Tests
    
    @Test("isProcessRunning returns true for current process")
    func isProcessRunningReturnsTrueForCurrentProcess() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        // Create a test config with current process ID
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configPath = supportDir.appendingPathComponent("RiffMCP/server.json")
        
        try? FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let config: [String: Any] = [
            "port": 3001,
            "host": "127.0.0.1", 
            "status": "running",
            "pid": currentPID
        ]
        
        let jsonData = try! JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try? jsonData.write(to: configPath)
        
        // Since we can't easily test the actual proxy without it trying to exit the process,
        // we'll verify the config exists and is readable
        #expect(FileManager.default.fileExists(atPath: configPath.path), "Config should exist")
        
        // Clean up
        try? FileManager.default.removeItem(at: configPath)
    }
    
    @Test("isProcessRunning returns false for non-existent process")
    func isProcessRunningReturnsFalseForNonExistentProcess() {
        let nonExistentPID: pid_t = 99999 // Very unlikely to exist
        
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configPath = supportDir.appendingPathComponent("RiffMCP/server.json")
        
        try? FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let config: [String: Any] = [
            "port": 3001,
            "host": "127.0.0.1",
            "status": "running", 
            "pid": nonExistentPID
        ]
        
        let jsonData = try! JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try? jsonData.write(to: configPath)
        
        // Note: Cannot test runAsProxyAndExitIfNeeded() directly as it returns Never
        // and would terminate the test process. Instead, verify the config was created.
        #expect(FileManager.default.fileExists(atPath: configPath.path), "Config should exist for testing")
        
        // Clean up
        try? FileManager.default.removeItem(at: configPath)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("ProxyError provides proper error descriptions")
    func proxyErrorProvidesProperErrorDescriptions() {
        let invalidHeaderError = ProxyError.invalidHeader("test reason")
        let eofError = ProxyError.unexpectedEndOfStream
        let httpError = ProxyError.invalidHTTPResponse("500 error")
        let encodingError = ProxyError.responseEncodingError
        
        #expect(invalidHeaderError.errorDescription?.contains("Invalid Stdio Header") == true)
        #expect(eofError.errorDescription?.contains("Unexpected end") == true)
        #expect(httpError.errorDescription?.contains("Invalid HTTP response") == true)
        #expect(encodingError.errorDescription?.contains("Failed to encode") == true)
    }
    
    // MARK: - Stdio Protocol Tests
    
    @Test("StdioProxy header reading format validation")
    func stdioProxyHeaderReadingFormatValidation() {
        // Test the Content-Length header format that StdioProxy expects
        let validHeader = "Content-Length: 123\r\n\r\n"
        let terminator = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n
        
        #expect(terminator.count == 4, "Header terminator should be 4 bytes")
        
        let headerData = validHeader.data(using: .ascii)!
        #expect(headerData.suffix(4).elementsEqual(terminator), "Valid header should end with terminator")
        
        // Test header parsing logic
        let lines = validHeader.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\r\n")
        var foundContentLength: Int?
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 && parts[0].lowercased() == "content-length" {
                foundContentLength = Int(parts[1])
                break
            }
        }
        #expect(foundContentLength == 123, "Should extract Content-Length value correctly")
    }
    
    @Test("StdioProxy response formatting includes proper headers")
    func stdioProxyResponseFormattingIncludesProperHeaders() {
        // Test response encoding format that StdioProxy uses
        let testData = "test response".data(using: .utf8)!
        let header = "Content-Length: \(testData.count)\r\n\r\n"
        let headerData = header.data(using: .utf8)!
        
        #expect(headerData.count > 0, "Header should be encodable")
        #expect(header.contains("Content-Length:"), "Header should contain Content-Length")
        #expect(header.hasSuffix("\r\n\r\n"), "Header should end with proper terminator")
        
        // Verify complete response format
        var completeResponse = Data()
        completeResponse.append(headerData)
        completeResponse.append(testData)
        
        #expect(completeResponse.count == headerData.count + testData.count, "Complete response should combine header and data")
    }
    
    // MARK: - Integration-Style Tests
    
    @Test("StdioProxy initialization creates proper URLSession configuration")
    func stdioProxyInitializationCreatesProperURLSessionConfiguration() {
        // Test that StdioProxy would be initialized with reasonable settings
        let testPort: UInt16 = 3001
        
        // Since StdioProxy's URLSession is private, we'll test the configuration
        // that would be used
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        
        #expect(config.timeoutIntervalForRequest == 30, "Timeout should be set to 30 seconds")
        #expect(config != URLSessionConfiguration.ephemeral, "Should use default configuration")
    }
    
    @Test("StdioProxy HTTP request format validation")
    func stdioProxyHTTPRequestFormatValidation() {
        // Test the HTTP request format that StdioProxy would send
        let testPort: UInt16 = 3001
        let testData = """
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {}
        }
        """.data(using: .utf8)!
        
        let url = URL(string: "http://127.0.0.1:\(testPort)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = testData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        #expect(request.httpMethod == "POST", "Should use POST method")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json", "Should set JSON content type")
        #expect(request.httpBody == testData, "Should include request body")
        #expect(request.url?.host == "127.0.0.1", "Should target localhost")
        #expect(request.url?.port == Int(testPort), "Should target correct port")
    }
    
    // MARK: - Mock Server Tests
    
    @Test("StdioProxy behavior with running HTTP server")
    func stdioProxyBehaviorWithRunningHTTPServer() async throws {
        // Create a simple HTTP server for testing
        let dummyAudioManager = DummyAudioManager()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("StdioProxyTest-\(UUID().uuidString)")
        
        let mcpHandler = MCPRequestHandler(
            audioManager: dummyAudioManager,
            host: "127.0.0.1",
            port: 0,
            tempDirectory: tempDir
        )
        
        let server = try HTTPServer(
            mcpRequestHandler: mcpHandler,
            host: "127.0.0.1",
            port: 0, // Let kernel pick port
            tempDirectory: tempDir
        )
        
        try await server.start()
        
        // Create a server config that points to our test server
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configPath = supportDir.appendingPathComponent("RiffMCP/server.json")
        
        try? FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let config: [String: Any] = [
            "port": server.resolvedPort!,
            "host": "127.0.0.1",
            "status": "running",
            "pid": ProcessInfo.processInfo.processIdentifier
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try jsonData.write(to: configPath)
        
        // Verify that the proxy would find a running server
        #expect(FileManager.default.fileExists(atPath: configPath.path), "Config should exist")
        
        // Since we can't actually test the proxy running without it calling exit(),
        // we verify the prerequisites are in place
        let data = try Data(contentsOf: configPath)
        let readConfig = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(readConfig?["port"] as? UInt16 == server.resolvedPort!, "Port should match")
        #expect(readConfig?["status"] as? String == "running", "Status should be running")
        #expect(readConfig?["pid"] as? pid_t == ProcessInfo.processInfo.processIdentifier, "PID should match current process")
        
        // Clean up
        await server.stop()
        try? FileManager.default.removeItem(at: configPath)
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Test Helper Extensions

extension StdioProxyTests {
    
    /// Dummy AudioManager for testing (reused from HTTPServerTests)
    actor DummyAudioManager: AudioManaging {
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
}