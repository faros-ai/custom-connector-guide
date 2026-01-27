import {
  Converter,
  DestinationModel,
  DestinationRecord,
  StreamContext,
} from "airbyte-faros-destination";
import { AirbyteRecord } from "faros-airbyte-cdk";

interface JSONPlaceholderUser {
  id: number;
  name: string;
  username: string;
  email: string;
  address?: {
    street: string;
    suite: string;
    city: string;
    zipcode: string;
    geo?: {
      lat: string;
      lng: string;
    };
  };
  phone?: string;
  website?: string;
  company?: {
    name: string;
    catchPhrase: string;
    bs: string;
  };
}

export class Users extends Converter {
  source = "JSONPlaceholder";

  readonly destinationModels: ReadonlyArray<DestinationModel> = ["tms_User"];

  id(record: AirbyteRecord): string {
    return String(record.record.data.id);
  }

  async convert(
    record: AirbyteRecord,
    ctx?: StreamContext,
  ): Promise<ReadonlyArray<DestinationRecord>> {
    const user = record.record.data as JSONPlaceholderUser;

    return [
      {
        model: "tms_User",
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
