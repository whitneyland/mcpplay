# RiffMCP

MacOS app with built-in MCP server for music playback and engraving.

## Overview
- Built-in web server handles MCP protocol over HTTP
- Multi-track support with independent instruments per track  
- JSON-based music sequence format
- Playback music as well as basic sheet music rendering

## How it works
- Add RiffMCP to an LLM supporting MCP servers (see Setup below)
- Once configured, you can chat to play music or see rendered output as .png

## Usage Examples
- "Play a happy melody" or "Play a sad melody"
- "Play a cascading blues minor scale with varying tempo"
- "Play a 12 bar jazz progression with walking bass"
- "Show me all available instruments"
- "Play Maple Leaf Rag"
- "Show me the sheet music for that"


# Setup

## Start RiffMCP app:
Launch the RiffMCP.app from Applications or Xcode. The HTTP server starts automatically on port 3001.

## Setup with Claude Desktop
1. **Add to Claude Desktop configuration:**
   Add this to your Claude Desktop app configuration file:
   
   **Location:** `~/Library/Application Support/Claude/claude_desktop_config.json`

2. **Create or extend the top-level "mcpServers" object.**   
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

## Setup with Gemini CLI
1. **Edit <project>/.gemini/settings.json**

2. **Create or extend the top-level "mcpServers" object.**
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
3. **Restart Gemini CLI** to activate the configuration.

## Requires Node ≥ 18:
brew install node

# For LLMs that don't support MCP servers
- Get a prompt from PROMPT_PIANO.md or PROMPT_MULTITRACK.md
- This will prompt any LLM to generate RiffMCP json format
- Copy the output and paste it into the json editor window in the RiffMCP app
- Press the Play button

# See usage examples to chat
