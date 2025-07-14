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
    @StateObject private var appServices: AppServices
    
    init() {
        do {
            let services = try AppServices()
            _appServices = StateObject(wrappedValue: services)
        } catch {
            fatalError("🚨 Failed to initialize app services: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appServices.audioManager)
                .environmentObject(appServices.httpServer)
                .task {
                    await appServices.startServices()
                }
        }
        .commands {
            AboutCommands()
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
