#!/bin/bash

# Test script to list available tools
set -euo pipefail

echo "🛠️  Testing available tools via Stdio Proxy..."

# Query Xcode for the actual build location
BUILT_PRODUCTS_DIR=$(xcodebuild \
    -scheme RiffMCP \
    -configuration Debug \
    -sdk macosx \
    -showBuildSettings 2>/dev/null | \
    awk -F' = ' '/BUILT_PRODUCTS_DIR = / {print $2}' | head -1)

RIFFMCP_PATH="$BUILT_PRODUCTS_DIR/RiffMCP.app/Contents/MacOS/RiffMCP"

# List tools request
TEST_MESSAGE='{"jsonrpc":"2.0","id":1,"method":"tools/list"}'

CONTENT_LENGTH=${#TEST_MESSAGE}

echo "🛠️  Listing available tools..."

if (printf "Content-Length: %d\r\n\r\n%s" "$CONTENT_LENGTH" "$TEST_MESSAGE") | "$RIFFMCP_PATH" --stdio; then
    echo "✅ Tools list completed!"
else
    echo "❌ Tools list failed with exit code $?"
fi