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

    /// Parses a note name string into its constituent parts: pitch name, octave, and accidental.
    ///
    /// - Parameter name: The note name string (e.g., "C#4").
    /// - Returns: A tuple containing the lowercase pitch name (e.g., "c"), the octave number,
    ///   and an optional accidental ("s" for sharp, "f" for flat).
    /// - Throws: `ConversionError.unsupportedPitchFormat` if the regex does not match.
    static func nameToPitch(_ name: String) throws -> (pname: String, oct: Int, accid: String?) {
        // Regex: ^([A-Ga-g])([#sb]?)(-?\d+)$
        // 1: Pitch letter (A-G, case-insensitive)
        // 2: Accidental (#, s, or b) - optional
        // 3: Octave number (can be negative)
        let regex = try! NSRegularExpression(pattern: #"^([A-Ga-g])([#sb]?)(-?\d+)$"#)
        guard let match = regex.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)),
              let pRange = Range(match.range(at: 1), in: name),
              let aRange = Range(match.range(at: 2), in: name),
              let oRange = Range(match.range(at: 3), in: name)
        else {
            throw ConversionError.unsupportedPitchFormat(name)
        }

        let pname = String(name[pRange]).lowercased()
        let accidentalStr = String(name[aRange])
        let oct = Int(name[oRange]) ?? 4 // Default to octave 4 if parsing fails

        let accid: String?
        switch accidentalStr {
            case "#", "s": accid = "s"
            case "b": accid = "f"
            default: accid = nil
        }
        return (pname, oct, accid)
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
