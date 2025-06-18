//
//  PianoRoll.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/18/25.
//

import SwiftUI

struct PianoRoll: View {
    let sequence: MusicSequence?
    let currentTime: Double
    let totalDuration: Double
    
    private let noteHeight: CGFloat = 8
    private let minHeight: CGFloat = 200
    
    var body: some View {
        GeometryReader { geometry in
            if let sequence = sequence {
                let noteRange = calculateNoteRange(sequence: sequence)
                let totalRows = noteRange.max - noteRange.min + 1
                let rollHeight = max(minHeight, CGFloat(totalRows) * noteHeight)
                
                ZStack(alignment: .topLeading) {
                    // Background
                    Rectangle()
                        .fill(Color(NSColor.controlBackgroundColor))
                    
                    // Grid lines
                    gridLines(geometry: geometry, sequence: sequence, noteRange: noteRange, rollHeight: rollHeight)
                    
                    // Note blocks
                    noteBlocks(geometry: geometry, sequence: sequence, noteRange: noteRange, rollHeight: rollHeight)
                    
                    // Playback cursor
                    if totalDuration > 0 {
                        let cursorX = (currentTime / totalDuration) * geometry.size.width
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2)
                            .offset(x: cursorX)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        Text("No sequence loaded")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(height: sequence != nil ? max(minHeight, CGFloat(calculateNoteRange(sequence: sequence!).max - calculateNoteRange(sequence: sequence!).min + 1) * noteHeight) : minHeight)
        .border(Color.gray, width: 1)
    }
    
    private func gridLines(geometry: GeometryProxy, sequence: MusicSequence, noteRange: (min: Int, max: Int), rollHeight: CGFloat) -> some View {
        ZStack {
            // Horizontal pitch lines
            ForEach(noteRange.min...noteRange.max, id: \.self) { midiNote in
                let y = CGFloat(noteRange.max - midiNote) * noteHeight
                let isSharp = isSharpNote(midiNote)
                Rectangle()
                    .fill(isSharp ? Color.gray.opacity(0.3) : Color.gray.opacity(0.1))
                    .frame(height: 1)
                    .offset(y: y)
            }
            
            // Vertical beat lines
            let beatsPerMeasure = 4
            let beatDuration = 60.0 / sequence.tempo
            let totalBeats = Int(ceil(totalDuration / beatDuration))
            
            ForEach(0...totalBeats, id: \.self) { beat in
                let x = (Double(beat) * beatDuration / totalDuration) * geometry.size.width
                let isMeasureLine = beat % beatsPerMeasure == 0
                Rectangle()
                    .fill(isMeasureLine ? Color.gray.opacity(0.6) : Color.gray.opacity(0.3))
                    .frame(width: isMeasureLine ? 2 : 1)
                    .offset(x: x)
            }
        }
    }
    
    private func noteBlocks(geometry: GeometryProxy, sequence: MusicSequence, noteRange: (min: Int, max: Int), rollHeight: CGFloat) -> some View {
        let noteRects = generateNoteRects(sequence: sequence, geometry: geometry, noteRange: noteRange)
        
        return ZStack(alignment: .topLeading) {
            ForEach(Array(noteRects.enumerated()), id: \.offset) { index, noteRect in
                Rectangle()
                    .fill(noteRect.color.opacity(noteRect.alpha))
                    .frame(width: noteRect.width, height: noteRect.height)
                    .offset(x: noteRect.x, y: noteRect.y)
            }
        }
    }
    
    private struct NoteRect {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let color: Color
        let alpha: Double
    }
    
    private func generateNoteRects(sequence: MusicSequence, geometry: GeometryProxy, noteRange: (min: Int, max: Int)) -> [NoteRect] {
        var noteRects: [NoteRect] = []
        
        for (trackIndex, track) in sequence.tracks.enumerated() {
            let trackColor = getTrackColor(trackIndex: trackIndex)
            
            for event in track.events {
                for pitch in event.pitches {
                    let midiNote = pitch.midiValue
                    if midiNote >= noteRange.min && midiNote <= noteRange.max {
                        let beatDuration = 60.0 / sequence.tempo
                        let startTime = event.time * beatDuration
                        let duration = event.duration * beatDuration
                        
                        let x = (startTime / totalDuration) * geometry.size.width
                        let width = max(2, (duration / totalDuration) * geometry.size.width)
                        let y = CGFloat(noteRange.max - midiNote) * noteHeight
                        
                        let velocity = event.velocity ?? 100
                        let alpha = Double(velocity) / 127.0 * 0.8 + 0.2
                        
                        noteRects.append(NoteRect(
                            x: x,
                            y: y,
                            width: width,
                            height: noteHeight - 1,
                            color: trackColor,
                            alpha: alpha
                        ))
                    }
                }
            }
        }
        
        return noteRects
    }
    
    private func calculateNoteRange(sequence: MusicSequence) -> (min: Int, max: Int) {
        var minNote = 127
        var maxNote = 0
        
        for track in sequence.tracks {
            for event in track.events {
                for pitch in event.pitches {
                    let midiNote = pitch.midiValue
                    minNote = min(minNote, midiNote)
                    maxNote = max(maxNote, midiNote)
                }
            }
        }
        
        // Add some padding
        minNote = max(0, minNote - 2)
        maxNote = min(127, maxNote + 2)
        
        return (min: minNote, max: maxNote)
    }
    
    private func isSharpNote(_ midiNote: Int) -> Bool {
        let noteInOctave = midiNote % 12
        return [1, 3, 6, 8, 10].contains(noteInOctave) // C#, D#, F#, G#, A#
    }
    
    private func getTrackColor(trackIndex: Int) -> Color {
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .red, .yellow, .pink, .cyan
        ]
        return colors[trackIndex % colors.count]
    }
}

#Preview {
    let sampleSequence = MusicSequence(
        version: 1,
        title: "Sample",
        tempo: 120,
        tracks: [
            Track(instrument: "acoustic_grand_piano", name: nil, events: [
                SequenceEvent(time: 0.0, pitches: [Pitch.int(60)], duration: 1.0, velocity: 100),
                SequenceEvent(time: 1.0, pitches: [Pitch.int(64)], duration: 1.0, velocity: 80),
                SequenceEvent(time: 2.0, pitches: [Pitch.int(67)], duration: 1.0, velocity: 90)
            ])
        ]
    )
    
    PianoRoll(sequence: sampleSequence, currentTime: 1.5, totalDuration: 4.0)
        .frame(height: 300)
}