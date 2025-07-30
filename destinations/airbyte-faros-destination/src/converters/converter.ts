import {AirbyteRecord} from 'faros-airbyte-cdk';

export type DestinationModel = string;

export interface DestinationRecord {
  readonly model: DestinationModel;
  readonly record: any;
}

export interface StreamContext {
  readonly streamName: {
    readonly source: string;
    readonly name: string;
  };
  get(streamName: string, recordId: string): any;
}

export abstract class Converter {
  abstract source: string;
  abstract destinationModels: ReadonlyArray<DestinationModel>;
  
  abstract id(record: AirbyteRecord): string;
  
  abstract convert(
    record: AirbyteRecord,
    ctx?: StreamContext
  ): Promise<ReadonlyArray<DestinationRecord>>;
}