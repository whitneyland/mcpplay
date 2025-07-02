# RiffMCP Server

This MCP server allows an LLM to compose and play music sequences.

## Setup Instructions for Claude Desktop on MacOS

1. **Start RiffMCP app:**
   Launch the RiffMCP.app from Applications or Xcode. The HTTP server starts automatically on port 3001.

2. **Add to Claude Desktop configuration:**
   Add this to your Claude Desktop app configuration file:
   
   **Location:** `~/Library/Application Support/Claude/claude_desktop_config.json`
   
   ```json
   {
     "mcpServers": {
       "riffmcp": {
         "command": "npx",
         "args": ["mcp-remote", "http://localhost:3001"]
       }
     }
   }
   ```

3. **Restart Claude Desktop** to activate the configuration.

## Available Commands

- `play` - Play music directly from JSON sequence data

## Usage Examples

Once configured, you can chat to request things like:

- "Play a simple C major scale"
- "Play Twinkle Twinkle Little Star"
- "Create and play a chord progression"
- "Show me all available instruments"

## JSON Format

Music sequences support multi-track JSON with multi-instrument support:

```json
{
  "title": "My First Multi-Track Song",
  "tempo": 120,
  "tracks": [
    {
      "instrument": "acoustic_grand_piano",
      "name": "Piano Chords",
      "events": [
        { "time": 0.0, "pitches": ["C3", "G3", "E4"], "dur": 4.0, "vel": 60 },
        { "time": 4.0, "pitches": ["A2", "E3", "C4"], "dur": 4.0, "vel": 60 }
      ]
    },
    {
      "instrument": "string_ensemble_1",
      "name": "String Melody",
      "events": [
        { "time": 0.0, "pitches": ["C5"], "dur": 3.0, "vel": 90 },
        { "time": 3.0, "pitches": ["B4"], "dur": 1.0, "vel": 85 }
      ]
    }
  ]
}
```

- **time**: When to play (in beats)
- **pitches**: Note names like "C4" or MIDI numbers like 60
- **dur**: How long to play (1.0 = quarter note)
- **vel**: Volume 0-127 (optional, defaults to 100)

## Architecture

- HTTP server embedded in RiffMCP app using Swift Foundation
- JSON-RPC 2.0 protocol for all communication
- Real-time audio synthesis with 70 General MIDI instruments
- Multi-track support with independent instrument assignment
