#!/bin/bash

# Simple note test
set -euo pipefail

echo "🎵 Testing single note playback..."

# Query Xcode for the actual build location
BUILT_PRODUCTS_DIR=$(xcodebuild \
    -scheme RiffMCP \
    -configuration Debug \
    -sdk macosx \
    -showBuildSettings 2>/dev/null | \
    awk -F' = ' '/BUILT_PRODUCTS_DIR = / {print $2}' | head -1)

RIFFMCP_PATH="$BUILT_PRODUCTS_DIR/RiffMCP.app/Contents/MacOS/RiffMCP"

# Test playing a single C4 note
TEST_MESSAGE='{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"play","arguments":{"tempo":120,"tracks":[{"instrument":"grand_piano","events":[{"time":0,"pitches":["C4"],"dur":1.0}]}]}}}'

CONTENT_LENGTH=${#TEST_MESSAGE}

echo "🎵 Playing C4 note..."

if (printf "Content-Length: %d\r\n\r\n%s" "$CONTENT_LENGTH" "$TEST_MESSAGE") | "$RIFFMCP_PATH" --stdio; then
    echo "✅ Note test completed!"
else
    echo "❌ Note test failed with exit code $?"
fi