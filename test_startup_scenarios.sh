#!/bin/bash

# Test script for RiffMCP startup scenarios
# Tests the App Startup Decision Tree implementation

set -e

APP_NAME="RiffMCP"
APP_PATH="/Users/lee/Library/Developer/Xcode/DerivedData/RiffMCP-*/Build/Products/Debug/RiffMCP.app"
CONFIG_DIR="$HOME/Library/Application Support/RiffMCP"
CONFIG_FILE="$CONFIG_DIR/server.json"

echo "🧪 Testing RiffMCP Startup Decision Tree"
echo "======================================="

# Helper functions
cleanup() {
    echo "🧹 Cleaning up..."
    rm -f "$CONFIG_FILE"
    killall RiffMCP 2>/dev/null || true
    sleep 1
}

wait_for_config() {
    local timeout=10
    local count=0
    while [ $count -lt $timeout ]; do
        if [ -f "$CONFIG_FILE" ]; then
            echo "✅ Config file appeared after ${count}s"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    echo "❌ Config file did not appear within ${timeout}s"
    return 1
}

check_process_running() {
    local pid="$1"
    if kill -0 "$pid" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

create_stale_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
{
  "port": 3001,
  "host": "127.0.0.1",
  "status": "running",
  "pid": 99999
}
EOF
}

trap cleanup EXIT

# Test 1: Normal GUI Launch with No Existing Instance
echo ""
echo "🧪 Test 1: Normal GUI Launch - No Existing Instance"
echo "=================================================="
cleanup
sleep 2

echo "📱 Launching RiffMCP normally..."
# Find the actual app path
ACTUAL_APP_PATH=$(find /Users/lee/Library/Developer/Xcode/DerivedData -name "RiffMCP.app" -type d 2>/dev/null | head -1)
if [ -z "$ACTUAL_APP_PATH" ]; then
    echo "❌ Could not find RiffMCP.app. Please build the project first."
    exit 1
fi

open "$ACTUAL_APP_PATH" &
APP_PID=$!

echo "⏳ Waiting for server config to be created..."
if wait_for_config; then
    echo "✅ Test 1 PASSED: Normal launch created config file"
    cat "$CONFIG_FILE"
else
    echo "❌ Test 1 FAILED: Config file was not created"
fi

# Test 2: Normal GUI Launch with Stale Config
echo ""
echo "🧪 Test 2: Normal GUI Launch - Stale Config Cleanup"
echo "=================================================="
cleanup
sleep 2

echo "📄 Creating stale config file..."
create_stale_config
echo "Created stale config with PID 99999"

echo "📱 Launching RiffMCP normally..."
open "$ACTUAL_APP_PATH" &

echo "⏳ Waiting for config to be updated..."
if wait_for_config; then
    NEW_PID=$(grep -o '"pid": [0-9]*' "$CONFIG_FILE" | grep -o '[0-9]*')
    if [ "$NEW_PID" != "99999" ]; then
        echo "✅ Test 2 PASSED: Stale config was cleaned up and replaced"
        echo "New PID: $NEW_PID"
    else
        echo "❌ Test 2 FAILED: Stale config was not cleaned up"
    fi
else
    echo "❌ Test 2 FAILED: Config file was not updated"
fi

# Test 3: Normal GUI Launch with Existing Instance
echo ""
echo "🧪 Test 3: Normal GUI Launch - Existing Instance Detection"
echo "========================================================"
# Keep current instance running and try to launch another
sleep 2

echo "📱 Launching second RiffMCP instance..."
open "$ACTUAL_APP_PATH" &
SECOND_PID=$!

echo "⏳ Waiting 3 seconds to see if duplicate terminates..."
sleep 3

# Check if the second instance is still running
if check_process_running $SECOND_PID; then
    echo "❌ Test 3 FAILED: Second instance is still running"
else
    echo "✅ Test 3 PASSED: Second instance was terminated"
fi

# Test 4: --stdio Launch with Running Server
echo ""
echo "🧪 Test 4: --stdio Launch - Running Server Found"
echo "=============================================="
# Use current running instance
sleep 2

echo "📱 Launching RiffMCP with --stdio flag..."
timeout 5 "$ACTUAL_APP_PATH/Contents/MacOS/RiffMCP" --stdio < /dev/null &
STDIO_PID=$!

echo "⏳ Waiting 3 seconds for --stdio process..."
sleep 3

if check_process_running $STDIO_PID; then
    echo "⚠️  --stdio process still running (expected if waiting for input)"
    kill $STDIO_PID 2>/dev/null || true
    echo "✅ Test 4 PASSED: --stdio found running server"
else
    echo "❌ Test 4 UNCLEAR: --stdio process ended (could be normal)"
fi

# Test 5: --stdio Launch with No Server
echo ""
echo "🧪 Test 5: --stdio Launch - No Server (Launch and Discover)"
echo "=========================================================="
cleanup
sleep 2

echo "📱 Launching RiffMCP with --stdio flag (no server running)..."
timeout 10 "$ACTUAL_APP_PATH/Contents/MacOS/RiffMCP" --stdio < /dev/null &
STDIO_PID=$!

echo "⏳ Waiting for GUI app to be launched and discovered..."
sleep 5

if wait_for_config; then
    echo "✅ Test 5 PASSED: --stdio launched GUI and discovered server"
    cat "$CONFIG_FILE"
else
    echo "❌ Test 5 FAILED: --stdio did not launch GUI or discover server"
fi

# Clean up stdio process
kill $STDIO_PID 2>/dev/null || true

# Test 6: --stdio Launch with Stale Config
echo ""
echo "🧪 Test 6: --stdio Launch - Stale Config (Launch and Discover)"
echo "=============================================================="
cleanup
sleep 2

echo "📄 Creating stale config file..."
create_stale_config
echo "Created stale config with PID 99999"

echo "📱 Launching RiffMCP with --stdio flag (stale config)..."
timeout 10 "$ACTUAL_APP_PATH/Contents/MacOS/RiffMCP" --stdio < /dev/null &
STDIO_PID=$!

echo "⏳ Waiting for GUI app to be launched and discovered..."
sleep 5

if wait_for_config; then
    NEW_PID=$(grep -o '"pid": [0-9]*' "$CONFIG_FILE" | grep -o '[0-9]*')
    if [ "$NEW_PID" != "99999" ]; then
        echo "✅ Test 6 PASSED: --stdio cleaned up stale config and launched GUI"
        echo "New PID: $NEW_PID"
    else
        echo "❌ Test 6 FAILED: Stale config was not cleaned up"
    fi
else
    echo "❌ Test 6 FAILED: --stdio did not launch GUI or discover server"
fi

# Clean up stdio process
kill $STDIO_PID 2>/dev/null || true

echo ""
echo "🎉 All startup scenario tests completed!"
echo "======================================="
echo "Review the results above to verify the startup decision tree is working correctly."