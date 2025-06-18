//
//  Utility.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/14/25.
//

import Foundation

struct Util {
    static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else {
            return "0:00.0"
        }
        let minutes = Int(seconds) / 60
        let remainingSeconds = seconds.truncatingRemainder(dividingBy: 60.0)
        return String(format: "%d:%04.1f", minutes, remainingSeconds)
    }

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

    /// Cleans a user-supplied JSON-like string so that it can be parsed by
    /// `JSONDecoder`. Performs the following cleanup steps:
    /// 1. Replace "smart quotes", 'smart apostrophes' and back-ticks with plain
    ///    double quotes ("). Users frequently paste content from ChatGPT or
    ///    text editors that converts the quotes, which the JSON parser cannot
    ///    handle.
    /// 2. Remove single-line "// …" comments.
    /// 3. Strip trailing commas that appear immediately before a closing
    ///    object/array bracket (", }" or ", ]"), which are illegal in JSON but
    ///    common in hand-edited snippets.
    static func cleanJSON(from jsonString: String) -> String {
        var cleanedString = jsonString

        // 1. Normalise quotes/back-ticks to standard double quotes
        let quoteReplacements: [String: String] = [
            "‘": "\"",
            "’": "\"",
            "“": "\"",
            "”": "\"",
            "`": "\""
        ]
        for (target, replacement) in quoteReplacements {
            cleanedString = cleanedString.replacingOccurrences(of: target, with: replacement)
        }

        // 2. Remove // comments (keep code before comment on the same line)
        let lines = cleanedString.components(separatedBy: .newlines)
        let uncommentedLines = lines.map { line -> String in
            guard let idx = line.firstIndex(of: "/") else { return line }
            let nextIdx = line.index(after: idx)
            if nextIdx < line.endIndex && line[nextIdx] == "/" {
                // Trim whitespace at the end to avoid stray spaces
                return String(line[..<idx]).trimmingCharacters(in: .whitespaces)
            }
            return line
        }
        cleanedString = uncommentedLines.joined(separator: "\n")

        // 3. Remove trailing commas before a closing } or ]
        if let trailingCommaRegex = try? NSRegularExpression(pattern: #",\s*(?=[}\]])"#, options: []) {
            let range = NSRange(location: 0, length: cleanedString.utf16.count)
            cleanedString = trailingCommaRegex.stringByReplacingMatches(in: cleanedString, options: [], range: range, withTemplate: "")
        }
        
        return cleanedString
    }
}
