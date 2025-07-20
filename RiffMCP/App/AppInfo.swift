//
//  AppInfo.swift
//  RiffMCP
//
//  Created by Lee Whitney on 7/18/25.
//
import Foundation

enum AppInfo {
    static let name: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
    static let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    static let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    static let bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.whitneyland.riffmcp"
    static var fullVersion: String { "\(version) (\(build))" }
}
