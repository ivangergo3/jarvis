import {createHash} from 'node:crypto';
import Ajv from 'ajv';
import {acceptTurnReceipt} from './turn-receipt.js';

function checker() {
  const ajv = new Ajv({ownProperties: true, logger: false});
  // JavaScript cannot represent every wire-level 64-bit integer exactly.
  // Decline evidence outside the lossless range.
  const bounds: Record<string, readonly [number, number]> = {
    uint8: [0, 255],
    uint16: [0, 65535],
    uint32: [0, 4294967295],
    int32: [-2147483648, 2147483647],
    uint: [0, Number.MAX_SAFE_INTEGER],
    uint64: [0, Number.MAX_SAFE_INTEGER],
    int64: [Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER],
  };
  for (const [name, [min, max]] of Object.entries(bounds)) {
    ajv.addFormat(name, {
      type: 'number',
      validate: (value: number) =>
        Number.isSafeInteger(value) && value >= min && value <= max,
    });
  }
  return ajv;
}

/** Accept only the unmodified TurnStartResponse schema emitted by the pinned
 * Codex CLI. Compile it once for the worker. Partial or foreign schemas
 * cannot authorize the service to bind a provider turn. */
export function qualifyCodexTurnReceipt(bytes: Uint8Array) {
  try {
    if (bytes.byteLength > 128 * 1024) return undefined;
    const snapshot = Buffer.from(bytes);
    const digest = createHash('sha256').update(snapshot).digest('hex');
    if (
      digest !==
      '9604458949acd680b5c7c768d0e0f70eb3e026bff5496f5ad7afa02021ef305f'
    )
      return undefined;
    const schema: unknown = JSON.parse(snapshot.toString('utf8'));
    if (!schema || typeof schema !== 'object' || Array.isArray(schema))
      return undefined;
    const check = checker().compile(schema);
    return acceptTurnReceipt.bind(
      undefined,
      (result: unknown) => check(result) === true,
    );
  } catch {
    return undefined;
  }
}
