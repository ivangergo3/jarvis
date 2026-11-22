import {Request} from '@example/contracts';

export function canSendDraft(projectId: string, sessionId: string, text: string): boolean {
  return Request.safeParse({version: 1, projectId, sessionId, text}).success;
}
