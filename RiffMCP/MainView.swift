//
//  MainView.swift
//  RiffMCP
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
    @State private var currentSequence: MusicSequence?
    @State private var notationSVG: String?

    var body: some View {
        VSplitView {
            // Top section now split horizontally
            HSplitView {
                // Left side: JSON Editor and controls
                VStack {
                    TextEditor(text: $jsonInput)
                        .border(Color.gray, width: 1)
                        .padding(.bottom, 5)
                        .frame(minHeight: 100)

                    if !presetManager.presets.isEmpty {
                        Picker("Examples", selection: $selectedPresetId) {
                            ForEach(presetManager.presets, id: \.fileName) { preset in
                                Text(preset.displayName).tag(preset.fileName)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: selectedPresetId) {
                            loadPresetToInput()
                        }
                    } else {
                        Text("No presets available")
                            .foregroundColor(.secondary)
                    }
                    HStack {
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
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .background(Color.gray30)
                        .cornerRadius(6)
                        .disabled(jsonInput.isEmpty)
                        
                        Spacer()
                        
                        Text("\(Util.formatTime(audioManager.elapsedTime)) / \(Util.formatTime(audioManager.totalDuration))")
                            .font(.body.monospaced())
                            .foregroundColor(.secondary)
                    }
                    .padding(.top,5)
                }
                .padding()

                // Right side: Server Activity View
                ServerActivityView()
                    .frame(minWidth: 300) // Give it a reasonable minimum width
            }

            // Bottom section with Piano Roll and Sheet music
            HSplitView {
                PianoRollView(
                    sequence: currentSequence,
                    elapsedTime: animatedElapsedTime,
                    duration: audioManager.totalDuration
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)

                SheetMusicView(notationSVG: notationSVG)
            }
            .frame(minHeight: 50)
        }
        .onAppear {
            if !presetManager.presets.isEmpty && selectedPresetId.isEmpty {
                selectedPresetId = presetManager.presets.first?.fileName ?? ""
                loadPresetToInput()
            }
        }
        .onReceive(audioManager.$receivedJSON) { newJSON in
            if !newJSON.isEmpty {
                jsonInput = newJSON
                updateCurrentSequence()
            }
        }
        .onChange(of: jsonInput) {
            audioManager.calculateDurationFromJSON(jsonInput)
            updateCurrentSequence()
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
    }
    
    private func loadPresetToInput() {
        guard let preset = presetManager.getPreset(by: selectedPresetId) else {
            print("Could not find preset with id: \(selectedPresetId)")
            return
        }
        
        jsonInput = preset.content
        audioManager.calculateDurationFromJSON(preset.content)
    }
    
    private func updateCurrentSequence() {
        guard !jsonInput.isEmpty else {
            currentSequence = nil
            notationSVG = nil
            return
        }
        
        do {
            let cleanedJSON = Util.cleanJSON(from: jsonInput)
            guard let data = cleanedJSON.data(using: .utf8) else { return }
            currentSequence = try JSONDecoder().decode(MusicSequence.self, from: data)
            
            updateNotationImage()
        } catch {
            currentSequence = nil
            notationSVG = nil
        }
    }
    
    private func updateNotationImage() {
        guard let currentSequence = currentSequence else {
            print("No current sequence available, using fallback notation")
            let svg = Verovio.svgFromSimpleTestXml()
            notationSVG = svg
            return
        }
        
        print("Updating notation for sequence with \(currentSequence.tracks.count) tracks")
        
        do {
            // Convert current sequence to JSON
            let sequenceData = try JSONEncoder().encode(currentSequence)
            print("Encoded sequence data: \(sequenceData.count) bytes")
            
            // Convert JSON to MEI XML
            let meiXML = try MEIConverter.convert(from: sequenceData)
            print("Generated MEI XML: \(meiXML.count) characters")
            
            // Generate SVG from MEI
            let svg = Verovio.svgFromMEI(meiXML)
            notationSVG = svg
            print("Generated SVG notation successfully")
        } catch {
            print("Error converting sequence to notation: \(error)")
            // Fall back to simple test notation
            let svg = Verovio.svgFromSimpleTestXml()
            notationSVG = svg
        }
    }    
}
#Preview {
    MainView()
        .environmentObject(AudioManager())
}
