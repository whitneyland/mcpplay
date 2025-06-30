//
//  Extensions.swift
//  RiffMCP
//
//  Created by Lee Whitney on 6/14/25.
//

import Foundation
import SwiftUI

extension Data {
    func append(to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: url)
        }
    }
}

// A debug-only counter that lives (and mutates) on the main thread.
@MainActor
enum ViewDebugCounter {
    static var count = 0
}

extension View {
    @MainActor                       // also main-thread-only
    func printCount<T>(_ value: @autoclosure () -> T) -> some View {
        ViewDebugCounter.count += 1
        print("\(value()), count: \(ViewDebugCounter.count)")
        return self                  // still returns the original view
    }
}

@MainActor
enum Debug {
    static func printCount<T>(_ value: @autoclosure () -> T) {
        ViewDebugCounter.count += 1
        print("\(value()), count: \(ViewDebugCounter.count)")
    }
}
