import {compilePinnedReply} from './pinned-schema.js';
import {acceptTurnReceipt} from './turn-receipt.js';

export function qualifyCodexTurnReceipt(bytes: Uint8Array) {
  const check = compilePinnedReply(
    bytes,
    '9604458949acd680b5c7c768d0e0f70eb3e026bff5496f5ad7afa02021ef305f',
  );
  return check && acceptTurnReceipt.bind(undefined, check);
}
