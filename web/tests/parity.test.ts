/**
 * The TypeScript engine must race like the Swift engine it was ported from.
 *
 * `fixtures/swift-trace-61fps.txt` is the Swift engine running a scripted race on every course
 * (`TRACE_FPS=61 tools/headless/run.sh trace` from the repository root), sampled twice a second.
 * The same script runs here and the two are compared sample by sample.
 *
 * Swift computes in 32-bit floats and TypeScript in 64-bit, so the two runs are not bit for bit
 * equal: when two sleds brush at the very edge of the contact distance, the rounding decides
 * whether a push happens, and from then on that race goes its own way. Before that happens the
 * runs agree to within a ten-thousandth of the course. 61 fps is used because at exactly 60 fps
 * many timers (a 0.8 s boost is 48 frames) land exactly on zero, where the two roundings
 * disagree by a frame.
 *
 * If you change the engine on purpose, this test will (rightly) fail; the Swift engine is no
 * longer the reference. Delete this test once the Swift app is retired.
 */
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { traceCourse, type TraceRow } from './support/trace';

const swift = new Map<number, number[][]>();
for (const line of readFileSync(new URL('./fixtures/swift-trace-61fps.txt', import.meta.url), 'utf8').split('\n')) {
  const f = line.trim().split(/\s+/);
  if (f[0] !== 'TRACE') continue;
  const course = Number(f[1]);
  if (!swift.has(course)) swift.set(course, []);
  swift.get(course)!.push(f.slice(2).map(Number));
}

/** Index of the first sample where the runs part ways, or -1 if they never do. */
function divergence(ref: number[][], mine: TraceRow[]): number {
  const n = Math.min(ref.length, mine.length);
  for (let i = 0; i < n; i += 1) {
    const [, progress, , , , crystals, hits, rivalProgress] = ref[i];
    const m = mine[i];
    if (
      Math.abs(m.progress - progress) > 1e-4 ||
      Math.abs(m.rivalProgress - rivalProgress) > 1e-4 ||
      m.crystals !== crystals ||
      m.hits !== hits
    ) {
      return i;
    }
  }
  return ref.length === mine.length ? -1 : n;
}

describe('engine races like the Swift engine', () => {
  const results = [...swift.keys()].map((course) => {
    const mine = traceCourse(course, { fps: 61 });
    const ref = swift.get(course)!;
    const at = divergence(ref, mine);
    return { course, at, t: at < 0 ? Infinity : ref[at][0] };
  });

  it('has a Swift trace for all 24 courses', () => {
    expect(results.length).toBe(24);
  });

  it('matches every course sample for sample for the first 8 seconds', () => {
    const early = results.filter((r) => r.t <= 8);
    expect(early, JSON.stringify(early)).toEqual([]);
  });

  it('matches most courses for the whole race, crystals and crashes included', () => {
    const whole = results.filter((r) => r.at < 0).length;
    expect(whole).toBeGreaterThanOrEqual(15);
  });
});
