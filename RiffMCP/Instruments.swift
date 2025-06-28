//
//  Instruments.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/16/25.
//

import Foundation

struct InstrumentInfo {
    let name: String           // raw name (e.g., "acoustic_grand_piano")
    let displayName: String    // polished name (e.g., "Grand Piano")
    let midiProgram: Int       // MIDI program number (0-based)
    let defaultClef: String    // "treble", "bass", "alto", "tenor"
    let isPiano: Bool          // for special piano handling
}

struct Instruments {
    static func getInstruments() -> [String: [(name: String, display: String)]] {
        return [
            "Piano": [
                ("acoustic_grand_piano", "Grand Piano"),
                ("bright_acoustic_piano", "Bright Piano"),
                ("electric_grand_piano", "Electric Grand Piano"),
                ("honky_tonk_piano", "Honky Tonk Piano"),
                ("electric_piano_1", "Electric Piano 1"),
                ("electric_piano_2", "Electric Piano 2"),
                ("harpsichord", "Harpsichord"),
                ("clavinet", "Clavinet")
            ],
            "Percussion": [
                ("celesta", "Celesta"),
                ("glockenspiel", "Glockenspiel"),
                ("music_box", "Music Box"),
                ("vibraphone", "Vibraphone"),
                ("marimba", "Marimba"),
                ("xylophone", "Xylophone"),
                ("tubular_bells", "Tubular Bells"),
                ("dulcimer", "Dulcimer")
            ],
            "Organ": [
                ("drawbar_organ", "Drawbar Organ"),
                ("percussive_organ", "Percussive Organ"),
                ("rock_organ", "Rock Organ"),
                ("church_organ", "Church Organ"),
                ("reed_organ", "Reed Organ"),
                ("accordion", "Accordion"),
                ("harmonica", "Harmonica"),
                ("tango_accordion", "Tango Accordion")
            ],
            "Guitar": [
                ("acoustic_guitar_nylon", "Guitar (Nylon)"),
                ("acoustic_guitar_steel", "Guitar (Steel)"),
                ("electric_guitar_jazz", "Electric Guitar (Jazz)"),
                ("electric_guitar_clean", "Electric Guitar (Clean)"),
                ("electric_guitar_muted", "Electric Guitar (Muted)"),
                ("overdriven_guitar", "Overdriven Guitar"),
                ("distortion_guitar", "Distortion Guitar"),
                ("guitar_harmonics", "Guitar Harmonics")
            ],
            "Bass": [
                ("acoustic_bass", "Acoustic Bass"),
                ("electric_bass_finger", "Electric Bass (Finger)"),
                ("electric_bass_pick", "Electric Bass (Pick)"),
                ("fretless_bass", "Fretless Bass"),
                ("slap_bass_1", "Slap Bass 1"),
                ("slap_bass_2", "Slap Bass 2"),
                ("synth_bass_1", "Synth Bass 1"),
                ("synth_bass_2", "Synth Bass 2")
            ],
            "Strings": [
                ("violin", "Violin"),
                ("viola", "Viola"),
                ("cello", "Cello"),
                ("contrabass", "Contrabass"),
                ("tremolo_strings", "Tremolo Strings"),
                ("pizzicato_strings", "Pizzicato Strings"),
                ("orchestral_harp", "Orchestral Harp"),
                ("timpani", "Timpani"),
                ("string_ensemble_1", "String Ensemble 1"),
                ("string_ensemble_2", "String Ensemble 2"),
                ("synth_strings_1", "Synth Strings 1"),
                ("synth_strings_2", "Synth Strings 2")
            ],
            "Brass": [
                ("trumpet", "Trumpet"),
                ("trombone", "Trombone"),
                ("tuba", "Tuba"),
                ("muted_trumpet", "Muted Trumpet"),
                ("french_horn", "French Horn"),
                ("brass_section", "Brass Section"),
                ("synth_brass_1", "Synth Brass 1"),
                ("synth_brass_2", "Synth Brass 2")
            ],
            "Woodwinds": [
                ("soprano_sax", "Soprano Sax"),
                ("alto_sax", "Alto Sax"),
                ("tenor_sax", "Tenor Sax"),
                ("baritone_sax", "Baritone Sax"),
                ("oboe", "Oboe"),
                ("english_horn", "English Horn"),
                ("bassoon", "Bassoon"),
                ("clarinet", "Clarinet"),
                ("piccolo", "Piccolo"),
                ("flute", "Flute"),
                ("recorder", "Recorder"),
                ("pan_flute", "Pan Flute"),
                ("blown_bottle", "Blown Bottle"),
                ("shakuhachi", "Shakuhachi"),
                ("whistle", "Whistle"),
                ("ocarina", "Ocarina")
            ],
            "Choir": [
                ("choir_aahs", "Choir Aahs"),
                ("voice_oohs", "Voice Oohs"),
                ("synth_voice", "Synth Voice"),
                ("orchestra_hit", "Orchestra Hit")
            ]
        ]
    }

