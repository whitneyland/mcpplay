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
    private var playbackTimer: Timer?
    @Published var isPlaying = false
    
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
        guard let data = jsonString.data(using: .utf8) else {
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
    
    private func scheduleSequence(_ sequence: MusicSequence) {
        stopSequence()
        
        let beatDuration = 60.0 / sequence.tempo
        
        isPlaying = true
        
        for event in sequence.events {
            let eventStartSeconds = event.time * beatDuration
            let eventDuration = event.duration * beatDuration
            let velocity = UInt8(event.velocity ?? 100)
            
            for pitch in event.pitches {
                let midiNote = UInt8(pitch.midiValue)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + eventStartSeconds) {
                    self.sampler.startNote(midiNote, withVelocity: velocity, onChannel: 0)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + eventStartSeconds + eventDuration) {
                    self.sampler.stopNote(midiNote, onChannel: 0)
                }
            }
        }
        
        let totalDuration = sequence.events.map { $0.time + $0.duration }.max() ?? 0
        let playbackDuration = totalDuration * beatDuration
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: playbackDuration, repeats: false) { _ in
            DispatchQueue.main.async {
                self.isPlaying = false
            }
        }
    }
    
    func stopSequence() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        for note in 0...127 {
            sampler.stopNote(UInt8(note), onChannel: 0)
        }
        
        isPlaying = false
    }
}