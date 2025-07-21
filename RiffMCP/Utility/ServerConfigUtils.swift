//
//  ServerConfigUtils.swift
//  RiffMCP
//
//  Created by Claude on 7/18/2025.
//

import Foundation
import Darwin
import AppKit

/// Shared utilities for server configuration and process management
enum ServerConfigUtils {
    
    /// Server configuration data structure
    struct ServerConfig {
        let port: UInt16
        let pid: pid_t
        let host: String
        let status: String
        let instance: String
        let timestamp: Double   // epoch seconds
    }
    
    /// Reads server.json, validates it, and enforces a 1-hour staleness limit.
    /// - Returns: `ServerConfig` when the file exists *and* the PID/timestamp look valid; otherwise `nil`.
    static func readServerConfig() -> ServerConfig? {
        let configPath = getConfigFilePath()

        guard FileManager.default.fileExists(atPath: configPath.path) else {
            Log.server.info("❌ ServerConfig: not found - \(configPath.path)")
            return nil
        }

        guard let data = try? Data(contentsOf: configPath) else {
            Log.server.info("❌ ServerConfig: could not read - \(configPath.path)")
            return nil
        }

        // Best-effort JSON parse (don’t crash on bad types)
        guard
            let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let port  = json["port"]  as? UInt16 ?? (json["port"] as? Int).map(UInt16.init),
            let pid   = json["pid"]   as? Int,
            let host  = json["host"]  as? String,
            let status = json["status"] as? String,
            let instance = json["instance"] as? String
        else {
            Log.server.error("❌ ServerConfig: missing/invalid keys – deleting - \(configPath.path)")
            try? FileManager.default.removeItem(at: configPath)
            return nil
        }

        // Reject anything but a “running” status
        guard status == "running" else { return nil }

        // ----- age check (1 hour) ------------------------------------------------
        let epoch   = json["timestamp"] as? TimeInterval ?? 0         // 0 = distant past
        let age     = Date().timeIntervalSince1970 - epoch
        if age > 3600 {
            Log.server.info("⏰ ServerConfig: stale (age \(Int(age)) s) – deleting")
            try? FileManager.default.removeItem(at: configPath)
            return nil
        }

        return ServerConfig(port: port,
                            pid:  pid_t(pid),
                            host: host,
                            status: status,
                            instance: instance,
                            timestamp: epoch)
    }

    /// Checks if a process with the given PID is still running
    /// - Parameter pid: The process ID to check
    /// - Returns: true if the process is running, false otherwise
    static func isProcessRunning(pid: pid_t) -> Bool {
        // Use NSRunningApplication for more reliable process detection
        if let runningApp = NSRunningApplication(processIdentifier: pid) {
            return !runningApp.isTerminated
        }
        
        // Fallback to kill(pid, 0) for non-application processes
        let result = kill(pid, 0)
        if result == 0 {
            return true
        }
        if result == -1 && errno == EPERM {
            // Process exists but is not signalable — still counts as running
            return true
        }
        if result == -1 && errno == ESRCH {
            // Process does not exist — clean up stale config files
            cleanupStaleConfig()
            return false
        }
        // Other unexpected errors (e.g., invalid pid)
        return false
    }
    
    /// Returns the canonical path to the server config file
    /// - Returns: URL to the server.json file inside the sandbox container
    static func getConfigFilePath() -> URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return supportDir.appendingPathComponent("RiffMCP/server.json")
    }
    
    /// Removes stale server configuration files
    private static func cleanupStaleConfig() {
        let configPath = getConfigFilePath()
        try? FileManager.default.removeItem(at: configPath)
    }
}
