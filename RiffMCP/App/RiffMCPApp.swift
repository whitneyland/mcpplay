//
//  RiffMCPApp.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/7/25.
//

import SwiftUI
import Foundation

@main
struct RiffMCPApp: App {
    @State private var services: AppServices?
    @State private var launchError: Error?
    
    // This is set to false only if we must terminate due to a duplicate instance.
    private static var shouldLaunchUI: Bool = true

    init() {
        // CASE 1: Launched with --stdio. This path takes over the process and never returns.
        if CommandLine.arguments.contains("--stdio") {
            // The compiler knows this function is `-> Never`, meaning it will not
            // return. The process will be terminated within this call.
            // The SwiftUI App body will never be initialized.
            StdioProxy.runAsProxyAndExitIfNeeded()
        }

        // CASE 2: Normal GUI Launch. This code is only reached if --stdio is NOT present.
        // Check for an existing instance of the GUI app.
        if let existingInstance = checkForExistingGUIInstance() {
            Log.server.info("🔍 Found existing GUI instance: port \(existingInstance.port), pid \(existingInstance.pid)")

            // Bring existing window to front.
            bringExistingWindowToFront()

            // This new, redundant instance should not launch its UI and should terminate.
            RiffMCPApp.shouldLaunchUI = false
            Log.server.info("🏁 Terminating duplicate instance.")
            NSApp.terminate(nil) // Gracefully terminates this redundant process.

        } else {
            // No existing GUI instance was found. Proceed with a normal launch.
            // `shouldLaunchUI` remains its default `true` value.
            Log.server.info("✅ No existing GUI instance found - proceeding with normal launch")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                // Only show the main view if we're not in a successful proxy mode.
                if RiffMCPApp.shouldLaunchUI {
                    if let svc = services {
                        // ✅ Services exist – run the real UI
                        MainView()
                            .environmentObject(svc.audioManager)
                            .environmentObject(svc.httpServer)
                    } else if launchError == nil {
                        // ⏳ Still launching
                        ProgressView("Starting services…")
                            .padding()
                    }
                }
            }
            // Kick off launch once the view appears
            .task(id: "startup") {
                // Only run once and only if we should launch UI
                guard RiffMCPApp.shouldLaunchUI && services == nil && launchError == nil else { return }

                do {
                    let svc = try AppServices()
                    services = svc               // <- @State is settable
                    try await svc.startServices()
                } catch {
                    launchError = error
                }
            }
            // Show an alert if we failed
            .alert(
                "RiffMCP failed to start",
                isPresented: .constant(RiffMCPApp.shouldLaunchUI && launchError != nil)
            ) {
                Button("Quit") { NSApp.terminate(nil) }
            } message: {
                Text(launchError?.localizedDescription ?? "Unknown error")
            }
        }
        .commands { AboutCommands() }
    }
    
    /// Checks for an existing GUI instance by looking for a valid server.json file
    /// - Returns: Server config if found and process is running, nil otherwise
    private func checkForExistingGUIInstance() -> (port: UInt16, pid: pid_t)? {
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
    
    /// Brings the existing window to the front by activating the running process
    private func bringExistingWindowToFront() {
        // Use NSRunningApplication instead of AppleScript to avoid sandbox entitlement requirements
        guard let config = ServerConfigUtils.readServerConfig() else {
            Log.server.error("Cannot bring window to front: no server config found")
            return
        }
        
        if let app = NSRunningApplication(processIdentifier: config.pid) {
            let success = app.activate(options: [.activateIgnoringOtherApps])
            if success {
                Log.server.info("✅ Brought existing window to front")
            } else {
                Log.server.error("Failed to activate existing application window")
            }
        } else {
            Log.server.error("Failed to find running application with PID: \(config.pid)")
        }
    }
}

struct AboutCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About RiffMCP") {
                if let window = NSApplication.shared.windows.first {
                    let aboutView = AboutView()
                    let hostingController = NSHostingController(rootView: aboutView)
                    let aboutWindow = NSWindow(contentViewController: hostingController)
                    aboutWindow.title = "About RiffMCP"
                    window.beginSheet(aboutWindow, completionHandler: nil)
                }
            }
        }
    }
}
