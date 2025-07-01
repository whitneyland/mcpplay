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

    var direction: Edge = .bottom
    var menuWidth: CGFloat = 220

    // MARK: State
    @State private var isPresented = false

    var body: some View {
        HStack {
            Text(selectedItem ?? "Choose Item")
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .frame(height: 30)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .overlay(alignment: .bottomLeading) {
            if selectedItem != nil {
                Rectangle()
                    .fill(color)
                    .frame(height: 2)
                    .offset(y: -4)
                    .padding(.leading, 10)
                    .padding(.trailing, 24)
            }
        }
        .onTapGesture {
            isPresented.toggle()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .popover(isPresented: $isPresented, arrowEdge: direction) {
            menuContent
        }
    }

    // The content of the popover menu
    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(categories) { category in
                // Header (more semantic than a disabled button)
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 5)

                ForEach(category.items, id: \.self) { item in
                    Button {
                        selectedItem = item
                        isPresented = false // Dismiss popover on selection
                    } label: {
                        HStack {
                            Text(item)
                                .foregroundColor(.primary)
                            Spacer()
                            // Add a checkmark for the selected item
                            if selectedItem == item {
                                Image(systemName: "checkmark")
                                    .fontWeight(.bold)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle()) // Make the whole row tappable
                    }
                    .buttonStyle(.plain)
                    .background(selectedItem == item ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(5)
                }

                // Add a divider unless it's the last category
                if category.id != categories.last?.id {
                    Divider().padding(.top, 8)
                }
            }
        }
        .padding(.vertical, 5)
        .frame(width: menuWidth)
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
            VStack {
                Spacer() // Push the content to the bottom
                HStack(spacing: 20) {
                    ColorCodedMenu(
                        categories: sample,
                        selectedItem: $selection1,
                        color: .green,
                        direction: .top     // Opens up
                    )

                    ColorCodedMenu(
                        categories: sample,
                        selectedItem: $selection2,
                        color: .yellow,
                        direction: .bottom  // Opens down
                    )

                    ColorCodedMenu(
                        categories: sample,
                        selectedItem: $selection3,
                        color: .orange,
                        direction: .top     // Opens up
                    )
                }
                .padding()
            }
            .frame(width: 600, height: 400)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
    return ColorCodedMenuDemo()
}
