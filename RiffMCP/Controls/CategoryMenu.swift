//
//  CategoryMenu.swift
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

struct CategoryMenu: View {
    let categories: [Category]
    @Binding var selectedItem: String?
    @State private var isExpanded = false
    private let cornerRadius: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            menuButton
            if isExpanded { dropdown }
        }
        .animation(.easeInOut, value: isExpanded)
    }

    private var menuButton: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack {
                Text(selectedItem ?? "Choose Item")
                    .foregroundStyle(selectedItem == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.separator))
        }
        .accessibilityLabel("Category menu")
        .accessibilityValue(selectedItem ?? "No item selected")
    }

    private var dropdown: some View {
        ScrollView {                    // prevents overflow
            VStack(spacing: 0) {
                ForEach(categories) { cat in
                    Text(cat.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    ForEach(cat.items, id: \.self) { item in
                        Button {
                            selectedItem = item
                            isExpanded = false
                        } label: {
                            Text(item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                    }
                }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.separator))
            .shadow(radius: 4)
        }
        .frame(maxHeight: 250)          // tweak as needed
        .transition(.opacity)
    }
}

#Preview {
    struct CategoryMenuDemo: View {
        @State private var selection: String? = nil

        private let sample: [Category] = [
            .init(name: "Fruits",     items: ["Apple", "Banana", "Grape"]),
            .init(name: "Vegetables", items: ["Carrot", "Broccoli", "Spinach"])
        ]

        var body: some View {
            VStack(spacing: 20) {
                Text("Selected: \(selection ?? "None")")
                CategoryMenu(categories: sample, selectedItem: $selection)
            }
            .padding()
        }
    }

    return CategoryMenuDemo()
}
