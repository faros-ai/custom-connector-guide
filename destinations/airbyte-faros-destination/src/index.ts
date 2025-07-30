#!/usr/bin/env node

import {Users as JSONPlaceholderUsers} from './converters/jsonplaceholder/users';
import {Todos as JSONPlaceholderTodos} from './converters/jsonplaceholder/todos';

// Simple destination that processes records and converts them
async function main() {
  const usersConverter = new JSONPlaceholderUsers();
  const todosConverter = new JSONPlaceholderTodos();
  
  // Read from stdin line by line
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
  });

  for await (const line of rl) {
    try {
      const msg = JSON.parse(line);
      
      if (msg.type === 'RECORD') {
        const streamName = msg.record.stream;
        
        // Route to appropriate converter based on stream name
        if (streamName.includes('users')) {
          const converted = await usersConverter.convert(msg);
          console.log('Converted user:', JSON.stringify(converted));
        } else if (streamName.includes('todos')) {
          const converted = await todosConverter.convert(msg);
          console.log('Converted todo:', JSON.stringify(converted));
        }
      } else if (msg.type === 'STATE') {
        // Echo state messages
        console.log(JSON.stringify(msg));
      }
    } catch (error) {
      console.error('Error processing line:', error);
    }
  }
}

// Export for testing
export {JSONPlaceholderUsers, JSONPlaceholderTodos};

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}