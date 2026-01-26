import { FarosDestinationRunner } from "airbyte-faros-destination";
import { Command } from "commander";

import { Todos } from "./converters/jsonplaceholder/todos";
import { Users } from "./converters/jsonplaceholder/users";

// Main entry point
export function mainCommand(): Command {
  const destinationRunner = new FarosDestinationRunner();

  // Register your custom converter(s)
  destinationRunner.registerConverters(new Users(), new Todos());

  return destinationRunner.program;
}
