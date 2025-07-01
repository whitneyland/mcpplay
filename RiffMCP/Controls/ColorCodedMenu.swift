//
//  ColorCodedMenu.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/30/25.
//

import SwiftUI

struct Category: Identifiable {
    let id = UUID()
    let name: String
    let items: [String]
}

struct ColorCodedMenu: View {
    let categories: [Category]
    @Binding var selectedItem: String?
    let color: Color

    var body: some View {
        VStack(spacing: 20) {
            Menu {
                ForEach(categories) { category in
                    Button(category.name) {}              // header
                        .disabled(true)

                    ForEach(category.items, id: \.self) { item in
                        Button(item) { selectedItem = item }
                    }
                }
            } label: {
                Text(selectedItem ?? "Choose Item")

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
                        .fill(color)
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
    struct ColorCodedMenuDemo: View {
        @State private var selection1: String? = "Broccoli"
        @State private var selection2: String? = "Banana"
        @State private var selection3: String? = "Carrot"

        private let sample: [Category] = [
            .init(name: "Fruits",     items: ["Apple", "Banana", "Grape"]),
            .init(name: "Vegetables", items: ["Carrot", "Broccoli", "Spinach"])
        ]

        var body: some View {
            HStack {
                ColorCodedMenu(categories: sample, selectedItem: $selection1, color: .green)
                ColorCodedMenu(categories: sample, selectedItem: $selection2, color: .yellow)
                ColorCodedMenu(categories: sample, selectedItem: $selection3, color: .orange)
            }
        }
    }

    return ColorCodedMenuDemo()
}
