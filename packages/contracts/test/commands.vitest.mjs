import {expect, test} from 'vitest';
import {
  Answer,
  Command,
  httpStatus,
  Receipt,
  ServiceError,
  StagingCommand,
  stagingCommandId,
  StagingCursor,
  StagingReceipt,
  StagingRetirement,
  StagingTakeover,
  DraftInput,
  matchesPrompt,
  matchesRunRevision,
  Prompt,
  parsePrivateAnswer,
  parsePrivatePrompt,
} from '../src/index.ts';

const id = (n) => '00000000-0000-4000-8000-' + String(n).padStart(12, '0');
const digest = '0'.repeat(64);
const header = {
  schemaVersion: 1,
  controllerEpoch: id(1),
  originatingSessionId: id(2),
  commandId: id(3),
};
const project = {projectId: id(4)};
const session = {...project, sessionId: id(5)};
const run = {...session, runId: id(6)};
const request = {...run, requestId: id(7), generationId: id(8), revision: '1'};
const live = {
  ...request,
  authSessionId: header.originatingSessionId,
  channelId: id(9),
};
const text = {contentId: id(10), bytes: 8, sha256: digest};
const emptyDigest =
  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
const frozen = {...session, bindingId: id(30), repositoryRevision: '2'};
const submitted = {
  ...header,
  operation: 'run.submit',
  target: frozen,
  payload: {revision: '1', text, images: []},
};
const stamp = {
  schemaVersion: 1,
  ownerId: id(60),
  originatingSessionId: header.originatingSessionId,
  commandId: header.commandId,
  controllerEpoch: header.controllerEpoch,
  sequence: '11',
  fingerprint: digest,
  recordedAt: '2026-10-01T12:00:00.000Z',
};

test('project and session titles round-trip as PostgreSQL text', () => {
  for (const [operation, target] of [
    ['project.create', {}],
    ['session.create', project],
  ]) {
    const command = (title) => ({
      ...header,
      operation,
      target,
      payload: {title},
    });
    for (const title of ['Roadmap 🗺️', '東京', 'e\u0301']) {
      expect(Command.parse(command(title)).payload.title).toBe(title);
    }
    for (const title of ['Roadmap\0Draft', '\ud800', '\udfff']) {
      expect(Command.safeParse(command(title)).success).toBe(false);
    }
  }
});

test('submission refers to one frozen destination and the precise sealed editor revision', () => {
  expect(Command.parse(submitted)).toEqual(submitted);
  for (const field of Object.keys(submitted)) {
    const incomplete = {...submitted};
    delete incomplete[field];
    expect(Command.safeParse(incomplete).success, field).toBe(false);
  }
  for (const invalid of [
    {...submitted, schemaVersion: 2},
    {...submitted, operation: 'run.future'},
    {...submitted, payload: null},
    {...submitted, payload: {...submitted.payload, text: null}},
    {...submitted, payload: {...submitted.payload, text: undefined}},
  ])
    expect(Command.safeParse(invalid).success).toBe(false);
  for (const target of [
    session,
    {...frozen, sessionId: undefined},
    {...frozen, bindingId: 'display name'},
    {...frozen, repoPath: '/private'},
  ])
    expect(Command.safeParse({...submitted, target}).success).toBe(false);
  const images = Array.from({length: 6}, (_, n) => ({
    attachmentId: id(100 + n),
    contentId: id(110 + n),
    bytes: 20 * 1024 * 1024,
    sha256: digest,
    mime: 'image/png',
  }));
  const imageOnly = {
    revision: '7',
    text: {...text, bytes: 0, sha256: emptyDigest},
    images,
  };
  expect(DraftInput.parse(imageOnly)).toEqual(imageOnly);
  for (const invalid of [
    {...imageOnly, images: []},
    {...imageOnly, images: [...images, images[0]]},
    {...imageOnly, images: [{...images[0], attachmentId: id(150)}, images[0]]},
    {...imageOnly, images: [{...images[0], contentId: id(150)}, images[0]]},
    {
      ...imageOnly,
      images: [{...images[0], contentId: imageOnly.text.contentId}],
    },
    {...imageOnly, images: [{...images[0], bytes: 20 * 1024 * 1024 + 1}]},
    {...imageOnly, text: 'new text'},
    {...imageOnly, text: {...imageOnly.text, sha256: digest}},
  ])
    expect(DraftInput.safeParse(invalid).success).toBe(false);
  const seventh = {...images[0], attachmentId: id(106), contentId: id(116)};
  expect(
    DraftInput.safeParse({...imageOnly, images: [...images, seventh]}).success,
  ).toBe(false);
});

