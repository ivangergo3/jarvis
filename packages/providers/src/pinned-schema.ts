import {createHash} from 'node:crypto';
import Ajv from 'ajv';

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

/** Only original local CLI bytes matching the expected release may supply a schema. */
export function compilePinnedReply(bytes: Uint8Array, expectedSha256: string) {
  try {
    if (bytes.byteLength > 128 * 1024) return undefined;
    const original = Buffer.from(bytes);
    if (createHash('sha256').update(original).digest('hex') !== expectedSha256)
      return undefined;
    const schema: unknown = JSON.parse(original.toString('utf8'));
    if (!schema || typeof schema !== 'object' || Array.isArray(schema))
      return undefined;
    const check = checker().compile(schema);
    return (value: unknown) => check(value) === true;
  } catch {
    return undefined;
  }
}
