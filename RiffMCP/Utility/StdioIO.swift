//
//  StdioIO.swift
//  RiffMCP
//
//  A tiny, reusable helper for JSON-RPC over stdio.
//  Handles Content-Length framing and EOF detection.
//
import Foundation
import Darwin   // for fd-based reads

enum StdioIO {
    // MARK: Header / body constants
    private static let crlfTerminator = Data([0x0D,0x0A,0x0D,0x0A]) // \r\n\r\n
    private static let lfTerminator   = Data([0x0A,0x0A])           //  \n\n
    private static let newline = Data([0x0A]) // \n
    private static let chunk      = 4096                           // 4 kB

    // Thread-local storage for buffered data
    private nonisolated(unsafe) static var bufferedData: Data?
    
    enum ProtocolFormat {
        case contentLength  // Legacy LSP-style with Content-Length headers
        case newlineDelimited  // New MCP format with newline-delimited JSON
    }

    private static func headerTerminatorRange(in data: Data) -> Range<Data.Index>? {
        data.range(of: crlfTerminator) ?? data.range(of: lfTerminator)
    }

    // MARK: Reading (FileHandle) – used by StdioServer
    /// Returns `(length, format)` for the next message, or `nil` on clean EOF.
    static func readHeader(from handle: FileHandle) throws -> (length: Int, format: ProtocolFormat)? {
        var buf = Data()
        
        while true {
            // `availableData` blocks until ≥1 byte or EOF, regardless of O_NONBLOCK
            let chunk = handle.availableData

            if chunk.isEmpty {               // true EOF (write-end closed)
                if buf.isEmpty { return nil } // clean EOF before any data
                throw StdioError.unexpectedEndOfStream // mid-message EOF
            }

            buf.append(chunk)

            // --- framing detection as before ---
            let format = detectFormat(in: buf)

            switch format {
            case .contentLength:
                if let termRange = headerTerminatorRange(in: buf) {
                    let headerEnd  = termRange.upperBound
                    let headerData = buf.prefix(upTo: headerEnd)
                    bufferedData   = buf.count > headerEnd ? buf.suffix(from: headerEnd) : nil
                    return (try parseContentLength(in: headerData), .contentLength)
                }

            case .newlineDelimited:
                if let nlRange = buf.range(of: newline) {
                    let jsonData = buf.prefix(upTo: nlRange.lowerBound)
                    bufferedData = buf.count > nlRange.upperBound ? buf.suffix(from: nlRange.upperBound) : nil
                    // store full line so `readBody` can return it directly
                    bufferedData = jsonData
                    return (jsonData.count, .newlineDelimited)
                }
            }
        }
    }
    
    private static func detectFormat(in buffer: Data) -> ProtocolFormat {
        // Convert to string to check the beginning
        guard let text = String(data: buffer.prefix(50), encoding: .utf8) else {
            return .contentLength // Default to legacy format if we can't decode
        }
        
        // If it starts with "Content-Length:", it's the legacy format
        if text.hasPrefix("Content-Length:") {
            return .contentLength
        }
        
        // If it starts with "{", it's likely newline-delimited JSON
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
            return .newlineDelimited
        }
        
        // Default to legacy format for backwards compatibility
        return .contentLength
    }

    static func readBody(from handle: FileHandle, length: Int) throws -> Data {
        // For newline-delimited format, the JSON data is already in bufferedData
        if let buffered = bufferedData {
            bufferedData = nil // Clear it after use
            
            // If the buffered data is exactly the expected length, it's newline-delimited JSON
            if buffered.count == length {
                return buffered
            }
            
            // Otherwise, it's Content-Length format - use buffered data and read more if needed
            var body = Data()
            let useBytes = min(buffered.count, length)
            body.append(buffered.prefix(useBytes))
            
            if buffered.count > useBytes {
                // Store remaining buffered data
                bufferedData = Data(buffered.suffix(from: useBytes))
            }
            
            // Read additional data if needed for Content-Length format
            while body.count < length {
                let need = min(chunk, length - body.count)
                if let part = try handle.read(upToCount: need), !part.isEmpty {
                    body.append(part)
                } else {
                    throw StdioError.unexpectedEndOfStream
                }
            }
            
            return body
        }
        
        // No buffered data - read from handle (Content-Length format)
        var body = Data()
        while body.count < length {
            let need = min(chunk, length - body.count)
            if let part = try handle.read(upToCount: need), !part.isEmpty {
                body.append(part)
            } else {
                throw StdioError.unexpectedEndOfStream
            }
        }
        
        return body
    }

    // MARK: Reading (fd) – used by StdioProxy
    static func readHeader(fd: Int32) throws -> Int? {
        var buf = Data()
        while headerTerminatorRange(in: buf) == nil {
            guard let part = try readChunk(fd: fd) else { return nil }
            buf.append(part)
        }
        return try parseContentLength(in: buf)
    }

    static func readBody(fd: Int32, length: Int) throws -> Data {
        var body = Data()
        while body.count < length {
            let need = min(chunk, length - body.count)
            guard let part = try readChunk(fd: fd, max: need) else {
                throw ProxyError.unexpectedEndOfStream
            }
            body.append(part)
        }
        return body
    }

    // MARK: Writing (shared)
    /// Writes one JSON-RPC message using the chosen framing.
    static func write(_ data: Data,
                      to handle: FileHandle,
                      using format: ProtocolFormat) throws {
        switch format {
        case .newlineDelimited:
            try handle.write(contentsOf: data)
            try handle.write(contentsOf: Data([0x0A]))        // '\n'
        case .contentLength:
            let hdr = "Content-Length: \(data.count)\r\n\r\n"
            guard let hdrData = hdr.data(using: .ascii) else {
                throw StdioError.responseEncodingError
            }
            try handle.write(contentsOf: hdrData)
            try handle.write(contentsOf: data)
        }
    }

    // Legacy write method for backward compatibility
    static func write(_ data: Data, to handle: FileHandle) throws {
        try write(data, to: handle, using: .contentLength)
    }

    // MARK: Helpers
    @inline(__always)
    private static func readChunk(fd: Int32, max: Int = chunk) throws -> Data? {
        var buf = [UInt8](repeating: 0, count: max)
        let n = Darwin.read(fd, &buf, max)
        if n == 0 { return nil }
        if n == -1 { throw ProxyError.stdinReadError(String(cString: strerror(errno))) }
        return Data(bytes: buf, count: n)
    }

    private static func parseContentLength(in header: Data) throws -> Int {
        guard let str = String(data: header, encoding: .ascii) else {
            throw StdioError.invalidHeader("ASCII decode failed")
        }
        for line in str.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 && parts[0].lowercased() == "content-length",
               let n = Int(parts[1]) { return n }
        }
        throw StdioError.invalidHeader("Content-Length not found")
    }
}

enum StdioError: Error, LocalizedError {
    case invalidHeader(String)
    case unexpectedEndOfStream
    case incompleteMessage
    case responseEncodingError

    var errorDescription: String? {
        switch self {
        case .invalidHeader(let reason): return "Invalid Stdio Header: \(reason)"
        case .unexpectedEndOfStream: return "Unexpected end of input stream."
        case .incompleteMessage: return "Incomplete message received."
        case .responseEncodingError: return "Failed to encode response for writing."
        }
    }
}
