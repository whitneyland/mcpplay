Using the .json format below -

Create an original, impressive composition in this format. Total of 30 seconds or more in duration. Really show me what you can do.




---
## Instructions

Use this JSON format for your music compositions:

### Root Object
- `title` (optional): Descriptive name for your piece
- `tempo` (required): BPM (beats per minute)
- `tracks` (required): Array of track objects

### Track Object
- `instrument` (optional): Choose from 70+ available instruments (defaults to "acoustic_grand_piano")
- `events` (required): Array of musical events

### Event Object
- `time` (required): When to play in beats from start (0.0 = beginning)
- `pitches` (required): Array of notes - use note names like "C4", "F#3" or MIDI numbers like 60
- `dur` (required): Length in beats (1.0 = quarter note at current tempo)
- `vel` (optional): Volume 0-127 (defaults to 100)

### Available Instruments
**Piano**: acoustic_grand_piano, bright_acoustic_piano, electric_grand_piano, honky_tonk_piano, electric_piano_1, electric_piano_2, harpsichord, clavinet

**Strings**: violin, viola, cello, contrabass, tremolo_strings, pizzicato_strings, orchestral_harp, string_ensemble_1, string_ensemble_2

**Brass**: trumpet, trombone, tuba, muted_trumpet, french_horn, brass_section

**Woodwinds**: flute, clarinet, oboe, bassoon, piccolo, recorder, soprano_sax, alto_sax, tenor_sax, baritone_sax

**Guitar**: acoustic_guitar_nylon, acoustic_guitar_steel, electric_guitar_jazz, electric_guitar_clean, electric_guitar_muted, overdriven_guitar, distortion_guitar

**Bass**: acoustic_bass, electric_bass_finger, electric_bass_pick, fretless_bass, slap_bass_1, slap_bass_2

**Other**: celesta, glockenspiel, music_box, vibraphone, marimba, xylophone, tubular_bells, drawbar_organ, church_organ, accordion, harmonica, choir_aahs, voice_oohs

### Key Points
- Time values are in **beats**, not seconds
- Multiple notes at the same time = chord (multiple pitches in same event)
- Multiple tracks = different instruments playing simultaneously
- Note names use octave numbers (C4 = middle C, C5 = octave above)
- MIDI numbers: 60 = C4, 61 = C#4, 72 = C5

**Important**: Do NOT wrap your response in tool call format. Provide only the raw JSON as shown in the example above.

## Example Song

