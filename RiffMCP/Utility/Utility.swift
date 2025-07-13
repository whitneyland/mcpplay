//
//  Utility.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/14/25.
//

import Foundation
import os

enum Log {
    static let app    = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.whitneyland.riffmcp", category: "app")
    static let server = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.whitneyland.riffmcp", category: "server")
    static let io     = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.whitneyland.riffmcp", category: "io")
    static let audio  = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.whitneyland.riffmcp", category: "audio")
}

extension Logger {
    /// Latency helper (replaces Util.logLatency)
    func latency(_ text: String, since start: Date) {
        let ms = (Date().timeIntervalSince(start) * 1000).rounded(.toNearestOrEven)
        info("\(text, privacy: .public) (\(ms, format: .fixed(precision: 1)) ms)")
    }
}
