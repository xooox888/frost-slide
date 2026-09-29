/**
 * The TypeScript course catalog must match the Swift one it was ported from.
 *
 * `fixtures/swift-catalog.json` is a dump of the Swift `LevelCatalog` made with
 * `tools/headless/run.sh catalog` (from the repository root), which replaces every
 * `Float.random(in: a...b)` in the Swift catalog with `a`. The TypeScript catalog is built here
 * with a random source that always returns 0, which gives the same lower bound, so every prop
 * can be compared exactly at 32-bit float precision.
 *
 * If you change a course on purpose, this test will (rightly) fail: the Swift catalog is no
 * longer the reference. Update the course in the Swift app too, or regenerate the fixture from
 * the TypeScript catalog with `npm run catalog:snapshot` and review the diff.
 */
import { describe, expect, it } from 'vitest';
import { buildLevel, level } from '../src/core/levelCatalog';
import { LEVEL_IDS, type LevelDefinition } from '../src/core/models';
import { stableId } from '../src/core/stableId';
import swiftCatalog from './fixtures/swift-catalog.json';

type Num = number;
interface SwiftLevel {
  id: string;
  name: string;
  subtitle: string;
  blurb: string;
  theme: string;
  length: Num;
  baseWidth: Num;
  slope: Num;
  startHeight: Num;
  parTime: Num;
  crystalTarget: Num;
  crystalStar: Num;
  checkpoints: Num[];
  palette: Record<string, Num | boolean | Num[]>;
  curves: Num[][];
  widths: Num[][];
  elevations: Num[][];
  events: (string | Num)[][];
  rivals: (string | Num | Num[])[][];
  firstIds: string[];
  entities: (string | Num)[][];
}

const swift = swiftCatalog as unknown as SwiftLevel[];
const f = Math.fround;

const bits = new Int32Array(1);
const floats = new Float32Array(bits.buffer);
/** Distance between two numbers in 32-bit float steps (ULPs). */
function ulps(a: number, b: number): number {
  floats[0] = a;
  const ia = bits[0];
  floats[0] = b;
  return Math.abs(ia - bits[0]);
}

/**
 * Equal at 32-bit float precision, with a readable failure message. `tolerance` is in float steps:
 * props placed with `sin`/`cos` may differ by a couple of steps (about a hundred-millionth of a
 * metre), because the fixture was made on Linux, whose `sinf` is not always correctly rounded
 * (for 12.6 it is one step off; JavaScript's `Math.sin` gives the correctly rounded value).
 */
function expectF32(actual: number, expected: number, where: string, tolerance = 0): void {
  if (f(actual) !== f(expected) && ulps(actual, expected) > tolerance) {
    throw new Error(`${where}: expected ${expected}, got ${actual}`);
  }
}

const TRIG_PLACED = new Set(['stalactite', 'crystalSpire', 'geyser']);

describe('course catalog matches the Swift app', () => {
  it('has the same 24 courses in the same order', () => {
    expect(swift.map((l) => l.id)).toEqual([...LEVEL_IDS]);
  });

  for (const ref of swift) {
    it(`${ref.id}: text, shape, goals, palette, rivals and every prop`, () => {
      const ts: LevelDefinition = buildLevel(ref.id as (typeof LEVEL_IDS)[number], () => 0);
      expect(ts.name).toBe(ref.name);
      expect(ts.subtitle).toBe(ref.subtitle);
      expect(ts.blurb).toBe(ref.blurb);
      expect(ts.theme).toBe(ref.theme);
      for (const key of ['length', 'baseWidth', 'slope', 'startHeight', 'parTime'] as const) {
        expectF32(ts[key], ref[key], `${ref.id}.${key}`);
      }
      expect(ts.crystalTarget).toBe(ref.crystalTarget);
      expect(ts.crystalStar).toBe(ref.crystalStar);
      expect(ts.checkpoints).toEqual(ref.checkpoints);

      for (const [key, value] of Object.entries(ref.palette)) {
        const mine = (ts.palette as unknown as Record<string, unknown>)[key];
        if (Array.isArray(value)) {
          value.forEach((c, i) => expectF32((mine as number[])[i], c, `${ref.id}.palette.${key}[${i}]`));
        } else if (typeof value === 'boolean') {
          expect(mine).toBe(value);
        } else {
          expectF32(mine as number, value, `${ref.id}.palette.${key}`);
        }
      }

      expect(ts.curves.length).toBe(ref.curves.length);
      ts.curves.forEach((c, i) => {
        [c.start, c.end, c.yawRadians].forEach((v, j) => expectF32(v, ref.curves[i][j], `${ref.id}.curves[${i}]`));
      });
      expect(ts.widths.length).toBe(ref.widths.length);
      ts.widths.forEach((w, i) => {
        [w.at, w.width, w.span].forEach((v, j) => expectF32(v, ref.widths[i][j], `${ref.id}.widths[${i}]`));
      });
      expect(ts.elevations.length).toBe(ref.elevations.length);
      ts.elevations.forEach((e, i) => {
        [e.at, e.height, e.span].forEach((v, j) => expectF32(v, ref.elevations[i][j], `${ref.id}.elevations[${i}]`));
      });
      expect(ts.events.length).toBe(ref.events.length);
      ts.events.forEach((e, i) => {
        const [kind, ...values] = ref.events[i];
        expect(e.kind).toBe(kind);
        [e.start, e.end, e.lateral, e.magnitude].forEach((v, j) =>
          expectF32(v, values[j] as number, `${ref.id}.events[${i}]`),
        );
      });

      expect(ts.rivals.length).toBe(ref.rivals.length);
      ts.rivals.forEach((r, i) => {
        const [id, name, color, personality, skill, lateral] = ref.rivals[i];
        expect(r.id).toBe(id);
        expect(r.name).toBe(name);
        (color as number[]).forEach((c, j) => expectF32(r.color[j], c, `${ref.id}.rivals[${i}].color`));
        expect(r.personality).toBe(personality);
        expectF32(r.skill, skill as number, `${ref.id}.rivals[${i}].skill`);
        expectF32(r.startLateral, lateral as number, `${ref.id}.rivals[${i}].startLateral`);
      });

      expect(ts.entities.map((e) => e.id).slice(0, 3)).toEqual(ref.firstIds);
      expect(ts.entities.length).toBe(ref.entities.length);
      ts.entities.forEach((e, i) => {
        const [kind, progress, lateral, yaw, scale, radius] = ref.entities[i];
        const where = `${ref.id}.entities[${i}] (${kind})`;
        expect(e.kind, where).toBe(kind);
        expectF32(e.progress, progress as number, `${where}.progress`);
        expectF32(e.lateral, lateral as number, `${where}.lateral`, TRIG_PLACED.has(e.kind) ? 2 : 0);
        expectF32(e.yaw, yaw as number, `${where}.yaw`);
        expectF32(e.scale, scale as number, `${where}.scale`);
        expectF32(e.radius, radius as number, `${where}.radius`);
      });
    });
  }

  it('gives every prop and rival the stable id the Swift app gives it', () => {
    const def = level('carnivalParade');
    def.entities.forEach((e, i) => expect(e.id).toBe(stableId(23, i)));
    def.rivals.forEach((r, i) => expect(r.id).toBe(stableId(23, 10_000 + i)));
  });

  it('seeds scenery so a course looks the same on every build', () => {
    const a = buildLevel('summitRush');
    const b = buildLevel('summitRush');
    expect(a.entities).toEqual(b.entities);
    const pines = a.entities.filter((e) => e.kind === 'pine');
    expect(new Set(pines.map((p) => p.scale)).size).toBeGreaterThan(5);
  });
});
