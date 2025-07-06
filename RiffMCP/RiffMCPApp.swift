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
    @StateObject private var audioManager = AudioManager()
    @StateObject private var httpServer: HTTPServer
    
    init() {
        let manager = AudioManager()
        let server = HTTPServer(audioManager: manager)
        _audioManager = StateObject(wrappedValue: manager)
        _httpServer = StateObject(wrappedValue: server)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(audioManager)
                .environmentObject(httpServer)
                .task {
                    validateVerovioIntegration()
                    await startHTTPServer()
                }
        }
        .commands {
            AboutCommands()
        }
    }
    
    private func validateVerovioIntegration() {
        print("🎼 Testing Verovio integration...")
        let success = Verovio.validateVerovioIntegration()
        if success {
            print("✅ Verovio library successfully integrated!")
        } else {
            print("❌ Verovio integration test failed")
        }
    }
    
    private func startHTTPServer() async {
        do {
            try await httpServer.start()
        } catch {
            print("❌ Failed to start HTTP server: \(error)")
        }
    }
    
    private func testEngravingPipeline() async {
        print("🧪 Testing engraving pipeline...")
        
        // Create a simple test sequence
        let testSequence = MusicSequence(
            title: "Test Melody",
            tempo: 120,
            tracks: [
                Track(
                    instrument: "grand_piano",
                    name: nil,
                    events: [
                        SequenceEvent(time: 0, pitches: [.name("C4")], dur: 1),
                        SequenceEvent(time: 1, pitches: [.name("D4")], dur: 1),
                        SequenceEvent(time: 2, pitches: [.name("E4")], dur: 1),
                        SequenceEvent(time: 3, pitches: [.name("F4")], dur: 1)
                    ]
                )
            ]
        )
        
        do {
            print("🎼 Starting test engraving...")
            let result = try await httpServer.testHandleEngraveSequence(sequence: testSequence)
            print("✅ Engraving test completed successfully!")
            print("📝 Result contains \(result.content.count) content items")
        } catch {
            print("❌ Engraving test failed: \(error.localizedDescription)")
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
