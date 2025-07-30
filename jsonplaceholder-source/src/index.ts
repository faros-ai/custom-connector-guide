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

/** The main entry point. */
export function mainCommand(): Command {
  const logger = new AirbyteSourceLogger();
  const source = new JSONPlaceholderSource(logger);
  return new AirbyteSourceRunner(logger, source).mainCommand();
}

/** JSONPlaceholder source implementation. */
export class JSONPlaceholderSource extends AirbyteSourceBase<SourceConfig> {
  get type(): string {
    return 'jsonplaceholder';
  }

  async spec(): Promise<AirbyteSpec> {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    return new AirbyteSpec(require('../resources/spec.json'));
  }
  
  async checkConnection(config: SourceConfig): Promise<[boolean, VError]> {
    try {
      const apiUrl = config.api_url || 'https://jsonplaceholder.typicode.com';
      const response = await axios.get(`${apiUrl}/users/1`, {
        timeout: 5000
      });
      
      if (response.status === 200) {
        return [true, null as any];
      }
      
      return [false, new VError('Failed to connect to JSONPlaceholder API')];
    } catch (error) {
      return [false, new VError('Connection check failed: %s', error instanceof Error ? error.message : String(error))];
    }
  }
  
  streams(config: SourceConfig): AirbyteStreamBase[] {
    return [
      new Users(config, this.logger),
      new Todos(config, this.logger),
    ];
  }
}