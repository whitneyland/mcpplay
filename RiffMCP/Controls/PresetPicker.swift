//
//  PresetPicker.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/7/25.
//

import SwiftUI

struct PresetPicker: View {
    let presets: [Preset]
    @Binding var selectedPresetId: String
    let onPresetSelected: () -> Void
    
    var body: some View {
        if !presets.isEmpty {
            FlexibleMenu(
                categories: [Category(name: "Presets", items: presets.map { $0.displayName })],
                selectedItem: Binding(
                    get: {
                        guard let selectedPreset = presets.first(where: { $0.fileName == selectedPresetId }) else { return nil }
                        return selectedPreset.displayName
                    },
                    set: { newDisplayName in
                        guard let newDisplayName = newDisplayName,
                              let preset = presets.first(where: { $0.displayName == newDisplayName }) else { return }
                        selectedPresetId = preset.fileName
                        onPresetSelected()
                    }
                ),
                color: nil
            )
        } else {
            Text("No presets available")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PresetPicker(
        presets: [
            Preset(fileName: "test1", displayName: "Test Preset 1", content: "{}"),
            Preset(fileName: "test2", displayName: "Test Preset 2", content: "{}")
        ],
        selectedPresetId: .constant("test1"),
        onPresetSelected: {}
    )
}