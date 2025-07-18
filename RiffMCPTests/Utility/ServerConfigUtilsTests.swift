//
//  ServerConfigUtilsTests.swift
//  RiffMCPTests
//
//  Created by Claude on 7/18/2025.
//

import Testing
import Foundation
@testable import RiffMCP

@Suite("ServerConfigUtils Tests")
struct ServerConfigUtilsTests {
    
    @Test("Read valid server config")
    func readServerConfig_ValidConfig() throws {
        // Given: A valid server config file at the canonical path
        let configFile = ServerConfigUtils.getConfigFilePath()
        let configDirectory = configFile.deletingLastPathComponent()
        
        // Backup existing config if it exists
        var backupData: Data? = nil
        if FileManager.default.fileExists(atPath: configFile.path) {
            backupData = try? Data(contentsOf: configFile)
        }
        
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        
        let config: [String: Any] = [
            "port": 3001,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "host": "127.0.0.1",
            "status": "running",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try JSONSerialization.data(withJSONObject: config)
        try data.write(to: configFile)
        
        // When: Reading the config
        let result = ServerConfigUtils.readServerConfig()
        
        // Then: Should return valid config
        #expect(result != nil)
        #expect(result?.port == 3001)
        #expect(result?.pid == ProcessInfo.processInfo.processIdentifier)
        #expect(result?.host == "127.0.0.1")
        #expect(result?.status == "running")
        
        // Cleanup: Remove test config and restore backup if needed
        try? FileManager.default.removeItem(at: configFile)
        if let backupData = backupData {
            try? backupData.write(to: configFile)
        }
    }
    
    @Test("Read server config with invalid status")
    func readServerConfig_InvalidStatus() throws {
        // Given: A config with invalid status at the canonical path
        let configFile = ServerConfigUtils.getConfigFilePath()
        let configDirectory = configFile.deletingLastPathComponent()
        
        // Backup existing config if it exists
        var backupData: Data? = nil
        if FileManager.default.fileExists(atPath: configFile.path) {
            backupData = try? Data(contentsOf: configFile)
        }
        
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        
        let config: [String: Any] = [
            "port": 3001,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "host": "127.0.0.1",
            "status": "stopped",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try JSONSerialization.data(withJSONObject: config)
        try data.write(to: configFile)
        
        // When: Reading the config
        let result = ServerConfigUtils.readServerConfig()
        
        // Then: Should return nil and remove file
        #expect(result == nil)
        #expect(!FileManager.default.fileExists(atPath: configFile.path))
        
        // Cleanup: Restore backup if needed
        if let backupData = backupData {
            try? backupData.write(to: configFile)
        }
    }
    
    @Test("Read server config when file missing")
    func readServerConfig_MissingFile() {
        // Given: No config file exists
        
        // When: Reading the config
        let result = ServerConfigUtils.readServerConfig()
        
        // Then: Should return nil
        #expect(result == nil)
    }
    
    @Test("Read corrupted server config file")
    func readServerConfig_CorruptedFile() throws {
        // Given: A corrupted config file
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RiffMCPTests")
            .appendingPathComponent(UUID().uuidString)
        
        let configDirectory = tempDirectory.appendingPathComponent("RiffMCP")
        let configFile = configDirectory.appendingPathComponent("server.json")
        
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        
        let corruptedData = "not valid json".data(using: .utf8)!
        try corruptedData.write(to: configFile)
        
        // When: Reading the config
        let result = ServerConfigUtils.readServerConfig()
        
        // Then: Should return nil and remove corrupted file
        #expect(result == nil)
        #expect(!FileManager.default.fileExists(atPath: configFile.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    @Test("Read server config with stale timestamp")
    func readServerConfig_StaleTimestamp() throws {
        // Given: A config with old timestamp (>1 hour ago)
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RiffMCPTests")
            .appendingPathComponent(UUID().uuidString)
        
        let configDirectory = tempDirectory.appendingPathComponent("RiffMCP")
        let configFile = configDirectory.appendingPathComponent("server.json")
        
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        
        // Create timestamp that's 2 hours old
        let staleTimestamp = Date().addingTimeInterval(-7200) // 2 hours ago
        let config: [String: Any] = [
            "port": 3001,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "host": "127.0.0.1",
            "status": "running",
            "timestamp": ISO8601DateFormatter().string(from: staleTimestamp)
        ]
        let data = try JSONSerialization.data(withJSONObject: config)
        try data.write(to: configFile)
        
        // When: Reading the config
        let result = ServerConfigUtils.readServerConfig()
        
        // Then: Should return nil and remove stale file
        #expect(result == nil)
        #expect(!FileManager.default.fileExists(atPath: configFile.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    @Test("Check if current process is running")
    func isProcessRunning_CurrentProcess() {
        // Given: Current process PID
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        // When: Checking if process is running
        let isRunning = ServerConfigUtils.isProcessRunning(pid: currentPID)
        
        // Then: Should return true
        #expect(isRunning == true)
    }
    
    @Test("Check if non-existent process is running")
    func isProcessRunning_NonExistentProcess() {
        // Given: A PID that doesn't exist (using a very high number)
        let fakePID: pid_t = 999999
        
        // When: Checking if process is running
        let isRunning = ServerConfigUtils.isProcessRunning(pid: fakePID)
        
        // Then: Should return false
        #expect(isRunning == false)
    }
}