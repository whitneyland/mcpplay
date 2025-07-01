//
//  ColorCodedMenu.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/30/25.
//

import SwiftUI

struct ColorCodedMenu: View {
    @State private var selectedItem: String? = "Electric Grand Piano"

    let groupedItems: [String: [String]] = [
        "Fruits": ["Electric Grand Piano", "Banana"],
        "Vegetables": ["Carrot", "Broccoli"],
        "Grains": ["Rice", "Wheat"]
    ]

    var body: some View {
        VStack(spacing: 20) {
            Menu {
                ForEach(groupedItems.sorted(by: { $0.key < $1.key }), id: \.key) { category, items in
                    Button(category) {}              // header
                        .disabled(true)

                    ForEach(items, id: \.self) { item in
                        Button(item) { selectedItem = item }
                    }
                }
            } label: {
                Text(selectedItem ?? "Instrument")

            }
            .padding(.leading, 4)
            .padding(.trailing, 2)
            .padding(.bottom, 4)
            .frame(height: 30)
            .background(Color.white.opacity(0.1))
            .menuStyle(.borderlessButton)      // keeps macOS from adding its own bezel
            .cornerRadius(8)
            .overlay(alignment: .bottomLeading) {
                if selectedItem != nil {
                    Rectangle()
                        .fill(.green)
                        .frame(height: 2)
                        .offset(y: -5)
                        .padding(.leading, 6)
                        .padding(.trailing, 24)
                }
            }
        }
        .padding()
    }
}

#Preview {
    HStack {
        ColorCodedMenu()
        ColorCodedMenu()
        ColorCodedMenu()
    }
}
