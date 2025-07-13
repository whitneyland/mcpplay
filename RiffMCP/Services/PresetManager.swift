//
//  PresetManager.swift
//  RiffMCP
//
//  Dynamic preset loader from examples folder
//

import Foundation

struct Preset {
    let fileName: String
    let displayName: String
    let content: String
}

class PresetManager: ObservableObject {
    @Published var presets: [Preset] = []
    
    init() {
        loadPresets()
    }
    
    private func loadPresets() {
        // Get all JSON files from the examples subdirectory
        let exampleJSONs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Examples") ?? []
        
        for fileURL in exampleJSONs {
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                let displayName = extractTitleFromJSON(content) ?? fileName.replacingOccurrences(of: "_", with: " ").capitalized
                let preset = Preset(fileName: fileName, displayName: displayName, content: content)
                presets.append(preset)
            }
        }
        
        presets.sort { $0.fileName < $1.fileName }
    }
    
    private func extractTitleFromJSON(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = jsonObject["title"] as? String else {
            return nil
        }
        return title
    }
    
    func getPreset(by id: String) -> Preset? {
        return presets.first { $0.fileName == id }
    }
}
