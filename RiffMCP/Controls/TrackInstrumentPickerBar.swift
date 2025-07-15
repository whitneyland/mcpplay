//
//  TrackInstrumentPickerBar.swift
//  RiffMCP
//
//  Created by Lee Whitney on 7/15/25.
//

import SwiftUI

struct TrackInstrumentPickerBar: View {
    let sequence: MusicSequence?
    @Binding var selections: [String?]
    let onChange: (Int, String?) -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            ForEach(Array((sequence?.tracks ?? []).enumerated()), id: \.0) { index, track in
                TrackInstrument(
                    trackIndex: index,
                    track: track,
                    trackInstrumentSelections: $selections,
                    updateTrackInstrument: onChange
                )
            }
        }
    }
}