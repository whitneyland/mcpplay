Create an impressive piano composition, around 15 seconds long. The piece should exciting, powerful, passionate, showcasing sophisticated chords, arpeggios, dynamic shifts, and rhythmic complexity. 

Use the following JSON format exactly:

---
## Instructions
Use this JSON format for your music compositions:

### Root Object
- `title` (optional): Descriptive name for your piece
- `tempo` (required): BPM (beats per minute)
- `tracks` (required): Array of track objects

### Track Object
- `instrument`: One of the available instruments below
- `events` (required): Array of musical events

### Event Object
- `time` (required): When to play in beats from start (0.0 = beginning)
- `pitches` (required): Array of notes - use note names like "C4", "F#3" or MIDI numbers like 60
- `dur` (required): Length in beats (1.0 = quarter note at current tempo)
- `vel` (optional): Volume 0-127 (defaults to 100)

### Available Instruments
grand_piano

### Key Points
- Time values are in **beats**, not seconds
- Multiple notes at the same time = chord (multiple pitches in same event)
- Multiple tracks = different instruments playing simultaneously
- Note names use octave numbers (C4 = middle C, C5 = octave above)
- MIDI numbers: 60 = C4, 61 = C#4, 72 = C5

