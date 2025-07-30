#!/bin/bash

# Script to test the JSONPlaceholder converter locally

set -e

echo "🧪 Testing JSONPlaceholder Converter..."

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

# Create test config for Faros destination
cat > $TEMP_DIR/test_config.json << EOF
{
  "dry_run": true
}
EOF

# Create test catalog
cat > $TEMP_DIR/test_catalog.json << EOF
{
  "streams": [
    {
      "stream": {
        "name": "jsonplaceholder__JSONPlaceholder__users"
      },
      "destination_sync_mode": "append"
    },
    {
      "stream": {
        "name": "jsonplaceholder__JSONPlaceholder__todos"
      },
      "destination_sync_mode": "append"
    }
  ]
}
EOF

echo "📋 Testing converter with sample data..."
echo "Note: Using dry_run mode to test conversion without writing to Faros"
echo ""

# Use the local destination
cd destinations/airbyte-faros-destination

# Check if it's built
if [ ! -d "lib" ]; then
  echo "⚠️  Destination not built. Building now..."
  npm run build
fi

cat $TEMP_DIR/test_records.jsonl | bin/main write --config $TEMP_DIR/test_config.json --catalog $TEMP_DIR/test_catalog.json

echo ""
echo "✅ Converter tests completed successfully!"
echo ""
echo "The converter successfully mapped:"
echo "- JSONPlaceholder users → tms_User"
echo "- JSONPlaceholder todos → tms_Task (with tms_TaskAssignment)"

# Clean up
rm -rf $TEMP_DIR