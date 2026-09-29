/**
 * Repeatable ids for authored course content, identical to the Swift app's `UUID(stable:_:)`
 * (SplitMix64 mixing of two small integers, printed as an uppercase UUID).
 */
const MASK = (1n << 64n) - 1n;
const GOLDEN = 0x9e3779b97f4a7c15n;

export function stableId(a: number, b: number): string {
  let state = (BigInt.asUintN(64, BigInt(a)) * GOLDEN + BigInt.asUintN(64, BigInt(b)) * 0xd1b54a32d192ed03n) & MASK;
  const next = (): bigint => {
    state = (state + GOLDEN) & MASK;
    let z = state;
    z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & MASK;
    z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & MASK;
    return z ^ (z >> 31n);
  };
  const high = next();
  const low = next();
  const hex = (v: bigint, digits: number): string => v.toString(16).toUpperCase().padStart(digits, '0');
  return [
    hex(high >> 32n, 8),
    hex((high >> 16n) & 0xffffn, 4),
    hex(high & 0xffffn, 4),
    hex((low >> 48n) & 0xffffn, 4),
    hex(low & 0xffffffffffffn, 12),
  ].join('-');
}

/** Byte `index` (0 or 1) of a UUID string, as Swift's `uuid.0` / `uuid.1`. */
export function uuidByte(id: string, index: 0 | 1): number {
  const value = parseInt(id.slice(index * 2, index * 2 + 2), 16);
  return Number.isNaN(value) ? 0 : value;
}
