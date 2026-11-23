import {expect, it} from 'vitest';
import {messageBlocks} from '../src/chat/message-blocks.ts';

it('keeps the Swift grapheme boundaries of block markers, fences and table delimiters', () => {
  const equivalent = '\u1fef';
  expect(
    messageBlocks([equivalent.repeat(3), 'inside', '```'].join('\n')),
  ).toEqual([{kind: 'code', text: 'inside'}]);
  expect(
    messageBlocks('A|B\n---|---\n' + equivalent + 'x|y' + equivalent + '|z')[0]
      .table.rows,
  ).toEqual([['`x|y`', 'z']]);
  for (const extended of ['\u0301', '\uFE0F', '\u200D']) {
    for (const marker of ['> ', '# ', '- ', '12. ', '٤) ', '~~~']) {
      const line = marker + extended + 'not a delimiter';
      expect(messageBlocks(line)).toEqual([{kind: 'paragraph', text: line}]);
    }
    const fenced = '~~~' + extended;
    expect(messageBlocks(['~~~', fenced, '# code', '~~~'].join('\n'))).toEqual([
      {kind: 'code', text: fenced + '\n# code'},
    ]);
  }
  const table = messageBlocks('First | Second\n--- | ---\n|̸ A | B')[0].table;
  expect(table.headers).toEqual(['First', 'Second']);
  expect(table.rows).toEqual([['|̸ A', 'B']]);
});
it('preserves existing whitespace, ordered list markers and table rows when block types change', () => {
  const spaced = 'left' + ' '.repeat(80000) + 'right';
  expect(messageBlocks(spaced)).toEqual([{kind: 'paragraph', text: spaced}]);
  expect(messageBlocks('a | b\r\n--- | ---')).toEqual([
    {kind: 'paragraph', text: 'a | b'},
    {kind: 'paragraph', text: '--- | ---'},
  ]);
  expect(messageBlocks('٤) item\u0085next')).toEqual([
    {kind: 'list', ordered: true, items: [{marker: '٤)', text: 'item'}]},
    {kind: 'paragraph', text: 'next'},
  ]);
  expect(messageBlocks('~~~\ninside\n\n')).toEqual([
    {kind: 'code', text: 'inside\n\n'},
  ]);
  const blocks = messageBlocks('A|B|C\n:---|---:|---\nx\\|y|`z|z`\nfinal');
  expect(blocks[0].table).toEqual({
    headers: ['A', 'B', 'C'],
    alignments: ['left', 'right', 'left'],
    rows: [['x\\|y', '`z|z`', '']],
  });
  expect(blocks[1]).toEqual({kind: 'paragraph', text: 'final'});
});
