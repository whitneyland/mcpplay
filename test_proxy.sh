#!/bin/bash

# Test script for RiffMCP Stdio Proxy functionality
set -euo pipefail

echo "🧪 Testing RiffMCP Stdio Proxy..."

# Query Xcode for the actual build location
echo "🔍 Querying Xcode for build location..."
BUILT_PRODUCTS_DIR=$(xcodebuild \
    -scheme RiffMCP \
    -configuration Debug \
    -sdk macosx \
    -showBuildSettings 2>/dev/null | \
    awk -F' = ' '/BUILT_PRODUCTS_DIR = / {print $2}' | head -1)

if [ -z "$BUILT_PRODUCTS_DIR" ]; then
    echo "❌ Error: Could not determine build location from Xcode"
    exit 1
fi

RIFFMCP_PATH="$BUILT_PRODUCTS_DIR/RiffMCP.app/Contents/MacOS/RiffMCP"
echo "🚀 Using executable: $RIFFMCP_PATH"

# Check if the executable exists
if [ ! -f "$RIFFMCP_PATH" ]; then
    echo "❌ Error: RiffMCP executable not found"
    echo "💡 Try building first with: xcodebuild -scheme RiffMCP -configuration Debug build"
    exit 1
fi

echo ""

# Test JSON-RPC message for playing a simple note
TEST_MESSAGE='{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
        "name": "play",
        "arguments": {
            "title": "Test Note",
            "tempo": 120,
            "tracks": [{
                "instrument": "grand_piano",
                "events": [{
                    "time": 0,
                    "pitches": ["C4"],
                    "dur": 1,
                    "vel": 100
                }]
            }]
        }
    }
}'

# Calculate content length
CONTENT_LENGTH=$(echo -n "$TEST_MESSAGE" | wc -c | tr -d ' ')

# Create the full stdio message with Content-Length header
FULL_MESSAGE="Content-Length: $CONTENT_LENGTH\r\n\r\n$TEST_MESSAGE"

echo "📝 Sending play command via stdio..."
echo "Content-Length: $CONTENT_LENGTH"
echo "Message: $TEST_MESSAGE"
echo ""

# Send the message to RiffMCP with --stdio flag
# This will either:
# 1. Start a new stdio server (if no GUI is running)
# 2. Proxy to existing GUI server (if GUI is running)
echo "$FULL_MESSAGE" | "$RIFFMCP_PATH" --stdio

echo ""
echo "✅ Test completed!"