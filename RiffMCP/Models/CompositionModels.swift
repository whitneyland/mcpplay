//
//  CompositionModels.swift
//  RiffMCP
//
//  Created by Lee Whitney on 7/15/25.
//

import Foundation

/// Models for music composition data that can be decoded from JSON for MEI conversion
public struct MEIComposition: Decodable {
    let title: String?
    let tempo: Double
    let tracks: [MEITrack]
}

public struct MEITrack: Decodable {
    let instrument: String?
    let events: [MEIEvent]
}

public struct MEIEvent: Decodable {
    let time: Double
    let pitches: [PitchValue]
    let dur: Double
    let vel: Int?
}

public enum PitchValue: Decodable {
    case name(String)
    case midi(Int)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let n = try? container.decode(Int.self) { 
            self = .midi(n) 
        } else { 
            self = .name(try container.decode(String.self)) 
        }
    }
}