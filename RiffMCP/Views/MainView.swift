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
    @State private var currentSequence: MusicSequence?
    @State private var notationSVG: String?
    @State private var trackInstrumentSelections: [String?] = []

    var body: some View {
        HSplitView {
            VSplitView {
                HSplitView {
                    VStack(spacing: 12) {
                        TextEditor(text: $jsonInput)
                            .border(Color.gray, width: 1)
                            .frame(minHeight: 100)

                        HStack {
                            TransportBar(
                                isPlaying: audioManager.isPlaying,
                                jsonInput: $jsonInput,
                                elapsedTime: audioManager.elapsedTime,
                                totalDuration: audioManager.totalDuration,
                                onPlayStop: {
                                    if audioManager.isPlaying {
                                        audioManager.stopSequence()
                                    } else {
                                        audioManager.playSequenceFromJSON(jsonInput)
                                    }
                                }
                            )
                            Spacer()

                            PresetPicker(
                                presets: presetManager.presets,
                                selectedPresetId: $selectedPresetId,
                                onPresetSelected: loadPresetToInput
                            )
                        }
                    }
                    .frame(idealWidth: 200, maxWidth: 600)
                    .padding(12)

                    ServerActivityView()
                        .frame(minWidth: 100, idealWidth: 700)
                }
                .frame(minHeight: 300, idealHeight: 400)

                VStack {
                    PianoRollView(
                        sequence: currentSequence,
                        elapsedTime: audioManager.elapsedTime,
                        duration: audioManager.totalDuration
                    )
                    
                    TrackInstrumentPickerBar(
                        sequence: currentSequence,
                        selections: $trackInstrumentSelections,
                        onChange: updateTrackInstrument
                    )
                }
                .frame(maxWidth: .infinity, idealHeight: 500, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
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
    }
    
    private func loadPresetToInput() {
        guard let preset = presetManager.getPreset(by: selectedPresetId) else {
            Log.app.error("Could not find preset with id: \(selectedPresetId, privacy: .public)")
            return
        }
        jsonInput = preset.content
    }
    
    private func updateCurrentSequence() {
        guard !jsonInput.isEmpty else {
            currentSequence = nil
            notationSVG = nil
            return
        }
        do {
            currentSequence = try MusicSequenceJSONSerializer.decode(jsonInput)
            ensureTrackSelectionsCount()
            updateNotationImage()
        } catch {
            currentSequence = nil
            notationSVG = nil
        }
    }
    
    private func updateNotationImage() {
        guard let currentSequence = currentSequence else {
            Log.app.info("No current sequence available, using fallback notation")
            let svg = Verovio.svgFromSimpleTestXml()
            notationSVG = svg
            return
        }
        
        do {
            // Convert current sequence to JSON
            let sequenceData = try JSONEncoder().encode(currentSequence)

            // Convert JSON to MEI XML
            let meiXML = try JSONToMEIConverter.convert(from: sequenceData)

            // Generate SVG from MEI
            let svg = Verovio.svg(from: meiXML)
            notationSVG = svg
        } catch {
            Log.app.error("Error converting sequence to notation: \(error.localizedDescription, privacy: .public)")
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
            jsonInput = try MusicSequenceJSONSerializer.prettyPrint(updatedSequence)
        } catch {
            Log.app.error("Error encoding updated sequence: \(error.localizedDescription, privacy: .public)")
        }
        
        // Update local state
        ensureTrackSelectionsCount()
        if trackIndex < trackInstrumentSelections.count {
            trackInstrumentSelections[trackIndex] = newInstrument
        }
    }
    
    func ensureTrackSelectionsCount() {
        let trackCount = currentSequence?.tracks.count ?? 0
        if trackInstrumentSelections.count != trackCount {
            trackInstrumentSelections = Array(0..<trackCount).map { index in
                currentSequence?.tracks[index].instrument
            }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AudioManager())
}
