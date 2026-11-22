import {expect, test} from 'vitest';
import {
  Answer,
  Command,
  DraftInput,
  matchesPrompt,
  Prompt,
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
test('submission refers to one frozen destination and the precise sealed editor revision', () => {
  expect(Command.parse(submitted)).toEqual(submitted);
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
    {...imageOnly, images: [images[0], images[0]]},
    {...imageOnly, images: [{...images[0], bytes: 20 * 1024 * 1024 + 1}]},
    {...imageOnly, text: 'new text'},
    {...imageOnly, text: {...imageOnly.text, sha256: digest}},
  ])
    expect(DraftInput.safeParse(invalid).success).toBe(false);
});

test('run control operations require the expected revision and make no new run or approval', () => {
  for (const operation of [
    'run.cancel',
    'run.resume_queued',
    'run.settle_unsent',
    'run.reconcile',
  ]) {
    const command = {...header, operation, target: {...run, revision: '2'}};
    expect(Command.parse(command)).toEqual(command);
    expect(Command.safeParse({...command, target: run}).success).toBe(false);
  }
  const acknowledge = {
    ...header,
    operation: 'run.acknowledge_unknown_effect',
    target: {...run, revision: '2'},
    payload: {repositoryId: id(18), fenceRevision: '6'},
  };
  expect(Command.parse(acknowledge)).toEqual(acknowledge);
  expect(
    Command.safeParse({...acknowledge, payload: {retry: true}}).success,
  ).toBe(false);
  const retire = {
    ...header,
    operation: 'command.retire',
    target: {
      originalCommandId: id(21),
      originalSessionId: id(22),
      originalOperation: 'run.submit',
      originalControllerEpoch: id(23),
      fingerprint: digest,
      destination: frozen,
    },
  };
  expect(Command.parse(retire)).toEqual(retire);
  for (const target of [
    {...retire.target, originalSessionId: header.originatingSessionId},
    {...retire.target, originalOperation: undefined},
    {...retire.target, originalControllerEpoch: undefined},
    {...retire.target, originalOperation: 'run.cancel'},
  ])
    expect(Command.safeParse({...retire, target}).success).toBe(false);
  for (const originalOperation of ['run.cancel', 'run.resume_queued']) {
    const value = {
      ...retire,
      target: {
        ...retire.target,
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
    payload: deny,
  };
  expect(Command.parse(command)).toEqual(command);
  expect(Command.safeParse({...command, target: request}).success).toBe(false);
  expect(
    Command.safeParse({...command, originatingSessionId: id(31)}).success,
  ).toBe(false);
  expect(matchesPrompt(prompt, deny)).toBe(true);
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
  expect(matchesPrompt(question, reply('Tomorrow'))).toBe(false);
});
