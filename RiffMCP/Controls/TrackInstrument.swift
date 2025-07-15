//
//  TrackInstrument.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/7/25.
//

import SwiftUI

struct TrackInstrument: View {
    let trackIndex: Int
    let track: Track
    @Binding var trackInstrumentSelections: [String?]
    let updateTrackInstrument: (Int, String?) -> Void
    
    private var currentInstrument: String {
        trackIndex < trackInstrumentSelections.count ? (trackInstrumentSelections[trackIndex] ?? track.instrument) : track.instrument
    }

    var body: some View {
        FlexibleMenu(
            categories: Instruments.getInstrumentCategories(),
            selectedItem: Binding(
                get: { Instruments.getDisplayName(for: currentInstrument) },
                set: { newDisplayName in
                    guard let newDisplayName = newDisplayName,
                          let instrumentName = Instruments.getInstrumentName(from: newDisplayName) else { return }
                    updateTrackInstrument(trackIndex, instrumentName)
                }
            ),
            color: PianoRollView.getTrackColor(trackIndex: trackIndex),
            direction: .top
        )
        .frame(width: 190)
    }
}