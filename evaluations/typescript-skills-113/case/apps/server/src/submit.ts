import type {Request} from '@example/contracts';

interface Dispatch {
  owns(projectId: string, sessionId: string): boolean;
  enqueue(command: Request): void;
}

export function submit(raw: unknown, dispatch: Dispatch) {
  const command = raw as Request;
  if (!dispatch.owns(command.projectId, command.sessionId)) return 'denied';
  dispatch.enqueue(command);
  return 'accepted';
}
