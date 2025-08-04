//
//  NoteConverter.swift
//  RiffMCP
//
//  Created by Lee Whitney on 7/15/25.
//

import Foundation

/// A centralized utility for converting between musical note representations.
struct NoteConverter {

    enum ConversionError: Error, LocalizedError {
        case unsupportedPitchFormat(String)

        public var errorDescription: String? {
            switch self {
            case .unsupportedPitchFormat(let p):
                return "The pitch ‘\(p)’ is in an unrecognized format."
            }
        }
    }

    /// Converts a note name string (e.g., "C#4", "Gb-1") into a MIDI note number.
    ///
    /// This function uses a regular expression to robustly parse the note name,
    /// its optional accidental, and its octave.
    ///
    /// - Parameter name: The note name string.
    /// - Returns: The corresponding MIDI note number (0-127).
    /// - Throws: `ConversionError.unsupportedPitchFormat` if the string cannot be parsed.
    static func nameToMIDI(_ name: String) throws -> Int {
        let p = try nameToPitch(name)
        let base: Int
        switch p.pname {
            case "c": base = 0
            case "d": base = 2
            case "e": base = 4
            case "f": base = 5
            case "g": base = 7
            case "a": base = 9
            case "b": base = 11
            default: throw ConversionError.unsupportedPitchFormat(name)
        }

        var midi = (p.oct + 1) * 12 + base
        if p.accid == "s" { midi += 1 }
        else if p.accid == "f" { midi -= 1 }

        // Clamp the final value to the valid MIDI range
        return min(max(midi, 0), 127)
    }

    /// Parses a note name string into pitch letter, octave, and accidental.
    /// Supports:
    ///   • Sharps  –  “#”, “♯”, or “s”
    ///   • Flats   –  “b”, “♭”, or “-” (dash) *when the dash isn’t followed by a digit*
    ///   • Negative octaves – written with a leading “-” *before* the octave digits
    ///
    /// Examples:
    ///   C4   → ("c", 4, nil)
    ///   C#4  → ("c", 4, "s")
    ///   Db3  → ("d", 3, "f")
    ///   C-1  → ("c", -1, nil)            // minus-sign octave
    ///   C--1 → ("c", -1, "f")            // flat + minus-sign octave
    static func nameToPitch(_ raw: String) throws -> (pname: String, oct: Int, accid: String?) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Pitch letter
        guard let first = s.first,
              ("A"..."G").contains(first.uppercased()) else {
            throw ConversionError.unsupportedPitchFormat(raw)
        }
        var i = s.index(after: s.startIndex)
        var accid: String? = nil

        // 2. Optional accidental
        if i < s.endIndex {
            let c = s[i]
            switch c {
            case "#", "♯", "s": accid = "s"; i = s.index(after: i)
            case "b", "♭":     accid = "f"; i = s.index(after: i)
            case "-":
                let next = s.index(after: i)
                if next < s.endIndex, s[next].isNumber { break }   // minus for octave
                accid = "f"; i = next                              // dash = flat
            default: break
            }
        }

        // 3. Optional minus for negative octave
        var octaveSign = ""
        if i < s.endIndex, s[i] == "-" {
            octaveSign = "-"
            i = s.index(after: i)
        }

        // 4. Octave digits (must have at least one)
        guard i < s.endIndex, s[i].isNumber else {
            throw ConversionError.unsupportedPitchFormat(raw)
        }
        let octave = Int(octaveSign + s[i...]) ?? 4   // ← default to 4 on overflow

        return (String(first).lowercased(), octave, accid)
    }

    /// Converts a MIDI note number into its constituent parts: pitch name and octave.
    ///
    /// This function prioritizes sharp notation for black keys.
    ///
    /// - Parameter midi: The MIDI note number (0-127).
    /// - Returns: A tuple containing the lowercase pitch name (e.g., "c"), the octave number,
    ///   and an optional accidental ("s" for sharp).
    static func midiToPitch(_ midi: Int) -> (pname: String, oct: Int, accid: String?) {
        let clampedMidi = min(max(midi, 0), 127)
        let noteNames = ["c", "c", "d", "d", "e", "f", "f", "g", "g", "a", "a", "b"]
        let noteAccs: [String?] = [nil, "s", nil, "s", nil, nil, "s", nil, "s", nil, "s", nil]

        let octave = (clampedMidi / 12) - 1
        let index = clampedMidi % 12

        return (noteNames[index], octave, noteAccs[index])
    }
}
