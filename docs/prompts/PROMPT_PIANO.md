Create an impressive piano composition.  The piece should be exciting, powerful, and passionate.

 * Showcase sophisticated techniques and rhythmic complexity. 
 * Make sure it's melodic.
 * Ensure chords are chosen to harmonize with the melody, resolve smoothly, and enhance the melody’s emotional feel.
 * Ensure harmonization, voice leading, and progressions fit the song’s tonal structure.
 * Calculate the nunmber of bars needed (given the chosen tempo) to ensure the piece is at least 15 seconds long.
  
Plan carefully before starting to ensure all the requirements are met.  Think as hard as you can, really show me what you've got.


Use the following JSON format exactly. Do not add comments in the json.
---
### Root Object
- `title` : Descriptive name for your piece
- `tempo` : BPM (beats per minute)
- `tracks` : Array of track objects

### Track Object
- `instrument`: One of the available instruments below
- `events` : Array of musical events

### Event Object
- `time` : When to play in beats from start (0.0 = beginning)
- `pitches` : Array of notes - use note names like "C4", "F#3" or MIDI numbers like 60
- `dur` : Length in beats (1.0 = quarter note at current tempo)
- `vel` : Volume 0-127 (defaults to 100)

### Available Instruments
grand_piano

### Key Points
- Time values are in **beats**, not seconds
- Multiple notes at the same time = chord (multiple pitches in same event)
- Multiple tracks = different instruments playing simultaneously
- Note names use octave numbers (C4 = middle C, C5 = octave above)
- MIDI numbers: 60 = C4, 61 = C#4, 72 = C5