//
//  AudioManager.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/8/25.
//

import AVFoundation
import Foundation

// By annotating the entire class with @MainActor, we guarantee that all of its
// properties and methods are accessed on the main thread. This makes the class
// safe to use in a concurrent environment.
@MainActor
class AudioManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var progress: Double = 0.0
    @Published var elapsedTime: Double = 0.0
    @Published var totalDuration: Double = 0.0
    @Published var currentlyPlayingTitle: String?
    @Published var currentlyPlayingInstrument: String?
    @Published var lastError: String?

    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine
    private var sampler: AVAudioUnitSampler
    private var trackSamplers: [AVAudioUnitSampler] = []
    private var sequenceLength: TimeInterval = 0.0
    private var progressUpdateTask: Task<Void, Never>?
    private var scheduledTasks: [Task<Void, Never>] = []
    private var playbackStartTime: Date?

    init() {
        audioEngine = AVAudioEngine()
        sampler = AVAudioUnitSampler()
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)

        do {
            try audioEngine.start()
            loadSoundFont()
        } catch {
            lastError = "Failed to start audio engine: \(error.localizedDescription)"
        }
    }
    
    private func loadSoundFont() {
        guard let soundFontURL = Bundle.main.url(forResource: "90_sNutz_GM", withExtension: "sf2") else {
            lastError = "Could not find soundfont file"
            return
        }
        
        do {
            try sampler.loadSoundBankInstrument(at: soundFontURL, program: 0, bankMSB: 0x79, bankLSB: 0)
        } catch {
            lastError = "Failed to load soundfont: \(error.localizedDescription)"
        }
    }

    func playSequenceFromJSON(_ jsonString: String) {
        // This method is now on the Main Actor. We can safely stop the current sequence.
        stopSequence()

        // Use a background Task to perform the heavy lifting of parsing and setup
        // without blocking the UI.
        Task {
            do {
                guard let data = jsonString.data(using: .utf8) else {
                    throw NSError(domain: "AudioManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
                }

                let sequenceData = try JSONDecoder().decode(MusicSequence.self, from: data)
                
                // Calculate duration and update UI
                let beatDuration = 60.0 / sequenceData.tempo
                let maxEnd = sequenceData.tracks
                    .flatMap { $0.events.map { $0.time + $0.duration } }
                    .max() ?? 0
                self.sequenceLength = maxEnd * beatDuration
                self.totalDuration = self.sequenceLength

                // Update UI properties on main thread
                self.isPlaying = true
                self.currentlyPlayingTitle = sequenceData.title ?? "Untitled Sequence"
                self.currentlyPlayingInstrument = sequenceData.tracks.first?.instrument
                
                // Set playback start time and schedule the sequence
                self.playbackStartTime = Date()
                await self.scheduleSequence(sequenceData)
                self.startProgressUpdates()

            } catch {
                // Also update the UI with the error on the main thread.
                self.lastError = "Failed to play sequence: \(error.localizedDescription)"
                self.isPlaying = false
            }
        }
    }
    
    private func scheduleSequence(_ sequence: MusicSequence) async {
        let beatDuration = 60.0 / sequence.tempo
        
        // Clear any existing scheduled tasks and track samplers
        scheduledTasks.removeAll()
        
        // Detach previous track samplers
        for ts in trackSamplers {
            audioEngine.detach(ts)
        }
        trackSamplers.removeAll()
        
        // Create and setup samplers for each track
        guard let soundFontURL = Bundle.main.url(forResource: "90_sNutz_GM", withExtension: "sf2") else {
            lastError = "Could not find soundfont file for tracks"
            return
        }
        
        let instrumentPrograms = getInstrumentPrograms()
        
        for track in sequence.tracks {
            let trackSampler = AVAudioUnitSampler()
            audioEngine.attach(trackSampler)
            audioEngine.connect(trackSampler, to: audioEngine.mainMixerNode, format: nil)
            
            let program = instrumentPrograms[track.instrument] ?? 0
            do {
                try trackSampler.loadSoundBankInstrument(at: soundFontURL, program: program, bankMSB: 0x79, bankLSB: 0)
            } catch {
                print("Failed to load instrument \(track.instrument): \(error)")
            }
            trackSamplers.append(trackSampler)
        }
        
        // Schedule note events for each track
        for (trackIndex, track) in sequence.tracks.enumerated() {
            let trackSampler = trackSamplers[trackIndex]
            
            for event in track.events {
                let startTime = event.time * beatDuration
                let duration = event.duration * beatDuration
                let velocity = UInt8(event.velocity ?? 100)
                
                for pitch in event.pitches {
                    let midiNote = UInt8(pitch.midiValue)
                    
                    // Schedule note start
                    let startTask = Task {
                        try? await Task.sleep(for: .seconds(startTime))
                        if self.isPlaying {
                            await MainActor.run {
                                trackSampler.startNote(midiNote, withVelocity: velocity, onChannel: 0)
                            }
                        }
                    }
                    scheduledTasks.append(startTask)
                    
                    // Schedule note stop
                    let stopTask = Task {
                        try? await Task.sleep(for: .seconds(startTime + duration))
                        if self.isPlaying {
                            await MainActor.run {
                                trackSampler.stopNote(midiNote, onChannel: 0)
                            }
                        }
                    }
                    scheduledTasks.append(stopTask)
                }
            }
        }
        
        // Schedule sequence end
        let endTask = Task {
            try? await Task.sleep(for: .seconds(sequenceLength))
            await MainActor.run {
                if self.isPlaying {
                    self.stopSequence()
                }
            }
        }
        scheduledTasks.append(endTask)
    }

    func stopSequence() {
        isPlaying = false
        progress = 0.0
        elapsedTime = 0.0
        currentlyPlayingTitle = nil
        currentlyPlayingInstrument = nil
        
        // Cancel all scheduled tasks
        for task in scheduledTasks {
            task.cancel()
        }
        scheduledTasks.removeAll()
        
        // Stop all currently playing notes
        for note in 0...127 {
            sampler.stopNote(UInt8(note), onChannel: 0)
        }
        // Stop track sampler notes
        for ts in trackSamplers {
            for note in 0...127 {
                ts.stopNote(UInt8(note), onChannel: 0)
            }
        }
        
        stopProgressUpdates()
    }

    // MARK: - Simple Note Playback

    func playNote(midiNote: UInt8, velocity: UInt8 = 100) {
        sampler.startNote(midiNote, withVelocity: velocity, onChannel: 0)
    }

    func stopNote(midiNote: UInt8) {
        sampler.stopNote(midiNote, onChannel: 0)
    }
    
    // MARK: - Duration Calculation
    
    func calculateDurationFromJSON(_ jsonString: String) {
        // Calculate duration for UI display without playing
        do {
            guard let data = jsonString.data(using: .utf8) else { return }
            let sequence = try JSONDecoder().decode(MusicSequence.self, from: data)
            let beatDuration = 60.0 / sequence.tempo
            
            // Find the maximum end time across all tracks
            var maxEndTime: Double = 0
            for track in sequence.tracks {
                for event in track.events {
                    let endTime = event.time + event.duration
                    maxEndTime = max(maxEndTime, endTime)
                }
            }
            // Convert to actual time using tempo
            let duration = maxEndTime * beatDuration
            sequenceLength = duration
            totalDuration = duration
        } catch {
            sequenceLength = 0
            totalDuration = 0
        }
    }

    // MARK: - Progress Updates (Modern Approach)

    private func startProgressUpdates() {
        // Cancel any existing task to ensure we only have one running.
        stopProgressUpdates()

        progressUpdateTask = Task {
            // This Task automatically inherits the MainActor context from this function.
            while !Task.isCancelled {
                // Calling updateProgress() is now safe and warning-free.
                updateProgress()

                // If updateProgress determined playback is over, exit the loop.
                if !self.isPlaying { break }

                // Asynchronously wait for 100ms without blocking the main thread.
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func updateProgress() {
        guard let startTime = playbackStartTime, isPlaying, sequenceLength > 0 else {
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        elapsedTime = elapsed
        progress = min(elapsed / sequenceLength, 1.0)

        if progress >= 1.0 {
            // Sequence should end naturally, but make sure it stops
            stopSequence()
        }
    }

    private func stopProgressUpdates() {
        progressUpdateTask?.cancel()
        progressUpdateTask = nil
        progress = 0.0
    }
    
    private func getInstrumentPrograms() -> [String: UInt8] {
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