```json
{
  "tempo": 110,
  "title": "Ethereal Journey",
  "tracks": [
    {
      "name": "Piano Melody",
      "events": [
        {"time": 0.0, "pitches": ["A4"], "dur": 1.0, "vel": 90},
        {"time": 1.0, "pitches": ["C5"], "dur": 0.5, "vel": 85},
        {"time": 1.5, "pitches": ["E5"], "dur": 0.5, "vel": 80},
        {"time": 2.0, "pitches": ["G5"], "dur": 1.5, "vel": 95},
        {"time": 3.5, "pitches": ["F5"], "dur": 0.5, "vel": 85},
        {"time": 4.0, "pitches": ["F5"], "dur": 1.0, "vel": 90},
        {"time": 5.0, "pitches": ["A4"], "dur": 0.5, "vel": 85},
        {"time": 5.5, "pitches": ["C5"], "dur": 0.5, "vel": 80},
        {"time": 6.0, "pitches": ["F5"], "dur": 2.0, "vel": 95},
        {"time": 8.0, "pitches": ["E5"], "dur": 1.0, "vel": 90},
        {"time": 9.0, "pitches": ["G5"], "dur": 0.5, "vel": 85},
        {"time": 9.5, "pitches": ["C6"], "dur": 0.5, "vel": 90},
        {"time": 10.0, "pitches": ["B5"], "dur": 1.5, "vel": 100},
        {"time": 11.5, "pitches": ["A5"], "dur": 0.5, "vel": 85},
        {"time": 12.0, "pitches": ["G5"], "dur": 1.0, "vel": 90},
        {"time": 13.0, "pitches": ["F5"], "dur": 0.5, "vel": 85},
        {"time": 13.5, "pitches": ["D5"], "dur": 0.5, "vel": 80},
        {"time": 14.0, "pitches": ["B4"], "dur": 1.0, "vel": 85},
        {"time": 15.0, "pitches": ["A4"], "dur": 1.0, "vel": 90}
      ],
      "instrument": "acoustic_grand_piano"
    },
    {
      "name": "String Harmony",
      "events": [
        {"time": 0.0, "pitches": ["A3", "C4", "E4"], "dur": 4.0, "vel": 65},
        {"time": 4.0, "pitches": ["F3", "A3", "C4"], "dur": 4.0, "vel": 65},
        {"time": 8.0, "pitches": ["C3", "E3", "G3"], "dur": 4.0, "vel": 70},
        {"time": 12.0, "pitches": ["G3", "B3", "D4"], "dur": 4.0, "vel": 65}
      ],
      "instrument": "string_ensemble_1"
    },
    {
      "name": "Bass Foundation",
      "events": [
        {"time": 0.0, "pitches": ["A2"], "dur": 1.0, "vel": 80},
        {"time": 2.0, "pitches": ["A2"], "dur": 1.0, "vel": 75},
        {"time": 4.0, "pitches": ["F2"], "dur": 1.0, "vel": 80},
        {"time": 6.0, "pitches": ["F2"], "dur": 1.0, "vel": 75},
        {"time": 8.0, "pitches": ["C2"], "dur": 1.0, "vel": 85},
        {"time": 10.0, "pitches": ["C2"], "dur": 1.0, "vel": 80},
        {"time": 12.0, "pitches": ["G2"], "dur": 1.0, "vel": 80},
        {"time": 14.0, "pitches": ["G2"], "dur": 1.0, "vel": 75}
      ],
      "instrument": "electric_bass_finger"
    },
    {
      "name": "Choir Atmosphere",
      "events": [
        {"time": 2.0, "pitches": ["E4", "A4"], "dur": 6.0, "vel": 50},
        {"time": 10.0, "pitches": ["G4", "C5"], "dur": 6.0, "vel": 55}
      ],
      "instrument": "choir_aahs"
    },
    {
      "name": "Timpani Accents",
      "events": [
        {"time": 0.0, "pitches": ["A2"], "dur": 0.5, "vel": 90},
        {"time": 4.0, "pitches": ["F2"], "dur": 0.5, "vel": 85},
        {"time": 8.0, "pitches": ["C3"], "dur": 0.5, "vel": 95},
        {"time": 12.0, "pitches": ["G2"], "dur": 0.5, "vel": 90}
      ],
      "instrument": "timpani"
    },
    {
      "name": "Violin Countermelody",
      "events": [
        {"time": 4.5, "pitches": ["C5"], "dur": 0.5, "vel": 70},
        {"time": 5.0, "pitches": ["D5"], "dur": 0.5, "vel": 75},
        {"time": 5.5, "pitches": ["E5"], "dur": 0.5, "vel": 70},
        {"time": 6.0, "pitches": ["F5"], "dur": 1.0, "vel": 80},
        {"time": 8.5, "pitches": ["E5"], "dur": 0.5, "vel": 70},
        {"time": 9.0, "pitches": ["F5"], "dur": 0.5, "vel": 75},
        {"time": 9.5, "pitches": ["G5"], "dur": 0.5, "vel": 80},
        {"time": 10.0, "pitches": ["A5"], "dur": 1.5, "vel": 85},
        {"time": 12.5, "pitches": ["F5"], "dur": 0.5, "vel": 70},
        {"time": 13.0, "pitches": ["D5"], "dur": 0.5, "vel": 75},
        {"time": 13.5, "pitches": ["B4"], "dur": 0.5, "vel": 70},
        {"time": 14.0, "pitches": ["G4"], "dur": 2.0, "vel": 80}
      ],
      "instrument": "violin"
    }
  ]
}
```