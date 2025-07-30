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
      // For incremental sync, check if we have a state
      const lastId = streamState?.lastId || 0;
      
      this.logger.info(`Fetching users from JSONPlaceholder API...`);
      const response = await axios.get(`${apiUrl}/users`);
      
      const users = response.data as any[];
      
      // Sort by ID to ensure consistent ordering
      users.sort((a, b) => a.id - b.id);
      
      for (const user of users) {
        // For incremental sync, only return users with ID greater than lastId
        if (syncMode === SyncMode.INCREMENTAL && user.id <= lastId) {
          continue;
        }
        
        yield user;
      }
    } catch (error) {
      this.logger.error(`Error fetching users: ${error instanceof Error ? error.message : String(error)}`);
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