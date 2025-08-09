//
//  AudioManager.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/8/25.
//

import AVFoundation
import Foundation
import QuartzCore

enum PlaybackState {
    case idle
    case loading
    case playing
    case stopped
}

enum AudioError: LocalizedError {
    case soundFontNotFound
    case sequencerStartFailed(String)
    case instrumentLoadFailed(String, String)
    case jsonDecodeFailed(String)
    case tempoTrackMissing
    
    var errorDescription: String? {
        switch self {
        case .soundFontNotFound:
            return "Could not find soundfont file"
        case .sequencerStartFailed(let detail):
            return "Failed to start sequencer: \(detail)"
        case .instrumentLoadFailed(let instrument, let detail):
            return "Failed to load instrument \(instrument): \(detail)"
        case .jsonDecodeFailed(let detail):
            return "Failed to play sequence: \(detail)"
        case .tempoTrackMissing:
            return "No tempo track available"
        }
    }
}

protocol AudioManaging: Sendable {
    @MainActor
    func playSequenceFromJSON(_ raw: String)
}

// @MainActor guarantees all properties and methods are accessed on the main thread.
@MainActor
class AudioManager: AudioManaging, ObservableObject {

    // MARK: - Published Properties
    @Published var playbackState: PlaybackState = .idle
    @Published var progress: Double = 0.0
    @Published var elapsedTime: Double = 0.0
    @Published var totalDuration: Double = 0.0
    @Published var currentlyPlayingTitle: String?
    @Published var currentlyPlayingInstrument: String?
    @Published var lastError: AudioError?
    @Published var receivedJSON: String = ""
    
    var isPlaying: Bool { playbackState == .playing }

    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine
    private var sampler: AVAudioUnitSampler
    private var trackSamplers: [AVAudioUnitSampler] = []
    private var currentTempo: Double = 120.0
    private var displayTimer: Timer?
    private var playbackStartTicks: CFTimeInterval?
    private var sequencer: AVAudioSequencer
    private let playbackTailTime: TimeInterval = 2.0

    init() {
        audioEngine = AVAudioEngine()
        sampler = AVAudioUnitSampler()
        sequencer = AVAudioSequencer(audioEngine: audioEngine)
        setupAudioEngine()
        Log.audio.info("🎶 AudioManager: Initialized")
    }

    private func setupAudioEngine() {
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)

