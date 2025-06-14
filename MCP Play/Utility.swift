//
//  Utility.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/14/25.
//

import Foundation

struct Util {
    static func logTiming(_ message: String) {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: now) + ".\(Int(now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 10))"
        var msg = "[TIMING] \(timeString) - \(message)"
        print(msg)
        msg += "\n"
        if let data = msg.data(using: .utf8) {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsPath.appendingPathComponent("mcp-timing.log")
            try? data.append(to: fileURL)
        }
    }
}
