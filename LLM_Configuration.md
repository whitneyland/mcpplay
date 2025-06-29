# LLM Configuration for HTTP Server

This document explains how to configure your LLM to use the HTTP-based MCP server.

## Claude Desktop Configuration

### Configuration File Location

The MCP configuration should be placed in Claude Desktop's configuration file:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

### Current Configuration (HTTP/mcp-remote Transport)

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

### Alternative Configuration (server-fetch)

```json
{
  "mcpServers": {
    "riffmcp": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-fetch@latest",
        "http://localhost:3001"
      ]
    }
  }
}
```

## Usage Instructions

### 1. Start the RiffMCP App
Launch the RiffMCP app:
1. Open the RiffMCP app from Applications or Xcode
2. The HTTP server will start automatically on port 3001
3. Check server status: `cat "~/Library/Application Support/RiffMCP/server.json"`

### 2. Verify Connection
Test the connection with curl:
```bash
curl -X POST http://localhost:3001/ \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

### 3. Configure Your LLM
Update your LLM configuration to point to the HTTP endpoint.

## Available Tools

The HTTP server provides comprehensive music tools:

### 1. `play`
**Purpose**: Play a music sequence from JSON data
**Parameters**:
- `version`: Schema version (always 1)
- `title`: Optional sequence title
- `tempo`: BPM (beats per minute)
- `tracks`: Array of track objects with instrument, name, and events

**Returns**: Summary of playback (tempo, event count, track count)


## Architecture Benefits

1. **Single Process**: No Node.js runtime dependency
2. **Scalable Sequences**: No size limits for JSON data
3. **Better Error Handling**: Direct HTTP error codes
4. **Clean Architecture**: Embedded server with JSON-RPC 2.0
5. **Real-time Testing**: Direct curl access for development

## Requirements

1. **App Launch**: App must be running for LLM requests
2. **Localhost Only**: Server only accepts connections from 127.0.0.1
3. **Fixed Port**: Port 3001 must be available
4. **Foundation Network**: Uses modern Swift concurrency

## Troubleshooting

### Server Not Responding
```bash
# Check if app is running
ps aux | grep "RiffMCP"

# Check server config
cat "~/Library/Application Support/RiffMCP/server.json"

# Test direct connection
curl -X POST http://localhost:3001/ -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

### Port Already in Use
If port 3001 is occupied:
1. Find the process: `lsof -i :3001`
2. Kill it: `kill -9 <PID>`
3. Or restart RiffMCP app

### Configuration Issues
1. Verify JSON-RPC 2.0 format in requests
2. Check Content-Type header is `application/json`
3. Ensure proper JSON escaping in configuration files

## Development Testing

Use the provided curl examples in `HTTP_API_Examples.md` for:
- Testing server functionality
- Debugging sequence issues
- Verifying instrument names
- Quick note playback tests

## Future Enhancements

Potential improvements:
- Auto-discovery of server port
- Server status API endpoint
- Health check endpoint
- Metrics and logging API
- Remote access with authentication