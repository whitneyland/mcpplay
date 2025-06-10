//
//  ContentView.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/7/25.
//

import SwiftUI


struct MainView: View {
    @EnvironmentObject var audioManager: AudioManager
    @State private var selectedSequence = "sample_sequence"
    @State private var jsonInput = ""

    // Piano keyboard view extracted to PianoView
    
    let availableSequences = [
        ("sample_sequence", "I-IV-V Demo"),
        ("moonlight_sonata", "Moonlight Sonata"),
        ("gemini_1", "Gemini 1"),
        ("claude_opus_1", "Claude Opus 1")
    ]

    var body: some View {
        VStack {
            Text("Temu Piano")
                .font(.title)
                .padding()
            
            VStack {
                Text("JSON Sequence")
                    .font(.headline)
                    .padding(.top)
                
                TextEditor(text: $jsonInput)
                    .frame(height: 120)
                    .border(Color.gray, width: 1)
                    .padding(.horizontal)
                    .onChange(of: jsonInput) {
                        audioManager.calculateDurationFromJSON(jsonInput)
                    }
                
                Picker("Select Sequence", selection: $selectedSequence) {
                    ForEach(availableSequences, id: \.0) { sequence in
                        Text(sequence.1).tag(sequence.0)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedSequence) {
                    loadSequenceToInput()
                }
                
                HStack {
                    ProgressView(value: audioManager.isPlaying ? audioManager.progress : 0.0)
                    Text("\(formatTime(audioManager.elapsedTime)) / \(formatTime(audioManager.totalDuration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button(action: {
                        audioManager.playSequenceFromJSON(jsonInput)
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Play Sequence")
                        }
                        .padding()
                        .background(audioManager.isPlaying ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(audioManager.isPlaying || jsonInput.isEmpty)
                    
                    Button(action: {
                        audioManager.stopSequence()
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(!audioManager.isPlaying)
                    
                    Button(action: {
                        testURLScheme()
                    }) {
                        HStack {
                            Image(systemName: "link")
                            Text("Test URL")
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
            .padding()

            PianoView()
                .padding()
        }
        .onAppear {
            loadSequenceToInput()
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
    
    private func testURLScheme() {
        let rawJSON = """
        {"version":1,"tempo":120,"instrument":"acoustic_grand_piano","events":[{"time":0,"pitches":[60],"duration":1,"velocity":100}]}
        """
        
        var components = URLComponents()
        components.scheme = "mcpplay"
        components.host = "play"
        components.queryItems = [URLQueryItem(name: "json", value: rawJSON)]
        
        if let url = components.url {
            // This should trigger the actual URL handling mechanism
            NSWorkspace.shared.open(url)
        }
    }
}
#Preview {
    MainView()
        .environmentObject(AudioManager())
}
