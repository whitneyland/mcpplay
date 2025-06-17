//
//  MainView.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/7/25.
//

import SwiftUI


struct MainView: View {
    @EnvironmentObject var audioManager: AudioManager
    @State private var selectedSequence = "scale"
    @State private var jsonInput = ""
    @State private var animatedElapsedTime: Double = 0.0

    let availableSequences = [
        ("scale", "Scale"),
        ("moonlight_sonata", "Moonlight Sonata"),
        ("sonnet_4_multi", "Sonnet 4"),
        ("gemini_1", "Gemini"),
        ("claude_opus_1", "Opus 4")
    ]

    var body: some View {
        VStack {
            TextEditor(text: $jsonInput)
                .border(Color.gray, width: 1)
                .onChange(of: jsonInput) {
                    audioManager.calculateDurationFromJSON(jsonInput)
                }

            Picker("Presets", selection: $selectedSequence) {
                ForEach(availableSequences, id: \.0) { sequence in
                    Text(sequence.1).tag(sequence.0)
                }
            }
            .padding(.top)
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedSequence) {
                loadSequenceToInput()
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
            loadSequenceToInput()
        }
        .onReceive(audioManager.$receivedJSON) { newJSON in
            if !newJSON.isEmpty {
                jsonInput = newJSON
            }
        }
    }

    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func loadSequenceToInput() {
        guard let sequenceURL = Bundle.main.url(forResource: selectedSequence, withExtension: "json") else {
            print("Could not find \(selectedSequence).json")
            return
        }
        
        do {
            let data = try Data(contentsOf: sequenceURL)
            let jsonString = String(data: data, encoding: .utf8) ?? ""
            jsonInput = jsonString
            audioManager.calculateDurationFromJSON(jsonString)
        } catch {
            print("Failed to load sequence: \(error)")
        }
    }    
}
#Preview {
    MainView()
        .environmentObject(AudioManager())
}
