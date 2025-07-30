#!/bin/bash

# Script to test the JSONPlaceholder converter with detailed output

set -e

echo "🧪 Testing JSONPlaceholder Converter with Detailed Output..."

# Create temporary directory for test files
TEMP_DIR=$(mktemp -d)
echo "📁 Using temporary directory: $TEMP_DIR"

# Create test data file with sample records
cat > $TEMP_DIR/test_records.jsonl << EOF
{"type":"RECORD","record":{"stream":"jsonplaceholder__JSONPlaceholder__users","data":{"id":1,"name":"Leanne Graham","username":"Bret","email":"Sincere@april.biz"},"emitted_at":1234567890}}
{"type":"RECORD","record":{"stream":"jsonplaceholder__JSONPlaceholder__users","data":{"id":2,"name":"Ervin Howell","username":"Antonette","email":"Shanna@melissa.tv"},"emitted_at":1234567891}}
{"type":"RECORD","record":{"stream":"jsonplaceholder__JSONPlaceholder__todos","data":{"userId":1,"id":1,"title":"delectus aut autem","completed":false},"emitted_at":1234567892}}
{"type":"RECORD","record":{"stream":"jsonplaceholder__JSONPlaceholder__todos","data":{"userId":1,"id":2,"title":"quis ut nam facilis et officia qui","completed":false},"emitted_at":1234567893}}
{"type":"RECORD","record":{"stream":"jsonplaceholder__JSONPlaceholder__todos","data":{"userId":2,"id":3,"title":"fugiat veniam minus","completed":false},"emitted_at":1234567894}}
EOF

echo "📋 Testing converter with sample data..."
echo ""

# Use the local destination
cd destinations/airbyte-faros-destination

# Run the converter and display output
echo "📊 Converter Output:"
echo "===================="
cat $TEMP_DIR/test_records.jsonl | node lib/index.js | grep -E "Converted|Error" || true
echo "===================="

echo ""
echo "✅ Converter detailed test completed!"

# Clean up
rm -rf $TEMP_DIR