//
//  ServerProcess.swift
//  RiffMCP
//
//  Created by Lee Whitney on 8/1/25.
//

import Foundation
import AppKit
import Darwin

enum GUIInstanceCheckResult {
    case found(port: UInt16, pid: pid_t)
    case noConfigFile
    case processNotRunning(staleConfig: (port: UInt16, pid: pid_t))
}

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
            ServerConfig.remove()
            return false
        }
        // Other unexpected errors (e.g., invalid pid)
        return false
    }

    /// Checks for an existing GUI instance by looking for a valid server.json file
    /// - Returns: Result indicating whether an instance was found, no config exists, or process is dead
    static func checkForExistingGUIInstance() -> GUIInstanceCheckResult {
        guard let config = ServerConfig.read() else {
            return .noConfigFile
        }

        // Check if the process is still running
        if ServerProcess.isProcessRunning(pid: config.pid) {
            return .found(port: config.port, pid: config.pid)
        } else {
            // Process is dead, config already cleaned up by ServerConfigUtils
            return .processNotRunning(staleConfig: (config.port, config.pid))
        }
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
