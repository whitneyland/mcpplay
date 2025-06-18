# RiffMCP

MacOS app for music playback with a built in MCP (Model Context Protocol) server.

## Overview
Chat to play music.  Examples:
- Play a G major scale
- Play a chord progression
- Play Canon in D
- Compose an original symphony
- Bring a famous poem to life as a multi-track song 

Currently tested to work with Claude Desktop as LLM client.

**MacOS App** (`RiffMCP`) - Swift-based music MCP server. Uses a JSON music sequence format that supports multi-track compositions with multiple instruments.

## Features

### MacOS App
- Built-in web server handles MCP protocol over HTTP
- Instruments playback using general MIDI soundfont
- Multi-track support with independent instruments per track  
- JSON-based music sequence format
- Piano roll visualization of music playback

