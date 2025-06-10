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
        let cleanedJSON = stripComments(from: jsonString)
        
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
    
    private func stripComments(from jsonString: String) -> String {
        var cleanedString = jsonString
        
        // Replace smart quotes with regular quotes
        cleanedString = cleanedString.replacingOccurrences(of: "“", with: "\"")
        cleanedString = cleanedString.replacingOccurrences(of: "”", with: "\"")
        
        // Remove // comments
        let lines = cleanedString.components(separatedBy: .newlines)
        let cleanedLines = lines.map { line in
            if let commentIndex = line.firstIndex(of: "/"),
               commentIndex < line.endIndex,
               line.index(after: commentIndex) < line.endIndex,
               line[line.index(after: commentIndex)] == "/" {
                return String(line[..<commentIndex]).trimmingCharacters(in: .whitespaces)
            }
            return line
        }
        return cleanedLines.joined(separator: "\n")
    }
    
    private func scheduleSequence(_ sequence: MusicSequence) {
        stopSequence()

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
            "acoustic_grand_piano": 0,
            "string_ensemble_1": 48
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + startSec) {
                        ts.startNote(midiNote, withVelocity: velocity, onChannel: 0)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + startSec + durSec) {
                        ts.stopNote(midiNote, onChannel: 0)
                    }
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
        let cleanedJSON = stripComments(from: jsonString)
        
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
