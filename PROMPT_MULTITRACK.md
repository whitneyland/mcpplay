
Create an impressive multi-track composition. The piece should exciting, passionate, showcasing sophistication, dynamic shifts, and rhythmic complexity. Make sure it's melodic. Make sure its at least 15 seconds long, all as one piece.

Use the following JSON format exactly:


## Instructions

Use this JSON format for your music compositions:

### Root Object
- `title` (optional): Descriptive name for your piece  
- `tempo` (required): BPM (beats per minute)  
- `tracks` (required): Array of track objects  

### Track Object
- `instrument` One of the available instruments below
- `events` (required): Array of musical events  

### Event Object
- `time` (required): When to play, in **beats** from start (0.0 = beginning)  
- `pitches` (required): Array of notes — use note names like `"C4"`, `"F#3"` or MIDI numbers like `60`  
- `dur` (required): Length in beats (1.0 = quarter-note at current tempo)  
- `vel` (optional): Volume 0–127 (defaults to 100)  

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
- **Time values are in beats** — not seconds.  
- Multiple pitches in the same event (same `time`) create a chord.  
- Multiple tracks let different instruments play simultaneously.  
- Note names follow scientific-pitch notation (`C4` = middle C).  
- MIDI numbers: `60` = C4, `61` = C#4/Db4, `72` = C5.