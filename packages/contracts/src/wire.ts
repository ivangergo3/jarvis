import {utf8Bytes} from './values.js';

export const eventLimit = 64 * 1024;
export const batchLimit = 1024 * 1024;

export function parseWire(
  text: string,
  maximum: number,
  validFrames?: (wire: string) => boolean,
): unknown {
  if (
    typeof text !== 'string' ||
    text.length > maximum ||
    utf8Bytes(text) > maximum
  )
    return undefined;
  try {
    if (validFrames && !validFrames(text)) return undefined;
    const value: unknown = JSON.parse(text);
    return containsUniqueMembers(text) ? value : undefined;
  } catch {
    return undefined;
  }
}

function afterSpace(text: string, index: number): number {
  while (index < text.length && text.charCodeAt(index) <= 32) index++;
  return index;
}

function closingQuote(text: string, index: number): number {
  for (index++; index < text.length && text[index] !== '"'; index++) {
    if (text[index] === '\\') index++;
  }
  return index;
}

// Native parsing validates the grammar, but accepts repeated keys using their last
// value. Inspect the same text iteratively so ambiguous destinations cannot act.
function containsUniqueMembers(text: string): boolean {
  const containers: Array<Set<string> | undefined> = [];
  for (let i = 0; i < text.length; i++) {
    const token = text[i];
    if (token === '"') {
      const start = i;
      i = closingQuote(text, i);
      const members = containers.at(-1);
      if (!members || text[afterSpace(text, i + 1)] !== ':') continue;
      const key: unknown = JSON.parse(text.slice(start, i + 1));
      if (typeof key !== 'string' || members.has(key)) return false;
      members.add(key);
    } else if (token === '{') containers.push(new Set());
    else if (token === '[') containers.push(undefined);
    else if (token === ']' || token === '}') containers.pop();
  }
  return true;
}

/** Check frame spans before decoding the enclosing batch. Native parsing subsequently
 * validates the JSON grammar; the caller rejects malformed keys or unterminated frames.
 */
export function eventFramesFit(text: string): boolean {
  let depth = 0;
  let start = -1;
  let found = false;
  for (let i = 0; i < text.length; i++) {
    const token = text[i];
    if (token === '"') {
      const quote = i;
      i = closingQuote(text, i);
      if (depth !== 1) continue;
      const colon = afterSpace(text, i + 1);
      if (
        text[colon] !== ':' ||
        JSON.parse(text.slice(quote, i + 1)) !== 'events'
      )
        continue;
      const array = afterSpace(text, colon + 1);
      if (found || text[array] !== '[') return false;
      found = true;
      start = array + 1;
      i = array;
      depth++;
      continue;
    }
    if (start >= 0 && depth === 2 && (token === ',' || token === ']')) {
      if (utf8Bytes(text.slice(start, i).trim()) > eventLimit) return false;
      start = token === ',' ? i + 1 : -1;
    }
    if (token === '[' || token === '{') depth++;
    if (token === ']' || token === '}') depth--;
  }
  return found;
}
