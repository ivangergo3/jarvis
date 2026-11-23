import type {z} from 'zod';
import type {OwnerId, SessionTarget} from './values.js';
import {batchLimit, parseWire} from './wire.js';
import {
  ClosedEpochPage,
  ProjectPage,
  type ReadRequest,
  SessionPage,
} from './reads.js';
import {DraftManifestPage, HistoryPage, ReceiptPage} from './recovery.js';

type PageRequest = Extract<
  ReadRequest,
  {
    operation:
      | 'project.list'
      | 'session.list'
      | 'draft.list'
      | 'history.read'
      | 'controller.closed_epochs'
      | 'controller.receipts';
  }
>;

/** Decode the original wire text and match it to the requesting owner and destination. */
export function parseReadPage(
  wire: string,
  ownerId: OwnerId,
  request: PageRequest,
) {
  const value = parseWire(wire, batchLimit);
  function scoped<Page extends {ownerId: OwnerId}>(
    schema: z.ZodType<Page>,
    matches: (page: Page) => boolean,
  ): Page | undefined {
    const parsed = schema.safeParse(value);
    if (
      parsed.success &&
      parsed.data.ownerId === ownerId &&
      matches(parsed.data)
    )
      return parsed.data;
    return undefined;
  }
  switch (request.operation) {
    case 'project.list':
      return scoped(
        ProjectPage,
        (page) =>
          page.after === request.page.after &&
          page.records.length <= request.page.limit,
      );
    case 'session.list':
      return scoped(
        SessionPage,
        (page) =>
          page.target.projectId === request.target.projectId &&
          page.after === request.page.after &&
          page.records.length <= request.page.limit,
      );
    case 'controller.closed_epochs':
      return scoped(
        ClosedEpochPage,
        (page) =>
          page.through === request.through &&
          page.after === request.page.after &&
          page.ledgers.length <= request.page.limit,
      );
    case 'controller.receipts':
      return scoped(
        ReceiptPage,
        (page) =>
          page.epoch === request.epoch &&
          matchesRecoveryPage(request.page, page, page.receipts.length),
      );
    case 'draft.list':
      return scoped(
        DraftManifestPage,
        (page) =>
          sameSession(page.target, request.target) &&
          matchesRecoveryPage(request.page, page, page.drafts.length),
      );
    case 'history.read':
      return scoped(
        HistoryPage,
        (page) =>
          sameSession(page.target, request.target) &&
          matchesRecoveryPage(request.page, page, page.entries.length),
      );
  }
}

function sameSession(left: SessionTarget, right: SessionTarget): boolean {
  return (
    left.projectId === right.projectId && left.sessionId === right.sessionId
  );
}

function matchesRecoveryPage(
  requested: {highWater: string; after: string | null; limit: number} | null,
  response: {highWater: string; pageToken: string | null},
  count: number,
): boolean {
  if (requested === null) return response.pageToken === null;
  return (
    response.highWater === requested.highWater &&
    response.pageToken === requested.after &&
    count <= requested.limit
  );
}