test('run control operations require the expected revision and make no new run or approval', () => {
  const acknowledge = {
    ...header,
    operation: 'run.acknowledge_unknown_effect',
    target: {...run, revision: '2'},
    payload: {repositoryId: id(18), fenceRevision: '6'},
  };
  for (const operation of [
    'run.acknowledge_unknown_effect',
    'run.cancel',
    'run.resume_queued',
    'run.settle_unsent',
    'run.reconcile',
  ]) {
    const command =
      operation === acknowledge.operation
        ? acknowledge
        : {...header, operation, target: {...run, revision: '2'}};
    const parsed = Command.parse(command);
    expect(parsed).toEqual(command);
    const current = {...run, revision: '2'};
    expect(matchesRunRevision(parsed.target, current)).toBe(true);
    for (const changed of [
      {revision: '3'},
      {runId: id(50)},
      {sessionId: id(51)},
      {projectId: id(52)},
    ]) {
      expect(matchesRunRevision(parsed.target, {...current, ...changed})).toBe(
        false,
      );
    }
    expect(Command.safeParse({...command, target: run}).success).toBe(false);
  }
  expect(Command.parse(acknowledge)).toEqual(acknowledge);
  expect(
    Command.safeParse({...acknowledge, payload: {retry: true}}).success,
  ).toBe(false);
  const retire = {
    ...header,
    operation: 'command.retire',
    target: {originalCommandId: id(21)},
    payload: {
      originalSessionId: id(22),
      originalOperation: 'run.submit',
      originalControllerEpoch: id(23),
      fingerprint: digest,
      destination: frozen,
    },
  };
  expect(Command.parse(retire)).toEqual(retire);
  const successor = {
    ...retire,
    commandId: id(27),
    originatingSessionId: id(26),
    target: {originalCommandId: retire.commandId},
    payload: {
      ...retire.payload,
      originalOperation: 'command.retire',
      originalSessionId: retire.originatingSessionId,
      originalControllerEpoch: retire.controllerEpoch,
      destination: retire.target,
    },
  };
  expect(Command.parse(successor)).toEqual(successor);
  for (const payload of [
    {...retire.payload, originalSessionId: header.originatingSessionId},
    {...retire.payload, originalOperation: undefined},
    {...retire.payload, originalControllerEpoch: undefined},
    {...retire.payload, originalOperation: 'run.cancel'},
  ])
    expect(Command.safeParse({...retire, payload}).success).toBe(false);
  for (const originalOperation of ['run.cancel', 'run.resume_queued']) {
    const value = {
      ...retire,
      payload: {
        ...retire.payload,
        originalOperation,
        destination: {...run, revision: '2'},
      },
    };
    expect(Command.parse(value)).toEqual(value);
  }
  expect(
    Command.safeParse({...retire, commandId: retire.target.originalCommandId})
      .success,
  ).toBe(false);
});

