
Create an impressive multi-track composition.

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
**Piano**  
`grand_piano`, `electric_piano`, `harpsichord`, `clavinet`

**Percussion**  
`celesta`, `glockenspiel`, `music_box`, `vibraphone`, `marimba`, `xylophone`,  
`tubular_bells`, `timpani`, `agogo`, `steel_drums`, `woodblock`, `taiko_drum`,  
`castanets`, `concert_bass_drum`, `melodic_tom`, `synth_drum`

**Organ**  
`drawbar_organ`, `percussive_organ`, `rock_organ`, `church_organ`,  
`reed_organ`, `accordian`, `harmonica`, `bandoneon`

**Guitar**  
`nylon_string_guitar`, `steel_string_guitar`, `jazz_guitar`,  
`clean_guitar`, `distortion_guitar`

**Bass**  
`acoustic_bass`, `fingered_bass`, `picked_bass`, `synth_bass`

**Strings**  
`violin`, `viola`, `cello`, `contrabass`, `tremolo`, `pizzicato_section`,  
`harp`, `strings`, `slow_strings`

**Choir**  
`ahh_choir`, `ohh_voices`, `orchestra_hit`

**Brass**  
`trumpet`, `trombone`, `tuba`, `muted_trumpet`, `french_horns`, `brass_section`

**Woodwinds**  
`soprano_sax`, `alto_sax`, `tenor_sax`, `baritone_sax`, `oboe`, `english_horn`,  
`bassoon`, `clarinet`, `piccolo`, `flute`, `recorder`, `pan_flute`,  
`bottle_chiff`, `shakuhachi`, `whistle`, `ocarina`

**World**  
`sitar`, `banjo`, `shamisen`, `koto`, `kalimba`, `bagpipe`,  
`fiddle`, `shenai`, `tinker_bell`

### Key Points
- Time values are in **beats**, not seconds
- Multiple notes at the same time = chord (multiple pitches in same event)
- Multiple tracks = different instruments playing simultaneously
- Note names use octave numbers (C4 = middle C, C5 = octave above)
- MIDI numbers: 60 = C4, 61 = C#4, 72 = C5