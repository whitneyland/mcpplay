//
//  PianoKey.swift
//  RiffMCP
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