#!/bin/bash

# End-to-end test script for JSONPlaceholder connector

set -e

echo "🚀 Running End-to-End Test for JSONPlaceholder Connector..."

# Create temporary directory for test
TEMP_DIR=$(mktemp -d)
echo "📁 Using temporary directory: $TEMP_DIR"

# Change to source directory
cd jsonplaceholder-source

# Create config
mkdir -p secrets
cat > secrets/config.json << EOF
{
  "api_url": "https://jsonplaceholder.typicode.com"
}
EOF

# Create catalog
mkdir -p test_files
cat > test_files/full_configured_catalog.json << EOF
{
  "streams": [
    {
      "stream": {
        "name": "users",
        "json_schema": {
          "$schema": "http://json-schema.org/draft-07/schema#",
          "type": "object"
        },
        "supported_sync_modes": ["full_refresh", "incremental"],
        "source_defined_cursor": true,
        "default_cursor_field": ["id"],
        "source_defined_primary_key": [["id"]]
      },
      "sync_mode": "full_refresh",
      "destination_sync_mode": "overwrite"
    },
    {
      "stream": {
        "name": "todos",
        "json_schema": {
          "$schema": "http://json-schema.org/draft-07/schema#",
          "type": "object"
        },
        "supported_sync_modes": ["full_refresh", "incremental"],
        "source_defined_cursor": true,
        "default_cursor_field": ["id"],
        "source_defined_primary_key": [["id"]]
      },
      "sync_mode": "full_refresh",
      "destination_sync_mode": "overwrite"
    }
  ]
}
EOF

echo "📖 Reading data from JSONPlaceholder API..."
bin/main read --config secrets/config.json --catalog test_files/full_configured_catalog.json > $TEMP_DIR/source_output.jsonl

# Add stream prefix as expected by Faros destination
cat $TEMP_DIR/source_output.jsonl | jq -c 'select(.type == "RECORD") | .record.stream = "jsonplaceholder__JSONPlaceholder__\(.record.stream)"' > $TEMP_DIR/prefixed_output.jsonl

# Change to local Faros destination directory
cd ../destinations/airbyte-faros-destination

# Create destination config
cat > $TEMP_DIR/dest_config.json << EOF
{
  "dry_run": true
}
EOF

# Create destination catalog
cat > $TEMP_DIR/dest_catalog.json << EOF
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

echo ""
echo "🔄 Converting data to Faros models..."
cat $TEMP_DIR/prefixed_output.jsonl | bin/main write --config $TEMP_DIR/dest_config.json --catalog $TEMP_DIR/dest_catalog.json > $TEMP_DIR/conversion_output.log 2>&1

echo ""
echo "📊 Summary of converted records:"
echo "- Source records read: $(grep -c '"type":"RECORD"' $TEMP_DIR/source_output.jsonl || echo 0)"
echo "- Users found: $(grep -c '"stream":"users"' $TEMP_DIR/source_output.jsonl || echo 0)"
echo "- Todos found: $(grep -c '"stream":"todos"' $TEMP_DIR/source_output.jsonl || echo 0)"

echo ""
echo "✅ End-to-end test completed successfully!"
echo ""
echo "Note: This test ran in dry_run mode. To actually write to Faros:"
echo "1. Implement a real Faros destination writer"
echo "2. Set up your Faros API credentials"
echo "3. Remove the 'dry_run: true' option"

# Clean up
rm -rf $TEMP_DIR