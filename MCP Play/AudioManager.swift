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
        
        // Clear any existing scheduled tasks
        scheduledTasks.removeAll()
        
        // Schedule note events for each track
        for track in sequence.tracks {
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
                                self.sampler.startNote(midiNote, withVelocity: velocity, onChannel: 0)
                            }
                        }
                    }
                    scheduledTasks.append(startTask)
                    
                    // Schedule note stop
                    let stopTask = Task {
                        try? await Task.sleep(for: .seconds(startTime + duration))
                        if self.isPlaying {
                            await MainActor.run {
                                self.sampler.stopNote(midiNote, onChannel: 0)
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
}
