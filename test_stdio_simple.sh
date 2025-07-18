#!/bin/bash

# Simple test script for --stdio functionality
# Tests basic JSON-RPC communication via stdio

set -e

APP_NAME="RiffMCP"
CONFIG_DIR="$HOME/Library/Application Support/RiffMCP"
CONFIG_FILE="$CONFIG_DIR/server.json"

echo "🧪 Testing --stdio JSON-RPC Communication"
echo "========================================"

# Find the actual app path
ACTUAL_APP_PATH=$(find /Users/lee/Library/Developer/Xcode/DerivedData -name "RiffMCP.app" -type d 2>/dev/null | head -1)
if [ -z "$ACTUAL_APP_PATH" ]; then
    echo "❌ Could not find RiffMCP.app. Please build the project first."
    exit 1
fi

EXECUTABLE_PATH="$ACTUAL_APP_PATH/Contents/MacOS/RiffMCP"

echo "📱 App found at: $ACTUAL_APP_PATH"
echo "🔧 Executable at: $EXECUTABLE_PATH"

# Test 1: Basic --stdio launch and initialize
echo ""
echo "🧪 Test 1: Basic --stdio Communication"
echo "====================================="

echo "📱 Launching RiffMCP with --stdio..."

# Create a simple JSON-RPC initialize request
INIT_REQUEST='{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "processId": null,
    "clientInfo": {
      "name": "test-client",
      "version": "1.0.0"
    },
    "capabilities": {}
  }
}'

# Calculate content length
CONTENT_LENGTH=$(echo -n "$INIT_REQUEST" | wc -c)

# Create the full message with Content-Length header
FULL_MESSAGE="Content-Length: $CONTENT_LENGTH"$'\r\n'$'\r\n'"$INIT_REQUEST"

echo "📤 Sending initialize request..."
echo "Content-Length: $CONTENT_LENGTH"
echo "$INIT_REQUEST" | jq . 2>/dev/null || echo "$INIT_REQUEST"

# Send the message and capture response
RESPONSE=$(echo -n "$FULL_MESSAGE" | timeout 10 "$EXECUTABLE_PATH" --stdio 2>&1)

echo ""
echo "📥 Response received:"
echo "$RESPONSE"

# Test 2: List tools request
echo ""
echo "🧪 Test 2: List Tools Request"
echo "============================="

TOOLS_REQUEST='{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list",
  "params": {}
}'

CONTENT_LENGTH=$(echo -n "$TOOLS_REQUEST" | wc -c)
FULL_MESSAGE="Content-Length: $CONTENT_LENGTH"$'\r\n'$'\r\n'"$TOOLS_REQUEST"

echo "📤 Sending tools/list request..."
echo "Content-Length: $CONTENT_LENGTH"
echo "$TOOLS_REQUEST" | jq . 2>/dev/null || echo "$TOOLS_REQUEST"

RESPONSE=$(echo -n "$FULL_MESSAGE" | timeout 10 "$EXECUTABLE_PATH" --stdio 2>&1)

echo ""
echo "📥 Response received:"
echo "$RESPONSE"

# Test 3: Invalid JSON request
echo ""
echo "🧪 Test 3: Invalid JSON Handling"
echo "==============================="

INVALID_REQUEST='{ "invalid": json }'
CONTENT_LENGTH=$(echo -n "$INVALID_REQUEST" | wc -c)
FULL_MESSAGE="Content-Length: $CONTENT_LENGTH"$'\r\n'$'\r\n'"$INVALID_REQUEST"

echo "📤 Sending invalid JSON..."
echo "Content-Length: $CONTENT_LENGTH"
echo "$INVALID_REQUEST"

RESPONSE=$(echo -n "$FULL_MESSAGE" | timeout 10 "$EXECUTABLE_PATH" --stdio 2>&1)

echo ""
echo "📥 Response received:"
echo "$RESPONSE"

echo ""
echo "🎉 --stdio communication tests completed!"
echo "========================================"
echo "Check the responses above to verify JSON-RPC communication is working."