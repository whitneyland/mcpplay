
//
//  MusicSequenceJSONSerializerTests.swift
//  RiffMCPTests
//
//  Created by Lee Whitney on 7/15/25.
//

import Testing
@testable import RiffMCP

@Suite("MusicSequenceJSONSerializer Tests")
struct MusicSequenceJSONSerializerTests {

    // MARK: - Test Data
    
    private let cleanJSON = """
    {
        "tempo": 120.0,
        "tracks": [
            {
                "instrument": "grand_piano",
                "events": [
                    { "time": 0, "pitches": ["C4"], "dur": 1, "vel": 100 }
                ]
            }
        ]
    }
    """
    
    private let dirtyJSON = """
    {
        // This is a test with lots of junk
        `tempo`: 120.0, // tempo here
        “tracks”: [
            {
                ‘instrument’: ‘grand_piano’,
                "events": [
                    { "time": 0, "pitches": ["C#", "Gb"], "dur": 0.5 }, // note C#4 and Gb4
                ] // trailing comma here
            },
        ]
    }
    """

    // MARK: - Decoding Tests

    @Test("Decode clean JSON successfully")
    func testDecodeCleanJSON() throws {
        let sequence = try MusicSequenceJSONSerializer.decode(cleanJSON)
        #expect(sequence.tempo == 120.0)
        #expect(sequence.tracks.count == 1)
        #expect(sequence.tracks[0].instrument == "grand_piano")
        #expect(sequence.tracks[0].events.count == 1)
        #expect(sequence.tracks[0].events[0].pitches.first?.midiValue == 60)
    }

    @Test("Decode dirty JSON with comments, smart quotes, and trailing commas")
    func testDecodeDirtyJSON() throws {
        let sequence = try MusicSequenceJSONSerializer.decode(dirtyJSON)
        #expect(sequence.tempo == 120.0)
        #expect(sequence.tracks.count == 1)
        #expect(sequence.tracks[0].instrument == "grand_piano")
        #expect(sequence.tracks[0].events.count == 1)
        
        let event = sequence.tracks[0].events[0]
        #expect(event.pitches.count == 2)
        // Check that default octave was added correctly
        #expect(event.pitches[0].midiValue == 61) // C#4
        #expect(event.pitches[1].midiValue == 66) // Gb4
    }
    
    @Test("Decoding throws error on fundamentally broken JSON")
    func testThrowsOnBrokenJSON() async throws {
        let brokenJSON = "{ \"tempo\": 120, \"tracks\": [ }"
        await #expect(throws: Error.self) {
            _ = try MusicSequenceJSONSerializer.decode(brokenJSON)
        }
    }

    // MARK: - Compaction Tests
    
    @Test("Compacts event objects correctly")
    func testCompactEventObjects() throws {
        let expandedJSON = """
        {
          "events": [
            {
              "dur": 1,
              "pitches": ["C4"],
              "time": 0
            },
            {
              "dur": 1,
              "pitches": ["E4"],
              "time": 1
            }
          ]
        }
        """
        
        let (compacted, replacements) = MusicSequenceJSONSerializer.compactEventObjects(expandedJSON)
        
        #expect(replacements == 1)
        #expect(compacted.contains("\"events\": [\n        { \"dur\": 1, \"pitches\": [\"C4\"], \"time\": 0 },\n        { \"dur\": 1, \"pitches\": [\"E4\"], \"time\": 1 }\n      ]"))
    }
    
    @Test("Handles empty event array during compaction")
    func testCompactEmptyEventArray() throws {
        let jsonWithEmptyEvents = "{\n  \"events\": []\n}"
        let (compacted, replacements) = MusicSequenceJSONSerializer.compactEventObjects(jsonWithEmptyEvents)
        
        #expect(replacements == 1)
        #expect(compacted.contains("\"events\": []"))
    }
}
