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
    @State private var trackInstrumentSelections: [String?] = []

    var body: some View {
        HSplitView {
            // Left side: VSplit with JSON/Activity on top, Piano Roll on bottom
            VSplitView {
                // Top section: JSON Editor and Server Activity
                HSplitView {
                    // Left: JSON Editor and controls
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

                    // Right: Server Activity View
                    ServerActivityView()
                        .frame(minWidth: 300, idealWidth: 700)
                }
                .frame(minHeight: 300, idealHeight: 400)

                // Bottom section: Piano Roll and Instrument list
                VStack {
                    PianoRollView(
                        sequence: currentSequence,
                        elapsedTime: animatedElapsedTime,
                        duration: audioManager.totalDuration
                    )
                    HStack {
                        ForEach(Array((currentSequence?.tracks ?? []).enumerated()), id: \.0) { index, track in
                            TrackInstrumentRow(
                                trackIndex: index,
                                track: track,
                                trackInstrumentSelections: $trackInstrumentSelections,
                                updateTrackInstrument: updateTrackInstrument
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, idealHeight: 500, maxHeight: .infinity)
                .padding(.horizontal, 12)

            }
            .frame(minWidth: 400, idealWidth: 1200, minHeight: 200)

            SheetMusicView(notationSVG: notationSVG)
                .frame(minWidth: 200, idealWidth: 400)
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
            currentSequence = try SequenceJSON.decode(jsonInput)
            ensureTrackSelectionsCount()
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
    
    private func updateTrackInstrument(trackIndex: Int, newInstrument: String?) {
        guard let newInstrument = newInstrument,
              let sequence = currentSequence,
              trackIndex < sequence.tracks.count else { return }
        
        // Update the track instrument
        var updatedTracks = sequence.tracks
        let updatedTrack = Track(
            instrument: newInstrument,
            name: updatedTracks[trackIndex].name,
            events: updatedTracks[trackIndex].events
        )
        updatedTracks[trackIndex] = updatedTrack
        
        // Create updated sequence
        let updatedSequence = MusicSequence(
            title: sequence.title,
            tempo: sequence.tempo,
            tracks: updatedTracks
        )

        // Encode back to JSON and update the input
        do {
            jsonInput = try SequenceJSON.prettyPrint(updatedSequence)
        } catch {
            print("Error encoding updated sequence: \(error)")
        }        
        
        // Update local state
        ensureTrackSelectionsCount()
        if trackIndex < trackInstrumentSelections.count {
            trackInstrumentSelections[trackIndex] = newInstrument
        }
    }
    
    private func ensureTrackSelectionsCount() {
        let trackCount = currentSequence?.tracks.count ?? 0
        if trackInstrumentSelections.count != trackCount {
            trackInstrumentSelections = Array(0..<trackCount).map { index in
                currentSequence?.tracks[index].instrument
            }
        }
    }
}

struct TrackInstrumentRow: View {
    let trackIndex: Int
    let track: Track
    @Binding var trackInstrumentSelections: [String?]
    let updateTrackInstrument: (Int, String?) -> Void
    
    private var currentInstrument: String {
        trackIndex < trackInstrumentSelections.count ? (trackInstrumentSelections[trackIndex] ?? track.instrument) : track.instrument
    }
    
    private var displayName: String {
        Instruments.getDisplayName(for: currentInstrument)
    }
    
    var body: some View {
        Rectangle()
            .fill(PianoRollView.getTrackColor(trackIndex: trackIndex))
            .frame(width: 30, height: 12)
        CategoryMenu(
            categories: Instruments.getInstrumentCategories(),
            selectedItem: Binding(
                get: { displayName },
                set: { newDisplayName in
                    guard let newDisplayName = newDisplayName,
                          let instrumentName = Instruments.getInstrumentName(from: newDisplayName) else { return }
                    updateTrackInstrument(trackIndex, instrumentName)
                }
            )
        )
        .frame(width: 180)
    }
}

#Preview {
    MainView()
        .environmentObject(AudioManager())
}
