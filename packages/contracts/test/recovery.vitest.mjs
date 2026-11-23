import {expect, test} from 'vitest';
import {
  DraftManifestPage,
  HistoryPage,
  LiveRequestDescriptor,
  ReadRequest,
  Receipt,
  ReceiptPage,
  StagingReceipt,
  stagingCommandId,
} from '../src/index.ts';

const id = (n) => '00000000-0000-4000-8000-' + String(n).padStart(12, '0');
const session = {projectId: id(1), sessionId: id(2)};
const run = {...session, runId: id(3)};
const request = {...run, generationId: id(4), requestId: id(5), revision: '1'};
const reference = {contentId: id(6), bytes: 12, sha256: 'f'.repeat(64)};
const page = {
  schemaVersion: 1,
  ownerId: id(7),
  highWater: '12',
  offset: '0',
  totalRecords: '1',
  pageToken: null,
  next: null,
};
const at = '2026-11-22T12:00:00.000Z';

test('recover private prompt descriptors through the original request before fetching content', () => {
  const lookup = {
    schemaVersion: 1,
    operation: 'request.describe',
    target: request,
  };
  expect(ReadRequest.parse(lookup)).toEqual(lookup);
  const descriptor = {
    schemaVersion: 1,
    ownerId: page.ownerId,
    target: {...request, authSessionId: id(8), channelId: id(9)},
    kind: 'approval',
    content: reference,
  };
  expect(LiveRequestDescriptor.parse(descriptor)).toEqual(descriptor);
  for (const [bytes, allowed] of [
    [0, false],
    [1024 * 1024, true],
    [1024 * 1024 + 1, false],
  ]) {
    expect(
      LiveRequestDescriptor.safeParse({
        ...descriptor,
        content: {...reference, bytes},
      }).success,
    ).toBe(allowed);
  }
  expect(
    LiveRequestDescriptor.safeParse({...descriptor, target: request}).success,
  ).toBe(false);
  const read = {
    schemaVersion: 1,
    operation: 'request.content',
    target: descriptor.target,
    part: {contentId: descriptor.content.contentId, offset: 0},
  };
  expect(ReadRequest.parse(read)).toEqual(read);
});

test('recover cancellation outcomes once and reject a conflicting ID as a permanent refusal', () => {
  const stamp = {
    schemaVersion: 1,
    commandId: id(10),
    ownerId: page.ownerId,
    originatingSessionId: id(8),
    controllerEpoch: id(11),
    fingerprint: reference.sha256,
    recordedAt: at,
    sequence: '12',
  };
  const result = {
    ...stamp,
    status: 'accepted',
    operation: 'run.cancel',
    target: run,
    revision: '3',
    observation: {state: 'completed', workerExit: 'verified_forced'},
  };
  expect(Receipt.parse(result)).toEqual(result);
  for (const invalid of [
    {...result, observation: undefined},
    {...result, observation: {state: 'queued'}},
    {
      ...stamp,
      status: 'definitively_refused',
      reason: 'command_id_reused',
      attempted: {operation: 'run.cancel', target: run},
    },
  ])
    expect(Receipt.safeParse(invalid).success).toBe(false);
  const ledger = {...page, epoch: id(11), receipts: [result]};
  expect(ReceiptPage.parse(ledger)).toEqual(ledger);
  for (const invalid of [
    {...ledger, epoch: id(33)},
    {...ledger, ownerId: id(34)},
    {...ledger, highWater: '11'},
    {...ledger, totalRecords: '2'},
    {...ledger, totalRecords: '2', next: 'more'},
  ])
    expect(ReceiptPage.safeParse(invalid).success).toBe(false);
});

