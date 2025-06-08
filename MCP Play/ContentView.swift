//
//  ContentView.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/7/25.
//

import SwiftUI

struct PianoKey: View {
    let note: Int
    let isBlack: Bool
    let audioManager: AudioManager
    @State private var isPressed = false

    private static let noteNames: [String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(isPressed ? (isBlack ? Color.gray : Color.gray.opacity(0.3)) : (isBlack ? Color.black : Color.white))
                .stroke(Color.gray, lineWidth: 1)

            Text(noteName(for: note))
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundColor(isBlack ? .white : .black)
                .padding(.bottom, isBlack ? 10 : 20)
        }
        .frame(width: isBlack ? 30 : 50, height: isBlack ? 120 : 180)
        .zIndex(isBlack ? 1 : 0)
        .onTapGesture {
            playNote()
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }

    private func noteName(for note: Int) -> String {
        let index = note % 12
        // Reference the static property on the PianoKey type.
        return PianoKey.noteNames[index]
    }

    private func playNote() {
        isPressed = true
        audioManager.playNote(midiNote: UInt8(note))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isPressed = false
            audioManager.stopNote(midiNote: UInt8(note))
        }
    }
}

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()

    // Using constants for key dimensions makes calculations clearer
    private let whiteKeyWidth: CGFloat = 50
    private let blackKeyWidth: CGFloat = 30

    let whiteKeys = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83]
    let blackKeys = [61, 63, 66, 68, 70, 73, 75, 78, 80, 82]

    var body: some View {
        VStack {
            Text("Temu Piano")
                .font(.title)
                .padding()

            ZStack(alignment: .topLeading) {
                // 1. Draw the White Keys (Unchanged)
                HStack(spacing: 0) {
                    ForEach(whiteKeys, id: \.self) { note in
                        PianoKey(note: note, isBlack: false, audioManager: audioManager)
                    }
                }

                // 2. Draw each Black Key individually at its correct offset
                ForEach(blackKeys, id: \.self) { note in
                    PianoKey(note: note, isBlack: true, audioManager: audioManager)
                        .offset(x: blackKeyOffset(for: note))
                }
            }
            .frame(height: 180) // Set a fixed height for the container
            .padding()
        }
    }

    /// Calculates the precise leading-edge offset for a black key.
    private func blackKeyOffset(for note: Int) -> CGFloat {
        // Find the starting C for the note's octave (60, 72, etc.)
        let octaveStartNote = 60
        let octave = (note - octaveStartNote) / 12

        // Calculate the base offset for the octave.
        // Each octave contains 7 white keys.
        let octaveOffset = CGFloat(octave) * 7 * whiteKeyWidth

        // Calculate the additional offset within the octave
        let noteInOctave = note % 12
        var whiteKeysBefore: Int

        switch noteInOctave {
            case 1: whiteKeysBefore = 1 // C# is after 1 white key (C)
            case 3: whiteKeysBefore = 2 // D# is after 2 white keys (C, D)
            case 6: whiteKeysBefore = 4 // F# is after 4 white keys (C, D, E, F)
            case 8: whiteKeysBefore = 5 // G# is after 5 white keys (C, D, E, F, G)
            case 10: whiteKeysBefore = 6 // A# is after 6 white keys (C, D, E, F, G, A)
            default: whiteKeysBefore = 0 // Should not happen for black keys
        }

        // The position of the gap is after the preceding white keys.
        let gapPosition = CGFloat(whiteKeysBefore) * whiteKeyWidth

        // The key's offset is the gap position minus half the key's own width to center it.
        let keyOffset = gapPosition - (blackKeyWidth / 2)

        return octaveOffset + keyOffset
    }
}
#Preview {
    ContentView()
}
