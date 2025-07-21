//
//  MEIModels.swift
//  RiffMCP
//
//  Created by Lee Whitney on 7/15/25.
//

import Foundation

/// Internal processing models used during MEI conversion

public struct ClefInfo { 
    let shape: String
    let line: Int 
    
    public static func clefFromString(_ clefName: String) -> ClefInfo {
        switch clefName {
        case "treble": return ClefInfo(shape: "G", line: 2)
        case "bass":   return ClefInfo(shape: "F", line: 4)
        case "alto":   return ClefInfo(shape: "C", line: 3)
        case "tenor":  return ClefInfo(shape: "C", line: 4)
        default:       return ClefInfo(shape: "G", line: 2) // default to treble
        }
    }
}

public class ProcessedTrack {
    let originalTrackIndex: Int
    let staffIndex: Int
    let instrumentName: String
    let label: String
    let midiProgram: Int
    let clef: ClefInfo
    
    public init(originalTrackIndex: Int, staffIndex: Int,
                instrumentName: String, label: String,
                midiProgram: Int, clef: ClefInfo) {
        self.originalTrackIndex = originalTrackIndex
        self.staffIndex = staffIndex
        self.instrumentName = instrumentName
        self.label = label
        self.midiProgram = midiProgram
        self.clef = clef
    }
}

public struct ProcessedEvent {
    let event: MEIEvent
    let staffIndex: Int
}
