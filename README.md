# Airbyte Custom Connector Guide

This directory contains a complete, self-contained walkthrough guide for building custom Airbyte connectors using the JSONPlaceholder API as an example.

## Contents

- **WALKTHROUGH.md** - Comprehensive step-by-step guide
- **sources/jsonplaceholder-source/** - JSONPlaceholder source connector
- **destinations/airbyte-faros-destination/** - Faros destination with JSONPlaceholder converters

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
   $SRC_PATH/bin/main read --config $SRC_PATH/test_files/config.json --catalog $SRC_PATH/test_files/catalog
   ```
4. Test source + destination end-to-end:
   ```bash
   export SRC_PATH=sources/jsonplaceholder-source
   export DST_PATH=destinations/airbyte-faros-destination
   $SRC_PATH/bin/main read --config $SRC_PATH/test_files/config.json --catalog $SRC_PATH/test_files/catalog | \
   jq -c 'if .type == "RECORD" then .record.stream = "mytestsource__jsonplaceholder__\(.record.stream)" else . end' | \
   $DST_PATH/bin/main write --config $DST_PATH/test_files/config.json --catalog $DST_PATH/test_files/catalog
   ```

## What You'll Learn

- How to create an Airbyte source connector
- How to implement streams for reading data
- How to support incremental syncing
- How to create Faros destination converters
- How to map external data to the Faros schema
- How to test and deploy your connector

## Project Structure

This guide contains a self-contained example with all necessary components:

```
custom-connector-guide/
├── sources/                             # Source connectors
│   └── jsonplaceholder-source/          # Example source connector
│       ├── src/                         # Source code
│       │   ├── index.ts                 # Main source class
│       │   └── streams/                 # Stream implementations
│       │       ├── users.ts
│       │       └── todos.ts
│       └── resources/                   # Configuration and schemas
│           ├── spec.json
│           └── schemas/
│               ├── users.json
│               └── todos.json
│
├── destinations/                        # Destination connectors
│   └── airbyte-faros-destination/       # Custom Faros destination
│       ├── src/
│       │   ├── index.ts                 # Main entry point
│       │   └── converters/
│       │       └── jsonplaceholder/     # JSONPlaceholder converters
│       │           ├── users.ts         # Users converter
│       │           └── todos.ts         # Todos converter
│       ├── bin/main                     # Executable entry point
│       └── package.json
│
├── WALKTHROUGH.md                       # Detailed guide
└── README.md                           # This file
```

## Key Concepts

- **Source**: Reads data from external systems (JSONPlaceholder API in this example)
- **Streams**: Different types of data from the source (users, todos)
- **Converters**: Transform source data to Faros canonical models
- **Faros Schema**: Standardized data models (tms_User, tms_Task, etc.)

## Requirements

- Node.js 22+
- npm
- Basic TypeScript knowledge
- Docker (optional, for containerization)

## Note

This is a simplified example for educational purposes. In a real-world scenario:
- The source would be more complex with actual API integration
- Error handling and logging would be more comprehensive
