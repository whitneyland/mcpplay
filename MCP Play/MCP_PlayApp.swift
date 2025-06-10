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

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(audioManager)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }

    private func handleURL(_ url: URL) {
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
                audioManager.playSequenceFromJSON(tidyJSON)
            } else if let sequenceName = components?.queryItems?.first(where: { $0.name == "sequence" })?.value {
                print("🎵 Playing sequence: \(sequenceName)")
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
