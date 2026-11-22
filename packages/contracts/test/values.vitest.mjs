import {expect, test} from 'vitest';
import {
  CommandId,
  Cursor,
  ProjectTarget,
  RequestTarget,
  Sequence,
  Timestamp,
} from '../src/index.ts';

const id = (n) => '00000000-0000-4000-8000-' + String(n).padStart(12, '0');

test('a request names its immutable ancestry and revision', () => {
  const original = {
    projectId: id(1),
    sessionId: id(2),
    runId: id(3),
    requestId: id(4),
    generationId: id(5),
    revision: '1',
  };
  expect(RequestTarget.parse(original)).toEqual(original);
  for (const key of Object.keys(original)) {
    expect(
      RequestTarget.safeParse({...original, [key]: undefined}).success,
    ).toBe(false);
  }
  expect(ProjectTarget.safeParse(original).success).toBe(false);
  expect(
    RequestTarget.safeParse({...original, sessionId: 'Marketing'}).success,
  ).toBe(false);
});

test('timestamps, UUID versions, and owner counters reject incompatible values', () => {
  expect(CommandId.safeParse(id(1)).success).toBe(true);
  expect(
    CommandId.safeParse('00000000-0000-8000-8000-000000000001').success,
  ).toBe(false);
  expect(Timestamp.safeParse('2026-01-31T12:00:00.000Z').success).toBe(true);
  expect(Timestamp.safeParse('2026-01-31T12:00:00.000+01:00').success).toBe(
    false,
  );
  expect(Cursor.parse('0')).toBe('0');
  expect(Sequence.safeParse('0').success).toBe(false);
  expect(Sequence.parse('9223372036854775807')).toBe('9223372036854775807');
  for (const value of [null, 1, '01', '-1', '18446744073709551616'])
    expect(Cursor.safeParse(value).success).toBe(false);
});
