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
    private static let terminator = Data([0x0D, 0x0A, 0x0D, 0x0A]) // \r\n\r\n
    private static let chunk      = 4096                           // 4 kB

    // MARK: Reading (FileHandle) – used by StdioServer
    static func readHeader(from handle: FileHandle) throws -> Int? {
        var buf = Data()
        while buf.count < terminator.count ||
              !buf.suffix(terminator.count).elementsEqual(terminator) {

            if let chunk = try handle.read(upToCount: Self.chunk), !chunk.isEmpty {
                buf.append(chunk)
            } else {
                // This handles nil (error/closed) and empty data (EOF)
                if buf.isEmpty { return nil } // Clean EOF before anything was read
                throw StdioError.unexpectedEndOfStream // EOF mid-header
            }
        }
        return try parseContentLength(in: buf)
    }

    static func readBody(from handle: FileHandle, length: Int) throws -> Data {
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
        while buf.count < terminator.count ||
              !buf.suffix(terminator.count).elementsEqual(terminator) {

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
    static func write(_ data: Data, to handle: FileHandle) throws {
        let header = "Content-Length: \(data.count)\r\n\r\n"
        guard let headerData = header.data(using: .ascii) else {     // HTTP specs are defined on an ASCII not utf8
            throw StdioError.responseEncodingError
        }
        try handle.write(contentsOf: headerData)
        try handle.write(contentsOf: data)
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
        for line in str.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 && parts[0].lowercased() == "content-length",
               let n = Int(parts[1]) { return n }
        }
        throw StdioError.invalidHeader("Content-Length not found")
    }
}
