//
//  AppServices.swift
//  RiffMCP
//
//  Created by Lee Whitney on 7/14/25.
//

import SwiftUI
import Foundation

/// Composition Root: centralized dependency injection and service management
@MainActor
class AppServices: ObservableObject {
    let audioManager: AudioManager
    let httpServer: HTTPServer
    
    init() throws {
        // Create AudioManager first
        let audioManager = AudioManager()
        
        // Create HTTPServer with AudioManager dependency
        let httpServer = try HTTPServer(audioManager: audioManager)
        
        // Store references
        self.audioManager = audioManager
        self.httpServer = httpServer
    }
    
    /// Start all services that need to run at app launch
    func startServices() async {
        do {
            try await httpServer.start()
        } catch {
            Log.server.error("❌ Failed to start HTTP server: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Clean shutdown of all services
    func stopServices() async {
        await httpServer.stop()
    }
}