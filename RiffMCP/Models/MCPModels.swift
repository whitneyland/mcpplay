//
//  MCPModels.swift
//  RiffMCP
//

import Foundation

// MARK: - MCP Models

enum MCPContentItem: Codable, Sendable {
    case text(String)
    case image(data: String, mimeType: String)
    case resource(uri: String, name: String, mimeType: String, description: String?)

    enum CodingKeys: String, CodingKey {
        case type, text, data, mimeType, uri, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "image":
            let data = try container.decode(String.self, forKey: .data)
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            self = .image(data: data, mimeType: mimeType)
        case "resource":
            let uri = try container.decode(String.self, forKey: .uri)
            let name = try container.decode(String.self, forKey: .name)
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            let description = try container.decodeIfPresent(String.self, forKey: .text)
            self = .resource(uri: uri, name: name, mimeType: mimeType, description: description)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported content type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let textContent):
            try container.encode("text", forKey: .type)
            try container.encode(textContent, forKey: .text)
        case .image(let data, let mimeType):
            try container.encode("image", forKey: .type)
            try container.encode(data, forKey: .data)
            try container.encode(mimeType, forKey: .mimeType)
        case .resource(let uri, let name, let mime, let desc):
            try container.encode("resource",  forKey: .type)
            try container.encode(uri,         forKey: .uri)
            try container.encode(name,        forKey: .name)
            try container.encode(mime,        forKey: .mimeType)
            if let d = desc { try container.encode(d, forKey: .text) }
        }
    }
}

struct MCPResult: Codable, Sendable { 
    let content: [MCPContentItem] 
}

struct MCPTool: Codable, Sendable {
    let name: String
    let description: String
    let inputSchema: [String: JSONValue]

    init?(from dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String,
              let description = dictionary["description"] as? String,
              let inputSchema = dictionary["inputSchema"] as? [String: Any] else {
            return nil
        }
        self.name = name
        self.description = description

        do {
            let schemaData = try JSONSerialization.data(withJSONObject: inputSchema)
            let jsonValue = try JSONDecoder().decode(JSONValue.self, from: schemaData)
            self.inputSchema = jsonValue.objectValue ?? [:]
        } catch {
            Log.server.error("❌ Failed to parse inputSchema for tool \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

struct MCPToolsResult: Codable, Sendable { 
    let tools: [MCPTool] 
}

struct MCPPromptArgument: Codable, Sendable {
    let name: String
    let description: String
    let required: Bool

    init?(from dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String,
              let description = dictionary["description"] as? String else {
            return nil
        }
        self.name = name
        self.description = description
        self.required = dictionary["required"] as? Bool ?? false
    }
}

struct MCPPrompt: Codable, Sendable {
    let name: String
    let description: String
    let arguments: [MCPPromptArgument]?

    init?(from dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String,
              let description = dictionary["description"] as? String else {
            return nil
        }
        self.name = name
        self.description = description

        if let argsArray = dictionary["arguments"] as? [[String: Any]] {
            self.arguments = argsArray.compactMap { MCPPromptArgument(from: $0) }
        } else {
            self.arguments = nil
        }
    }
}

struct MCPPromptsResult: Codable, Sendable { 
    let prompts: [MCPPrompt] 
}

struct MCPCapabilities: Codable, Sendable {
    let tools: [String: JSONValue]
    let prompts: [String: JSONValue]?
    let resources: [String: JSONValue]?

    init(tools: [String: JSONValue], prompts: [String: JSONValue]? = nil, resources: [String: JSONValue]? = nil) {
        self.tools = tools
        self.prompts = prompts
        self.resources = resources
    }
}

struct MCPServerInfo: Codable, Sendable { 
    let name: String
    let version: String 
}

struct MCPInitializeResult: Codable, Sendable { 
    let protocolVersion: String
    let capabilities: MCPCapabilities
    let serverInfo: MCPServerInfo 
}