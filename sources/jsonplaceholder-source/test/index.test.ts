import { AirbyteSourceLogger } from "faros-airbyte-cdk";

import { JSONPlaceholderSource } from "../src/index";

describe("JSONPlaceholderSource", () => {
  const logger = new AirbyteSourceLogger();
  const source = new JSONPlaceholderSource(logger);

  test("spec", async () => {
    const spec = await source.spec();
    expect(spec.spec.documentationUrl).toBe(
      "https://jsonplaceholder.typicode.com/",
    );
  });

  test("checkConnection - success", async () => {
    const config = {
      api_url: "https://jsonplaceholder.typicode.com",
    };

    const [success, error] = await source.checkConnection(config);
    expect(success).toBe(true);
    expect(error).toBeUndefined();
  });

  test("checkConnection - failure", async () => {
    const config = {
      api_url: "https://invalid.jsonplaceholder.typicode.com",
    };

    const [success, error] = await source.checkConnection(config);
    expect(success).toBe(false);
    expect(error).toBeDefined();
  });

  test("streams", () => {
    const config = {
      api_url: "https://jsonplaceholder.typicode.com",
    };

    const streams = source.streams(config);
    expect(streams).toHaveLength(2);
    expect(streams[0].constructor.name).toBe("Users");
    expect(streams[1].constructor.name).toBe("Todos");
  });
});
