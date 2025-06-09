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
            ContentView()
                .environmentObject(audioManager)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        guard url.scheme == "mcpplay" else { return }
        
        let command = url.host ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        switch command {
        case "play":
            if let jsonString = components?.queryItems?.first(where: { $0.name == "json" })?.value {
                // Play inline JSON
                audioManager.playSequenceFromJSON(jsonString)
            } else if let sequenceName = components?.queryItems?.first(where: { $0.name == "sequence" })?.value {
                // Play from file
                audioManager.playSequence(named: sequenceName)
            }
        case "stop":
            audioManager.stopSequence()
        default:
            print("Unknown command: \(command)")
        }
    }
}
