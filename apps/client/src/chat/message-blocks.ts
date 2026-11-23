type Alignment = 'left' | 'center' | 'right';
export interface MessageTable {
  headers: string[];
  alignments: Alignment[];
  rows: string[][];
}

type Block =
  | {kind: 'paragraph' | 'quote' | 'code'; text: string}
  | {kind: 'heading'; level: number; text: string}
  | {kind: 'list'; ordered: boolean; items: {marker: string; text: string}[]}
  | {kind: 'table'; table: MessageTable};

// Foundation's .whitespaces includes U+200B and excludes U+FEFF.
const horizontal = /[\p{Zs}\t\u200B]/u;
function trimHorizontal(text: string) {
  let start = 0;
  let end = text.length;
  while (start < end && horizontal.test(text.charAt(start))) start++;
  while (end > start && horizontal.test(text.charAt(end - 1))) end--;
  return text.slice(start, end);
}

const graphemes = new Intl.Segmenter(undefined, {granularity: 'grapheme'});

// The last ASCII delimiter must be a complete Swift Character.
function hasMarker(text: string, marker: string) {
  if (text.slice(0, marker.length).normalize('NFC') !== marker.normalize('NFC'))
    return false;
  if (text.length === marker.length || text.charCodeAt(marker.length) < 128)
    return true;
  return (
    graphemes.segment(text).containing(marker.length)?.index === marker.length
  );
}

function cells(line: string): string[] | undefined {
  const text = trimHorizontal(line);
  if (!text.includes('|')) return;
  const chars = Array.from(graphemes.segment(text), (part) => part.segment);
  const result: string[] = [];
  let cell = '';
  let ticks = 0;
  let separators = 0;
  for (let i = 0; i < chars.length; i++) {
    const char = chars[i] ?? '';
    if (char === '\\' && i + 1 < chars.length) {
      cell += char + chars[++i];
    } else if (char.normalize('NFC') === '`') {
      const start = i;
      while (chars[i + 1]?.normalize('NFC') === '`') i++;
      const length = i + 1 - start;
      if (ticks === 0) ticks = length;
      else if (length === ticks) ticks = 0;
      cell += '`'.repeat(length);
    } else if (char === '|' && ticks === 0) {
      result.push(trimHorizontal(cell));
      cell = '';
      separators++;
    } else {
      cell += char;
    }
  }
  if (separators === 0) return;
  result.push(trimHorizontal(cell));
  if (chars[0] === '|') result.shift();
  if (chars.at(-1) === '|' && result.at(-1) === '') result.pop();
  return result.length ? result : undefined;
}

function tableHeader(
  line: string,
  separator: string,
): MessageTable | undefined {
  if (!separator.includes('-') || !line.includes('|')) return;
  const headers = cells(line);
  const marks = cells(separator);
  if (
    !headers ||
    headers.length > 32 ||
    !marks ||
    headers.length !== marks.length ||
    !marks.every((mark) => /^:?-{3,}:?$/.test(mark))
  )
    return;
  return {
    headers,
    alignments: marks.map((mark) =>
      !mark.endsWith(':') ? 'left' : mark.startsWith(':') ? 'center' : 'right',
    ),
    rows: [],
  };
}

export function messageBlocks(source: string): Block[] {
  const result: Block[] = [];
  const lines = source.split(/[\r\n\v\f\u0085\u2028\u2029]/);
  let paragraph: string[] = [];
  let list: Extract<Block, {kind: 'list'}> | undefined;
  function finishText() {
    if (paragraph.length)
      result.push({kind: 'paragraph', text: paragraph.join('\n')});
    paragraph = [];
  }
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i] ?? '';
    const trimmed = trimHorizontal(line);
    if (!trimmed) {
      list = undefined;
      finishText();
      continue;
    }
    const fence = trimmed.slice(0, 3).normalize('NFC');
    if ((fence === '```' || fence === '~~~') && hasMarker(trimmed, fence)) {
      finishText();
      list = undefined;
      const start = ++i;
      while (
        i < lines.length &&
        !hasMarker(trimHorizontal(lines[i] ?? ''), fence)
      )
        i++;
      result.push({kind: 'code', text: lines.slice(start, i).join('\n')});
      continue;
    }
    const table = tableHeader(line, lines[i + 1] ?? '');
    if (table) {
      finishText();
      list = undefined;
      i++;
      let row;
      while (i + 1 < lines.length && (row = cells(lines[i + 1] ?? ''))) {
        const sourceRow = row;
        table.rows.push(
          table.headers.map((_, column) => sourceRow[column] ?? ''),
        );
        i++;
      }
      result.push({kind: 'table', table});
      continue;
    }
    const listMatch = /^(\p{Decimal_Number}+[.)]|[-*+]) (.*)$/u.exec(trimmed);
    if (listMatch && hasMarker(trimmed, (listMatch[1] ?? '') + ' ')) {
      finishText();
      const marker = listMatch[1] ?? '';
      const ordered = /^[\p{Decimal_Number}]/u.test(marker);
      if (list?.ordered !== ordered) {
        list = {kind: 'list', ordered, items: []};
        result.push(list);
      }
      list.items.push({
        marker: ordered ? marker : '•',
        text: listMatch[2] ?? '',
      });
      continue;
    }
    list = undefined;
    const heading = /^(#{1,6}) (.*)$/.exec(trimmed);
    if (heading && hasMarker(trimmed, (heading[1] ?? '') + ' ')) {
      finishText();
      result.push({
        kind: 'heading',
        level: heading[1]?.length ?? 1,
        text: heading[2] ?? '',
      });
    } else if (hasMarker(trimmed, '> ')) {
      finishText();
      result.push({kind: 'quote', text: trimmed.slice(2)});
    } else {
      paragraph.push(line);
    }
  }
  finishText();
  return result;
}
