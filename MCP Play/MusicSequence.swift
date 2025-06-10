//
//  MusicSequence.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/8/25.
//

import Foundation

/// Represents a musical sequence, possibly containing multiple tracks.
struct MusicSequence: Decodable {
    let version: Int
    let title: String?
    let tempo: Double
    let tracks: [Track]

    enum CodingKeys: String, CodingKey {
        case version, title, tempo, tracks, instrument, events, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        tempo = try container.decode(Double.self, forKey: .tempo)
        if let decodedTracks = try? container.decode([Track].self, forKey: .tracks) {
            tracks = decodedTracks
        } else {
            // Fallback for version 1 format
            let instrument = try container.decode(String.self, forKey: .instrument)
            let events = try container.decode([SequenceEvent].self, forKey: .events)
            let legacyTrack = Track(instrument: instrument, name: nil, events: events)
            tracks = [legacyTrack]
        }
    }
}

/// Represents a single track within a sequence.
struct Track: Decodable {
    let instrument: String
    let name: String?
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