#!/bin/bash

# Script to launch GUI and debug server config creation
set -euo pipefail

echo "🚀 Launching GUI app and monitoring server config creation..."

# Get the app path
BUILT_PRODUCTS_DIR=$(xcodebuild \
    -scheme RiffMCP \
    -configuration Debug \
    -sdk macosx \
    -showBuildSettings 2>/dev/null | \
    awk -F' = ' '/BUILT_PRODUCTS_DIR = / {print $2}' | head -1)

APP_PATH="$BUILT_PRODUCTS_DIR/RiffMCP.app"
CONFIG_PATH="$HOME/Library/Application Support/RiffMCP/server.json"

echo "📱 App path: $APP_PATH"
echo "📄 Config path: $CONFIG_PATH"

# Clean slate
echo "🧹 Removing any existing config..."
rm -f "$CONFIG_PATH"

# Launch app in background
echo "🚀 Launching GUI app..."
open "$APP_PATH"

# Monitor for config file creation
echo "👀 Monitoring for server.json creation..."
for i in {1..10}; do
    sleep 1
    if [ -f "$CONFIG_PATH" ]; then
        echo "✅ Config file created after ${i} seconds!"
        echo "📄 Contents:"
        cat "$CONFIG_PATH"
        break
    else
        echo "⏳ Waiting... (${i}/10)"
    fi
done

if [ ! -f "$CONFIG_PATH" ]; then
    echo "❌ Config file was NOT created after 10 seconds"
    echo ""
    echo "🔍 Checking running processes:"
    ps aux | grep -i riffmcp | grep -v grep || echo "No RiffMCP processes found"
    echo ""
    echo "🌐 Checking network connections:"
    lsof -i -P | grep -i riffmcp || echo "No network connections found"
fi