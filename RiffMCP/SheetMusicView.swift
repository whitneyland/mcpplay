//
//  SheetMusicView.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/29/25.
//

import SwiftUI

struct SheetMusicView: View {
    let notationSVG: String?
    
    var body: some View {
        VStack {
            if let notationSVG = notationSVG {
                SVGImageView(svgString: notationSVG)
                    .border(Color.gray.opacity(0.3), width: 1)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        Text("No notation")
                            .foregroundColor(.secondary)
                    )
                    .border(Color.gray.opacity(0.3), width: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SheetMusicView(notationSVG: nil)
        .frame(width: 400, height: 300)
}