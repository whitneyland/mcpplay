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
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
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

            HStack(spacing: 20) {
                Button(action: {
                    audioManager.playSequenceFromJSON(jsonInput)
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Play")
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                .background(Color.gray30)
                .cornerRadius(8)
                .disabled(audioManager.isPlaying || jsonInput.isEmpty)

                Button(action: {
                    audioManager.stopSequence()
                }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                .background(Color.gray30)
                .cornerRadius(8)
                .disabled(!audioManager.isPlaying)
            }

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
            return "0:00"
        }
        
        let totalSeconds = Int(seconds.rounded())
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
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
