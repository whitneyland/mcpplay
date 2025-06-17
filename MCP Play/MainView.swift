//
//  MainView.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/7/25.
//

import SwiftUI


struct MainView: View {
    @EnvironmentObject var audioManager: AudioManager
    @StateObject private var presetManager = PresetManager()
    @State private var selectedPresetId: String = ""
    @State private var jsonInput = ""
    @State private var animatedElapsedTime: Double = 0.0

    var body: some View {
        VStack {
            TextEditor(text: $jsonInput)
                .border(Color.gray, width: 1)
                .onChange(of: jsonInput) {
                    audioManager.calculateDurationFromJSON(jsonInput)
                }

            if !presetManager.presets.isEmpty {
                Picker("Presets", selection: $selectedPresetId) {
                    ForEach(presetManager.presets, id: \.id) { preset in
                        Text(preset.displayName).tag(preset.id)
                    }
                }
                .padding(.top)
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedPresetId) {
                    loadPresetToInput()
                }
            } else {
                Text("No presets available")
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            HStack {
                AnimatedProgressBar(
                    progress: animatedElapsedTime,
                    total: audioManager.totalDuration
                )
                
                Text("\(formatTime(audioManager.elapsedTime)) / \(formatTime(audioManager.totalDuration))")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .trailing)
            }
            .onChange(of: audioManager.playbackState) { _, state in
                switch state {
                case .playing:
                    animatedElapsedTime = 0.0
                    withAnimation(.linear(duration: audioManager.totalDuration)) {
                        animatedElapsedTime = audioManager.totalDuration
                    }
                case .stopped, .idle:
                    animatedElapsedTime = 0.0
                case .loading:
                    break
                }
            }
            .padding(.top)
            .padding(.bottom)

            Button(action: {
                if audioManager.isPlaying {
                    audioManager.stopSequence()
                } else {
                    audioManager.playSequenceFromJSON(jsonInput)
                }
            }) {
                HStack {
                    Image(systemName: audioManager.isPlaying ? "stop.fill" : "play.fill")
                    Text(audioManager.isPlaying ? "Stop" : "Play")
                }
                .foregroundColor(.white)
                .padding()
            }
            .background(Color.gray30)
            .cornerRadius(8)
            .disabled(jsonInput.isEmpty)

//            PianoView()
//                .padding()
        }
        .padding()
        .onAppear {
            if !presetManager.presets.isEmpty && selectedPresetId.isEmpty {
                selectedPresetId = presetManager.presets.first?.id ?? ""
                loadPresetToInput()
            }
        }
        .onReceive(audioManager.$receivedJSON) { newJSON in
            if !newJSON.isEmpty {
                jsonInput = newJSON
            }
        }
    }

    
    private func formatTime(_ seconds: Double) -> String {
        // Handle invalid input scenarios
        guard seconds.isFinite && seconds >= 0 else {
            return "0:00.0"
        }
        
        let minutes = Int(seconds) / 60
        let remainingSeconds = seconds.truncatingRemainder(dividingBy: 60.0)
        return String(format: "%d:%04.1f", minutes, remainingSeconds)
    }
    
    private func loadPresetToInput() {
        guard let preset = presetManager.getPreset(by: selectedPresetId) else {
            print("Could not find preset with id: \(selectedPresetId)")
            return
        }
        
        jsonInput = preset.content
        audioManager.calculateDurationFromJSON(preset.content)
    }    
}
#Preview {
    MainView()
        .environmentObject(AudioManager())
}
