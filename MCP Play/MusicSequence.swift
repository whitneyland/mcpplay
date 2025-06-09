//
//  MusicSequence.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/8/25.
//

import Foundation

struct MusicSequence: Decodable {
    let version: Int
    let tempo: Double
    let instrument: String
    let events: [SequenceEvent]
}

struct SequenceEvent: Decodable {
    let time: Double
    let pitches: [Pitch]
    let duration: Double
    let velocity: Int?
}

enum Pitch: Decodable {
    case int(Int)
    case name(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else {
            self = .name(try container.decode(String.self))
        }
    }
    
    var midiValue: Int {
        switch self {
        case .int(let value):
            return value
        case .name(let noteName):
            return NoteNameConverter.toMIDI(noteName)
        }
    }
}

struct NoteNameConverter {
    private static let noteMap: [String: Int] = [
        "C": 0, "C#": 1, "DB": 1, "D": 2, "D#": 3, "EB": 3,
        "E": 4, "F": 5, "F#": 6, "GB": 6, "G": 7, "G#": 8,
        "AB": 8, "A": 9, "A#": 10, "BB": 10, "B": 11
    ]
    
    static func toMIDI(_ noteName: String) -> Int {
        let cleanName = noteName.uppercased()
        
        guard cleanName.count >= 2 else { return 60 }
        
        let octaveString = String(cleanName.last!)
        guard let octave = Int(octaveString) else { return 60 }
        
        let noteString = String(cleanName.dropLast())
        guard let noteOffset = noteMap[noteString] else { return 60 }
        
        return (octave + 1) * 12 + noteOffset
    }
}