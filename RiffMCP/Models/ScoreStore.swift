//
//  ScoreStore.swift
//  RiffMCP
//
//  Thread-safe storage for musical sequences with score ID tracking
//  Created by Lee Whitney on 7/16/25.
//

import Foundation

// ScoreStore is a lightweight race-free cache that lets engrave look up whatever play just stored
// without changing the rest of out stateless HTTP plumbing.
//
// To use as a non-local server, we'd have to manage user sessions and create a fresh ScoreStore for each NWConnection;
// then pass it down the tool-call pipeline. 
actor ScoreStore {
    private var lastScoreID: String?
    private var scores: [String: MusicSequence] = [:]
    private let maxStoredScores = 100 // Prevent unbounded growth
    
    /// Store a sequence with a unique ID and mark it as the last score
    func put(_ id: String, _ sequence: MusicSequence) {
        scores[id] = sequence
        lastScoreID = id
        
        // Simple cleanup: remove oldest entries if we exceed max
        if scores.count > maxStoredScores {
            let oldestKeys = Array(scores.keys.prefix(scores.count - maxStoredScores))
            for key in oldestKeys {
                scores.removeValue(forKey: key)
            }
        }
    }
    
    /// Retrieve a sequence by ID, or the last sequence if ID is nil
    func get(_ id: String?) -> MusicSequence? {
        if let id = id {
            return scores[id]
        }
        return lastScoreID.flatMap { scores[$0] }
    }
    
    /// Get the last score ID for debugging/logging
    func getLastScoreID() -> String? {
        return lastScoreID
    }
    
    /// Clear all stored scores
    func clear() {
        scores.removeAll()
        lastScoreID = nil
    }
}
