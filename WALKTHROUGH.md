# Airbyte Custom Connector Walkthrough Guide

This guide will walk you through building a complete Airbyte connector using the free JSONPlaceholder API. By the end of this tutorial, you'll have:

1. A working Airbyte source that reads users and todos from JSONPlaceholder
2. A Faros destination converter that maps this data to the Faros schema
3. An end-to-end data pipeline from JSONPlaceholder to Faros

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Part 1: Understanding the Source](#part-1-understanding-the-source)
- [Part 2: Understanding the Converters](#part-2-understanding-the-converters)
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

This guide includes a complete working example:

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
├── WALKTHROUGH.md                       # This guide
└── README.md
```

## Prerequisites

- Node.js 22 or later
- npm
- jq (for stream prefixing in end-to-end tests)
- Docker (optional, for containerization)
- Basic knowledge of TypeScript

## Part 1: Understanding the Source

This section explains the structure of the JSONPlaceholder source connector located in `sources/jsonplaceholder-source/`. Use this as a reference when building your own source.

### The Configuration Spec

The `resources/spec.json` file defines what configuration the source needs:

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

### Data Schemas

The `resources/schemas/` directory contains JSON Schema definitions for each stream.

`resources/schemas/users.json`:

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

`resources/schemas/todos.json`:

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

### Configuration Interface

The `src/config.ts` file defines the TypeScript interface for the source configuration:

```typescript
import {AirbyteConfig} from 'faros-airbyte-cdk';

export interface SourceConfig extends AirbyteConfig {
  readonly api_url?: string;
}
```

### Main Source Class

The `src/index.ts` file contains the main source class that ties everything together:

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

### Stream Implementations

Each stream is a class that defines how to read data from the API.

`src/streams/users.ts`:

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

The `src/streams/todos.ts` file follows the same pattern for todos.

### Building and Testing the Source

```bash
# Install dependencies
npm install

# Build the source
npm run build

# Test the source (using the provided test_files)
bin/main spec
bin/main check --config test_files/config.json
bin/main discover --config test_files/config.json
```

## Part 2: Understanding the Converters

This section explains the Faros destination converters located in `destinations/airbyte-faros-destination/src/converters/jsonplaceholder/`.

Converters transform source data into Faros canonical models. Each converter handles one stream type.

### Users Converter

`src/converters/jsonplaceholder/users.ts`:

```typescript
import {
  Converter,
  DestinationModel,
  DestinationRecord,
  StreamContext,
} from 'airbyte-faros-destination';
import {AirbyteRecord} from 'faros-airbyte-cdk';

interface JSONPlaceholderUser {
  id: number;
  name: string;
  username: string;
  email: string;
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

### Todos Converter

`src/converters/jsonplaceholder/todos.ts`:

```typescript
import {
  Converter,
  DestinationModel,
  DestinationRecord,
  StreamContext,
} from 'airbyte-faros-destination';
import {AirbyteRecord} from 'faros-airbyte-cdk';

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

### Converter Discovery

Converters are automatically discovered by the Faros destination based on the stream name pattern. No manual registration is needed. The naming convention is:

- Stream name: `<origin>__<source>__<stream>`
- Example: `mytestsource__jsonplaceholder__users`

The destination parses the stream name and finds the matching converter class (`Users`) in the `jsonplaceholder` directory.

## Part 3: Testing Everything

### Building the Project

From the root of the project, install dependencies and build:

```bash
npm install
npm run build
```

This uses Turborepo to build all packages in the correct order.

**Note:** The `bin/main` commands run the compiled JavaScript in the `lib/` directory, so you must run `npm run build` before testing. If you make changes to the source code, rebuild before testing again.

### Running Automated Tests

Both the source and destination have automated tests using Jest. Run all tests from the root:

```bash
npm test
```

Or run tests for a specific package:

```bash
# Source tests
npm test --workspace=sources/jsonplaceholder-source

# Destination converter tests (requires build first)
npm run build --workspace=destinations/airbyte-faros-destination
npm test --workspace=destinations/airbyte-faros-destination
```

The destination tests use `faros-airbyte-testing-tools` for snapshot testing of converter output. If you modify a converter, update snapshots with:

```bash
npm test --workspace=destinations/airbyte-faros-destination -- -u
```

### Testing the Source

Test individual source commands:

```bash
export SRC_PATH=sources/jsonplaceholder-source

# View the connector spec
$SRC_PATH/bin/main spec

# Check connection to the API
$SRC_PATH/bin/main check --config $SRC_PATH/test_files/config.json

# Discover available streams
$SRC_PATH/bin/main discover --config $SRC_PATH/test_files/config.json

# Read data from all streams
$SRC_PATH/bin/main read --config $SRC_PATH/test_files/config.json --catalog $SRC_PATH/test_files/catalog.json
```

### Testing the Destination Converter

To test the converter in isolation, you can pipe sample records through it:

```bash
export DST_PATH=destinations/airbyte-faros-destination

# Create sample test records
cat << 'EOF' | $DST_PATH/bin/main write --config $DST_PATH/test_files/config.json --catalog $DST_PATH/test_files/catalog.json
{"type":"RECORD","record":{"stream":"mytestsource__jsonplaceholder__users","data":{"id":1,"name":"Test User","email":"test@example.com"},"emitted_at":1234567890}}
{"type":"RECORD","record":{"stream":"mytestsource__jsonplaceholder__todos","data":{"userId":1,"id":1,"title":"Test Todo","completed":false},"emitted_at":1234567891}}
EOF
```

Note the stream naming convention: `origin__source__stream` (e.g., `mytestsource__jsonplaceholder__users`).

### End-to-End Test

Run a full pipeline from source to destination:

```bash
export SRC_PATH=sources/jsonplaceholder-source
export DST_PATH=destinations/airbyte-faros-destination

$SRC_PATH/bin/main read --config $SRC_PATH/test_files/config.json --catalog $SRC_PATH/test_files/catalog.json | \
jq -c 'if .type == "RECORD" then .record.stream = "mytestsource__jsonplaceholder__\(.record.stream)" else . end' | \
$DST_PATH/bin/main write --config $DST_PATH/test_files/config.json --catalog $DST_PATH/test_files/catalog.json
```

This command:
1. Reads data from the JSONPlaceholder API via the source
2. Uses `jq` to prefix stream names with the origin and source (required by the destination to find the correct converter)
3. Pipes the records to the destination which converts them to Faros models

The destination runs in `dry_run` mode by default (configured in `test_files/config.json`), so it will show what would be written without actually sending data to Faros.

## Part 4: Docker Deployment

### Building Docker Images

Build the source and destination images:

```bash
# Build source connector
docker build . --build-arg path=sources/jsonplaceholder-source --build-arg version=0.0.1 -t test/airbyte-jsonplaceholder-source

# Build destination connector
docker build . --build-arg path=destinations/airbyte-faros-destination --build-arg version=0.0.1 -t test/airbyte-faros-destination
```

### Running with Docker

You can test the images directly:

```bash
# Test the source spec
docker run --rm test/airbyte-jsonplaceholder-source spec

# Test the destination spec
docker run --rm test/airbyte-faros-destination spec
```

### Using airbyte-local-cli

The easiest way to run a full sync is with [airbyte-local-cli](https://github.com/faros-ai/airbyte-local-cli):

```bash
# Run source only (outputs records to stdout)
bash <(curl -s https://raw.githubusercontent.com/faros-ai/airbyte-local-cli/main/airbyte-local.sh) \
  --src 'test/airbyte-jsonplaceholder-source' \
  --no-src-pull \
  --src-only

# Run source + destination (dry run mode with state for incremental syncs)
bash <(curl -s https://raw.githubusercontent.com/faros-ai/airbyte-local-cli/main/airbyte-local.sh) \
  --src 'test/airbyte-jsonplaceholder-source' \
  --no-src-pull \
  --dst 'test/airbyte-faros-destination' \
  --dst.dry_run true \
  --no-dst-pull \
  --dst-stream-prefix "mytestsource__jsonplaceholder__" \
  --state ./state.json
```

The `--dst-stream-prefix` flag adds the required prefix to stream names so the destination can find the correct converters. The `--state` flag specifies a JSON file to read/write sync state, enabling incremental syncs across runs.

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

### Field Mapping Reference

Here's how JSONPlaceholder data maps to Faros models in this example:

**User Mapping (JSONPlaceholder → tms_User):**
| Source Field | Destination Field | Notes |
|--------------|-------------------|-------|
| `id` | `uid` | Converted to string |
| `name` | `name` | Direct mapping |
| `email` | `emailAddress` | Direct mapping |
| - | `source` | Fixed value: `"JSONPlaceholder"` |
| - | `inactive` | Fixed value: `false` |

**Todo Mapping (JSONPlaceholder → tms_Task):**
| Source Field | Destination Field | Notes |
|--------------|-------------------|-------|
| `id` | `uid` | Converted to string |
| `title` | `name` | Direct mapping |
| `title` | `description` | Prefixed with `"Todo item: "` |
| - | `type.category` | Fixed value: `"Task"` |
| - | `type.detail` | Fixed value: `"todo"` |
| `completed` | `status.category` | `false` → `"Todo"`, `true` → `"Done"` |
| `completed` | `status.detail` | `false` → `"pending"`, `true` → `"completed"` |
| - | `source` | Fixed value: `"JSONPlaceholder"` |

**Task Assignment (JSONPlaceholder → tms_TaskAssignment):**
| Source Field | Destination Field | Notes |
|--------------|-------------------|-------|
| `id` | `task.uid` | Reference to the task |
| `userId` | `assignee.uid` | Reference to the user |
| - | `task.source` | Fixed value: `"JSONPlaceholder"` |
| - | `assignee.source` | Fixed value: `"JSONPlaceholder"` |

## Common Issues and Solutions

### Issue: Connection Failed

**Solution**: Check that the API URL is correct and accessible. The default should work unless JSONPlaceholder is down.

### Issue: No Data Returned

**Solution**: Check the catalog configuration. Make sure the stream names match exactly.

### Issue: Converter Not Found

**Solution**: Ensure the stream name follows the pattern: `<origin>__<source>__<stream>`. For example: `mytestsource__jsonplaceholder__users`

### Issue: Type Errors

**Solution**: Make sure all dependencies are installed and the TypeScript version matches the project requirements.

## Next Steps

Now that you understand how the connector works:

1. **Add More Streams**: JSONPlaceholder has posts, comments, albums, and photos
2. **Enhance Mappings**: Add more fields or create relationships between models
3. **Extend Tests**: Add more test cases for edge cases and error handling
4. **Production Setup**: Configure real Faros API credentials and remove dry_run mode
5. **Build Your Own**: Use this as a template for your own source and converters

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