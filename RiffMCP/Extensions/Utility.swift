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
    
    /// Add default octave (4) to note names that don't have an octave number.
    /// This converts "F" → "F4", "C#" → "C#4", etc. within pitch arrays.
    private static func addDefaultOctaveToNotes(_ jsonString: String) -> String {
        // Regex to find note names within pitch arrays that don't end with a digit
        // Matches: "C", "F#", "Bb", etc. but not "C4", "F#3", etc.
        // Pattern explanation:
        // "([A-G][#b]?)" - Capture note name (A-G) optionally followed by # or b
        // (?!\d) - Negative lookahead: not followed by a digit
        // " - Match closing quote
        let notePattern = #""([A-G][#b]?)(?!\d)""#
        
        guard let regex = try? NSRegularExpression(pattern: notePattern, options: .caseInsensitive) else {
            print("⚠️ Failed to create octave regex pattern")
            return jsonString
        }
        
        let range = NSRange(location: 0, length: jsonString.utf16.count)
        let matches = regex.matches(in: jsonString, options: [], range: range)
        print("🎵 Found \(matches.count) octaveless notes to fix")
        
        for match in matches {
            if let swiftRange = Range(match.range, in: jsonString) {
                print("  - Converting: \(String(jsonString[swiftRange]))")
            }
        }
        
        let result = regex.stringByReplacingMatches(
            in: jsonString,
            options: [],
            range: range,
            withTemplate: "\"$14\""  // Add "4" (default octave) to the captured note
        )
        
        if result != jsonString {
            print("🎵 Octave conversion successful")
        }
        
        return result
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
    /// 4. Add default octave (4) to octaveless note names like "F" → "F4".
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
        
        // 4. Add default octave (4) to octaveless note names
        cleanedString = addDefaultOctaveToNotes(cleanedString)
        
        return cleanedString
    }
}
