# Airbyte Custom Connector Guide

This directory contains a complete, self-contained walkthrough guide for building custom Airbyte connectors using the JSONPlaceholder API as an example.

## Contents

- **WALKTHROUGH.md** - Comprehensive step-by-step guide
- **sources/jsonplaceholder-source/** - JSONPlaceholder source connector
- **destinations/airbyte-faros-destination/** - Faros destination with JSONPlaceholder converters

## Requirements

- Node.js 24+
- npm
- jq (for stream prefixing in end-to-end tests)
- Docker (optional, for containerization)

## Quick Start

1. Read the [WALKTHROUGH.md](./WALKTHROUGH.md) guide
2. Install dependencies and build (required before running any commands):
   ```bash
   npm install
   npm run build
   ```
3. Test the source:
   ```bash
   export SRC_PATH=sources/jsonplaceholder-source
   $SRC_PATH/bin/main read --config $SRC_PATH/test_files/config.json --catalog $SRC_PATH/test_files/catalog.json
   ```
4. Test the destination:
   ```bash
   export DST_PATH=destinations/airbyte-faros-destination
   cat << 'EOF' | $DST_PATH/bin/main write --config $DST_PATH/test_files/config.json --catalog $DST_PATH/test_files/catalog.json
   {"type":"RECORD","record":{"stream":"mytestsource__jsonplaceholder__users","data":{"id":1,"name":"Test User","email":"test@example.com"},"emitted_at":1234567890}}
   {"type":"RECORD","record":{"stream":"mytestsource__jsonplaceholder__todos","data":{"userId":1,"id":1,"title":"Test Todo","completed":false},"emitted_at":1234567891}}
   EOF
   ```
5. Test source + destination end-to-end:
   ```bash
   export SRC_PATH=sources/jsonplaceholder-source
   export DST_PATH=destinations/airbyte-faros-destination
   $SRC_PATH/bin/main read --config $SRC_PATH/test_files/config.json --catalog $SRC_PATH/test_files/catalog.json | \
   jq -c 'if .type == "RECORD" then .record.stream = "mytestsource__jsonplaceholder__\(.record.stream)" else . end' | \
   $DST_PATH/bin/main write --config $DST_PATH/test_files/config.json --catalog $DST_PATH/test_files/catalog.json
   ```

## What You'll Learn

- How to create an Airbyte source connector
- How to implement streams for reading data
- How to support incremental syncing
- How to create Faros destination converters
- How to map external data to the Faros schema
- How to test and deploy your connector

## Project Structure

```
custom-connector-guide/
├── sources/
│   └── jsonplaceholder-source/
│       ├── src/                         # Source code
│       ├── resources/                   # Spec and schemas
│       ├── test/                        # Jest tests
│       ├── test_files/                  # Manual test configs
│       └── bin/main                     # Entry point
│
├── destinations/
│   └── airbyte-faros-destination/
│       ├── src/converters/jsonplaceholder/  # Converters
│       ├── test/                        # Jest tests
│       ├── test_files/                  # Manual test configs
│       └── bin/main                     # Entry point
│
├── docker/                              # Docker entrypoint
├── Dockerfile                           # Multi-stage build
├── turbo.json                           # Turborepo config
├── package.json                         # Root package
├── WALKTHROUGH.md                       # Detailed guide
└── README.md
```

## Key Concepts

- **Source**: Reads data from external systems (JSONPlaceholder API in this example)
- **Streams**: Different types of data from the source (users, todos)
- **Converters**: Transform source data to Faros canonical models
- **Faros Schema**: Standardized data models (tms_User, tms_Task, etc.)

## Note

This is a simplified example for educational purposes. In a real-world scenario:
- The source would be more complex with actual API integration
- Error handling and logging would be more comprehensive
