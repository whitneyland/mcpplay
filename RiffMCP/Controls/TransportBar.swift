//
//  TransportBar.swift
//  RiffMCP
//
//  Created by Lee Whitney on 7/15/25.
//

import SwiftUI

struct TransportBar: View {
    let isPlaying: Bool
    @Binding var jsonInput: String
    let elapsedTime: Double
    let totalDuration: Double
    let onPlayStop: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onPlayStop) {
                HStack {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    Text(isPlaying ? "Stop" : "Play")
                }
                .frame(width: 80, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.15))
                )

                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .frame(width: 80, height: 30)
            .buttonStyle(.plain)
            .disabled(jsonInput.isEmpty)

            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 200, height: 30)
                    .cornerRadius(6)
                Text("\(elapsedTime.asTimeString) / \(totalDuration.asTimeString)")
                    .font(.body.monospaced())
            }
        }
    }
}

extension Double {
    var asTimeString: String {
        guard isFinite && self >= 0 else {
            return "0:00.0"
        }
        let minutes = Int(self) / 60
        let remainingSeconds = self.truncatingRemainder(dividingBy: 60.0)
        return String(format: "%d:%04.1f", minutes, remainingSeconds)
    }
}

#Preview {
    TransportBar(
        isPlaying: false,
        jsonInput: .constant("test"),
        elapsedTime: 45.5,
        totalDuration: 120.0,
        onPlayStop: {}
    )
}