    static func getInstrumentNames() -> [String] {
        return getInstruments().values.flatMap { category in category.map { $0.name } }
    }

    static func getAllInstrumentInfo() -> [InstrumentInfo] {
        return [
            // Piano
            InstrumentInfo(name: "acoustic_grand_piano", displayName: "Grand Piano", midiProgram: 0, defaultClef: "treble", isPiano: true),
            InstrumentInfo(name: "bright_acoustic_piano", displayName: "Bright Piano", midiProgram: 1, defaultClef: "treble", isPiano: true),
            InstrumentInfo(name: "electric_grand_piano", displayName: "Electric Grand Piano", midiProgram: 2, defaultClef: "treble", isPiano: true),
            InstrumentInfo(name: "honky_tonk_piano", displayName: "Honky Tonk Piano", midiProgram: 3, defaultClef: "treble", isPiano: true),
            InstrumentInfo(name: "electric_piano_1", displayName: "Electric Piano 1", midiProgram: 4, defaultClef: "treble", isPiano: true),
            InstrumentInfo(name: "electric_piano_2", displayName: "Electric Piano 2", midiProgram: 5, defaultClef: "treble", isPiano: true),
            InstrumentInfo(name: "harpsichord", displayName: "Harpsichord", midiProgram: 6, defaultClef: "treble", isPiano: true),
            InstrumentInfo(name: "clavinet", displayName: "Clavinet", midiProgram: 7, defaultClef: "treble", isPiano: true),
            
            // Percussion
            InstrumentInfo(name: "celesta", displayName: "Celesta", midiProgram: 8, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "glockenspiel", displayName: "Glockenspiel", midiProgram: 9, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "music_box", displayName: "Music Box", midiProgram: 10, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "vibraphone", displayName: "Vibraphone", midiProgram: 11, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "marimba", displayName: "Marimba", midiProgram: 12, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "xylophone", displayName: "Xylophone", midiProgram: 13, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "tubular_bells", displayName: "Tubular Bells", midiProgram: 14, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "dulcimer", displayName: "Dulcimer", midiProgram: 15, defaultClef: "treble", isPiano: false),
            
            // Organ
            InstrumentInfo(name: "drawbar_organ", displayName: "Drawbar Organ", midiProgram: 16, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "percussive_organ", displayName: "Percussive Organ", midiProgram: 17, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "rock_organ", displayName: "Rock Organ", midiProgram: 18, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "church_organ", displayName: "Church Organ", midiProgram: 19, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "reed_organ", displayName: "Reed Organ", midiProgram: 20, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "accordion", displayName: "Accordion", midiProgram: 21, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "harmonica", displayName: "Harmonica", midiProgram: 22, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "tango_accordion", displayName: "Tango Accordion", midiProgram: 23, defaultClef: "treble", isPiano: false),
            
            // Guitar
            InstrumentInfo(name: "acoustic_guitar_nylon", displayName: "Guitar (Nylon)", midiProgram: 24, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "acoustic_guitar_steel", displayName: "Guitar (Steel)", midiProgram: 25, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "electric_guitar_jazz", displayName: "Electric Guitar (Jazz)", midiProgram: 26, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "electric_guitar_clean", displayName: "Electric Guitar (Clean)", midiProgram: 27, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "electric_guitar_muted", displayName: "Electric Guitar (Muted)", midiProgram: 28, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "overdriven_guitar", displayName: "Overdriven Guitar", midiProgram: 29, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "distortion_guitar", displayName: "Distortion Guitar", midiProgram: 30, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "guitar_harmonics", displayName: "Guitar Harmonics", midiProgram: 31, defaultClef: "treble", isPiano: false),
            
            // Bass
            InstrumentInfo(name: "acoustic_bass", displayName: "Acoustic Bass", midiProgram: 32, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "electric_bass_finger", displayName: "Electric Bass (Finger)", midiProgram: 33, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "electric_bass_pick", displayName: "Electric Bass (Pick)", midiProgram: 34, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "fretless_bass", displayName: "Fretless Bass", midiProgram: 35, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "slap_bass_1", displayName: "Slap Bass 1", midiProgram: 36, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "slap_bass_2", displayName: "Slap Bass 2", midiProgram: 37, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "synth_bass_1", displayName: "Synth Bass 1", midiProgram: 38, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "synth_bass_2", displayName: "Synth Bass 2", midiProgram: 39, defaultClef: "bass", isPiano: false),
            
            // Strings
            InstrumentInfo(name: "violin", displayName: "Violin", midiProgram: 40, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "viola", displayName: "Viola", midiProgram: 41, defaultClef: "alto", isPiano: false),
            InstrumentInfo(name: "cello", displayName: "Cello", midiProgram: 42, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "contrabass", displayName: "Contrabass", midiProgram: 43, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "tremolo_strings", displayName: "Tremolo Strings", midiProgram: 44, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "pizzicato_strings", displayName: "Pizzicato Strings", midiProgram: 45, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "orchestral_harp", displayName: "Orchestral Harp", midiProgram: 46, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "timpani", displayName: "Timpani", midiProgram: 47, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "string_ensemble_1", displayName: "String Ensemble 1", midiProgram: 48, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "string_ensemble_2", displayName: "String Ensemble 2", midiProgram: 49, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "synth_strings_1", displayName: "Synth Strings 1", midiProgram: 50, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "synth_strings_2", displayName: "Synth Strings 2", midiProgram: 51, defaultClef: "treble", isPiano: false),
            
            // Choir
            InstrumentInfo(name: "choir_aahs", displayName: "Choir Aahs", midiProgram: 52, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "voice_oohs", displayName: "Voice Oohs", midiProgram: 53, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "synth_voice", displayName: "Synth Voice", midiProgram: 54, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "orchestra_hit", displayName: "Orchestra Hit", midiProgram: 55, defaultClef: "treble", isPiano: false),
            
            // Brass
            InstrumentInfo(name: "trumpet", displayName: "Trumpet", midiProgram: 56, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "trombone", displayName: "Trombone", midiProgram: 57, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "tuba", displayName: "Tuba", midiProgram: 58, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "muted_trumpet", displayName: "Muted Trumpet", midiProgram: 59, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "french_horn", displayName: "French Horn", midiProgram: 60, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "brass_section", displayName: "Brass Section", midiProgram: 61, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "synth_brass_1", displayName: "Synth Brass 1", midiProgram: 62, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "synth_brass_2", displayName: "Synth Brass 2", midiProgram: 63, defaultClef: "treble", isPiano: false),
            
            // Woodwinds
            InstrumentInfo(name: "soprano_sax", displayName: "Soprano Sax", midiProgram: 64, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "alto_sax", displayName: "Alto Sax", midiProgram: 65, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "tenor_sax", displayName: "Tenor Sax", midiProgram: 66, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "baritone_sax", displayName: "Baritone Sax", midiProgram: 67, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "oboe", displayName: "Oboe", midiProgram: 68, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "english_horn", displayName: "English Horn", midiProgram: 69, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "bassoon", displayName: "Bassoon", midiProgram: 70, defaultClef: "bass", isPiano: false),
            InstrumentInfo(name: "clarinet", displayName: "Clarinet", midiProgram: 71, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "piccolo", displayName: "Piccolo", midiProgram: 72, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "flute", displayName: "Flute", midiProgram: 73, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "recorder", displayName: "Recorder", midiProgram: 74, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "pan_flute", displayName: "Pan Flute", midiProgram: 75, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "blown_bottle", displayName: "Blown Bottle", midiProgram: 76, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "shakuhachi", displayName: "Shakuhachi", midiProgram: 77, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "whistle", displayName: "Whistle", midiProgram: 78, defaultClef: "treble", isPiano: false),
            InstrumentInfo(name: "ocarina", displayName: "Ocarina", midiProgram: 79, defaultClef: "treble", isPiano: false)
        ]
    }

