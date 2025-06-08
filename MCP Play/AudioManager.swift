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
}