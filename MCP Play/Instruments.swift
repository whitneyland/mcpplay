//
//  Instruments.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/16/25.
//

import Foundation

struct Instruments {
    static func getInstruments() -> [String: [(name: String, display: String)]] {
        return [
            "Piano": [
                ("acoustic_grand_piano", "Acoustic Grand Piano"),
                ("bright_acoustic_piano", "Bright Acoustic Piano"),
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
                ("acoustic_guitar_nylon", "Acoustic Guitar (Nylon)"),
                ("acoustic_guitar_steel", "Acoustic Guitar (Steel)"),
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
}
