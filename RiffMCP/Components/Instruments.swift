//
//  Instruments.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/16/25.
//

import Foundation
import SwiftUI

struct InstrumentInfo {
    let name: String           // raw name (e.g., "acoustic_grand_piano")
    let displayName: String    // polished name (e.g., "Grand Piano")
    let category: String       // category (e.g., "Piano")
    let midiProgram: Int       // MIDI program number (0-based)
    let defaultClef: String    // "treble", "bass", "alto", "tenor"
    let isPiano: Bool          // for special piano handling
}

struct Instruments {
    // SINGLE SOURCE OF TRUTH - all instrument data
    private static let allInfo: [InstrumentInfo] = [
        // Piano
        InstrumentInfo(name: "acoustic_grand_piano", displayName: "Grand Piano", category: "Piano", midiProgram: 0, defaultClef: "treble", isPiano: true),
        InstrumentInfo(name: "bright_acoustic_piano", displayName: "Bright Piano", category: "Piano", midiProgram: 1, defaultClef: "treble", isPiano: true),
        InstrumentInfo(name: "electric_grand_piano", displayName: "Electric Grand Piano", category: "Piano", midiProgram: 2, defaultClef: "treble", isPiano: true),
        InstrumentInfo(name: "honky_tonk_piano", displayName: "Honky Tonk Piano", category: "Piano", midiProgram: 3, defaultClef: "treble", isPiano: true),
        InstrumentInfo(name: "electric_piano_1", displayName: "Electric Piano 1", category: "Piano", midiProgram: 4, defaultClef: "treble", isPiano: true),
        InstrumentInfo(name: "electric_piano_2", displayName: "Electric Piano 2", category: "Piano", midiProgram: 5, defaultClef: "treble", isPiano: true),
        InstrumentInfo(name: "harpsichord", displayName: "Harpsichord", category: "Piano", midiProgram: 6, defaultClef: "treble", isPiano: true),
        InstrumentInfo(name: "clavinet", displayName: "Clavinet", category: "Piano", midiProgram: 7, defaultClef: "treble", isPiano: true),
        
        // Percussion
        InstrumentInfo(name: "celesta", displayName: "Celesta", category: "Percussion", midiProgram: 8, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "glockenspiel", displayName: "Glockenspiel", category: "Percussion", midiProgram: 9, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "music_box", displayName: "Music Box", category: "Percussion", midiProgram: 10, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "vibraphone", displayName: "Vibraphone", category: "Percussion", midiProgram: 11, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "marimba", displayName: "Marimba", category: "Percussion", midiProgram: 12, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "xylophone", displayName: "Xylophone", category: "Percussion", midiProgram: 13, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "tubular_bells", displayName: "Tubular Bells", category: "Percussion", midiProgram: 14, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "dulcimer", displayName: "Dulcimer", category: "Percussion", midiProgram: 15, defaultClef: "treble", isPiano: false),
        
        // Organ
        InstrumentInfo(name: "drawbar_organ", displayName: "Drawbar Organ", category: "Organ", midiProgram: 16, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "percussive_organ", displayName: "Percussive Organ", category: "Organ", midiProgram: 17, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "rock_organ", displayName: "Rock Organ", category: "Organ", midiProgram: 18, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "church_organ", displayName: "Church Organ", category: "Organ", midiProgram: 19, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "reed_organ", displayName: "Reed Organ", category: "Organ", midiProgram: 20, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "accordion", displayName: "Accordion", category: "Organ", midiProgram: 21, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "harmonica", displayName: "Harmonica", category: "Organ", midiProgram: 22, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "tango_accordion", displayName: "Tango Accordion", category: "Organ", midiProgram: 23, defaultClef: "treble", isPiano: false),
        
        // Guitar
        InstrumentInfo(name: "acoustic_guitar_nylon", displayName: "Guitar (Nylon)", category: "Guitar", midiProgram: 24, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "acoustic_guitar_steel", displayName: "Guitar (Steel)", category: "Guitar", midiProgram: 25, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "electric_guitar_jazz", displayName: "Electric Guitar (Jazz)", category: "Guitar", midiProgram: 26, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "electric_guitar_clean", displayName: "Electric Guitar (Clean)", category: "Guitar", midiProgram: 27, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "electric_guitar_muted", displayName: "Electric Guitar (Muted)", category: "Guitar", midiProgram: 28, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "overdriven_guitar", displayName: "Overdriven Guitar", category: "Guitar", midiProgram: 29, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "distortion_guitar", displayName: "Distortion Guitar", category: "Guitar", midiProgram: 30, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "guitar_harmonics", displayName: "Guitar Harmonics", category: "Guitar", midiProgram: 31, defaultClef: "treble", isPiano: false),
        
        // Bass
        InstrumentInfo(name: "acoustic_bass", displayName: "Acoustic Bass", category: "Bass", midiProgram: 32, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "electric_bass_finger", displayName: "Electric Bass (Finger)", category: "Bass", midiProgram: 33, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "electric_bass_pick", displayName: "Electric Bass (Pick)", category: "Bass", midiProgram: 34, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "fretless_bass", displayName: "Fretless Bass", category: "Bass", midiProgram: 35, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "slap_bass_1", displayName: "Slap Bass 1", category: "Bass", midiProgram: 36, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "slap_bass_2", displayName: "Slap Bass 2", category: "Bass", midiProgram: 37, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "synth_bass_1", displayName: "Synth Bass 1", category: "Bass", midiProgram: 38, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "synth_bass_2", displayName: "Synth Bass 2", category: "Bass", midiProgram: 39, defaultClef: "bass", isPiano: false),
        
        // Strings
        InstrumentInfo(name: "violin", displayName: "Violin", category: "Strings", midiProgram: 40, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "viola", displayName: "Viola", category: "Strings", midiProgram: 41, defaultClef: "alto", isPiano: false),
        InstrumentInfo(name: "cello", displayName: "Cello", category: "Strings", midiProgram: 42, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "contrabass", displayName: "Contrabass", category: "Strings", midiProgram: 43, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "tremolo_strings", displayName: "Tremolo Strings", category: "Strings", midiProgram: 44, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "pizzicato_strings", displayName: "Pizzicato Strings", category: "Strings", midiProgram: 45, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "orchestral_harp", displayName: "Orchestral Harp", category: "Strings", midiProgram: 46, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "timpani", displayName: "Timpani", category: "Strings", midiProgram: 47, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "string_ensemble_1", displayName: "String Ensemble 1", category: "Strings", midiProgram: 48, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "string_ensemble_2", displayName: "String Ensemble 2", category: "Strings", midiProgram: 49, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "synth_strings_1", displayName: "Synth Strings 1", category: "Strings", midiProgram: 50, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "synth_strings_2", displayName: "Synth Strings 2", category: "Strings", midiProgram: 51, defaultClef: "treble", isPiano: false),
        
        // Choir
        InstrumentInfo(name: "choir_aahs", displayName: "Choir Aahs", category: "Choir", midiProgram: 52, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "voice_oohs", displayName: "Voice Oohs", category: "Choir", midiProgram: 53, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "synth_voice", displayName: "Synth Voice", category: "Choir", midiProgram: 54, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "orchestra_hit", displayName: "Orchestra Hit", category: "Choir", midiProgram: 55, defaultClef: "treble", isPiano: false),
        
        // Brass
        InstrumentInfo(name: "trumpet", displayName: "Trumpet", category: "Brass", midiProgram: 56, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "trombone", displayName: "Trombone", category: "Brass", midiProgram: 57, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "tuba", displayName: "Tuba", category: "Brass", midiProgram: 58, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "muted_trumpet", displayName: "Muted Trumpet", category: "Brass", midiProgram: 59, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "french_horn", displayName: "French Horn", category: "Brass", midiProgram: 60, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "brass_section", displayName: "Brass Section", category: "Brass", midiProgram: 61, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "synth_brass_1", displayName: "Synth Brass 1", category: "Brass", midiProgram: 62, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "synth_brass_2", displayName: "Synth Brass 2", category: "Brass", midiProgram: 63, defaultClef: "treble", isPiano: false),
        
        // Woodwinds
        InstrumentInfo(name: "soprano_sax", displayName: "Soprano Sax", category: "Woodwinds", midiProgram: 64, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "alto_sax", displayName: "Alto Sax", category: "Woodwinds", midiProgram: 65, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "tenor_sax", displayName: "Tenor Sax", category: "Woodwinds", midiProgram: 66, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "baritone_sax", displayName: "Baritone Sax", category: "Woodwinds", midiProgram: 67, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "oboe", displayName: "Oboe", category: "Woodwinds", midiProgram: 68, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "english_horn", displayName: "English Horn", category: "Woodwinds", midiProgram: 69, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "bassoon", displayName: "Bassoon", category: "Woodwinds", midiProgram: 70, defaultClef: "bass", isPiano: false),
        InstrumentInfo(name: "clarinet", displayName: "Clarinet", category: "Woodwinds", midiProgram: 71, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "piccolo", displayName: "Piccolo", category: "Woodwinds", midiProgram: 72, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "flute", displayName: "Flute", category: "Woodwinds", midiProgram: 73, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "recorder", displayName: "Recorder", category: "Woodwinds", midiProgram: 74, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "pan_flute", displayName: "Pan Flute", category: "Woodwinds", midiProgram: 75, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "blown_bottle", displayName: "Blown Bottle", category: "Woodwinds", midiProgram: 76, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "shakuhachi", displayName: "Shakuhachi", category: "Woodwinds", midiProgram: 77, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "whistle", displayName: "Whistle", category: "Woodwinds", midiProgram: 78, defaultClef: "treble", isPiano: false),
        InstrumentInfo(name: "ocarina", displayName: "Ocarina", category: "Woodwinds", midiProgram: 79, defaultClef: "treble", isPiano: false)
    ]

