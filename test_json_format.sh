#!/bin/bash

# Test with the exact JSON format from the working test
TEST_MESSAGE='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'

echo "Testing JSON format:"
echo "$TEST_MESSAGE"
echo ""
echo "Length: ${#TEST_MESSAGE}"
echo ""

# Validate JSON
echo "$TEST_MESSAGE" | python3 -m json.tool >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ JSON is valid"
else
    echo "❌ JSON is invalid"
fi