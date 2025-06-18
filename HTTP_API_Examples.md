# HTTP API Examples

This document provides curl examples for testing the MCP Play HTTP server directly.

## Server Configuration

The HTTP server runs on:
- **Host**: `127.0.0.1` (localhost only)
- **Port**: `27272`
- **Protocol**: HTTP (JSON-RPC 2.0)

Server configuration is written to: `~/Library/Application Support/MCP Play/server.json`

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
curl -X POST http://localhost:27272/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
  }'
```

### 2. List Instruments

Get all available instruments organized by category:

```bash
curl -X POST http://localhost:27272/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "list_instruments",
      "arguments": {}
    },
    "id": 2
  }'
```

### 3. Play a Simple Sequence

Play a simple melody:

```bash
curl -X POST http://localhost:27272/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "play_sequence",
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

### 4. Play a Multi-Track Sequence

Play a sequence with multiple instruments:

```bash
curl -X POST http://localhost:27272/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "play_sequence",
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

### 5. Stop Playback

Stop any currently playing music:

```bash
curl -X POST http://localhost:27272/ \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "stop",
      "arguments": {}
    },
    "id": 5
  }'
```

## Simple Note Endpoint

For quick testing, there's a simplified endpoint that plays a single note:

```bash
curl -X POST http://localhost:27272/play_note \
  -H "Content-Type: application/json" \
  -d '{
    "pitch": "C4",
    "duration": 1.0,
    "velocity": 100
  }'
```

**Parameters:**
- `pitch`: Note name (e.g., "C4", "F#3", "Bb5")
- `duration`: Duration in seconds (optional, default: 1.0)
- `velocity`: Volume 0-127 (optional, default: 100)

**Examples:**
```bash
# Play middle C for 1 second
curl -X POST http://localhost:27272/play_note -H "Content-Type: application/json" -d '{"pitch":"C4"}'

# Play F# above middle C for 2 seconds at half volume
curl -X POST http://localhost:27272/play_note -H "Content-Type: application/json" -d '{"pitch":"F#4","duration":2.0,"velocity":64}'

# Play low A for 0.5 seconds
curl -X POST http://localhost:27272/play_note -H "Content-Type: application/json" -d '{"pitch":"A2","duration":0.5}'
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
1. Check if MCP Play app is running
2. Verify server config: `cat "~/Library/Application Support/MCP Play/server.json"`
3. Check app logs for startup errors

**Invalid instrument error?**
Use the `list_instruments` tool to see all available instrument names.

**JSON formatting issues?**
Ensure proper escaping of quotes in bash. Use single quotes around the JSON data or escape double quotes with backslashes.