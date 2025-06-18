//
//  AudioManager.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/8/25.
//

import AVFoundation
import Foundation

enum PlaybackState {
    case idle
    case loading
    case playing
    case stopped
}

// By annotating the entire class with @MainActor, we guarantee that all of its
// properties and methods are accessed on the main thread. This makes the class
// safe to use in a concurrent environment.
@MainActor
class AudioManager: ObservableObject {
    // MARK: - Published Properties
    @Published var playbackState: PlaybackState = .idle
    @Published var progress: Double = 0.0
    @Published var elapsedTime: Double = 0.0
    @Published var totalDuration: Double = 0.0
    @Published var currentlyPlayingTitle: String?
    @Published var currentlyPlayingInstrument: String?
    @Published var lastError: String?
    @Published var receivedJSON: String = ""
    
    // Computed property for backward compatibility
    var isPlaying: Bool { playbackState == .playing }

    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine
    private var sampler: AVAudioUnitSampler
    private var trackSamplers: [AVAudioUnitSampler] = []
    private var sequenceLength: TimeInterval = 0.0
    private var progressUpdateTask: Task<Void, Never>?
    private var isSchedulingActive = false
    private var playbackStartTime: Date?
    private var testTimers: [DispatchSourceTimer] = []
    private var noteTimers: [DispatchSourceTimer] = []

    init() {
        audioEngine = AVAudioEngine()
        sampler = AVAudioUnitSampler()
        setupAudioEngine()
        Util.logTiming("AudioManager init completed")
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
        let startTime = Date()
        Util.logTiming("AudioManager.playSequenceFromJSON started")

        // This method is now on the Main Actor. We can safely stop the current sequence.
        stopSequence()
        
        // Set loading state immediately
        playbackState = .loading

        // Use a background Task to perform the heavy lifting of parsing and setup
        // without blocking the UI.
        Task {
            do {
                // Single pipeline: clean, decode, validate, re-encode for display
                let sequenceData = try processJSONSequence(jsonString)
                let decodeTime = Date().timeIntervalSince(startTime) * 1000
                Util.logTiming("JSON processed in \(String(format: "%.1f", decodeTime))ms, calling scheduleSequence")
                
                // Calculate duration and update UI
                let beatDuration = 60.0 / sequenceData.tempo
                let maxEnd = sequenceData.tracks
                    .flatMap { $0.events.map { $0.time + $0.dur } }
                    .max() ?? 0
                self.sequenceLength = maxEnd * beatDuration
                self.totalDuration = self.sequenceLength
                print("🎵 AudioManager: totalDuration set to \(self.totalDuration) seconds")

                // Update UI properties on main thread
                self.currentlyPlayingTitle = sequenceData.title ?? "Untitled Sequence"
                self.currentlyPlayingInstrument = sequenceData.tracks.first?.instrument
                
                // Set playback start time and schedule the sequence
                self.playbackStartTime = Date()
                await self.scheduleSequence(sequenceData)
                self.startElapsedTimeUpdates()
                
                // CLEAN START EVENT: Everything is ready, start playback
                print("🎵 AudioManager: Setting playbackState to .playing with totalDuration=\(self.totalDuration)")
                self.playbackState = .playing

            } catch {
                // Also update the UI with the error on the main thread.
                self.lastError = "Failed to play sequence: \(error.localizedDescription)"
                self.playbackState = .idle
            }
        }
    }
    