test('a decision binds to its original authorization session, channel, revision and offered option', () => {
  const prompt = Prompt.parse({
    kind: 'approval',
    capability: 'command',
    description: 'Test synthetic checkout',
    decisions: ['deny'],
  });
  const deny = Answer.parse({kind: 'approval', decision: 'deny'});
  const command = {
    ...header,
    operation: 'request.answer',
    target: live,
    payload: {answerId: id(35), bytes: 40, sha256: digest},
  };
  expect(Command.parse(command)).toEqual(command);
  expect(Command.safeParse({...command, target: request}).success).toBe(false);
  expect(
    Command.safeParse({...command, originatingSessionId: id(31)}).success,
  ).toBe(false);
  expect(matchesPrompt(prompt, deny)).toBe(true);
  expect(Command.safeParse({...command, payload: deny}).success).toBe(false);
  expect(parsePrivateAnswer(JSON.stringify(deny)).success).toBe(true);
  expect(parsePrivatePrompt(JSON.stringify(prompt)).success).toBe(true);
  expect(
    matchesPrompt(
      prompt,
      Answer.parse({kind: 'approval', decision: 'allow_once'}),
    ),
  ).toBe(false);
  const question = Prompt.parse({
    kind: 'input',
    questions: [
      {
        questionId: id(33),
        label: 'When?',
        options: [{label: 'Today', description: ''}],
        allowText: false,
      },
    ],
  });
  const reply = (value) =>
    Answer.parse({kind: 'input', answers: [{questionId: id(33), text: value}]});
  expect(matchesPrompt(question, reply('Today'))).toBe(true);
  expect(
    Command.safeParse({...command, payload: reply('private note')}).success,
  ).toBe(false);
  expect(
    parsePrivateAnswer(
      JSON.stringify({
        kind: 'input',
        answers: [{questionId: id(33), text: 'a'.repeat(65536)}],
      }),
    ).success,
  ).toBe(false);
  expect(
    parsePrivatePrompt(' '.repeat(1024 * 1024) + JSON.stringify(prompt))
      .success,
  ).toBe(false);
  expect(
    Prompt.safeParse({
      ...question,
      questions: Array.from({length: 129}, () => question.questions[0]),
    }).success,
  ).toBe(false);
  expect(matchesPrompt(question, reply('Tomorrow'))).toBe(false);
});

test('durable local receipts and transient responses have distinct wire shapes', () => {
  const accepted = {
    ...stamp,
    status: 'accepted',
    operation: 'run.submit',
    target: run,
    draftRevision: '1',
  };
  expect(Receipt.parse(accepted)).toEqual(accepted);
  const canceled = {
    ...stamp,
    status: 'accepted',
    operation: 'run.cancel',
    target: run,
    revision: '2',
  };
  expect(
    Receipt.safeParse({...canceled, observation: {state: 'queued'}}).success,
  ).toBe(false);
  expect(
    Receipt.safeParse({...canceled, observation: {state: 'completed'}}).success,
  ).toBe(true);
  for (const invalid of [
    {...accepted, completed: true},
    {...accepted, target: session},
    {...accepted, sequence: '0'},
    {...stamp, status: 'definitively_refused', reason: 'commit_unknown'},
  ])
    expect(Receipt.safeParse(invalid).success).toBe(false);
  expect(
    Receipt.safeParse({
      ...stamp,
      status: 'retired_unsent',
      attempted: {operation: 'run.submit', target: session},
    }).success,
  ).toBe(true);
  for (const [code, status] of [
    ['invalid_payload', 400],
    ['sign_in_required', 401],
    ['action_denied', 403],
    ['target_not_found', 404],
    ['stale_revision', 409],
    ['expired_cursor', 410],
    ['input_too_large', 413],
    ['queue_full', 429],
    ['dependency_unavailable', 503],
    ['commit_unknown', 503],
  ]) {
    const error =
      code === 'commit_unknown'
        ? {schemaVersion: 1, code, commandId: header.commandId}
        : {schemaVersion: 1, code};
    expect(ServiceError.parse(error).code).toBe(code);
    expect(httpStatus(code)).toBe(status);
  }
  expect(
    ServiceError.safeParse({
      schemaVersion: 1,
      code: 'commit_unknown',
      stack: 'raw provider payload',
    }).success,
  ).toBe(false);
});

