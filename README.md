# MCP Play

A MacOS music composition and playback system with MCP (Model Context Protocol) server integration.

## Overview

This project consists of two components that work together:

1. **MacOS App** (`MCP Play/`) - A Swift-based piano/music app for playback
2. **MCP Server** (`mcp-server/`) - A Node.js server that enables LLMs to compose and play music

Both components use a shared JSON music sequence format that supports multi-track compositions with 70 different General MIDI instruments.

## Features

### MacOS App
- Real-time MIDI playback using General MIDI soundfont
- Multi-track support with independent instruments per track  
- JSON-based music sequence format
- Piano keyboard visualization
- Direct URL scheme integration (`mcpplay://`)

### MCP Server
- **70 General MIDI instruments** across 9 categories
- **3 MCP tools** for LLM interaction:
  - `list_instruments` - Discover available instruments
  - `play_sequence` - Play music from JSON
  - `stop` - Stop current playback
- Automatic file management for large sequences
- Cross-platform LLM integration

## Supported Instruments

The system supports 70 instruments organized by category:

- **Piano** (8): Grand pianos, electric pianos, harpsichord, clavinet
- **Percussion** (8): Celesta, glockenspiel, vibraphone, marimba, xylophone, etc.
- **Organ** (8): Church organ, rock organ, accordion, harmonica, etc.  
- **Guitar** (8): Acoustic, electric, jazz, distortion, harmonics
- **Bass** (8): Acoustic, electric, fretless, slap bass, synth bass
- **Strings** (12): Violin, viola, cello, harp, string ensembles, timpani
- **Brass** (8): Trumpet, trombone, tuba, french horn, brass sections
- **Woodwinds** (16): Saxophones, flutes, clarinets, oboe, recorder, pan flute
- **Choir** (4): Vocal sounds, synth voice, orchestra hit

Use the MCP server's `list_instruments` tool to see the complete list with exact instrument names.

## JSON Sequence Format

Music is defined in JSON with this structure:

```json
{
  "version": 1,
  "title": "Song Title",
  "tempo": 120,
  "tracks": [
    {
      "instrument": "acoustic_grand_piano",
      "name": "Piano Track",
      "events": [
        {
          "time": 0.0,
          "pitches": ["C4", "E4", "G4"],
          "duration": 1.0,
          "velocity": 100
        }
      ]
    }
  ]
}
```

See `LLM Help.md` for complete format documentation and examples.

## Getting Started

### MacOS App
1. Open `MCP Play.xcodeproj` in Xcode
2. Build and run the app
3. Use the built-in examples or paste JSON sequences

### MCP Server
1. Navigate to `mcp-server/` directory
2. Install dependencies: `npm install`
3. Run the server: `node index.js`
4. Configure your LLM to use the MCP server

### Integration
The MCP server communicates with the MacOS app via custom URL schemes (`mcpplay://`). When an LLM calls `play_sequence`, the server opens a URL that triggers playback in the app.

## Files

- `MCP Play/` - MacOS Swift application
- `mcp-server/` - Node.js MCP server  
- `LLM Help.md` - Complete format documentation for LLMs
- `README_MCP.md` - MCP server specific documentation

## License

This project is provided as-is for educational and creative purposes.