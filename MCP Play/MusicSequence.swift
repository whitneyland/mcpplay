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
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        title = try container.decodeIfPresent(String.self, forKey: .title)
        tempo = try container.decode(Double.self, forKey: .tempo)
        if let decodedTracks = try? container.decode([Track].self, forKey: .tracks) {
            tracks = decodedTracks
        } else {
            // Fallback for single-track format
            let instrument = try container.decodeIfPresent(String.self, forKey: .instrument) ?? "acoustic_grand_piano"
            let events = try container.decode([SequenceEvent].self, forKey: .events)
            let singleTrack = Track(instrument: instrument, name: nil, events: events)
            tracks = [singleTrack]
        }
    }
}

/// Represents a single track within a sequence.
struct Track: Decodable {
    let instrument: String
    let name: String?
    let events: [SequenceEvent]
    
    enum CodingKeys: String, CodingKey {
        case instrument, name, events
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instrument = try container.decodeIfPresent(String.self, forKey: .instrument) ?? "acoustic_grand_piano"
        name = try container.decodeIfPresent(String.self, forKey: .name)
        events = try container.decode([SequenceEvent].self, forKey: .events)
    }
    
    // Manual initializer for track creation
    init(instrument: String, name: String?, events: [SequenceEvent]) {
        self.instrument = instrument
        self.name = name
        self.events = events
    }
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