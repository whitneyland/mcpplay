//
//  Utility.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/14/25.
//

import Foundation
import os

// Evaluate once at startup
enum LogConfig {
    static let mirrorToStderr: Bool = {
        if CommandLine.arguments.contains("--stdio") { return true }
        // if CommandLine.arguments.contains("--log-stdio") { return true }
        // OR environment variable
        if ProcessInfo.processInfo.environment["RIFF_LOG_STDIO"] == "1" { return true }
        return false
    }()

    // Optional: choose JSON format for machine parsing
    static let json: Bool = ProcessInfo.processInfo.environment["RIFF_LOG_JSON"] == "1"
}

enum Log {
    static let app    = DualLogger(category: "app")
    static let server = DualLogger(category: "server")
    static let io     = DualLogger(category: "io")
    static let audio  = DualLogger(category: "audio")
}

struct DualLogger {
    private let oslog: Logger
    private let category: String

    init(category: String) {
        let subsystem = AppInfo.bundleIdentifier
        self.oslog = Logger(subsystem: subsystem, category: category)
        self.category = category
    }

    func info(_ message: @autoclosure () -> String) {
        let text = message()
        oslog.info("\(text, privacy: .public)")
        mirror("info", text)
    }

    func error(_ message: @autoclosure () -> String) {
        let text = message()
        oslog.error("\(text, privacy: .public)")
        mirror("error", text)
    }

    func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        let text = message()
        oslog.debug("\(text, privacy: .public)")
        mirror("debug", text)
        #endif
    }

    func latency(_ label: String, since start: Date) {
        let ms = (Date().timeIntervalSince(start) * 1000)
        let formatted = String(format: "%.1f ms", ms)
        let line = "\(label) (\(formatted))"
        oslog.info("\(line, privacy: .public)")
        mirror("latency", line)
    }

    private func mirror(_ level: String, _ text: String) {
        guard LogConfig.mirrorToStderr else { return }
        if LogConfig.json {
            let jsonLine = #"{"ts":"\#(isoNow())","lvl":"\#(level)","cat":"\#(category)","msg":\#(jsonEscape(text))}"#
            write(jsonLine + "\n")
        } else {
            let line = "[\(shortTime())] \(level.uppercased()) \(category): \(text)\n"
            write(line)
        }
    }

    private func write(_ s: String) {
        if let data = s.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }

    private func shortTime() -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        return df.string(from: Date())
    }

    private func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private func jsonEscape(_ s: String) -> String {
        // Minimal escape; ok for logs
        s.replacingOccurrences(of: #"\"#, with: #"\\#").replacingOccurrences(of: "\"", with: #"\""#)
    }
}

extension Logger {
    func msg(_ text: String) {
        info("\(text, privacy: .public)")
    }

    func latency(_ text: String, since start: Date) {
        let ms = (Date().timeIntervalSince(start) * 1000).rounded(.toNearestOrEven)
        info("\(text, privacy: .public) (\(ms, format: .fixed(precision: 1)) ms)")
    }
}
