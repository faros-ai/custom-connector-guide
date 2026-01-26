# Airbyte Custom Connector Walkthrough Guide

This guide will walk you through building a complete Airbyte connector using the free JSONPlaceholder API. By the end of this tutorial, you'll have:

1. A working Airbyte source that reads users and todos from JSONPlaceholder
2. A Faros destination converter that maps this data to the Faros schema
3. An end-to-end data pipeline from JSONPlaceholder to Faros

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Part 1: Creating the Source](#part-1-creating-the-source)
- [Part 2: Creating the Converter](#part-2-creating-the-converter)
- [Part 3: Testing Everything](#part-3-testing-everything)
- [Part 4: Docker Deployment](#part-4-docker-deployment)
- [Key Concepts Explained](#key-concepts-explained)

## Overview

### What is JSONPlaceholder?

[JSONPlaceholder](https://jsonplaceholder.typicode.com/) is a free online REST API that provides fake data for testing and prototyping. It requires no authentication and provides several endpoints including:
- `/users` - 10 users with detailed information
- `/todos` - 200 todo items assigned to users

### Architecture

```
JSONPlaceholder API → Airbyte Source → Airbyte Platform → Faros Destination → Faros Graph
                            ↓                                      ↓
                     (reads data)                          (converts to Faros models)
                            ↓                                      ↓
                    users, todos                        tms_User, tms_Task, tms_TaskAssignment
```

### Project Structure

This guide includes a self-contained example with all necessary components:

```
custom-connector-guide/
├── sources/                             # Source connectors
│   └── jsonplaceholder-source/          # Example source connector
├── destinations/                        # Destination connectors
│   └── airbyte-faros-destination/       # Custom Faros destination
│       └── src/converters/
│           └── jsonplaceholder/         # JSONPlaceholder converters
│               ├── users.ts
│               └── todos.ts
├── setup.sh                             # Setup script
├── test-source.sh                       # Source testing script
├── test-converter.sh                    # Converter testing script
└── run-e2e.sh                          # End-to-end test script
```

## Prerequisites

- Node.js 22 or later
- npm
- Docker (for containerization)
- Basic knowledge of TypeScript
- Familiarity with REST APIs

## Part 1: Creating the Source

### Step 1: Set Up the Project Structure

```bash
# Copy the example source as a template
cp -r sources/example-source custom-connector-guide/sources/jsonplaceholder-source
cd custom-connector-guide/sources/jsonplaceholder-source
```

### Step 2: Update package.json

Edit `package.json` to rename the package:

```json
{
  "name": "jsonplaceholder-source",
  "version": "0.0.1",
  "description": "JSONPlaceholder Airbyte source",
  ...
}
```

### Step 3: Define the Configuration Spec

Create `resources/spec.json` to define what configuration the source needs:

```json
{
  "documentationUrl": "https://jsonplaceholder.typicode.com/",
  "connectionSpecification": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "JSONPlaceholder Spec",
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "api_url": {
        "type": "string",
        "title": "API URL",
        "description": "The base URL for the JSONPlaceholder API",
        "default": "https://jsonplaceholder.typicode.com",
        "examples": ["https://jsonplaceholder.typicode.com"]
      }
    }
  }
}
```

### Step 4: Create Data Schemas

Define the structure of the data we'll be reading.

Create `resources/schemas/users.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "id": {"type": "integer"},
    "name": {"type": "string"},
    "username": {"type": "string"},
    "email": {"type": "string"},
    "address": {
      "type": "object",
      "properties": {
        "street": {"type": "string"},
        "suite": {"type": "string"},
        "city": {"type": "string"},
        "zipcode": {"type": "string"},
        "geo": {
          "type": "object",
          "properties": {
            "lat": {"type": "string"},
            "lng": {"type": "string"}
          }
        }
      }
    },
    "phone": {"type": "string"},
    "website": {"type": "string"},
    "company": {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "catchPhrase": {"type": "string"},
        "bs": {"type": "string"}
      }
    }
  }
}
```

Create `resources/schemas/todos.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "userId": {"type": "integer"},
    "id": {"type": "integer"},
    "title": {"type": "string"},
    "completed": {"type": "boolean"}
  }
}
```

### Step 5: Update the Configuration Interface

Edit `src/config.ts`:

```typescript
import {AirbyteConfig} from 'faros-airbyte-cdk';

export interface SourceConfig extends AirbyteConfig {
  readonly api_url?: string;
}
```

### Step 6: Implement the Main Source Class

Edit `src/index.ts`:

```typescript
import {Command} from 'commander';
import {
  AirbyteSourceBase,
  AirbyteSourceLogger,
  AirbyteSourceRunner,
  AirbyteSpec,
  AirbyteStreamBase,
} from 'faros-airbyte-cdk';
import VError from 'verror';
import axios from 'axios';

import {SourceConfig} from './config';
import {Users, Todos} from './streams';

export function mainCommand(): Command {
  const logger = new AirbyteSourceLogger();
  const source = new JSONPlaceholderSource(logger);
  return new AirbyteSourceRunner(logger, source).mainCommand();
}

export class JSONPlaceholderSource extends AirbyteSourceBase<SourceConfig> {
  get type(): string {
    return 'jsonplaceholder';
  }

  async spec(): Promise<AirbyteSpec> {
    return new AirbyteSpec(require('../resources/spec.json'));
  }
  
  async checkConnection(config: SourceConfig): Promise<[boolean, VError]> {
    try {
      const apiUrl = config.api_url || 'https://jsonplaceholder.typicode.com';
      const response = await axios.get(`${apiUrl}/users/1`, {
        timeout: 5000
      });
      
      if (response.status === 200) {
        return [true, undefined];
      }
      
      return [false, new VError('Failed to connect to JSONPlaceholder API')];
    } catch (error) {
      return [false, new VError(error, 'Connection check failed')];
    }
  }
  
  streams(config: SourceConfig): AirbyteStreamBase[] {
    return [
      new Users(config, this.logger),
      new Todos(config, this.logger),
    ];
  }
}
```

### Step 7: Implement the Streams

Create `src/streams/users.ts`:

```typescript
import {
  AirbyteLogger,
  AirbyteStreamBase,
  StreamKey,
  SyncMode,
} from 'faros-airbyte-cdk';
import {Dictionary} from 'ts-essentials';
import axios from 'axios';

import {SourceConfig} from '../config';

export class Users extends AirbyteStreamBase {
  constructor(
    private readonly config: SourceConfig,
    protected readonly logger: AirbyteLogger
  ) {
    super(logger);
  }

  getJsonSchema(): Dictionary<any, string> {
    return require('../../resources/schemas/users.json');
  }
  
  get primaryKey(): StreamKey {
    return 'id';
  }
  
  get cursorField(): string | string[] {
    return 'id';
  }

  async *readRecords(
    syncMode: SyncMode,
    cursorField?: string[],
    streamSlice?: Dictionary<any, string>,
    streamState?: Dictionary<any, string>
  ): AsyncGenerator<Dictionary<any, string>, any, unknown> {
    const apiUrl = this.config.api_url || 'https://jsonplaceholder.typicode.com';
    
    try {
      const lastId = streamState?.lastId || 0;
      
      this.logger.info(`Fetching users from JSONPlaceholder API...`);
      const response = await axios.get(`${apiUrl}/users`);
      
      const users = response.data as any[];
      users.sort((a, b) => a.id - b.id);
      
      for (const user of users) {
        if (syncMode === SyncMode.INCREMENTAL && user.id <= lastId) {
          continue;
        }
        yield user;
      }
    } catch (error) {
      this.logger.error(`Error fetching users: ${error.message}`);
      throw error;
    }
  }

  getUpdatedState(
    currentStreamState: Dictionary<any>,
    latestRecord: Dictionary<any>
  ): Dictionary<any> {
    return {
      lastId: Math.max(
        currentStreamState.lastId || 0,
        latestRecord.id || 0
      ),
    };
  }
}
```

Create a similar `src/streams/todos.ts` file with the same pattern but for todos.

### Step 8: Build and Test the Source

```bash
# Install dependencies
npm install

# Build the source
npm run build

# Create test configuration
mkdir -p secrets
echo '{"api_url": "https://jsonplaceholder.typicode.com"}' > secrets/config.json

# Test the source
bin/main spec
bin/main check --config secrets/config.json
bin/main discover --config secrets/config.json
```

## Part 2: Creating the Converter

### Step 1: Understanding the Converter Location

In this guide, we have a self-contained example of the Faros destination with just the JSONPlaceholder converters. The converters are located at:

```
destinations/airbyte-faros-destination/src/converters/jsonplaceholder/
```

Note: In a real-world scenario, you would add converters to the main Faros destination repository following the same pattern as other converters like `asana/`, `azure-workitems/`, etc.

### Step 2: Implement the Converters

Create `destinations/airbyte-faros-destination/src/converters/jsonplaceholder/users.ts`:

```typescript
import {AirbyteRecord} from 'faros-airbyte-cdk';

import {DestinationModel, DestinationRecord, StreamContext} from '../converter';
import {Converter} from '../converter';

interface JSONPlaceholderUser {
  id: number;
  name: string;
  username: string;
  email: string;
  // ... other fields
}

export class Users extends Converter {
  source = 'JSONPlaceholder';
  
  readonly destinationModels: ReadonlyArray<DestinationModel> = ['tms_User'];

  id(record: AirbyteRecord): string {
    return String(record.record.data.id);
  }

  async convert(
    record: AirbyteRecord,
    ctx?: StreamContext
  ): Promise<ReadonlyArray<DestinationRecord>> {
    const user = record.record.data as JSONPlaceholderUser;
    
    return [
      {
        model: 'tms_User',
        record: {
          uid: String(user.id),
          name: user.name,
          emailAddress: user.email,
          source: this.source,
          inactive: false,
        },
      },
    ];
  }
}
```

Create `destinations/airbyte-faros-destination/src/converters/jsonplaceholder/todos.ts`:

```typescript
import {AirbyteRecord} from 'faros-airbyte-cdk';

import {DestinationModel, DestinationRecord, StreamContext} from '../converter';
import {Converter} from '../converter';

interface JSONPlaceholderTodo {
  userId: number;
  id: number;
  title: string;
  completed: boolean;
}

export class Todos extends Converter {
  source = 'JSONPlaceholder';
  
  readonly destinationModels: ReadonlyArray<DestinationModel> = [
    'tms_Task',
    'tms_TaskAssignment',
  ];

  id(record: AirbyteRecord): string {
    return String(record.record.data.id);
  }

  async convert(
    record: AirbyteRecord,
    ctx?: StreamContext
  ): Promise<ReadonlyArray<DestinationRecord>> {
    const todo = record.record.data as JSONPlaceholderTodo;
    const results: DestinationRecord[] = [];
    
    // Convert todo to tms_Task
    results.push({
      model: 'tms_Task',
      record: {
        uid: String(todo.id),
        name: todo.title,
        description: `Todo item: ${todo.title}`,
        type: {
          category: 'Task',
          detail: 'todo',
        },
        status: {
          category: todo.completed ? 'Done' : 'Todo',
          detail: todo.completed ? 'completed' : 'pending',
        },
        source: this.source,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        resolvedAt: todo.completed ? new Date().toISOString() : null,
      },
    });
    
    // Create task assignment
    if (todo.userId) {
      results.push({
        model: 'tms_TaskAssignment',
        record: {
          task: {
            uid: String(todo.id),
            source: this.source,
          },
          assignee: {
            uid: String(todo.userId),
            source: this.source,
          },
        },
      });
    }
    
    return results;
  }
}
```

### Step 3: How Converters Are Discovered

The converters are automatically discovered by the Faros destination based on the stream name pattern. No manual registration is needed. The naming convention is:

- Stream name: `<origin>__<source>__<stream>`
- Example: `jsonplaceholder__JSONPlaceholder__users`

The destination will automatically find and use the `Users` class in the `jsonplaceholder` directory.

## Part 3: Testing Everything

### Using the Helper Scripts

We've provided several helper scripts to make testing easier:

1. **setup.sh** - Sets up the entire development environment
2. **test-source.sh** - Tests the JSONPlaceholder source
3. **test-converter.sh** - Tests the Faros destination converter
4. **run-e2e.sh** - Runs an end-to-end test

### Running the Setup

```bash
cd custom-connector-guide
./setup.sh
```

### Testing the Source

```bash
./test-source.sh
```

This will:
- Test the spec command
- Check the connection
- Discover available streams
- Read some sample data

### Testing the Converter

```bash
./test-converter.sh
```

This will:
- Create sample JSONPlaceholder records
- Run them through the converter
- Show how they map to Faros models

### End-to-End Test

```bash
./run-e2e.sh
```

This will:
- Read real data from JSONPlaceholder API
- Convert it to Faros models
- Show a summary of converted records

## Part 4: Docker Deployment

### Building Docker Images

For the source:

```bash
# From the root of the main repository
docker build . --build-arg path=sources/jsonplaceholder-source --build-arg version=0.0.1 -t jsonplaceholder-source
```

For the destination (from within the guide directory):

```bash
docker build . --build-arg path=destinations/airbyte-faros-destination --build-arg version=0.0.1 -t airbyte-faros-destination
```

### Running with Docker

```bash
# Test the source
docker run --rm jsonplaceholder-source spec
docker run --rm -v $(pwd)/secrets:/secrets jsonplaceholder-source check --config /secrets/config.json

# Read data
docker run --rm -v $(pwd)/secrets:/secrets -v $(pwd)/test_files:/test_files jsonplaceholder-source read --config /secrets/config.json --catalog /test_files/catalog.json
```

## Key Concepts Explained

### Streams

Streams represent different types of data from your source. Each stream:
- Has a schema (JSON Schema)
- Has a primary key
- Can support incremental syncing with a cursor field
- Implements `readRecords()` to fetch data

### Sync Modes

- **Full Refresh**: Reads all data every time
- **Incremental**: Only reads new/updated data based on a cursor field

### Converters

Converters transform source data into Faros models:
- Each converter handles one stream
- Maps source fields to destination fields
- Can create multiple destination records from one source record

### Faros Schema

The Faros schema uses namespaces:
- `tms_` - Task Management System (Jira-like)
- `vcs_` - Version Control System (Git-like)
- `cicd_` - CI/CD systems
- etc.

For this guide, we used:
- `tms_User` - Represents a user
- `tms_Task` - Represents a task/issue
- `tms_TaskAssignment` - Links tasks to users

## Common Issues and Solutions

### Issue: Connection Failed

**Solution**: Check that the API URL is correct and accessible. The default should work unless JSONPlaceholder is down.

### Issue: No Data Returned

**Solution**: Check the catalog configuration. Make sure the stream names match exactly.

### Issue: Converter Not Found

**Solution**: Ensure the stream name follows the pattern: `<origin>__<source>__<stream>`. For example: `jsonplaceholder__JSONPlaceholder__users`

### Issue: Type Errors

**Solution**: Make sure all dependencies are installed and the TypeScript version matches the project requirements.

## Next Steps

Now that you have a working connector:

1. **Add More Streams**: JSONPlaceholder has posts, comments, albums, and photos
2. **Enhance Mappings**: Add more fields or create relationships between models
3. **Add Tests**: Write unit tests for your streams and converters
4. **Production Setup**: Configure real Faros API credentials and remove dry_run mode
5. **Deploy to Airbyte**: Add your connector to an Airbyte instance

## Additional Resources

- [Airbyte Documentation](https://docs.airbyte.com/)
- [JSONPlaceholder API Docs](https://jsonplaceholder.typicode.com/)

## Summary

Congratulations! You've built a complete Airbyte connector that:
- Reads data from an external API
- Supports incremental syncing
- Converts data to the Faros canonical schema
- Can be deployed as Docker containers

This pattern can be applied to build connectors for any API or data source!