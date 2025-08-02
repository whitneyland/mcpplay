//
//  ServerProcess.swift
//  RiffMCP
//
//  Created by Lee Whitney on 8/1/25.
//

import Foundation
import AppKit
import Darwin

enum ServerProcess {
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
            ServerConfig.cleanup()
            return false
        }
        // Other unexpected errors (e.g., invalid pid)
        return false
    }

    /// Return a live `ServerConfig` if the GUI server is confirmed running.
    static func findRunningServer() -> ServerConfig? {

        // 1. read file
        guard let cfg = ServerConfig.read() else {
            return nil
        }
        // Log.server.info("📄 StdioProxy: config says port \(cfg.port), pid \(cfg.pid)")

        // 2. verify PID alive
        guard ServerProcess.isProcessRunning(pid: cfg.pid) else {
            Log.server.info("⚠️  StdioProxy: process \(cfg.pid) is dead – removing stale server.json")
            try? FileManager.default.removeItem(at: ServerConfig.getConfigFilePath())
            return nil
        }

        // 3. success
        Log.server.info("✅ StdioProxy: process \(cfg.pid) is running; using existing server")
        return cfg
    }

    static func startAppGUI() throws -> NSRunningApplication {

        do {
            let runningApp: NSRunningApplication
            let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            Log.server.info("🚀 StdioProxy: Launching GUI app via LaunchServices at: \(bundleURL.path)")

            // Launch via LaunchServices to avoid sandbox termination
            // Use the synchronous launchApplication method for compatibility
            runningApp = try NSWorkspace.shared.launchApplication(at: bundleURL, options: [.newInstance, .andHide], configuration: [:])
            let childPID = runningApp.processIdentifier
            Log.server.info("🚀 Launched GUI via LaunchServices — pid \(childPID)")
            return runningApp
        } catch {
            throw ProxyError.launchError("Failed to launch GUI app via LaunchServices: \(error.localizedDescription)")
        }
    }
}
