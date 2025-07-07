# HTTP API Examples

This document provides curl examples for testing the RiffMCP HTTP server directly.

## Server Configuration

The HTTP server runs on:
- **Host**: `127.0.0.1` (localhost only)
- **Port**: `3001`
- **Protocol**: HTTP (JSON-RPC 2.0)

Server configuration is written to: `~/Library/Application Support/RiffMCP/server.json`

## JSON-RPC 2.0 Format

All requests use JSON-RPC 2.0 format:
```json
{
  "jsonrpc": "2.0",
  "method": "method_name",
  "params": {...},
  "id": 1
}
```

## Available Methods

### 1. List Available Tools

Get the list of available MCP tools:

```bash
curl -X POST http://localhost:3001/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
  }'
```

### 2. Play a Simple Sequence

Play a simple melody:

```bash
curl -X POST http://localhost:3001/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "play",
      "arguments": {
        "tempo": 120,
        "tracks": [
          {
            "instrument": "acoustic_grand_piano",
            "name": "Simple Melody",
            "events": [
              {"time": 0.0, "pitches": ["C4"], "dur": 1.0, "vel": 100},
              {"time": 1.0, "pitches": ["E4"], "dur": 1.0, "vel": 100},
              {"time": 2.0, "pitches": ["G4"], "dur": 1.0, "vel": 100},
              {"time": 3.0, "pitches": ["C5"], "dur": 2.0, "vel": 100}
            ]
          }
        ]
      }
    },
    "id": 3
  }'
```

### 3. Play a Multi-Track Sequence

Play a sequence with multiple instruments:

```bash
curl -X POST http://localhost:3001/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "play",
      "arguments": {
        "title": "Multi-Track Example",
        "tempo": 120,
        "tracks": [
          {
            "instrument": "acoustic_grand_piano",
            "name": "Piano",
            "events": [
              {"time": 0.0, "pitches": ["C4", "E4", "G4"], "dur": 2.0, "vel": 80},
              {"time": 2.0, "pitches": ["F4", "A4", "C5"], "dur": 2.0, "vel": 80}
            ]
          },
          {
            "instrument": "acoustic_bass",
            "name": "Bass",
            "events": [
              {"time": 0.0, "pitches": ["C2"], "dur": 1.0, "vel": 100},
              {"time": 1.0, "pitches": ["C2"], "dur": 1.0, "vel": 100},
              {"time": 2.0, "pitches": ["F2"], "dur": 1.0, "vel": 100},
              {"time": 3.0, "pitches": ["F2"], "dur": 1.0, "vel": 100}
            ]
          }
        ]
      }
    },
    "id": 4
  }'
```


## Common Note Names

**Octaves:** C4 = Middle C, C3 = One octave below, C5 = One octave above

**Chromatic scale around middle C:**
- C4, C#4, D4, D#4, E4, F4, F#4, G4, G#4, A4, A#4, B4, C5

**Alternative notation:**
- Sharps: C#4, D#4, F#4, G#4, A#4
- Flats: Db4, Eb4, Gb4, Ab4, Bb4

## Response Format

All JSON-RPC responses follow this format:

**Success:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Playing music sequence at 120 BPM with 4 events"
      }
    ]
  },
  "id": 1
}
```

**Error:**
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32602,
    "message": "Invalid params"
  },
  "id": 1
}
```

## Troubleshooting

**Server not responding?**
1. Check if RiffMCP app is running
2. Verify server config: `cat "~/Library/Application Support/RiffMCP/server.json"`
3. Check app logs for startup errors

**Invalid instrument error?**
Check the instrument names in the `play` tool schema for all available options.

**JSON formatting issues?**
Ensure proper escaping of quotes in bash. Use single quotes around the JSON data or escape double quotes with backslashes.