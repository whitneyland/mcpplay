#!/bin/bash

# Debug script to see what's happening with proxy detection
set -euo pipefail

echo "🔍 Debug: Proxy Detection Analysis"
echo "=================================="

# Check if server config exists
CONFIG_PATH="$HOME/Library/Application Support/RiffMCP/server.json"
echo "📁 Checking config at: $CONFIG_PATH"

if [ -f "$CONFIG_PATH" ]; then
    echo "✅ Config file exists"
    echo "📄 Contents:"
    cat "$CONFIG_PATH"
    echo ""
    
    # Extract PID and check if process is running
    PID=$(cat "$CONFIG_PATH" | grep '"pid"' | sed 's/.*"pid": *\([0-9]*\).*/\1/')
    PORT=$(cat "$CONFIG_PATH" | grep '"port"' | sed 's/.*"port": *\([0-9]*\).*/\1/')
    
    echo "🔢 Extracted PID: $PID"
    echo "🌐 Extracted PORT: $PORT"
    
    if kill -0 "$PID" 2>/dev/null; then
        echo "✅ Process $PID is running"
        echo "🔄 Proxy should activate and forward to port $PORT"
    else
        echo "❌ Process $PID is NOT running (stale config)"
        echo "🧹 Config should be cleaned up automatically"
    fi
else
    echo "❌ No config file found"
    echo "🆕 New stdio server should start"
fi

echo ""
echo "🖥️  Currently running RiffMCP processes:"
ps aux | grep -i riffmcp | grep -v grep || echo "No RiffMCP processes found"

echo ""
echo "🌐 Network connections on common ports:"
netstat -an | grep -E ":(300[0-9]|301[0-9])" | head -5 || echo "No connections found"