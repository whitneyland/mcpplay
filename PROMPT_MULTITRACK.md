Using the .json format below -

Compose a multi-track music sequence. 

-------------------

## JSON Instructions

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
- `duration` (required): Length in beats (1.0 = quarter note at current tempo)
- `velocity` (optional): Volume 0-127 (defaults to 100)

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


## Example Song

```json
{
  "tempo": 110,
  "title": "Ethereal Journey",
  "tracks": [
    {
      "name": "Piano Melody",
      "events": [
        {"time": 0.0, "pitches": ["A4"], "duration": 1.0, "velocity": 90},
        {"time": 1.0, "pitches": ["C5"], "duration": 0.5, "velocity": 85},
        {"time": 1.5, "pitches": ["E5"], "duration": 0.5, "velocity": 80},
        {"time": 2.0, "pitches": ["G5"], "duration": 1.5, "velocity": 95},
        {"time": 3.5, "pitches": ["F5"], "duration": 0.5, "velocity": 85},
        {"time": 4.0, "pitches": ["F5"], "duration": 1.0, "velocity": 90},
        {"time": 5.0, "pitches": ["A4"], "duration": 0.5, "velocity": 85},
        {"time": 5.5, "pitches": ["C5"], "duration": 0.5, "velocity": 80},
        {"time": 6.0, "pitches": ["F5"], "duration": 2.0, "velocity": 95},
        {"time": 8.0, "pitches": ["E5"], "duration": 1.0, "velocity": 90},
        {"time": 9.0, "pitches": ["G5"], "duration": 0.5, "velocity": 85},
        {"time": 9.5, "pitches": ["C6"], "duration": 0.5, "velocity": 90},
        {"time": 10.0, "pitches": ["B5"], "duration": 1.5, "velocity": 100},
        {"time": 11.5, "pitches": ["A5"], "duration": 0.5, "velocity": 85},
        {"time": 12.0, "pitches": ["G5"], "duration": 1.0, "velocity": 90},
        {"time": 13.0, "pitches": ["F5"], "duration": 0.5, "velocity": 85},
        {"time": 13.5, "pitches": ["D5"], "duration": 0.5, "velocity": 80},
        {"time": 14.0, "pitches": ["B4"], "duration": 1.0, "velocity": 85},
        {"time": 15.0, "pitches": ["A4"], "duration": 1.0, "velocity": 90}
      ],
      "instrument": "acoustic_grand_piano"
    },
    {
      "name": "String Harmony",
      "events": [
        {"time": 0.0, "pitches": ["A3", "C4", "E4"], "duration": 4.0, "velocity": 65},
        {"time": 4.0, "pitches": ["F3", "A3", "C4"], "duration": 4.0, "velocity": 65},
        {"time": 8.0, "pitches": ["C3", "E3", "G3"], "duration": 4.0, "velocity": 70},
        {"time": 12.0, "pitches": ["G3", "B3", "D4"], "duration": 4.0, "velocity": 65}
      ],
      "instrument": "string_ensemble_1"
    },
    {
      "name": "Bass Foundation",
      "events": [
        {"time": 0.0, "pitches": ["A2"], "duration": 1.0, "velocity": 80},
        {"time": 2.0, "pitches": ["A2"], "duration": 1.0, "velocity": 75},
        {"time": 4.0, "pitches": ["F2"], "duration": 1.0, "velocity": 80},
        {"time": 6.0, "pitches": ["F2"], "duration": 1.0, "velocity": 75},
        {"time": 8.0, "pitches": ["C2"], "duration": 1.0, "velocity": 85},
        {"time": 10.0, "pitches": ["C2"], "duration": 1.0, "velocity": 80},
        {"time": 12.0, "pitches": ["G2"], "duration": 1.0, "velocity": 80},
        {"time": 14.0, "pitches": ["G2"], "duration": 1.0, "velocity": 75}
      ],
      "instrument": "electric_bass_finger"
    },
    {
      "name": "Choir Atmosphere",
      "events": [
        {"time": 2.0, "pitches": ["E4", "A4"], "duration": 6.0, "velocity": 50},
        {"time": 10.0, "pitches": ["G4", "C5"], "duration": 6.0, "velocity": 55}
      ],
      "instrument": "choir_aahs"
    },
    {
      "name": "Timpani Accents",
      "events": [
        {"time": 0.0, "pitches": ["A2"], "duration": 0.5, "velocity": 90},
        {"time": 4.0, "pitches": ["F2"], "duration": 0.5, "velocity": 85},
        {"time": 8.0, "pitches": ["C3"], "duration": 0.5, "velocity": 95},
        {"time": 12.0, "pitches": ["G2"], "duration": 0.5, "velocity": 90}
      ],
      "instrument": "timpani"
    },
    {
      "name": "Violin Countermelody",
      "events": [
        {"time": 4.5, "pitches": ["C5"], "duration": 0.5, "velocity": 70},
        {"time": 5.0, "pitches": ["D5"], "duration": 0.5, "velocity": 75},
        {"time": 5.5, "pitches": ["E5"], "duration": 0.5, "velocity": 70},
        {"time": 6.0, "pitches": ["F5"], "duration": 1.0, "velocity": 80},
        {"time": 8.5, "pitches": ["E5"], "duration": 0.5, "velocity": 70},
        {"time": 9.0, "pitches": ["F5"], "duration": 0.5, "velocity": 75},
        {"time": 9.5, "pitches": ["G5"], "duration": 0.5, "velocity": 80},
        {"time": 10.0, "pitches": ["A5"], "duration": 1.5, "velocity": 85},
        {"time": 12.5, "pitches": ["F5"], "duration": 0.5, "velocity": 70},
        {"time": 13.0, "pitches": ["D5"], "duration": 0.5, "velocity": 75},
        {"time": 13.5, "pitches": ["B4"], "duration": 0.5, "velocity": 70},
        {"time": 14.0, "pitches": ["G4"], "duration": 2.0, "velocity": 80}
      ],
      "instrument": "violin"
    }
  ],
  "version": 1
}
```