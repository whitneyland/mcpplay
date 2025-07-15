//
//  JSONToMEIConverterTests.swift
//  RiffMCPTests
//
//  Created by Lee Whitney on 7/15/25.
//

import Testing
@testable import RiffMCP

@Suite("JSONToMEIConverter Tests")
struct JSONToMEIConverterTests {

    // MARK: - Helper to run conversion and catch errors
    
    private func convertJSON(_ jsonString: String) throws -> String {
        let jsonData = jsonString.data(using: .utf8)!
        return try JSONToMEIConverter.convert(from: jsonData)
    }

    // MARK: - Pitch Validation Tests

    @Test("Converter throws error for malformed pitch name (no octave)")
    func testMalformedPitchNoOctave() async throws {
        let json = """
        {
            "tempo": 120,
            "tracks": [{
                "instrument": "grand_piano",
                "events": [{"time": 0, "pitches": ["C#"], "dur": 1}]
            }]
        }
        """
        await #expect(throws: JSONToMEIConverter.ConversionError.self) {
            _ = try self.convertJSON(json)
        }
    }

    @Test("Converter throws error for invalid pitch name")
    func testInvalidPitchName() async throws {
        let json = """
        {
            "tempo": 120,
            "tracks": [{
                "instrument": "grand_piano",
                "events": [{"time": 0, "pitches": ["X4"], "dur": 1}]
            }]
        }
        """
        await #expect(throws: JSONToMEIConverter.ConversionError.self) {
            _ = try self.convertJSON(json)
        }
    }
    
    @Test("Converter throws error for pitch name with invalid characters")
    func testInvalidPitchCharacters() async throws {
        let json = """
        {
            "tempo": 120,
            "tracks": [{
                "instrument": "grand_piano",
                "events": [{"time": 0, "pitches": ["C##4"], "dur": 1}]
            }]
        }
        """
        await #expect(throws: JSONToMEIConverter.ConversionError.self) {
            _ = try self.convertJSON(json)
        }
    }

    // MARK: - Duration Validation Tests

    @Test("Converter handles zero duration gracefully")
    func testZeroDuration() async throws {
        let json = """
        {
            "tempo": 120,
            "tracks": [{
                "instrument": "grand_piano",
                "events": [{"time": 0, "pitches": ["C4"], "dur": 0}]
            }]
        }
        """
        // It should convert but log a warning and use a default duration.
        // We can't check the log here, but we can ensure it doesn't crash.
        let mei = try convertJSON(json)
        #expect(mei.contains("dur=\"4\""))
    }

    @Test("Converter handles negative duration gracefully")
    func testNegativeDuration() async throws {
        let json = """
        {
            "tempo": 120,
            "tracks": [{
                "instrument": "grand_piano",
                "events": [{"time": 0, "pitches": ["C4"], "dur": -1.0}]
            }]
        }
        """
        // It should also convert but use a default duration.
        let mei = try convertJSON(json)
        #expect(mei.contains("dur=\"4\""))
    }

    @Test("Converter handles non-standard duration outside snap tolerance")
    func testNonStandardDuration() async throws {
        let json = """
        {
            "tempo": 120,
            "tracks": [{
                "instrument": "grand_piano",
                "events": [{"time": 0, "pitches": ["C4"], "dur": 0.9}]
            }]
        }
        """
        // A duration of 0.9 is not a standard power-of-two or dotted value.
        // The nearest is 1.0 (quarter note). The relative error is |1.0 - 0.9| / 0.9 = 0.11,
        // which is within the 0.25 tolerance, so it should snap to a quarter note.
        var mei = try convertJSON(json)
        #expect(mei.contains("dur=\"4\""))
        
        let jsonFar = """
        {
            "tempo": 120,
            "tracks": [{
                "instrument": "grand_piano",
                "events": [{"time": 0, "pitches": ["C4"], "dur": 0.7}]
            }]
        }
        """
        // A duration of 0.7 is far from 0.5 (error > 0.25) and 1.0 (error > 0.25).
        // It should use a default duration and add a staccato mark as a warning.
        mei = try convertJSON(jsonFar)
        #expect(mei.contains("dur=\"4\""))
        #expect(mei.contains("artic=\"stacc\""))
    }
    
    // MARK: - General Structure Tests
    
    @Test("Converter throws error for malformed JSON")
    func testMalformedJSON() async throws {
        let json = """
        {
            "tempo": 120,
            "tracks": [{
                "instrument": "grand_piano",
                "events": [{"time": 0, "pitches": ["C4"], "dur": 1}]
            } // Missing comma
            {
                "instrument": "violin",
                "events": []
            }]
        }
        """
        await #expect(throws: JSONToMEIConverter.ConversionError.self) {
            _ = try self.convertJSON(json)
        }
    }
}