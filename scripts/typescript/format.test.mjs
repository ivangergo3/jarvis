import assert from 'node:assert/strict';
import test from 'node:test';
import {isFormatted} from './format.mjs';

test('formatting rejects spacing and quotes and accepts the restored source', async () => {
  const file = 'example.ts';
  assert.equal(await isFormatted('const phrase="Hello";\n', file), false);
  assert.equal(await isFormatted("const phrase = 'Hello';\n", file), true);
});
