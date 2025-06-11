//
//  AudioManager.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/7/25.
//

import Foundation
import AVFoundation

class AudioManager: ObservableObject {
    private var audioEngine = AVAudioEngine()
    private var sampler = AVAudioUnitSampler()
    private var trackSamplers: [AVAudioUnitSampler] = []
    private var playbackTimer: Timer?
    private var progressTimer: Timer?
    private var playbackStartTime: Date?
    private var scheduledWorkItems: [DispatchWorkItem] = []
    @Published var totalDuration: Double = 0
    @Published var isPlaying = false
    @Published var progress: Double = 0.0
    @Published var elapsedTime: Double = 0.0
    
    init() {
        setupAudio()
    }
    
    private func setupAudio() {
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)
        
        do {
            try audioEngine.start()
            loadSoundFont()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func loadSoundFont() {
        guard let soundFontURL = Bundle.main.url(forResource: "90_sNutz_GM", withExtension: "sf2") else {
            print("Could not find soundfont file")
            return
        }
        
        do {
            try sampler.loadSoundBankInstrument(at: soundFontURL, program: 0, bankMSB: 0x79, bankLSB: 0)
        } catch {
            print("Failed to load soundfont: \(error)")
        }
    }
    
    func playNote(midiNote: UInt8) {
        sampler.startNote(midiNote, withVelocity: 64, onChannel: 0)
    }
    
    func stopNote(midiNote: UInt8) {
        sampler.stopNote(midiNote, onChannel: 0)
    }
    
    func playSequence(named sequenceName: String = "sample_sequence") {
        guard let sequenceURL = Bundle.main.url(forResource: sequenceName, withExtension: "json") else {
            print("Could not find \(sequenceName).json")
            return
        }
        
        do {
            let data = try Data(contentsOf: sequenceURL)
            let sequence = try JSONDecoder().decode(MusicSequence.self, from: data)
            scheduleSequence(sequence)
        } catch {
            print("Failed to load or decode sequence: \(error)")
        }
    }
    
    func playSequenceFromJSON(_ jsonString: String) {
        let cleanedJSON = cleanJSON(from: jsonString)
        
        guard let data = cleanedJSON.data(using: .utf8) else {
            print("Failed to convert JSON string to data")
            return
        }
        
        do {
            let sequence = try JSONDecoder().decode(MusicSequence.self, from: data)
            scheduleSequence(sequence)
        } catch {
            print("Failed to decode JSON sequence: \(error)")
        }
    }
    
    /// Attempts to make a user-supplied string parseable as JSON by performing
    /// a few pragmatic clean-ups:
    /// 1. Replace “smart quotes”, ‘smart apostrophes’ and back-ticks with plain
    ///    double quotes (").  Users frequently paste content from ChatGPT or
    ///    text editors that converts the quotes, which the JSON parser cannot
    ///    handle.
    /// 2. Remove single-line "// …" comments.
    /// 3. Strip trailing commas that appear immediately before a closing
    ///    object/array bracket (", }" or ", ]"), which are illegal in JSON but
    ///    common in hand-edited snippets.
    /// Cleans a user-supplied JSON-like string so that it can be parsed by
    /// `JSONDecoder`.  See inline documentation for the exact steps.
    private func cleanJSON(from jsonString: String) -> String {
        var cleanedString = jsonString

        // 1. Normalise quotes/back-ticks to standard double quotes
        let quoteReplacements: [String: String] = [
            "“": "\"",
            "”": "\"",
            "‘": "\"",
            "’": "\"",
            "`": "\""
        ]
        for (target, replacement) in quoteReplacements {
            cleanedString = cleanedString.replacingOccurrences(of: target, with: replacement)
        }

        // 2. Remove // comments (keep code before comment on the same line)
        let lines = cleanedString.components(separatedBy: .newlines)
        let uncommentedLines = lines.map { line -> String in
            guard let idx = line.firstIndex(of: "/") else { return line }
            let nextIdx = line.index(after: idx)
            if nextIdx < line.endIndex && line[nextIdx] == "/" {
                // Trim whitespace at the end to avoid stray spaces
                return String(line[..<idx]).trimmingCharacters(in: .whitespaces)
            }
            return line
        }
        cleanedString = uncommentedLines.joined(separator: "\n")

        // 3. Remove trailing commas before a closing } or ]
        // Remove trailing commas before a closing brace or bracket
        if let trailingCommaRegex = try? NSRegularExpression(pattern: #",\s*(?=[}\]])"#, options: []) {
            let range = NSRange(location: 0, length: cleanedString.utf16.count)
            cleanedString = trailingCommaRegex.stringByReplacingMatches(in: cleanedString, options: [], range: range, withTemplate: "")
        }

        return cleanedString
    }
    
    private func scheduleSequence(_ sequence: MusicSequence) {
        stopSequence()
        
        // Clear any previous work items
        scheduledWorkItems.removeAll()

        let beatDuration = 60.0 / sequence.tempo
        isPlaying = true

        // Detach previous track samplers
        for ts in trackSamplers {
            audioEngine.detach(ts)
        }
        trackSamplers.removeAll()

        guard let soundFontURL = Bundle.main.url(forResource: "90_sNutz_GM", withExtension: "sf2") else {
            print("Could not find soundfont file for tracks")
            return
        }
        // Map instrument names to GM program numbers
        let instrumentPrograms: [String: UInt8] = [
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
        // Attach and load each track's sampler
        for track in sequence.tracks {
            let ts = AVAudioUnitSampler()
            audioEngine.attach(ts)
            audioEngine.connect(ts, to: audioEngine.mainMixerNode, format: nil)
            let program = instrumentPrograms[track.instrument] ?? 0
            do {
                try ts.loadSoundBankInstrument(at: soundFontURL, program: program, bankMSB: 0x79, bankLSB: 0)
            } catch {
                print("Failed to load instrument \(track.instrument): \(error)")
            }
            trackSamplers.append(ts)
        }

        // Schedule events for each track
        for (trackIndex, track) in sequence.tracks.enumerated() {
            let ts = trackSamplers[trackIndex]
            for event in track.events {
                let startSec = event.time * beatDuration
                let durSec = event.duration * beatDuration
                let velocity = UInt8(event.velocity ?? 100)
                for pitch in event.pitches {
                    let midiNote = UInt8(pitch.midiValue)
                    
                    // Schedule note start
                    let startWorkItem = DispatchWorkItem {
                        ts.startNote(midiNote, withVelocity: velocity, onChannel: 0)
                    }
                    scheduledWorkItems.append(startWorkItem)
                    DispatchQueue.main.asyncAfter(deadline: .now() + startSec, execute: startWorkItem)
                    
                    // Schedule note stop
                    let stopWorkItem = DispatchWorkItem {
                        ts.stopNote(midiNote, onChannel: 0)
                    }
                    scheduledWorkItems.append(stopWorkItem)
                    DispatchQueue.main.asyncAfter(deadline: .now() + startSec + durSec, execute: stopWorkItem)
                }
            }
        }

        // Compute total duration across all tracks
        let maxEnd = sequence.tracks
            .flatMap { $0.events.map { $0.time + $0.duration } }
            .max() ?? 0
        totalDuration = maxEnd * beatDuration
        playbackStartTime = Date()

        playbackTimer = Timer.scheduledTimer(withTimeInterval: totalDuration, repeats: false) { _ in
            DispatchQueue.main.async {
                self.isPlaying = false
                self.progress = 1.0
                self.stopProgressTimer()
            }
        }

        startProgressTimer()
    }
    
    func stopSequence() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        stopProgressTimer()
        
        // Cancel all scheduled work items
        for workItem in scheduledWorkItems {
            workItem.cancel()
        }
        scheduledWorkItems.removeAll()
        
        // Stop manual sampler notes
        for note in 0...127 {
            sampler.stopNote(UInt8(note), onChannel: 0)
        }
        // Stop track sampler notes
        for ts in trackSamplers {
            for note in 0...127 {
                ts.stopNote(UInt8(note), onChannel: 0)
            }
        }
        
        isPlaying = false
        progress = 0.0
        elapsedTime = 0.0
    }
    
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateProgress()
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard let startTime = playbackStartTime, totalDuration > 0 else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        elapsedTime = elapsed
        progress = min(elapsed / totalDuration, 1.0)
    }
    
    func calculateDurationFromJSON(_ jsonString: String) {
        let cleanedJSON = cleanJSON(from: jsonString)
        
        guard let data = cleanedJSON.data(using: .utf8) else {
            totalDuration = 0
            return
        }
        
        do {
            let sequence = try JSONDecoder().decode(MusicSequence.self, from: data)
            let beatDuration = 60.0 / sequence.tempo
            // Determine max end time across all tracks
            let maxEnd = sequence.tracks
                .flatMap { $0.events.map { $0.time + $0.duration } }
                .max() ?? 0
            totalDuration = maxEnd * beatDuration
        } catch {
            totalDuration = 0
        }
    }
}
