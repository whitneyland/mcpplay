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

protocol AudioManaging {
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
    private var sequenceLength: TimeInterval = 0.0
    private var currentTempo: Double = 120.0
    private var displayTimer: Timer?
    private var playbackStartTicks: CFTimeInterval?
    private var sequencer: AVAudioSequencer

    init() {
        audioEngine = AVAudioEngine()
        sampler = AVAudioUnitSampler()
        sequencer = AVAudioSequencer(audioEngine: audioEngine)
        setupAudioEngine()
        Log.audio.info("AudioManager init completed")
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
        let startTime = Date()
        Log.audio.info("AudioManager.playSequenceFromJSON started")

        stopSequence()                     // cancel anything already playing
        playbackState = .loading

        do {
            // ── 1. Parse / validate ───────────────────────────────
            let sequence = try MusicSequenceJSONSerializer.decode(rawJSON)
            Log.audio.latency("JSON processed", since: startTime)

            // ── 2. Duration & UI fields ───────────────────────────
            currentTempo = sequence.tempo
            let beat = 60.0 / sequence.tempo
            let maxEndBeat = sequence.tracks
                .flatMap { $0.events.map { $0.time + $0.dur } }
                .max() ?? 0
            sequenceLength = maxEndBeat * beat
            totalDuration  = sequenceLength

            currentlyPlayingTitle       = sequence.title ?? "Untitled Sequence"
            currentlyPlayingInstrument  = sequence.tracks.first?.instrument

            // ── 3. Schedule & start ───────────────────────────────
            playbackStartTicks = CACurrentMediaTime()
            try scheduleSequence(sequence)
            startElapsedTimeUpdates()
            Log.audio.info("🎶 Audio playback started")
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
        Log.audio.info("Sequence scheduling started, tempo=\(sequence.tempo)")

        // Stop and clear any existing sequencer
        sequencer.stop()
        
        // 1. Get the tempo track
        let tempoTrack = sequencer.tempoTrack
        
        // 2. Remove any previous tempo events (skip if track is empty to avoid error -50)
        if tempoTrack.lengthInBeats > 0 {
            tempoTrack.clearEvents(in: AVMakeBeatRange(0, tempoTrack.lengthInBeats))
        }
        
        // 3. Insert the new tempo event
        tempoTrack.addEvent(
            AVExtendedTempoEvent(tempo: sequence.tempo),   // <-- <-- the right class
            at: AVMusicTimeStamp(0)
        )
        
        // 4. Keep the global speed-multiplier at 1×
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
            Log.audio.info("🎵 Track \(index): Loading \(track.instrument, privacy: .public) (program \(program, privacy: .public))")
            
            do {
                try trackSampler.loadSoundBankInstrument(at: soundFontURL, program: program, bankMSB: 0x79, bankLSB: 0)
                Log.audio.info("🎵 Track \(index, privacy: .public): Successfully loaded soundbank")
            } catch {
                Log.audio.error("🎵 Track \(index, privacy: .public): Failed to load instrument \(track.instrument, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
            Log.audio.info("🎵 Track \(trackIndex, privacy: .public): Connected to \(track.instrument, privacy: .public) sampler, \(track.events.count, privacy: .public) events")
            
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
            Log.audio.info("🎵 Track \(trackIndex, privacy: .public): Added \(eventCount, privacy: .public) MIDI events, length \(String(format: "%.3f", sequencerTrack.lengthInBeats), privacy: .public) beats")
        }
        
        // Prepare and start the sequencer
        sequencer.prepareToPlay()

        // Reset position to start of sequence
        sequencer.currentPositionInBeats = 0.0

        do {
            try sequencer.start()
            Log.audio.info("🎶 AVAudioSequencer started")
        } catch {
            Log.audio.error("🎵 Sequencer: Failed to start - \(error.localizedDescription, privacy: .public)")
            throw AudioError.sequencerStartFailed(error.localizedDescription)
        }
    }

    func stopSequence() {
        playbackState = .stopped
        progress = 0.0
        elapsedTime = 0.0
        currentTempo = 120.0
        currentlyPlayingTitle = nil
        currentlyPlayingInstrument = nil
        
        // Stop the sequencer
        sequencer.stop()

        // Send MIDI CC 123 (allNotesOff) to stop all notes efficiently
        sampler.sendController(123, withValue: 0, onChannel: 0)
        for ts in trackSamplers {
            ts.sendController(123, withValue: 0, onChannel: 0)
        }
        
        // Detach track samplers to free resources
        for ts in trackSamplers {
            audioEngine.detach(ts)
        }
        trackSamplers.removeAll()
        
        stopElapsedTimeUpdates()
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
            let duration = maxEndTime * beatDuration
            sequenceLength = duration
            totalDuration = duration
        } catch {
            sequenceLength = 0
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

    private func updateElapsedTime() {
        guard isPlaying, sequenceLength > 0 else { return }
        
        let currentBeats = sequencer.currentPositionInBeats
        let beatDuration = 60.0 / currentTempo
        elapsedTime = currentBeats * beatDuration

        // Stop sequence when we've exceeded the total duration
        if elapsedTime >= sequenceLength {
            stopSequence()
        }
    }
}
