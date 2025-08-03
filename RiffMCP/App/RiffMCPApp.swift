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
    private static var allowLaunchUI: Bool = true

    init() {
        //
        // CASE 1: Launched with --stdio. This path takes over the process and never returns.
        //
        if CommandLine.arguments.contains("--stdio") {
            Log.app.info("\(AppInfo.name) v\(AppInfo.fullVersion) started in --stdio mode, pid: \(getpid())")

            // The compiler knows this function is `-> Never`, meaning it will not
            // return. The process will be terminated within this call.
            // The SwiftUI App body will never be initialized.
            StdioProxy.runStdioMode()
        }
        //
        // CASE 2: Normal GUI Launch. This code is only reached if --stdio is NOT present.
        // Check for an existing instance of the GUI app.
        //
        Log.app.info("\(AppInfo.name) v\(AppInfo.fullVersion) started in GUI mode (full app)")
        switch ServerProcess.checkForExistingGUIInstance() {
        case .found(let port, let pid):
            Log.app.info("🔍 GUI: Found existing GUI instance: port \(port), pid \(pid)")

            // Bring existing window to front.
            bringExistingWindowToFront()

            // This new, redundant instance should not launch its UI and should terminate.
            RiffMCPApp.allowLaunchUI = false
            DispatchQueue.main.async {      // Wait until after init when NSApp is not nil
                NSApp.terminate(nil)        // Use this instead of exit() to gracefully terminate this redundant process.
            }
            
        case .noConfigFile:
            RiffMCPApp.allowLaunchUI = true
            Log.app.info("✅ GUI: No server config file found, proceeding with normal launch, pid: \(getpid())")
            
        case .processNotRunning(let staleConfig):
            RiffMCPApp.allowLaunchUI = true
            Log.app.info("🧹 GUI: Old process is dead (port \(staleConfig.port), pid \(staleConfig.pid)), proceeding with normal launch, pid: \(getpid())")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                // Only show the main view if we're not in a successful proxy mode.
                if RiffMCPApp.allowLaunchUI {
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
                guard RiffMCPApp.allowLaunchUI && services == nil && launchError == nil else { return }

                do {
                    let svc = try AppServices()
                    services = svc               // <- @State is settable
                    await svc.startServices()
                } catch {
                    launchError = error
                }
            }
            // Show an alert if we failed
            .alert(
                "RiffMCP failed to start",
                isPresented: .constant(RiffMCPApp.allowLaunchUI && launchError != nil)
            ) {
                Button("Quit") { NSApp.terminate(nil) }
            } message: {
                Text(launchError?.localizedDescription ?? "Unknown error")
            }
        }
        .commands { AboutCommands() }
    }
        
    /// Brings the existing window to the front by activating the running process
    private func bringExistingWindowToFront() {
        // Use NSRunningApplication instead of AppleScript to avoid sandbox entitlement requirements
        guard let config = ServerConfig.read() else {
            Log.server.error("❌ Cannot bring window to front: no server config found")
            return
        }
        
        if let app = NSRunningApplication(processIdentifier: config.pid) {
            let success = app.activate()
            if success {
                Log.server.info("✅ Brought existing window to front")
            } else {
                Log.server.error("❌ Failed to activate existing application window")
            }
        } else {
            Log.server.error("❌ Failed to find running application with PID: \(config.pid)")
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