test('staging IDs encode their own nonwrapping sequence separately from general command UUIDs', () => {
  const meta = {
    schemaVersion: 1,
    originatingSessionId: header.originatingSessionId,
    writerEpoch: id(40),
    sequence: '1',
    commandId: stagingCommandId('1'),
  };
  const target = {...session, revision: '5'};
  const chunk = {
    ...meta,
    operation: 'draft.chunk',
    target: {...target, index: 2047},
    payload: {bytes: 65536, sha256: digest},
  };
  expect(StagingCommand.parse(chunk)).toEqual(chunk);
  for (const c of [
    {...chunk, originatingSessionId: undefined},
    {...chunk, commandId: header.commandId},
    {...chunk, sequence: '2'},
    {...chunk, sequence: 'bad'},
    {...chunk, target: {...target, index: 2048}},
    {...chunk, payload: {...chunk.payload, bytes: 65537}},
  ])
    expect(StagingCommand.safeParse(c).success).toBe(false);
  expect(
    Command.safeParse({...submitted, commandId: meta.commandId}).success,
  ).toBe(false);
  expect(stagingCommandId('4611686018427387904')).toBe(
    '00000000-0000-8001-8000-000000000000',
  );
  expect(stagingCommandId('9223372036854775807')).toBe(
    '00000000-0000-8001-bfff-ffffffffffff',
  );
  expect(() => stagingCommandId('9223372036854775808')).toThrow();
  const seal = {
    ...meta,
    operation: 'draft.seal',
    target,
    payload: {chunkCount: 0, bytes: 0, sha256: emptyDigest},
  };
  expect(StagingCommand.safeParse(seal).success).toBe(true);
  expect(
    StagingCommand.safeParse({
      ...seal,
      payload: {...seal.payload, sha256: digest},
    }).success,
  ).toBe(false);
  expect(
    StagingCommand.safeParse({...seal, payload: {...seal.payload, bytes: 1}})
      .success,
  ).toBe(false);
  const lastReceipt = {
    ...meta,
    fingerprint: digest,
    recordedAt: stamp.recordedAt,
    status: 'committed',
    result: {operation: 'draft.discard', target},
  };
  expect(StagingReceipt.parse(lastReceipt)).toEqual(lastReceipt);
  const image = {...text, attachmentId: id(49), mime: 'image/png'};
  const savedImage = {
    ...lastReceipt,
    result: {operation: 'draft.image', target, image},
  };
  expect(StagingReceipt.parse(savedImage)).toEqual(savedImage);
  expect(
    StagingReceipt.safeParse({
      ...savedImage,
      result: {...savedImage.result, target: {...target, attachmentId: id(50)}},
    }).success,
  ).toBe(false);
  const cursor = {
    schemaVersion: 1,
    ownerId: id(41),
    writerEpoch: id(42),
    sequence: '2',
    lastReceipt,
  };
  expect(StagingCursor.parse(cursor)).toEqual(cursor);
  expect(
    StagingCursor.safeParse({...cursor, writerEpoch: meta.writerEpoch}).success,
  ).toBe(false);
  expect(
    StagingCursor.safeParse({
      ...cursor,
      writerEpoch: meta.writerEpoch,
      sequence: '1',
    }).success,
  ).toBe(true);
  expect(StagingCursor.safeParse({...cursor, sequence: '1'}).success).toBe(
    false,
  );
  expect(
    StagingCursor.safeParse({...cursor, sequence: 'invalid'}).success,
  ).toBe(false);
  expect(StagingCursor.safeParse({...cursor, sequence: '0'}).success).toBe(
    false,
  );
  const takeover = {
    schemaVersion: 1,
    operation: 'staging.takeover',
    originatingSessionId: header.originatingSessionId,
    requestId: '0194c620-0840-7440-8d53-d51e04b81cab',
    expectedWriterEpoch: meta.writerEpoch,
  };
  expect(StagingTakeover.parse(takeover)).toEqual(takeover);
  expect(
    ServiceError.parse({
      schemaVersion: 1,
      code: 'commit_unknown',
      commandId: takeover.requestId,
    }).commandId,
  ).toBe(takeover.requestId);
  for (const requestId of [header.commandId, meta.commandId]) {
    expect(StagingTakeover.safeParse({...takeover, requestId}).success).toBe(
      false,
    );
  }
  expect(
    Command.safeParse({...submitted, commandId: takeover.requestId}).success,
  ).toBe(false);
  expect(
    StagingCommand.safeParse({...chunk, commandId: takeover.requestId}).success,
  ).toBe(false);
  expect(
    StagingRetirement.safeParse({
      ...meta,
      operation: 'staging.retire',
      originalSessionId: id(38),
      fingerprint: digest,
    }).success,
  ).toBe(true);
});
