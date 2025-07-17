//
//  AppServices.swift
//  RiffMCP
//
//  Created by Gemini on 7/17/2025.
//

import Foundation
import Combine

/// A container for the application's core services.
///
/// This class is responsible for initializing and managing the lifecycle of the main
/// services, including the `MCPRequestHandler`, `HTTPServer`, and `StdioServer`.
/// It ensures that all components are wired together correctly upon application startup.
@MainActor
class AppServices: ObservableObject {

    // MARK: - Core Services
    let audioManager: AudioManager
    let mcpRequestHandler: MCPRequestHandler
    let httpServer: HTTPServer
    let stdioServer: StdioServer
    let presetManager: PresetManager

    // MARK: - Published Properties
    @Published var isServerRunning: Bool = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() throws {
        // 1. Initialize fundamental managers
        self.audioManager = AudioManager()
        self.presetManager = PresetManager()

        // 2. Initialize the central MCP request handler
        let tempDir = HTTPServer.defaultTempDir
        self.mcpRequestHandler = MCPRequestHandler(
            audioManager: audioManager,
            host: HTTPServer.defaultHost,
            port: HTTPServer.defaultPort, // Initial port, will be updated by HTTP server
            tempDirectory: tempDir
        )

        // 3. Initialize the transport layers, injecting the central handler
        self.httpServer = try HTTPServer(
            mcpRequestHandler: mcpRequestHandler,
            tempDirectory: tempDir
        )
        
        self.stdioServer = StdioServer(mcpRequestHandler: mcpRequestHandler)
        
        // 4. Set up observation
        setupBindings()
    }

    private func setupBindings() {
        // Observe the HTTP server's running state to update the UI
        httpServer.$isRunning
            .receive(on: RunLoop.main)
            .assign(to: &$isServerRunning)
    }

    // MARK: - Lifecycle Management

    /// Starts the necessary services based on command-line arguments.
    func startServices() async {
        // The HTTP server can always be started.
        Task {
            do {
                try await httpServer.start()
            } catch {
                Log.server.error("❌ Failed to start HTTP server: \(error.localizedDescription)")
            }
        }

        if CommandLine.arguments.contains("--stdio") {    // Only start stdio server if command-line arg is present.
            stdioServer.start()
        }
    }

    /// Stops all running services gracefully.
    func stopServices() async {
        await httpServer.stop()
        stdioServer.stop()
    }
}
