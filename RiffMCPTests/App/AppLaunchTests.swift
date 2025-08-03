//
//  AppLaunchTests.swift
//  RiffMCPTests
//
//

import Testing
import Foundation
@testable import RiffMCP

@Suite("App Launch Scenarios")
struct AppLaunchTests {

    // MARK: – helpers --------------------------------------------------------

    /// Make sure we never leave a stray server.json behind—even on failure.
    private func cleanUpConfig() { ServerConfig.remove() }

    /// Write an ad-hoc config file (lets us plant any PID we like).
    private func handRollConfig(port: UInt16, pid: pid_t) throws {
        let url  = ServerConfig.getConfigFilePath()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let json: [String: Any] = [
            "port"     : port,
            "host"     : "127.0.0.1",
            "status"   : "running",
            "pid"      : pid,
            "instance" : UUID().uuidString,
            "timestamp": Date().timeIntervalSince1970
        ]
        try JSONSerialization.data(withJSONObject: json).write(to: url)
    }

    // MARK: – 1. Round-trip --------------------------------------------------

    @Test("ServerConfig write → read → remove")
    func roundTrip() throws {
        defer { cleanUpConfig() }

        let port: UInt16 = 55_55
        try ServerConfig.write(host: "127.0.0.1", port: port)

        try #require(FileManager.default.fileExists(
            atPath: ServerConfig.getConfigFilePath().path),
                 "server.json should exist after write")

        guard let cfg = ServerConfig.read() else {
            #expect(false == true, "read() unexpectedly returned nil")
            return
        }

        #expect(cfg.port   == port)
        #expect(cfg.host   == "127.0.0.1")
        #expect(cfg.status == "running")
        #expect(cfg.pid    == ProcessInfo.processInfo.processIdentifier)

        ServerConfig.remove()
        #expect(ServerConfig.read() == nil, "remove() should delete the file")
    }

    // MARK: – 2. No server.json ---------------------------------------------

    @Test("Absence of server.json ⇒ .noConfigFile")
    func noConfigFile() {
        defer { cleanUpConfig() }
        ServerConfig.remove()

        let result = ServerProcess.checkForExistingGUIInstance()
        var ok = false
        if case .noConfigFile = result { ok = true }

        #expect(ok, "Expected .noConfigFile, got \(result)")
    }

    // MARK: – 3. Live config / live PID -------------------------------------

    @Test("Valid server.json with live PID ⇒ .found")
    func foundScenario() throws {
        defer { cleanUpConfig() }

        let port: UInt16 = 56_56
        try ServerConfig.write(host: "127.0.0.1", port: port)

        let result = ServerProcess.checkForExistingGUIInstance()
        var ok = false
        if case let .found(foundPort, foundPID) = result {
            ok = (foundPort == port) &&
                 (foundPID  == ProcessInfo.processInfo.processIdentifier)
        }
        #expect(ok, "Expected .found with current PID/port, got \(result)")
    }

    // MARK: – 4. Stale config / dead PID ------------------------------------

    @Test("Stale server.json (dead PID) ⇒ .processNotRunning and file removed")
    func staleConfig() throws {
        defer { cleanUpConfig() }

        let deadPID:  pid_t  = 99_999          // astronomically unlikely to exist
        let deadPort: UInt16 = 57_57
        try handRollConfig(port: deadPort, pid: deadPID)

        let result = ServerProcess.checkForExistingGUIInstance()
        var ok = false
        if case let .processNotRunning(stale) = result {
            ok = (stale.port == deadPort) && (stale.pid == deadPID)
        }
        #expect(ok, "Expected .processNotRunning, got \(result)")

        // isProcessRunning() should have purged the stale file.
        let exists = FileManager.default.fileExists(
                        atPath: ServerConfig.getConfigFilePath().path)
        #expect(!exists, "stale server.json should be deleted automatically")
    }
}