    private func scheduleSequence(_ sequence: MusicSequence) async {
        let beatDuration = 60.0 / sequence.tempo
        Util.logTiming("Sequence scheduling started, beatDuration=\(beatDuration)")

        // Clear any existing scheduling and track samplers  
        isSchedulingActive = false
        
        // Cancel and clear all note timers
        for timer in noteTimers {
            timer.cancel()
        }
        noteTimers.removeAll()
        
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

        let instrumentPrograms = Instruments.getInstrumentPrograms()

        Util.logTiming("Loading instruments")
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
        isSchedulingActive = true
        Util.logTiming("Begin scheduling")
        for (trackIndex, track) in sequence.tracks.enumerated() {

            let trackSampler = trackSamplers[trackIndex]
            
            for event in track.events {
                let startTime = event.time * beatDuration
                let duration = event.dur * beatDuration
                let velocity = UInt8(event.vel ?? 100)

                for pitch in event.pitches {
                    let midiNote = UInt8(pitch.midiValue)
                    
                    // Use DispatchSourceTimer for precise timing
                    let scheduledTime = startTime
                    let scheduleStart = CFAbsoluteTimeGetCurrent()
                    
                    // Note start timer
                    let startTimer = DispatchSource.makeTimerSource(queue: .main)
                    startTimer.schedule(deadline: .now() + .milliseconds(Int(startTime * 1000)))
                    startTimer.setEventHandler { [weak self] in
                        let actualDelay = CFAbsoluteTimeGetCurrent() - scheduleStart
                        Util.logTiming("Note \(midiNote) START: scheduled=\(scheduledTime)s, actual=\(String(format: "%.3f", actualDelay))s, diff=\(String(format: "%.3f", actualDelay - scheduledTime))s")
                        guard let self = self, self.isPlaying, self.isSchedulingActive else { return }
                        trackSampler.startNote(midiNote, withVelocity: velocity, onChannel: 0)
                        startTimer.cancel()
                    }
                    startTimer.resume()
                    noteTimers.append(startTimer)
                    
                    // Note stop timer
//                    let scheduledStopTime = startTime + duration
//                    let stopScheduleStart = CFAbsoluteTimeGetCurrent()
                    
                    let stopTimer = DispatchSource.makeTimerSource(queue: .main)
                    stopTimer.schedule(deadline: .now() + .milliseconds(Int((startTime + duration) * 1000)))
                    stopTimer.setEventHandler { [weak self] in
                        guard let self = self, self.isPlaying, self.isSchedulingActive else { return }
                        trackSampler.stopNote(midiNote, onChannel: 0)
                        stopTimer.cancel()
                    }
                    stopTimer.resume()
                    noteTimers.append(stopTimer)
                }
            }
        }
        
        // Schedule sequence end
        let endTimer = DispatchSource.makeTimerSource(queue: .main)
        endTimer.schedule(deadline: .now() + .milliseconds(Int(sequenceLength * 1000)))
        endTimer.setEventHandler { [weak self] in
            guard let self = self, self.isPlaying, self.isSchedulingActive else { return }
            self.stopSequence()
            endTimer.cancel()
        }
        endTimer.resume()
        noteTimers.append(endTimer)
    }

    func stopSequence() {
        playbackState = .stopped
        progress = 0.0
        elapsedTime = 0.0
        currentlyPlayingTitle = nil
        currentlyPlayingInstrument = nil
        
        // Stop all scheduling
        isSchedulingActive = false
        
        // Cancel all note timers
        for timer in noteTimers {
            timer.cancel()
        }
        noteTimers.removeAll()
        
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
        
        stopElapsedTimeUpdates()
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
        // Parse JSON for duration calculation only, don't update display
        do {
            let cleanedJSON = Util.cleanJSON(from: jsonString)
            guard let data = cleanedJSON.data(using: .utf8) else { return }
            
            let sequence = try JSONDecoder().decode(MusicSequence.self, from: data)
            let beatDuration = 60.0 / sequence.tempo
            
            // Find the maximum end time across all tracks
            var maxEndTime: Double = 0
            for track in sequence.tracks {
                for event in track.events {
                    let endTime = event.time + event.dur
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

    // MARK: - Elapsed Time Updates (Progress bar handled by SwiftUI animation)

    private func startElapsedTimeUpdates() {
        // Cancel any existing task to ensure we only have one running.
        stopElapsedTimeUpdates()

        progressUpdateTask = Task {
            // This Task automatically inherits the MainActor context from this function.
            while !Task.isCancelled {
                // Update elapsed time for display
                updateElapsedTime()

                // If sequence ended, exit the loop
                if !self.isPlaying { break }

                // Update every 100ms for smooth time display
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func updateElapsedTime() {
        guard let startTime = playbackStartTime, isPlaying, sequenceLength > 0 else {
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        elapsedTime = elapsed
        
        // Stop sequence when we've exceeded the total duration
        if elapsed >= sequenceLength {
            stopSequence()
        }
    }

    private func stopElapsedTimeUpdates() {
        progressUpdateTask?.cancel()
        progressUpdateTask = nil
    }
    
    // MARK: - JSON Processing Pipeline
    
    private func processJSONSequence(_ jsonString: String) throws -> MusicSequence {
        // Step 1: Clean the JSON
        let cleanedJSON = Util.cleanJSON(from: jsonString)
        
        // Step 2: Decode with validation and rounding
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw NSError(domain: "AudioManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        
        let sequenceData = try JSONDecoder().decode(MusicSequence.self, from: data)
        
        // Step 3: Re-encode for clean display (this will use our custom encoder with rounding)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let cleanEncodedData = try encoder.encode(sequenceData)
        
        if let prettyJSONString = String(data: cleanEncodedData, encoding: .utf8) {
            self.receivedJSON = compactEventObjects(prettyJSONString)
        }
        
        return sequenceData
    }
    
    private func compactEventObjects(_ jsonString: String) -> String {
        return jsonString
            .replacing(
                /"events"\s*:\s*\[(?<body>(?:\s*\{[^}]+\}\s*,?)*)\s*\]/
            ) { match in
                let parts = match.body.split(separator: "{", omittingEmptySubsequences: true)
                let glued = parts
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } // Skip empty/whitespace parts
                    .map { "{\($0)".replacing(#/\s+/#, with: " ") }
                    .joined(separator: "\n        ")
                
                return #""events": [\#(glued.isEmpty ? "" : "\n        \(glued)\n      ")]"#
            }
    }
    
}
