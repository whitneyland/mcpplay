# RiffMCP

MacOS app with built-in MCP server for music playback and sheet music rendering.

## Overview
- Built-in web server handles MCP protocol over HTTP
- Multi-track support with independent instruments per track  
- JSON-based music sequence format
- Piano roll visualization of music playback

## How it works
- Add RiffMCP to an LLM supporting MCP servers (see Setup below)
- Once configured, you can chat to play music or render the output as svg/png

## Usage Examples
- "Play a blues minor scale with varying tempo"
- "Play a 12 bar jazz progression with walking bass"
- "Show me all available instruments"
- "Play Maple Leaf Rag"
- "Show me the sheet music for that"


## Setup Instructions on MacOS 
# (for Claude Desktop, other LLMs refer to their MCP setup instructions)

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

4. **See usage examples to chat**

## For LLMs that don't support MCP servers
- Get a prompts from PROMPT_PIANO.md or PROMPT_MULTITRACK.md
- This will prompt any LLM to generate RiffMCP json format
- Copy the output and paste it into the json editor window in the RiffMCP app
- Press Play

