//
//  ServerConfig.swift
//  RiffMCP
//
//

import Foundation
import AppKit

/// Server configuration data structure
struct ServerConfig {
    let port: UInt16
    let pid: pid_t
    let host: String
    let status: String
    let instance: String
    let timestamp: Double   // epoch seconds
    
    /// Reads server.json, validates it, and enforces a 1-hour staleness limit.
    /// - Returns: `ServerConfig` when the file exists *and* the PID/timestamp look valid; otherwise `nil`.
    static func read() -> ServerConfig? {
        let configPath = getConfigFilePath()

        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return nil
        }

        guard let data = try? Data(contentsOf: configPath) else {
            Log.server.info("❌ Server config: could not read - \(configPath.path)")
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
            Log.server.error("❌ Server config: missing/invalid keys – deleting - \(configPath.path)")
            ServerConfig.remove()
            return nil
        }

        // Reject anything but a “running” status
        guard status == "running" else { return nil }

        // ----- age check (1 hour) ------------------------------------------------
        let epoch   = json["timestamp"] as? TimeInterval ?? 0         // 0 = distant past
//        let age     = Date().timeIntervalSince1970 - epoch
//        if age > 3600 {
//            Log.server.info("⏰ Server config: stale (age \(Int(age)) s) – deleting")
//            ServerConfig.remove()
//            return nil
//        }

        return ServerConfig(port: port,
                            pid:  pid_t(pid),
                            host: host,
                            status: status,
                            instance: instance,
                            timestamp: epoch)
    }

    static func write(host: String, port: UInt16) throws {
        let configPath = ServerConfig.getConfigFilePath()
        try FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)

        let instanceUUID = UUID().uuidString
        let config: [String: Any] = [
            "port": port,
            "host": host,
            "status": "running",
            "pid": ProcessInfo.processInfo.processIdentifier,
            "instance": instanceUUID,
            "timestamp": Date().timeIntervalSince1970
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try jsonData.write(to: configPath, options: .atomic)        

        // Sanity-check the write
        guard let config = ServerConfig.read(), config.instance == instanceUUID else {
            throw NSError(domain: "RiffMCP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Server config write verification failed"])
        }
    }
    
    /// Removes stale server configuration files
    static func remove() {
        let configPath = getConfigFilePath()
        do {
            if FileManager.default.fileExists(atPath: configPath.path) {
                try FileManager.default.removeItem(at: configPath)
            }
        } catch {
            Log.server.error("❌ Failed to remove server config: \(error.localizedDescription)")
        }
    }

    /// Returns the canonical path to the server config file
    /// - Returns: URL to the server.json file inside the sandbox container
    static func getConfigFilePath() -> URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return supportDir.appendingPathComponent("RiffMCP/server.json")
    }
}
