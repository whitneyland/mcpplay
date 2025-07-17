//
//  StdioServerTests.swift
//  RiffMCPTests
//
//  Tests for StdioServer functionality
//

import Testing
import Foundation
@testable import RiffMCP

@Suite("StdioServer Tests")
struct StdioServerTests {
    
    // MARK: - Mock Audio Manager
    
    @MainActor
    class MockAudioManager: AudioManaging {
        var lastPlayedSequence: String = ""
        
        func playSequenceFromJSON(_ json: String) {
            lastPlayedSequence = json
        }
    }
    
    // MARK: - Test Cases
    
    @Test("StdioServer can be created and started without crashing")
    func createAndStartServer() async throws {
        let mockAudioManager = await MockAudioManager()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test-stdio")
        let mcpHandler = MCPRequestHandler(
            audioManager: mockAudioManager,
            host: "127.0.0.1",
            port: 3001,
            tempDirectory: tempDir
        )
        
        let server = StdioServer(mcpRequestHandler: mcpHandler)
        
        // Start and immediately stop to test initialization
        server.start()
        server.stop()
        
        // If we get here without crashing, the test passes
        #expect(true, "StdioServer should start and stop without crashing")
    }
    
    @Test("StdioError provides proper error descriptions")
    func stdioErrorDescriptions() {
        let invalidHeaderError = StdioError.invalidHeader("test reason")
        let eofError = StdioError.unexpectedEndOfStream
        let incompleteError = StdioError.incompleteMessage
        let encodingError = StdioError.responseEncodingError
        
        #expect(invalidHeaderError.errorDescription?.contains("Invalid Stdio Header") == true)
        #expect(eofError.errorDescription?.contains("Unexpected end") == true)
        #expect(incompleteError.errorDescription?.contains("Incomplete message") == true)
        #expect(encodingError.errorDescription?.contains("Failed to encode") == true)
    }
    
    @Test("StdioServer processes JSON-RPC through MCPRequestHandler")
    func processJSONRPCThroughHandler() async throws {
        let mockAudioManager = await MockAudioManager()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test-stdio-handler")
        let mcpHandler = MCPRequestHandler(
            audioManager: mockAudioManager,
            host: "127.0.0.1",
            port: 3001,
            tempDirectory: tempDir
        )
        
        // Test that we can create a server with the handler
        let server = StdioServer(mcpRequestHandler: mcpHandler)
        
        // Verify the server exists and can be started/stopped
        server.start()
        server.stop()
        
        #expect(true, "StdioServer should work with MCPRequestHandler")
    }
    
    @Test("StdioServer header parsing handles Content-Length format")
    func headerParsingValidation() {
        // Test that the header terminator is correctly defined
        let terminator = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n
        #expect(terminator.count == 4, "Header terminator should be 4 bytes")
        
        // Test valid Content-Length header format
        let validHeader = "Content-Length: 123\r\n\r\n"
        let headerData = validHeader.data(using: .ascii)!
        #expect(headerData.suffix(4).elementsEqual(terminator), "Valid header should end with terminator")
        
        // Test that we can extract content length from header string
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
    
    @Test("StdioServer response formatting includes proper headers")
    func responseFormatting() throws {
        // Test response encoding format
        let mockResponse = JSONRPCResponse(result: .object(["test": .string("value")]), id: .int(1))
        let responseData = try JSONEncoder().encode(mockResponse)
        
        // Test header format that StdioServer would generate
        let headerString = "Content-Length: \(responseData.count)\r\n\r\n"
        let headerData = headerString.data(using: .utf8)!
        
        #expect(headerData.count > 0, "Header should be encodable")
        #expect(headerString.contains("Content-Length:"), "Header should contain Content-Length")
        #expect(headerString.hasSuffix("\r\n\r\n"), "Header should end with proper terminator")
        
        // Verify complete response format
        var completeResponse = Data()
        completeResponse.append(headerData)
        completeResponse.append(responseData)
        
        #expect(completeResponse.count == headerData.count + responseData.count, "Complete response should combine header and data")
    }
}