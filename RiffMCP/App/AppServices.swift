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
        // throw NSError(domain: "TestFailure", code: -1, userInfo: [NSLocalizedDescriptionKey: "🚧 Forced launch failure for testing"])

        let audioManager = AudioManager()
        let httpServer  = try HTTPServer(audioManager: audioManager)

        self.audioManager = audioManager
        self.httpServer   = httpServer
    }

    func startServices() async throws {
        try await httpServer.start()
    }

    /// Clean shutdown of all services
    func stopServices() async {
        await httpServer.stop()
    }
}
