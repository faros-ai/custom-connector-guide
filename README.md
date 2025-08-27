# Airbyte Custom Connector Guide

This directory contains a complete, self-contained walkthrough guide for building custom Airbyte connectors using the JSONPlaceholder API as an example.

## Contents

- **WALKTHROUGH.md** - Comprehensive step-by-step guide
- **jsonplaceholder-source/** - Example source connector implementation
- **destinations/airbyte-faros-destination/** - Minimal Faros destination with JSONPlaceholder converters
- **setup.sh** - Script to set up the development environment
- **test-source.sh** - Script to test the JSONPlaceholder source
- **test-converter.sh** - Script to test the Faros destination converter
- **run-e2e.sh** - Script to run end-to-end tests

## Quick Start

1. Read the [WALKTHROUGH.md](./WALKTHROUGH.md) guide
2. Run `./setup.sh` to set up the environment
3. Follow the guide to understand how the connector works
4. Use the test scripts to verify everything is working

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
airbyte-custom-connector-guide/
├── jsonplaceholder-source/               # Example source connector
│   ├── src/                             # Source code
│   │   ├── index.ts                     # Main source class
│   │   └── streams/                     # Stream implementations
│   │       ├── users.ts
│   │       └── todos.ts
│   └── resources/                       # Configuration and schemas
│       ├── spec.json
│       └── schemas/
│           ├── users.json
│           └── todos.json
│
├── destinations/                        # Minimal Faros destination
│   └── airbyte-faros-destination/
│       ├── src/
│       │   ├── index.ts                 # Simplified destination
│       │   └── converters/
│       │       ├── converter.ts         # Base converter class
│       │       └── jsonplaceholder/     # JSONPlaceholder converters
│       │           ├── users.ts         # Users converter
│       │           └── todos.ts         # Todos converter
│       ├── bin/main                     # Executable entry point
│       └── package.json
│
├── WALKTHROUGH.md                       # Detailed guide
├── README.md                           # This file
└── *.sh                                # Helper scripts
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