        do {
            try audioEngine.start()
            guard let soundFontURL = loadSoundFont() else {
                lastError = .soundFontNotFound
                return
            }
            do {
                try sampler.loadSoundBankInstrument(at: soundFontURL, program: 0, bankMSB: 0x79, bankLSB: 0)
            } catch {
                lastError = .instrumentLoadFailed("FluidR3_GM", error.localizedDescription)
            }
        } catch {
            lastError = .sequencerStartFailed(error.localizedDescription)
        }
    }
    
    private func loadSoundFont() -> URL? {
        return Bundle.main.url(forResource: "FluidR3_GM", withExtension: "sf2")
    }

    func playSequenceFromJSON(_ rawJSON: String) {
        // Log.audio.info("🎶 AudioManager: Sequence started")

        stopSequence()                     // cancel anything already playing
        playbackState = .loading

        do {
            // ── 1. Parse / validate ───────────────────────────────
            let sequence = try MusicSequenceJSONSerializer.decode(rawJSON)

            // ── 2. Duration & UI fields ───────────────────────────
            currentTempo = sequence.tempo
            let beat = 60.0 / sequence.tempo
            let maxEndBeat = sequence.tracks
                .flatMap { $0.events.map { $0.time + $0.dur } }
                .max() ?? 0
            totalDuration = maxEndBeat * beat

            currentlyPlayingTitle       = sequence.title ?? "Untitled Sequence"
            currentlyPlayingInstrument  = sequence.tracks.first?.instrument

            // ── 3. Schedule & start ───────────────────────────────
            playbackStartTicks = CACurrentMediaTime()
            try scheduleSequence(sequence)
            startElapsedTimeUpdates()
            Log.audio.info("🎶 AudioManager: Audio playback started, total duration: \(String(format: "%.1f", totalDuration)) seconds")
            playbackState = .playing

            // ── 4. Publish prettified JSON to the editor pane ─────
            receivedJSON = try MusicSequenceJSONSerializer.prettyPrint(sequence)

        } catch let audioError as AudioError {
            lastError = audioError
            playbackState = .idle
        } catch {
            lastError = .jsonDecodeFailed(error.localizedDescription)
            playbackState = .idle
        }
    }

    private func scheduleSequence(_ sequence: MusicSequence) throws {
        // Log.audio.info("🎶 AudioManager: Scheduling started, tempo=\(sequence.tempo)")

        sequencer.stop()

        // Clear old tracks (except tempo)
        for track in sequencer.tracks.reversed()
        where track != sequencer.tempoTrack {
            sequencer.removeTrack(track)
        }

        // Get tempo track
        let tempoTrack = sequencer.tempoTrack
        
        // Remove any previous tempo events (skip if track is empty to avoid error -50)
        if tempoTrack.lengthInBeats > 0 {
            tempoTrack.clearEvents(in: AVMakeBeatRange(0, tempoTrack.lengthInBeats))
        }
        
        // Insert the new tempo event
        tempoTrack.addEvent(
            AVExtendedTempoEvent(tempo: sequence.tempo),
            at: AVMusicTimeStamp(0)
        )
        
        // Keep the global speed-multiplier at 1×
        sequencer.rate = 1.0

        // Detach previous track samplers
        for ts in trackSamplers {
            audioEngine.detach(ts)
        }
        trackSamplers.removeAll()

        // Create and setup samplers for each track
        guard let soundFontURL = loadSoundFont() else {
            throw AudioError.soundFontNotFound
        }

        let instrumentPrograms = Instruments.getInstrumentPrograms()

        for (index, track) in sequence.tracks.enumerated() {
            let trackSampler = AVAudioUnitSampler()
            audioEngine.attach(trackSampler)
            audioEngine.connect(trackSampler, to: audioEngine.mainMixerNode, format: nil)
            
            let program = instrumentPrograms[track.instrument] ?? 0
            do {
                try trackSampler.loadSoundBankInstrument(at: soundFontURL, program: program, bankMSB: 0x79, bankLSB: 0)
                // Log.audio.info("🎵 AudioManager: Track \(index, privacy: .public): Successfully loaded soundbank")
            } catch {
                Log.audio.error("❌ AudioManager: Track \(index): Failed to load instrument \(track.instrument): \(error.localizedDescription)")
                throw AudioError.instrumentLoadFailed(track.instrument, error.localizedDescription)
            }
            trackSamplers.append(trackSampler)
        }
        
        // Create AVAudioSequencer tracks and schedule events
        for (trackIndex, track) in sequence.tracks.enumerated() {
            let sequencerTrack = sequencer.createAndAppendTrack()
            let trackSampler = trackSamplers[trackIndex]
            
            // Connect the sequencer track to our sampler
            sequencerTrack.destinationAudioUnit = trackSampler

            var eventCount = 0
            for event in track.events {
                let startTime = event.time  // Already in beats
                let duration = event.dur    // Already in beats
                let velocity = UInt8(event.vel ?? 100)

                for pitch in event.pitches {
                    let midiNote = UInt8(pitch.midiValue)
                    
                    // Create MIDI note event (times are in beats)
                    let noteEvent = AVMIDINoteEvent(
                        channel: 0,
                        key: UInt32(midiNote),
                        velocity: UInt32(velocity),
                        duration: AVMusicTimeStamp(duration)
                    )
                    
                    // Add to track at specified time (in beats)
                    sequencerTrack.lengthInBeats = max(sequencerTrack.lengthInBeats, AVMusicTimeStamp(startTime + duration))
                    let timeStamp = AVMusicTimeStamp(startTime)
                    sequencerTrack.addEvent(noteEvent, at: timeStamp)
                    eventCount += 1
                }
            }
            Log.audio.info("🎵 AudioManager: Track \(trackIndex): \(track.instrument) sampler, \(eventCount) MIDI events, \(String(format: "%.1f", sequencerTrack.lengthInBeats)) beats")
        }
        
        // Prepare and start the sequencer
        sequencer.prepareToPlay()

        // Reset position to start of sequence
        sequencer.currentPositionInBeats = 0.0

        do {
            try sequencer.start()
            // Log.audio.info("🎶 AudioManager: AVAudioSequencer started")
        } catch {
            Log.audio.error("❌ AudioManager: Sequencer failed to start - \(error.localizedDescription)")
            throw AudioError.sequencerStartFailed(error.localizedDescription)
        }
    }

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
            let sequence = try MusicSequenceJSONSerializer.decode(jsonString)
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
            totalDuration = maxEndTime * beatDuration
        } catch {
            totalDuration = 0
        }
    }

    // MARK: - Elapsed Time Updates
    private func startElapsedTimeUpdates() {
        stopElapsedTimeUpdates()                        // ensure single timer

        displayTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
        RunLoop.main.add(displayTimer!, forMode: .common)
    }

    private func stopElapsedTimeUpdates() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    // MARK: - Public API
    func stopSequence() {
        // User hit Stop – flip UI immediately, then clean up.
        playbackState = .stopped
        finishStopping()
    }

    // MARK: - Private helpers
    /// Shared teardown routine used by both user-initiated stop and automatic tail completion.
    private func finishStopping() {
        progress = 0.0
        elapsedTime = 0.0
        currentTempo = 120.0
        currentlyPlayingTitle = nil
        currentlyPlayingInstrument = nil

        sequencer.stop()
        sampler.sendController(123, withValue: 0, onChannel: 0)
        for ts in trackSamplers {
            ts.sendController(123, withValue: 0, onChannel: 0)
            audioEngine.detach(ts)
        }
        trackSamplers.removeAll()

        stopElapsedTimeUpdates()
    }

    /// Called automatically once the tail has rung out.
    private func tailCompleted() {
        finishStopping()                // UI already in .stopped
    }

    // Keep running even after UI flips to .stopped so we can finish the tail.
    private func updateElapsedTime() {
        guard totalDuration > 0 else {
            Log.audio.error("❌ AudioManager: updateElapsedTime called with zero duration")
            return
        }

        let beatDuration  = 60.0 / currentTempo
        let actualElapsed = sequencer.currentPositionInBeats * beatDuration

        // Musical time exposed to the UI (cap at score length)
        let musicalElapsed = min(actualElapsed, totalDuration)
        elapsedTime        = musicalElapsed
        progress           = musicalElapsed / totalDuration

        // As soon as the score is done, tell the UI we're stopped.
        if playbackState == .playing, actualElapsed >= totalDuration {
            playbackState = .stopped
            Log.audio.info("🎶 AudioManager: Playback completed \(self.totalDuration.asTimeString) seconds")
        }

        // When the tail has fully decayed, finish teardown.
        if actualElapsed >= totalDuration + playbackTailTime {
            tailCompleted()
        }
    }
}
