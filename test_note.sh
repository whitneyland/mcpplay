#!/bin/bash

# Test script to play notes through the stdio proxy
set -euo pipefail

echo "🎵 Testing RiffMCP Note Playback via Stdio Proxy..."

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

RIFFMCP_APP_PATH="$BUILT_PRODUCTS_DIR/RiffMCP.app"
RIFFMCP_PATH="$RIFFMCP_APP_PATH/Contents/MacOS/RiffMCP"

echo "📍 Build location: $BUILT_PRODUCTS_DIR"
echo "🚀 Executable: $RIFFMCP_PATH"

# Check if the executable exists
if [ ! -f "$RIFFMCP_PATH" ]; then
    echo "❌ Error: RiffMCP executable not found at:"
    echo "   $RIFFMCP_PATH"
    exit 1
fi

# Function to send a JSON-RPC message
send_message() {
    local message="$1"
    local length=${#message}
    printf "Content-Length: %d\r\n\r\n%s" "$length" "$message"
}

# Function to test a tool call
test_tool_call() {
    local tool_name="$1"
    local arguments="$2"
    local message_id="$3"
    
    echo "🎵 Testing tool: $tool_name"
    
    local tool_message="{\"jsonrpc\":\"2.0\",\"id\":$message_id,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool_name\",\"arguments\":$arguments}}"
    
    send_message "$tool_message"
}

{
    # 1. Initialize
    echo "📝 Step 1: Initialize connection..."
    INIT_MESSAGE='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
    send_message "$INIT_MESSAGE"
    
    # 2. Send initialized notification
    echo "📝 Step 2: Send initialized notification..."
    INIT_NOTIFICATION='{"jsonrpc":"2.0","method":"notifications/initialized"}'
    send_message "$INIT_NOTIFICATION"
    
    # 3. Play a C major scale
    echo "🎵 Step 3: Playing C major scale..."
    test_tool_call "play_notes" '{"notes":[{"note":"C4","duration":0.5},{"note":"D4","duration":0.5},{"note":"E4","duration":0.5},{"note":"F4","duration":0.5},{"note":"G4","duration":0.5},{"note":"A4","duration":0.5},{"note":"B4","duration":0.5},{"note":"C5","duration":1.0}]}' 3
    
    # 4. Play a simple melody
    echo "🎵 Step 4: Playing simple melody..."
    test_tool_call "play_notes" '{"notes":[{"note":"C4","duration":0.5},{"note":"E4","duration":0.5},{"note":"G4","duration":0.5},{"note":"C5","duration":1.0},{"note":"G4","duration":0.5},{"note":"E4","duration":0.5},{"note":"C4","duration":1.0}]}' 4
    
    # 5. Stop playback (in case it's still playing)
    echo "🛑 Step 5: Stopping playback..."
    test_tool_call "stop_playback" '{}' 5
    
} | "$RIFFMCP_PATH" --stdio

echo ""
echo "✅ Note playback test completed!"
echo "🎶 You should have heard a C major scale followed by a simple melody!"