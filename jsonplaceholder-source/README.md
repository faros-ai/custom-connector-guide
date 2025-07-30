# JSONPlaceholder Source

This is an Airbyte source connector for [JSONPlaceholder](https://jsonplaceholder.typicode.com/), a free fake REST API for testing and prototyping.

## Supported Streams

- **users** - Fetches user data
- **todos** - Fetches todo items

## Configuration

The source requires minimal configuration:

- **api_url** (optional): The base URL for the JSONPlaceholder API. Defaults to `https://jsonplaceholder.typicode.com`

## Features

- Full and incremental sync modes
- Simple ID-based cursor for incremental syncs
- No authentication required

## Development

See the common [development guide](../README.md#development) for instructions on building and testing this connector.