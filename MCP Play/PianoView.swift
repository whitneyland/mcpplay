//
//  PianoView.swift
//  MCP Play
//
//  Created by Lee Whitney on 6/7/25.
//

import SwiftUI

struct PianoView: View {
    @EnvironmentObject var audioManager: AudioManager

    private let whiteKeyWidth: CGFloat = 50
    private let blackKeyWidth: CGFloat = 30

    private let whiteKeys: [Int] = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83]
    private let blackKeys: [Int] = [61, 63, 66, 68, 70, 73, 75, 78, 80, 82]

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(whiteKeys, id: \.self) { note in
                    PianoKey(note: note, isBlack: false, audioManager: audioManager)
                }
            }

            ForEach(blackKeys, id: \.self) { note in
                PianoKey(note: note, isBlack: true, audioManager: audioManager)
                    .offset(x: blackKeyOffset(for: note))
            }
        }
        .frame(height: 180)
    }

    private func blackKeyOffset(for note: Int) -> CGFloat {
        let octaveStartNote = 60
        let octave = (note - octaveStartNote) / 12

        let octaveOffset = CGFloat(octave) * 7 * whiteKeyWidth

        let noteInOctave = note % 12
        let whiteKeysBefore: Int

        switch noteInOctave {
        case 1: whiteKeysBefore = 1
        case 3: whiteKeysBefore = 2
        case 6: whiteKeysBefore = 4
        case 8: whiteKeysBefore = 5
        case 10: whiteKeysBefore = 6
        default: whiteKeysBefore = 0
        }

        let gapPosition = CGFloat(whiteKeysBefore) * whiteKeyWidth

        return octaveOffset + gapPosition - (blackKeyWidth / 2)
    }
}

#if DEBUG
#Preview {
    PianoView()
        .environmentObject(AudioManager())
        .padding()
}
#endif