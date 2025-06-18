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