    static func getInstrumentPrograms() -> [String: UInt8] {
        return [
            // Piano
            "acoustic_grand_piano": 0,
            "bright_acoustic_piano": 1,
            "electric_grand_piano": 2,
            "honky_tonk_piano": 3,
            "electric_piano_1": 4,
            "electric_piano_2": 5,
            "harpsichord": 6,
            "clavinet": 7,

            // Percussion
            "celesta": 8,
            "glockenspiel": 9,
            "music_box": 10,
            "vibraphone": 11,
            "marimba": 12,
            "xylophone": 13,
            "tubular_bells": 14,
            "dulcimer": 15,

            // Organ
            "drawbar_organ": 16,
            "percussive_organ": 17,
            "rock_organ": 18,
            "church_organ": 19,
            "reed_organ": 20,
            "accordion": 21,
            "harmonica": 22,
            "tango_accordion": 23,

            // Guitar
            "acoustic_guitar_nylon": 24,
            "acoustic_guitar_steel": 25,
            "electric_guitar_jazz": 26,
            "electric_guitar_clean": 27,
            "electric_guitar_muted": 28,
            "overdriven_guitar": 29,
            "distortion_guitar": 30,
            "guitar_harmonics": 31,

            // Bass
            "acoustic_bass": 32,
            "electric_bass_finger": 33,
            "electric_bass_pick": 34,
            "fretless_bass": 35,
            "slap_bass_1": 36,
            "slap_bass_2": 37,
            "synth_bass_1": 38,
            "synth_bass_2": 39,

            // Strings
            "violin": 40,
            "viola": 41,
            "cello": 42,
            "contrabass": 43,
            "tremolo_strings": 44,
            "pizzicato_strings": 45,
            "orchestral_harp": 46,
            "timpani": 47,
            "string_ensemble_1": 48,
            "string_ensemble_2": 49,
            "synth_strings_1": 50,
            "synth_strings_2": 51,

            // Choir
            "choir_aahs": 52,
            "voice_oohs": 53,
            "synth_voice": 54,
            "orchestra_hit": 55,

            // Brass
            "trumpet": 56,
            "trombone": 57,
            "tuba": 58,
            "muted_trumpet": 59,
            "french_horn": 60,
            "brass_section": 61,
            "synth_brass_1": 62,
            "synth_brass_2": 63,

            // Woodwinds
            "soprano_sax": 64,
            "alto_sax": 65,
            "tenor_sax": 66,
            "baritone_sax": 67,
            "oboe": 68,
            "english_horn": 69,
            "bassoon": 70,
            "clarinet": 71,
            "piccolo": 72,
            "flute": 73,
            "recorder": 74,
            "pan_flute": 75,
            "blown_bottle": 76,
            "shakuhachi": 77,
            "whistle": 78,
            "ocarina": 79
        ]
    }
    
    // MARK: - Lookup Methods for MEIConverter
    static func getDisplayName(for instrumentName: String) -> String? {
        return getAllInstrumentInfo().first { $0.name == instrumentName }?.displayName
    }
    
    static func getMidiProgram(for instrumentName: String) -> Int? {
        return getAllInstrumentInfo().first { $0.name == instrumentName }?.midiProgram
    }
    
    static func getClef(for instrumentName: String) -> String {
        return getAllInstrumentInfo().first { $0.name == instrumentName }?.defaultClef ?? "treble"
    }
    
    static func isPianoInstrument(_ instrumentName: String) -> Bool {
        return getAllInstrumentInfo().first { $0.name == instrumentName }?.isPiano ?? false
    }
    
    static func getPianoInstrumentNames() -> Set<String> {
        return Set(getAllInstrumentInfo().filter { $0.isPiano }.map { $0.name })
    }
}