test('restore open or sealed draft manifests with indexed, bounded chunks', () => {
  const draft = {
    revision: '2',
    status: 'sealed',
    text: {...reference, contentId: id(42)},
    images: [],
    chunks: [{index: 0, ref: reference}],
  };
  const result = {...page, target: session, drafts: [draft]};
  expect(DraftManifestPage.parse(result)).toEqual(result);
  const second = {
    ...draft,
    revision: '3',
    text: {...reference, contentId: id(43), sha256: 'e'.repeat(64)},
    chunks: [{index: 0, ref: {...reference, sha256: 'e'.repeat(64)}}],
  };
  expect(
    DraftManifestPage.safeParse({
      ...result,
      totalRecords: '2',
      drafts: [draft, second],
    }).success,
  ).toBe(false);
  expect(
    DraftManifestPage.safeParse({
      ...result,
      drafts: [
        {
          ...draft,
          status: 'open',
          text: null,
          chunks: [{index: 6, ref: reference}],
        },
      ],
    }).success,
  ).toBe(true);
  for (const invalid of [
    {...draft, text: {...draft.text, bytes: 13}},
    {...draft, text: {...draft.text, sha256: 'a'.repeat(64)}},
    {...draft, chunks: [{index: 1, ref: reference}]},
    {...draft, status: 'open', text: reference},
    {
      ...draft,
      images: [
        {...draft.text, mime: 'image/png', bytes: 30, attachmentId: id(55)},
      ],
    },
    {
      ...draft,
      chunks: [{index: 0, ref: {...draft.text, sha256: 'e'.repeat(64)}}],
    },
  ])
    expect(
      DraftManifestPage.safeParse({...result, drafts: [invalid]}).success,
    ).toBe(false);
  const receipt = {
    schemaVersion: 1,
    originatingSessionId: id(14),
    writerEpoch: id(13),
    sequence: '1',
    commandId: stagingCommandId('1'),
    fingerprint: reference.sha256,
    recordedAt: at,
    status: 'committed',
    result: {
      operation: 'draft.chunk',
      target: {...session, revision: '2', index: 0},
      content: reference,
    },
  };
  expect(StagingReceipt.parse(receipt)).toEqual(receipt);
  const imageReceipt = {
    ...receipt,
    result: {
      operation: 'draft.image',
      target: {...session, revision: '2'},
      image: {...reference, mime: 'image/png', attachmentId: id(15)},
    },
  };
  expect(StagingReceipt.parse(imageReceipt)).toEqual(imageReceipt);
  expect(
    StagingReceipt.safeParse({
      ...imageReceipt,
      result: {
        ...imageReceipt.result,
        target: {...imageReceipt.result.target, attachmentId: id(16)},
      },
    }).success,
  ).toBe(false);
  for (const bytes of [0, 65537])
    expect(
      StagingReceipt.safeParse({
        ...receipt,
        result: {...receipt.result, content: {...reference, bytes}},
      }).success,
    ).toBe(false);
});

test('durable history retains safe categories and rejects wrong sessions or private answer bodies', () => {
  const item = {
    entryId: id(14),
    revision: '1',
    sequence: '10',
    occurredAt: at,
    kind: 'decision',
    target: request,
    decision: {requestKind: 'input', category: 'input_provided'},
    delivery: 'unknown',
  };
  const history = {...page, target: session, entries: [item]};
  expect(HistoryPage.parse(history)).toEqual(history);
  const firstText = {
    ...history.entries[0],
    kind: 'output',
    target: run,
    content: {kind: 'retained_text', ref: reference},
  };
  delete firstText.decision;
  delete firstText.delivery;
  const secondText = {...firstText, entryId: id(44), sequence: '12'};
  const twoEntries = {
    ...history,
    totalRecords: '2',
    entries: [firstText, secondText],
  };
  expect(HistoryPage.parse(twoEntries)).toEqual(twoEntries);
  expect(
    HistoryPage.safeParse({
      ...twoEntries,
      entries: [
        firstText,
        {
          ...secondText,
          content: {kind: 'retained_text', ref: {...reference, bytes: 13}},
        },
      ],
    }).success,
  ).toBe(false);
  const {decision, delivery, ...withoutDecision} = item;
  const unavailable = {
    ...withoutDecision,
    kind: 'request_status',
    metadata: {kind: 'approval', status: 'unavailable', reason: 'channel_lost'},
  };
  expect(
    HistoryPage.safeParse({...history, entries: [unavailable]}).success,
  ).toBe(true);
  expect(
    HistoryPage.safeParse({
      ...history,
      entries: [{...unavailable, decision, delivery}],
    }).success,
  ).toBe(false);
  for (const invalid of [
    {...item, target: {...request, sessionId: id(15)}},
    {...item, decision: {...item.decision, answer: 'private answer'}},
    {...item, decision: {requestKind: 'approval', category: 'input_provided'}},
  ])
    expect(
      HistoryPage.safeParse({...history, entries: [invalid]}).success,
    ).toBe(false);
});
