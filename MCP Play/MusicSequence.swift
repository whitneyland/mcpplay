//
//  MusicSequence.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/8/25.
//

import Foundation

/// Represents a musical sequence, possibly containing multiple tracks.
/// Conforms to Codable for JSON serialization and Sendable for safe concurrent use.
struct MusicSequence: Codable, Sendable {
    let version: Int
    let title: String?
    let tempo: Double
    let tracks: [Track]

    enum CodingKeys: String, CodingKey {
        case version, title, tempo, tracks
    }
    
    init(version: Int = 1, title: String?, tempo: Double, tracks: [Track]) {
        self.version = version
        self.title = title
        self.tempo = tempo
        self.tracks = tracks
    }

    // A helper struct for decoding arbitrary string keys, used in our legacy fallback.
    private struct LegacyCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { self.init(stringValue: "\(intValue)"); self.intValue = intValue }
    }

    // Custom decoder to support both multi-track and single-track (legacy) formats.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        title = try container.decodeIfPresent(String.self, forKey: .title)
        tempo = try container.decode(Double.self, forKey: .tempo)

        // Try to decode the standard 'tracks' array first.
        if let decodedTracks = try? container.decode([Track].self, forKey: .tracks) {
            tracks = decodedTracks
        } else {
            // Fallback for legacy single-track format where events are at the top level.
            let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
            let instrument = try legacyContainer.decodeIfPresent(String.self, forKey: .init(stringValue: "instrument")!) ?? "acoustic_grand_piano"
            let events = try legacyContainer.decode([SequenceEvent].self, forKey: .init(stringValue: "events")!)
            let singleTrack = Track(instrument: instrument, name: nil, events: events)
            tracks = [singleTrack]
        }
    }

    // We must manually implement `encode(to:)` because we have a custom `init(from:)`.
    // We always encode to the modern, standard format.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(tempo, forKey: .tempo)
        try container.encode(tracks, forKey: .tracks)
    }
}

/// Represents a single track within a sequence.
struct Track: Codable, Sendable {
    let instrument: String
    let name: String?
    let events: [SequenceEvent]

    // We must explicitly define CodingKeys because we have a custom decoder.
    enum CodingKeys: String, CodingKey {
        case instrument, name, events
    }

    // Manual initializer for direct track creation.
    init(instrument: String, name: String?, events: [SequenceEvent]) {
        self.instrument = instrument
        self.name = name
        self.events = events
    }

    // A custom decoder to provide a default value for 'instrument'.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instrument = try container.decodeIfPresent(String.self, forKey: .instrument) ?? "acoustic_grand_piano"
        name = try container.decodeIfPresent(String.self, forKey: .name)
        events = try container.decode([SequenceEvent].self, forKey: .events)
    }

    // Because we provide a custom init(from:), we must also provide encode(to:).
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(instrument, forKey: .instrument)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(events, forKey: .events)
    }
}

/// Represents a single musical event (note or chord).
struct SequenceEvent: Codable, Sendable {
    let time: Double
    let pitches: [Pitch]
    let duration: Double
    let velocity: Int?
    
    enum CodingKeys: String, CodingKey {
        case time, pitches, duration, velocity
    }
    
    init(time: Double, pitches: [Pitch], duration: Double, velocity: Int? = nil) {
        self.time = time
        self.pitches = pitches
        self.duration = duration
        self.velocity = velocity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Round to avoid floating-point precision issues
        let rawTime = try container.decode(Double.self, forKey: .time)
        let rawDuration = try container.decode(Double.self, forKey: .duration)
        
        self.time = (rawTime * 1000).rounded() / 1000  // Round to 3 decimal places
        self.duration = (rawDuration * 1000).rounded() / 1000
        self.pitches = try container.decode([Pitch].self, forKey: .pitches)
        self.velocity = try container.decodeIfPresent(Int.self, forKey: .velocity)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Format values to avoid floating-point display issues
        let formattedTime = Double(String(format: "%.3f", time))!
        let formattedDuration = Double(String(format: "%.3f", duration))!
        
        try container.encode(formattedTime, forKey: .time)
        try container.encode(pitches, forKey: .pitches)
        try container.encode(formattedDuration, forKey: .duration)
        try container.encodeIfPresent(velocity, forKey: .velocity)
    }
}

/// Represents a musical pitch, which can be an integer (MIDI value) or a string (note name).
enum Pitch: Codable, Sendable {
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value): try container.encode(value)
        case .name(let value): try container.encode(value)
        }
    }

    var midiValue: Int {
        switch self {
        case .int(let value): return value
        case .name(let noteName): return NoteNameConverter.toMIDI(noteName)
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
        let cleanName = noteName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleanName.count >= 2 else { 
            print("⚠️ Invalid note name: '\(noteName)' - too short")
            return 60 
        }
        let lastChar = String(cleanName.last!)
        guard let octave = Int(lastChar) else { 
            print("⚠️ Invalid note name: '\(noteName)' - no octave number")
            return 60 
        }
        let notePart = String(cleanName.dropLast())
        guard let noteOffset = noteMap[notePart] else { 
            print("⚠️ Invalid note name: '\(noteName)' - unknown note '\(notePart)'")
            return 60 
        }
        let midiNote = octave * 12 + noteOffset
        return midiNote
    }
}
