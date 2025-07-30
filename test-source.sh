#!/bin/bash

# Script to test the JSONPlaceholder source locally

set -e

echo "🧪 Testing JSONPlaceholder Source..."

# Change to source directory
cd jsonplaceholder-source

# Create secrets directory if it doesn't exist
mkdir -p secrets

# Create test config
cat > secrets/config.json << EOF
{
  "api_url": "https://jsonplaceholder.typicode.com"
}
EOF

echo "📋 Testing spec command..."
bin/main spec

echo ""
echo "🔌 Testing connection..."
bin/main check --config secrets/config.json

echo ""
echo "🔍 Testing discover command..."
bin/main discover --config secrets/config.json > test_files/discovered_catalog.json
echo "✅ Catalog saved to test_files/discovered_catalog.json"

# Create configured catalog for testing
cat > test_files/full_configured_catalog.json << EOF
{
  "streams": [
    {
      "stream": {
        "name": "users",
        "json_schema": {
          "$schema": "http://json-schema.org/draft-07/schema#",
          "type": "object",
          "properties": {
            "id": {"type": "integer"},
            "name": {"type": "string"},
            "username": {"type": "string"},
            "email": {"type": "string"}
          }
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
          "type": "object",
          "properties": {
            "userId": {"type": "integer"},
            "id": {"type": "integer"},
            "title": {"type": "string"},
            "completed": {"type": "boolean"}
          }
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

echo ""
echo "📖 Testing read command (first 5 records)..."
bin/main read --config secrets/config.json --catalog test_files/full_configured_catalog.json | head -20

echo ""
echo "✅ Source tests completed successfully!"