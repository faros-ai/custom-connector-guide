import {
  Converter,
  DestinationModel,
  DestinationRecord,
  StreamContext,
} from "airbyte-faros-destination";
import { AirbyteRecord } from "faros-airbyte-cdk";

interface JSONPlaceholderTodo {
  userId: number;
  id: number;
  title: string;
  completed: boolean;
}

interface TmsTaskType {
  category: "Task" | "Bug" | "Story" | "Custom";
  detail: string;
}

interface TmsTaskStatus {
  category: "Todo" | "InProgress" | "Done" | "Custom";
  detail: string;
}

export class Todos extends Converter {
  source = "JSONPlaceholder";

  readonly destinationModels: ReadonlyArray<DestinationModel> = [
    "tms_Task",
    "tms_TaskAssignment",
  ];

  id(record: AirbyteRecord): string {
    return String(record.record.data.id);
  }

  async convert(
    record: AirbyteRecord,
    ctx?: StreamContext,
  ): Promise<ReadonlyArray<DestinationRecord>> {
    const todo = record.record.data as JSONPlaceholderTodo;
    const results: DestinationRecord[] = [];

    // Convert todo to tms_Task
    const taskType: TmsTaskType = {
      category: "Task",
      detail: "todo",
    };

    const taskStatus: TmsTaskStatus = {
      category: todo.completed ? "Done" : "Todo",
      detail: todo.completed ? "completed" : "pending",
    };

    results.push({
      model: "tms_Task",
      record: {
        uid: String(todo.id),
        name: todo.title,
        description: `Todo item: ${todo.title}`,
        type: taskType,
        status: taskStatus,
        source: this.source,
        createdAt: new Date().toISOString(), // JSONPlaceholder doesn't provide dates
        updatedAt: new Date().toISOString(),
        resolvedAt: todo.completed ? new Date().toISOString() : null,
      },
    });

    // Create task assignment to link the task to the user
    if (todo.userId) {
      results.push({
        model: "tms_TaskAssignment",
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
