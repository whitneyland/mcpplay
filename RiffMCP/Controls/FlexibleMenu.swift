//
//  FlexibleMenu.swift
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

struct FlexibleMenu: View {
    let categories: [Category]
    @Binding var selectedItem: String?
    let color: Color?

    var direction: Edge = .bottom
    var menuWidth: CGFloat = 220
    var menuMaxHeight: CGFloat = 500

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
            if selectedItem != nil, let color = color {
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(categories) { category in
                        Text(category.name)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 10)
                            .padding(.bottom, 5)

                        ForEach(category.items, id: \.self) { item in
                            Button {
                                selectedItem = item
                                isPresented = false
                            } label: {
                                HStack {
                                    Text(item)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedItem == item {
                                        Image(systemName: "checkmark")
                                            .fontWeight(.bold)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(selectedItem == item ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(5)
                            // Assign a unique, scrollable ID to each button.
                            .id(item)
                        }

                        if category.id != categories.last?.id {
                            Divider().padding(.top, 8)
                        }
                    }
                }
                .padding(.vertical, 5)
                .frame(width: menuWidth)
                // When the content appears, scroll to the selected item if it exists.
                .onAppear {
                    // We only want to scroll if there is a selection.
                    guard let currentSelection = selectedItem else { return }

                    // Use the proxy to scroll to the view with the matching ID.
                    // The anchor parameter positions the item in the visible area.
                    // .center is usually a good choice.
                    withAnimation {
                        proxy.scrollTo(currentSelection, anchor: .center)
                    }
                }
            }
            .frame(maxHeight: menuMaxHeight)
        }
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

        // A longer list to demonstrate scrolling capability.
        private let longSample: [Category] = [
            .init(name: "Fruits", items: ["Apple", "Apricot", "Avocado", "Banana", "Blackberry", "Blueberry", "Cherry", "Cranberry", "Date", "Dragonfruit", "Elderberry"]),
            .init(name: "Vegetables", items: ["Artichoke", "Asparagus", "Beetroot", "Broccoli", "Cabbage", "Carrot", "Cauliflower", "Celery", "Corn", "Cucumber"]),
            .init(name: "Grains", items: ["Barley", "Buckwheat", "Millet", "Oats", "Quinoa", "Rice", "Rye", "Sorghum", "Spelt", "Wheat"])
        ]

        var body: some View {
            VStack(spacing: 40) {
                HStack(spacing: 20) {
                    // this menu will scroll because content is long
                    FlexibleMenu(
                        categories: longSample,
                        selectedItem: $selection1,
                        color: .green,
                        direction: .top
                    )

                    FlexibleMenu(
                        categories: longSample,
                        selectedItem: $selection2,
                        color: .yellow,
                        direction: .bottom
                    )

                    FlexibleMenu(
                        categories: longSample,
                        selectedItem: $selection3,
                        color: .orange,
                        direction: .top
                    )

                    FlexibleMenu(
                       categories: sample, // Using the short list
                       selectedItem: .constant("Apple"),
                       color: nil, // No color bar
                       direction: .bottom
                   )
                }
            }
            .padding()
            .frame(width: 700, height: 500)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
    return ColorCodedMenuDemo()
}
