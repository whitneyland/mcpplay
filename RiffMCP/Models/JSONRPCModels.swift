//
//  JSONRPCModels.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/8/25.
//

import Foundation

// MARK: - JSON-RPC Models

struct JSONRPCRequest: Codable, Sendable {
    let jsonrpc: String
    let method: String
    let params: JSONValue?
    let id: JSONValue?
}

struct JSONRPCResponse: Codable, Sendable {
    let jsonrpc: String
    let result: JSONValue?
    let error: JSONRPCError?
    let id: JSONValue?

    init(result: JSONValue?, id: JSONValue?) {
        self.jsonrpc = "2.0"
        self.result = result
        self.error = nil
        self.id = id
    }

    init(error: JSONRPCError, id: JSONValue?) {
        self.jsonrpc = "2.0"
        self.result = nil
        self.error = error
        self.id = id
    }
}

struct JSONRPCError: Codable, Sendable, Error {
    let code: Int
    let message: String

    static let parseError = JSONRPCError(code: -32700, message: "Parse error")
    static let invalidRequest = JSONRPCError(code: -32600, message: "Invalid Request")
    static let methodNotFound = JSONRPCError(code: -32601, message: "Method not found")
    static let invalidParams = JSONRPCError(code: -32602, message: "Invalid params")
    static let internalError = JSONRPCError(code: -32603, message: "Internal error")

    static func serverError(_ message: String) -> JSONRPCError {
        return JSONRPCError(code: -32000, message: message)
    }
}

// MARK: - JSON Value Type

enum JSONValue: Codable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        do { self = .bool(try container.decode(Bool.self)); return } catch { }
        do { self = .int(try container.decode(Int.self)); return } catch { }
        do { self = .double(try container.decode(Double.self)); return } catch { }
        do { self = .string(try container.decode(String.self)); return } catch { }
        do { self = .array(try container.decode([JSONValue].self)); return } catch { }
        do {
            self = .object(try container.decode([String: JSONValue].self))
        } catch {
            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Value could not be decoded as any of the supported JSON primitives.", underlyingError: error))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }

    // Helper properties to access underlying values
    var stringValue: String? { if case .string(let v) = self { return v }; return nil }
    var intValue: Int? { if case .int(let v) = self { return v }; return nil }
    var doubleValue: Double? {
        if case .double(let v) = self { return v }
        if case .int(let v) = self { return Double(v) }
        return nil
    }
    var arrayValue: [JSONValue]? { if case .array(let v) = self { return v }; return nil }
    var objectValue: [String: JSONValue]? { if case .object(let v) = self { return v }; return nil }

    /// Converts the JSONValue enum back into a Data object for decoding into a specific type.
    func toData() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}
