//
//  ServerConfigUtils.swift
//  RiffMCP
//
//  Created by Claude on 7/18/2025.
//

import Foundation
import Darwin

/// Shared utilities for server configuration and process management
enum ServerConfigUtils {
    
    /// Server configuration data structure
    struct ServerConfig {
        let port: UInt16
        let pid: pid_t
        let host: String
        let status: String
        let timestamp: Date
    }
    
    /// Reads server configuration from the JSON file
    /// - Returns: ServerConfig if found and valid, nil otherwise
    static func readServerConfig() -> ServerConfig? {
        // Use single canonical path inside the sandbox container
        let configPath = getConfigFilePath()
        
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: configPath)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let port = json?["port"] as? UInt16,
                  let pid = json?["pid"] as? pid_t,
                  let host = json?["host"] as? String,
                  let status = json?["status"] as? String,
                  status == "running" else {
                // Invalid or incomplete config data - remove it
                try? FileManager.default.removeItem(at: configPath)
                return nil
            }
            
            // Parse timestamp (if missing, assume very old)
            var timestamp = Date.distantPast
            if let timestampString = json?["timestamp"] as? String {
                let formatter = ISO8601DateFormatter()
                timestamp = formatter.date(from: timestampString) ?? Date.distantPast
            }
            
            // Ignore configs older than 1 hour (PID recycling protection)
            let configAge = Date().timeIntervalSince(timestamp)
            if configAge > 3600 { // 1 hour
                Log.server.info("⏰ ServerConfig: Ignoring stale config (age: \(Int(configAge))s)")
                try? FileManager.default.removeItem(at: configPath)
                return nil
            }
            
            return ServerConfig(port: port, pid: pid, host: host, status: status, timestamp: timestamp)
        } catch {
            // Corrupted config file - remove it
            try? FileManager.default.removeItem(at: configPath)
            return nil
        }
    }
    
    /// Checks if a process with the given PID is still running
    /// - Parameter pid: The process ID to check
    /// - Returns: true if the process is running, false otherwise
    static func isProcessRunning(pid: pid_t) -> Bool {
        //  result == 0:
        //      The process exists and you have permission to signal it.
        //  result == -1:
        //      An error occurred. errno will be set to indicate the reason:
        //          ESRCH (3) : No such process exists with the given pid.
        //          EPERM (1) : The process exists, but you don't have permission to signal it (e.g., it's owned by another user).
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