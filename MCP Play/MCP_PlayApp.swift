//
//  MCP_PlayApp.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/7/25.
//

import SwiftUI
import Foundation


@main
struct MCP_PlayApp: App {
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
                .onOpenURL { url in
                    handleURL(url)
                }
                .task {
                    await startHTTPServer()
                }
        }
    }
    
    private func startHTTPServer() async {
        do {
            try await httpServer.start()
        } catch {
            print("❌ Failed to start HTTP server: \(error)")
        }
    }

    private func handleURL(_ url: URL) {
        let startTime = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: startTime) + ".\(Int(startTime.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 10))"
        let timingMsg = "================================================================\n[TIMING] handleURL started at \(timeString)\n"
        print(timingMsg)
        if let data = timingMsg.data(using: .utf8) {
            let fileURL = URL(fileURLWithPath: "/tmp/mcp-timing.log")
            try? data.append(to: fileURL)
        }
        print("🔗 handleURL called with: \(url)")
        guard url.scheme == "mcpplay" else {
            print("❌ Invalid scheme: \(url.scheme ?? "nil")")
            return
        }

        let command = url.host ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        print("📱 Command: \(command)")
        print("🔍 Query items: \(components?.queryItems ?? [])")

        switch command {
        case "play":
            if let raw = components?
                .queryItems?
                .first(where: { $0.name == "json" })?
                .value {

                // 🚿 1. strip literal newlines / spaces users may paste in
                let tidyEncoded = raw
                    .components(separatedBy: .whitespacesAndNewlines)
                    .joined()

                // 🔓 2. decode the % sequences (one pass is enough after cleaning)
                guard let tidyJSON = tidyEncoded.removingPercentEncoding else {
                    print("❌ JSON payload couldn’t be percent-decoded")
                    return
                }
                print("🎵 Final JSON ready to parse -> \(tidyJSON)")
                print("[TIMING] About to call playSequenceFromJSON at \(Date().timeIntervalSince(startTime) * 1000)ms")
                audioManager.playSequenceFromJSON(tidyJSON)
            } else if let sequenceName = components?.queryItems?.first(where: { $0.name == "sequence" })?.value {
                print("🎵 Playing sequence: \(sequenceName)")
                print("[TIMING] About to call playSequence(named:) at \(Date().timeIntervalSince(startTime) * 1000)ms")
                audioManager.playSequence(named: sequenceName)
            } else {
                print("❌ No valid play parameters found")
            }
        case "stop":
            print("⏹️ Stopping playback")
            audioManager.stopSequence()
        default:
            print("❌ Unknown command: \(command)")
        }
    }
}
