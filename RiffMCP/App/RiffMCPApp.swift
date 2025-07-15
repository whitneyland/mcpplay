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

    var body: some Scene {
        WindowGroup {
            Group {
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
            // Kick off launch once the view appears
            .task(id: "startup") {
                // Only run once
                guard services == nil && launchError == nil else { return }

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
                isPresented: .constant(launchError != nil)
            ) {
                Button("Quit") { NSApp.terminate(nil) }
            } message: {
                Text(launchError?.localizedDescription ?? "Unknown error")
            }
        }
        .commands { AboutCommands() }
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
