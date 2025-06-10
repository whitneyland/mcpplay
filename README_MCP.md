# MCP Piano Server

This MCP server allows Claude Desktop to control your piano app and manage music sequences.

## Setup Instructions

1. **Install dependencies:**
   ```bash
   cd /Users/lee/mcpplay/mcp-server
   npm install
   ```

2. **Add to Claude Desktop configuration:**
   Add this to your Claude Desktop app configuration file:
   
   **Location:** `~/Library/Application Support/Claude/claude_desktop_config.json`
   
   ```json
   {
     "mcpServers": {
       "mcp-piano": {
         "command": "node",
         "args": ["/Users/lee/mcpplay/mcp-server/index.js"],
         "env": {}
       }
     }
   }
   ```

3. **Restart Claude Desktop** after adding the configuration.

## Available Commands

- `play_sequence` - Play music directly from JSON sequence data
- `stop` - Stop any currently playing music

## Usage Examples

Once configured, you can ask Claude Desktop:

- "Play a simple C major scale"
- "Play Twinkle Twinkle Little Star"
- "Create and play a chord progression"
- "Stop the music"

## JSON Format

Music sequences use this clear JSON structure:

```json
{
  "version": 1,
  "tempo": 120,
  "instrument": "acoustic_grand_piano",
  "events": [
    {
      "time": 0.0,
      "pitches": ["C4"],
      "duration": 1.0,
      "velocity": 100
    },
    {
      "time": 1.0, 
      "pitches": ["D4"],
      "duration": 1.0
    }
  ]
}
```

- **time**: When to play (in beats)
- **pitches**: Note names like "C4" or MIDI numbers like 60
- **duration**: How long to play (1.0 = quarter note)
- **velocity**: Volume 0-127 (optional, defaults to 100)

## Notes

- The MCP server communicates with your piano app using URL schemes  
- Make sure the MCP Play app is running when using playback commands
- Claude sends music data directly - no need to manage files