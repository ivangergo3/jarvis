import {Request} from '@example/contracts';

interface Dispatch {
  owns(projectId: string, sessionId: string): boolean;
  enqueue(command: Request): void;
}

export function submit(raw: unknown, dispatch: Dispatch) {
  const parsed = Request.safeParse(raw);
  if (!parsed.success) return 'invalid';
  const command = parsed.data;
  if (!dispatch.owns(command.projectId, command.sessionId)) return 'denied';
  dispatch.enqueue(command);
  return 'accepted';
}
