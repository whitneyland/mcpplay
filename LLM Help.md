# RiffMCP JSON Sequence Format

## Overview
The RiffMCP app accepts musical sequences in JSON format. Each sequence defines a musical piece with timing, notes, and playback parameters.

## Root Structure
```json
{
  "title": "Sequence Title",
  "tempo": 120,
  "tracks": [
    {
      "instrument": "acoustic_grand_piano",
      "name": "Track Name",
      "events": [...]
    }
  ]
}
```

### Fields:
- **tempo** (number): Beats per minute (e.g., 60, 120, 140)
- **title** (string, optional): Title of the sequence
- **instrument** (string): Instrument name (see Available Instruments section below)
- **tracks** (array): Array of track objects, each with its own instrument and events

## Event Structure
Each event in the `events` array represents notes to play at a specific time:

```json
{
  "time": 0.0,
  "pitches": [60, 64, 67],
  "dur": 1.0,
  "vel": 100
}
```

### Fields:
- **time** (number): When to start playing (in beats from start)
- **pitches** (array): Notes to play simultaneously
- **dur** (number): How long to hold the notes (in beats)
- **vel** (integer, optional): Volume/intensity (1-127, defaults to 100)

## Pitch Formats
Pitches can be specified in two ways:

### 1. MIDI Numbers (0-127)
```json
"pitches": [60, 64, 67]
```
- Middle C = 60
- Each number is one semitone
- C4 = 60, C#4 = 61, D4 = 62, etc.

### 2. Note Names with Octaves
```json
"pitches": ["C4", "E4", "G4"]
```
- Format: `NoteName + Octave`
- Note names: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
- Alternative: DB, EB, GB, AB, BB for flats
- Octaves: 0-9 (C4 = Middle C)

## Complete Examples

### Simple Chord Progression
```json
{
  "tempo": 100,
  "instrument": "acoustic_grand_piano",
  "events": [
    { "time": 0.0, "pitches": [60, 64, 67], "dur": 1.0 },
    { "time": 1.0, "pitches": [65, 69, 72], "dur": 1.0 },
    { "time": 2.0, "pitches": [67, 71, 74], "dur": 1.0 }
  ]
}
```

### Melody with Bass
```json
{
  "tempo": 120,
  "instrument": "acoustic_grand_piano",
  "events": [
    { "time": 0.0, "pitches": ["C2"], "dur": 4.0, "vel": 60 },
    { "time": 0.0, "pitches": ["C4"], "dur": 0.5, "vel": 80 },
    { "time": 0.5, "pitches": ["D4"], "dur": 0.5, "vel": 80 },
    { "time": 1.0, "pitches": ["E4"], "dur": 1.0, "vel": 80 }
  ]
}
```

## Tips for LLM Generation

1. **Timing**: Events can overlap (for harmony) or be sequential (for melody)
2. **Chords**: Use same `time` value with multiple `pitches`
3. **Velocity**: Lower values (30-50) for soft/background, higher (80-120) for melody
4. **Duration**: Can be fractional (0.25, 0.5, 1.5, etc.)
5. **Common Patterns**:
   - Quarter note = 1.0 beat
   - Eighth note = 0.5 beat  
   - Half note = 2.0 beats
   - Whole note = 4.0 beats

## Available Instruments

Currently supported instruments are organized by category:

### Piano (8 instruments)
- acoustic_grand_piano, bright_acoustic_piano, electric_grand_piano, honky_tonk_piano
- electric_piano_1, electric_piano_2, harpsichord, clavinet

### Percussion (8 instruments)  
- celesta, glockenspiel, music_box, vibraphone, marimba, xylophone, tubular_bells, dulcimer

### Organ (8 instruments)
- drawbar_organ, percussive_organ, rock_organ, church_organ, reed_organ, accordion, harmonica, tango_accordion

### Guitar (8 instruments)
- acoustic_guitar_nylon, acoustic_guitar_steel, electric_guitar_jazz, electric_guitar_clean
- electric_guitar_muted, overdriven_guitar, distortion_guitar, guitar_harmonics

### Bass (8 instruments)
- acoustic_bass, electric_bass_finger, electric_bass_pick, fretless_bass
- slap_bass_1, slap_bass_2, synth_bass_1, synth_bass_2

### Strings (12 instruments)
- violin, viola, cello, contrabass, tremolo_strings, pizzicato_strings
- orchestral_harp, timpani, string_ensemble_1, string_ensemble_2, synth_strings_1, synth_strings_2

### Brass (8 instruments)
- trumpet, trombone, tuba, muted_trumpet, french_horn, brass_section, synth_brass_1, synth_brass_2

### Woodwinds (16 instruments)
- soprano_sax, alto_sax, tenor_sax, baritone_sax, oboe, english_horn, bassoon, clarinet
- piccolo, flute, recorder, pan_flute, blown_bottle, shakuhachi, whistle, ocarina

### Choir (4 instruments)
- choir_aahs, voice_oohs, synth_voice, orchestra_hit

**Total: 70 instruments available**

Use the exact instrument name (left side) in your track definitions. The complete list above shows all available options.

## MCP Server Tools

When using the MCP server, you have access to these tools:

### `play` 
- **Purpose**: Play a music sequence directly from JSON data
- **Parameters**: `sequence` (JSON object matching the format above)
- **Returns**: Confirmation of playback start
- **Usage**: Send complete musical sequences for immediate playback


## Validation Rules
- All required fields must be present
- `time` and `dur` must be non-negative numbers
- `vel` must be 1-127 if provided
- MIDI numbers must be 0-127
- Note names must follow the format exactly (case-insensitive)
- Instrument names must match exactly (see instrument list above for valid options)