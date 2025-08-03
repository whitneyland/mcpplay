//
//  ConnectionState.swift
//  RiffMCP
//
//  Created by Lee Whitney on 8/3/25.
//

import Foundation

// MARK: - HTTP Connection State Management

class ConnectionState: @unchecked Sendable {
    enum ParsingState: Equatable {
        case readingHeaders
        case readingBody(expectedLength: Int)
        case complete
    }

    var buffer = Data()
    var state: ParsingState = .readingHeaders
    var headersEndIndex: Data.Index?
    var lastRequestContentLength: Int = 0

    func appendData(_ data: Data) {
        buffer.append(data)
    }

    func tryParseHeaders() -> [String: String]? {
        guard state == .readingHeaders else { return nil }

        // Look for end of headers marker
        let headerTerminator = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n
        guard let terminatorRange = buffer.range(of: headerTerminator) else {
            return nil // Headers not complete yet
        }

        headersEndIndex = terminatorRange.upperBound

        // Parse headers
        let headerData = buffer.prefix(upTo: terminatorRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            return nil
        }

        var headers: [String: String] = [:]
        let lines = headerString.components(separatedBy: "\r\n")

        for line in lines.dropFirst() { // Skip request line
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        return headers
    }

    func hasCompleteBody(expectedLength: Int) -> Bool {
        guard let headersEndIndex = headersEndIndex else { return false }
        let bodyData = buffer.suffix(from: headersEndIndex)
        return bodyData.count >= expectedLength
    }

    func extractCompleteRequest() -> (requestLine: String, headers: [String: String], body: String)? {
        guard let headersEndIndex = headersEndIndex else { return nil }

        let headerData = buffer.prefix(upTo: headersEndIndex.advanced(by: -4)) // Exclude \r\n\r\n
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        let bodyData = buffer.suffix(from: headersEndIndex)
        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyString = String(data: bodyData.prefix(contentLength), encoding: .utf8) ?? ""

        return (requestLine: requestLine, headers: headers, body: bodyString)
    }

    func consumeProcessedRequest() {
        guard let headersEndIndex = headersEndIndex else { return }

        // Calculate total request size (headers + body)
        // Use the saved content length instead of re-parsing headers
        let contentLength = self.lastRequestContentLength
        let headerLength = buffer.distance(from: buffer.startIndex, to: headersEndIndex)
        let totalRequestSize = headerLength + contentLength

        // Remove processed request from buffer
        if totalRequestSize <= buffer.count {
            buffer.removeFirst(totalRequestSize)
        } else {
            // If we don't have enough data, remove what we have
            buffer.removeAll()
        }

        // Reset state for next request
        state = .readingHeaders
        self.headersEndIndex = nil
        self.lastRequestContentLength = 0
    }
}
