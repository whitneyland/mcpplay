//
//  Utility.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/14/25.
//

import Foundation

struct Util {
    static func extractDimensions(from svg: String) -> (width: Int, height: Int)? {
        let pattern = #"width="(\d+)[a-zA-Z]*"\s+height="(\d+)[a-zA-Z]*""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: svg, range: NSRange(svg.startIndex..., in: svg)),
              let widthRange = Range(match.range(at: 1), in: svg),
              let heightRange = Range(match.range(at: 2), in: svg),
              let width = Int(svg[widthRange]),
              let height = Int(svg[heightRange]) else {
            return nil
        }
        return (width, height)
    }

    static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else {
            return "0:00.0"
        }
        let minutes = Int(seconds) / 60
        let remainingSeconds = seconds.truncatingRemainder(dividingBy: 60.0)
        return String(format: "%d:%04.1f", minutes, remainingSeconds)
    }

    static func logTiming(_ message: String) {
        logToFile("[TIMING]", message, emoji: nil, since: nil, useReadableTime: true)
    }
    
    static func logLatency(_ emoji: String, _ message: String, since startTime: Date? = nil) {
        logToFile("[LATENCY]", message, emoji: emoji, since: startTime, useReadableTime: true)
    }
    
    private static func logToFile(_ prefix: String, _ message: String, emoji: String?, since startTime: Date?, useReadableTime: Bool) {
        let now = Date()
        
        let timeString: String
        if useReadableTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            timeString = formatter.string(from: now) + ".\(Int(now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 10))"
        } else {
            timeString = String(now.timeIntervalSince1970)
        }
        
        let intervalText: String
        if let startTime = startTime {
            intervalText = " (+\(String(format: "%.1f", now.timeIntervalSince(startTime) * 1000))ms)"
        } else {
            intervalText = ""
        }
        
        let emojiPrefix = emoji != nil ? "\(emoji!) " : ""
        let msg = "\(emojiPrefix)\(prefix) \(timeString) - \(message)\(intervalText)"
        
        print(msg)
        
        // Write to log file
        let logMsg = msg + "\n"
        if let data = logMsg.data(using: .utf8) {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsPath.appendingPathComponent("mcp-timing.log")
            try? data.append(to: fileURL)
        }
    }
}
