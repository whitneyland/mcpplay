//
//  AppLaunchTests.swift
//  RiffMCPTests
//
//  Created by Claude on 7/18/2025.
//

import Testing
import Foundation
@testable import RiffMCP

@Suite("App Launch Scenarios")
struct AppLaunchTests {
    
    @Test("Normal GUI launch with no existing instance")
    func normalGUILaunch_NoExistingInstance() throws {
        // Given: No existing server config file
        cleanupAllConfigFiles()
        
        // When: Checking for existing GUI instance
        let app = RiffMCPApp()
        let existingInstance = app.checkForExistingGUIInstance()
        
        // Then: Should return nil (no existing instance)
        #expect(existingInstance == nil)
    }
    
    @Test("Normal GUI launch with stale config file")
    func normalGUILaunch_StaleConfig() throws {
        // Given: A stale config file with dead process
        let tempDirectory = createTempConfigDirectory()
        let configFile = tempDirectory.appendingPathComponent("server.json")
        
        let staleConfig: [String: Any] = [
            "port": 3001,
            "pid": 99999, // Non-existent PID
            "host": "127.0.0.1",
            "status": "running"
        ]
        let data = try JSONSerialization.data(withJSONObject: staleConfig)
        try data.write(to: configFile)
        
        // When: Checking for existing GUI instance
        let app = RiffMCPApp()
        let existingInstance = app.checkForExistingGUIInstance()
        
        // Then: Should return nil and clean up stale file
        #expect(existingInstance == nil)
        #expect(!FileManager.default.fileExists(atPath: configFile.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDirectory.deletingLastPathComponent())
    }
    
    @Test("Normal GUI launch with existing running instance")
    func normalGUILaunch_ExistingInstance() throws {
        // Given: A valid config file with current process
        let tempDirectory = createTempConfigDirectory()
        let configFile = tempDirectory.appendingPathComponent("server.json")
        
        let runningConfig: [String: Any] = [
            "port": 3001,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "host": "127.0.0.1",
            "status": "running"
        ]
        let data = try JSONSerialization.data(withJSONObject: runningConfig)
        try data.write(to: configFile)
        
        // When: Checking for existing GUI instance
        let app = RiffMCPApp()
        let existingInstance = app.checkForExistingGUIInstance()
        
        // Then: Should return the existing instance
        #expect(existingInstance != nil)
        #expect(existingInstance?.port == 3001)
        #expect(existingInstance?.pid == ProcessInfo.processInfo.processIdentifier)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDirectory.deletingLastPathComponent())
    }
    
    // Helper functions
    private func cleanupAllConfigFiles() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let regularPath = supportDir.appendingPathComponent("RiffMCP/server.json")
        let sandboxPath = supportDir.appendingPathComponent("../Containers/com.whitneyland.RiffMCP/Data/Library/Application Support/RiffMCP/server.json").standardized
        
        try? FileManager.default.removeItem(at: regularPath)
        try? FileManager.default.removeItem(at: sandboxPath)
    }
    
    private func createTempConfigDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RiffMCPTests")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("RiffMCP")
        
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
}

// Extension to make private methods testable
extension RiffMCPApp {
    func checkForExistingGUIInstance() -> (port: UInt16, pid: pid_t)? {
        guard let config = ServerConfigUtils.readServerConfig() else {
            return nil
        }
        
        // Check if the process is still running
        if ServerConfigUtils.isProcessRunning(pid: config.pid) {
            return (config.port, config.pid)
        } else {
            // Process is dead, config already cleaned up by ServerConfigUtils
            return nil
        }
    }
}