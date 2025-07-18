#!/bin/bash

# Simple test script using printf for proper \r\n formatting
set -euo pipefail

echo "🧪 Testing RiffMCP Stdio Proxy with simple initialize..."

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
echo "📦 App bundle: $RIFFMCP_APP_PATH"
echo "🚀 Executable: $RIFFMCP_PATH"

# Check if the executable exists
if [ ! -f "$RIFFMCP_PATH" ]; then
    echo "❌ Error: RiffMCP executable not found at:"
    echo "   $RIFFMCP_PATH"
    echo ""
    echo "💡 Try building first with: xcodebuild -scheme RiffMCP -configuration Debug build"
    exit 1
fi

# Simple initialize message
TEST_MESSAGE='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'

# Calculate content length
CONTENT_LENGTH=${#TEST_MESSAGE}

echo "📝 Sending initialize command..."
echo "Content-Length: $CONTENT_LENGTH"
echo "Executable: $RIFFMCP_PATH"
echo ""

# Use printf for proper formatting and pipe to the app
if (printf "Content-Length: %d\r\n\r\n%s" "$CONTENT_LENGTH" "$TEST_MESSAGE") | "$RIFFMCP_PATH" --stdio; then
    echo ""
    echo "✅ Test completed successfully!"
else
    echo ""
    echo "❌ Test failed with exit code $?"
fi