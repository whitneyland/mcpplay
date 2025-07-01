//
//  SequenceJSON.swift
//  RiffMCP
//
//  Centralised helpers for converting MusicSequence ⇄ JSON.
//

import Foundation

struct SequenceJSON {
    // MARK: - Public API

    /// Converts a raw (possibly hand-edited) JSON string into a `MusicSequence`.
    static func decode(_ raw: String) throws -> MusicSequence {
        let cleaned = addDefaultOctaves(
                        stripTrailingCommas(
                          stripSmartQuotesAndComments(raw)))
        guard let data = cleaned.data(using: .utf8) else {
            throw NSError(domain: "SequenceJSON", code: 1,
                          userInfo: [NSLocalizedDescriptionKey : "Invalid UTF-8"])
        }
        return try JSONDecoder().decode(MusicSequence.self, from: data)
    }

    /// Serialises a `MusicSequence` to a pretty-printed JSON string
    /// and compacts the `events` arrays to a single line per object.
    static func prettyPrint(_ sequence: MusicSequence) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sequence)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "SequenceJSON", code: 2,
                          userInfo: [NSLocalizedDescriptionKey : "Unable to encode JSON"])
        }

        print("JSON 1:\n\(json)")
        let compactedJson = compactEventObjects(json, debug: true).json
        print("JSON 2:\n\(compactedJson)")
        return compactedJson
    }

    // MARK: - Pipeline stages

    /// 1. Replace smart quotes/back-ticks and strip `//` comments.
    private static func stripSmartQuotesAndComments(_ input: String) -> String {
        var s = input
        let replacements: [String:String] = [
            "\u{2018}": "\"", // left single quote
            "\u{2019}": "\"", // right single quote
            "\u{201C}": "\"", // left double quote
            "\u{201D}": "\"", // right double quote
            "`": "\""
        ]
        replacements.forEach { s = s.replacingOccurrences(of: $0, with: $1) }

        let lines = s.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            guard let idx = line.firstIndex(of: "/"),
                  line.index(after: idx) < line.endIndex,
                  line[line.index(after: idx)] == "/" else { return String(line) }
            return String(line[..<idx]).trimmingCharacters(in: .whitespaces)
        }
        return lines.joined(separator: "\n")
    }

    /// 2. Remove dangling commas before `}` or `]`.
    private static func stripTrailingCommas(_ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #",\s*(?=[}\]])"#) else { return input }
        let range = NSRange(location: 0, length: input.utf16.count)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: "")
    }

    /// 3. Add default octave 4 to note names lacking a digit (e.g. `"F#"` → `"F#4"`).
    private static func addDefaultOctaves(_ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #""([A-G][#b]?)(?!\d)""#, options: [.caseInsensitive]) else { return input }
        let range = NSRange(location: 0, length: input.utf16.count)
        return regex.stringByReplacingMatches(in: input, range: range,
                                              withTemplate: "\"$14\"")
    }

    /// Compacts whitespace inside each `"events"` array and tells you how many
    /// arrays it rewrote.
    ///
    /// - Parameters:
    ///   - json:  Raw JSON text.
    ///   - debug: When `true`, prints one line per replacement.
    /// - Returns: `(compactJSON, replacementCount)`
    static func compactEventObjects(
        _ json: String,
        debug: Bool = false
    ) -> (json: String, replacements: Int) {

        // Typed regex → `match.body` is a real `Substring`, so no `AnyRegexOutput` issues.
        let pattern: Regex<(Substring, body: Substring)> = #/
            "events"\s*:\s*\[
            (?<body>(?:\s*\{[^}]+\}\s*,?)*)
            \s*\]
        /#

        var replacements = 0

        let compacted = json.replacing(pattern) { match in
            replacements += 1

            // Use regex to find complete JSON objects
            let bodyText = String(match.body)
            let objectPattern = #/\{[^}]+\}/#
            let matches = bodyText.matches(of: objectPattern)
            
            let eventObjects = matches.map { match in
                String(match.output)
                    .replacing(#/\s+/#, with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            let glued = eventObjects.joined(separator: ",\n        ")

            if debug { print("compactEventObjects – replacement #\(replacements)") }

            // Empty array → keep "events": []
            return #""events": [\#(glued.isEmpty ? "" : "\n        \(glued)\n      ")]"#
        }

        return (compacted, replacements)
    }
}