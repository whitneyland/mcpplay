Generate an original, impressive composition in this format.  Total of 30 seconds or less in duration.  Really show me what you can do.


MCP Play JSON Sequence Format

Overview

The MCP Play app accepts musical sequences in JSON format. Each sequence defines a musical piece with
timing, notes, and playback parameters.

Root Structure

{
"version": 1,
"tempo": 120,
"instrument": "acoustic_grand_piano",
"events": [...]
}

Fields:

version (integer): Format version, currently always 1
tempo (number): Beats per minute (e.g., 60, 120, 140)
instrument (string): Instrument name (currently only "acoustic_grand_piano" is supported)
events (array): Array of musical events to play
Event Structure

Each event in the events array represents notes to play at a specific time:

{
"time": 0.0,
"pitches": [60, 64, 67],
"duration": 1.0,
"velocity": 100
}

Fields:

time (number): When to start playing (in beats from start)
pitches (array): Notes to play simultaneously
duration (number): How long to hold the notes (in beats)
velocity (integer, optional): Volume/intensity (1-127, defaults to 100)
Pitch Formats

Pitches can be specified in two ways:

MIDI Numbers (0-127)
"pitches": [60, 64, 67]

Middle C = 60
Each number is one semitone
C4 = 60, C#4 = 61, D4 = 62, etc.
Note Names with Octaves
"pitches": ["C4", "E4", "G4"]

Format: NoteName + Octave
Note names: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
Alternative: DB, EB, GB, AB, BB for flats
Octaves: 0-9 (C4 = Middle C)
Complete Examples

Simple Chord Progression

{
"version": 1,
"tempo": 100,
"instrument": "acoustic_grand_piano",
"events": [
{ "time": 0.0, "pitches": [60, 64, 67], "duration": 1.0 },
{ "time": 1.0, "pitches": [65, 69, 72], "duration": 1.0 },
{ "time": 2.0, "pitches": [67, 71, 74], "duration": 1.0 }
]
}

Melody with Bass

{
"version": 1,
"tempo": 120,
"instrument": "acoustic_grand_piano",
"events": [
{ "time": 0.0, "pitches": ["C2"], "duration": 4.0, "velocity": 60 },
{ "time": 0.0, "pitches": ["C4"], "duration": 0.5, "velocity": 80 },
{ "time": 0.5, "pitches": ["D4"], "duration": 0.5, "velocity": 80 },
{ "time": 1.0, "pitches": ["E4"], "duration": 1.0, "velocity": 80 }
]
}

Tips for LLM Generation

Timing: Events can overlap (for harmony) or be sequential (for melody)
Chords: Use same time value with multiple pitches
Velocity: Lower values (30-50) for soft/background, higher (80-120) for melody
Duration: Can be fractional (0.25, 0.5, 1.5, etc.)
Common Patterns:
- Quarter note = 1.0 beat
- Eighth note = 0.5 beat
- Half note = 2.0 beats
- Whole note = 4.0 beats
Validation Rules

All required fields must be present
time and duration must be non-negative numbers
velocity must be 1-127 if provided
MIDI numbers must be 0-127
Note names must follow the format exactly (case-insensitive)