    // Pre-computed dictionaries for O(1) lookups
    private static let infoByName: [String: InstrumentInfo] = Dictionary(uniqueKeysWithValues: allInfo.map { ($0.name, $0) })
    private static let infoByDisplayName: [String: InstrumentInfo] = Dictionary(uniqueKeysWithValues: allInfo.map { ($0.displayName, $0) })

    // MARK: - Public API
    
    static func getInstrumentInfo(byName name: String) -> InstrumentInfo? {
        return infoByName[name]
    }

    static func getInstrumentInfo(byDisplayName displayName: String) -> InstrumentInfo? {
        return infoByDisplayName[displayName]
    }

    static func getDisplayName(for instrumentName: String) -> String {
        return infoByName[instrumentName]?.displayName ?? instrumentName
    }

    /// Get the instrument name from a display name (reverse lookup)
    static func getInstrumentName(from displayName: String) -> String? {
        return getInstrumentInfo(byDisplayName: displayName)?.name
    }

    static func getMidiProgram(for instrumentName: String) -> Int? {
        return infoByName[instrumentName]?.midiProgram
    }

    static func getClef(for instrumentName: String) -> String {
        return infoByName[instrumentName]?.defaultClef ?? "treble"
    }

    static func isPianoInstrument(_ instrumentName: String) -> Bool {
        return infoByName[instrumentName]?.isPiano ?? false
    }

    static func getPianoInstrumentNames() -> Set<String> {
        return Set(allInfo.filter { $0.isPiano }.map { $0.name })
    }

    static func getInstrumentCategories() -> [Category] {
        // Group instruments by category
        let grouped = Dictionary(grouping: allInfo, by: { $0.category })
        
        // Define preferred category order
        let categoryOrder = ["Piano", "Percussion", "Organ", "Guitar", "Bass", "Strings", "Choir", "Brass", "Woodwinds"]
        
        return categoryOrder.compactMap { categoryName in
            guard let items = grouped[categoryName] else { return nil }
            return Category(name: categoryName, items: items.map { $0.displayName })
        }
    }

    static func getInstrumentPrograms() -> [String: UInt8] {
        return Dictionary(uniqueKeysWithValues: allInfo.map { ($0.name, UInt8($0.midiProgram)) })
    }
    
    static func getInstrumentNames() -> [String] {
        return allInfo.map { $0.name }
    }
}
