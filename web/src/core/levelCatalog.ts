/**
 * The 24 courses. A port of `Core/LevelCatalog.swift`: the course functions below were translated
 * mechanically from the Swift source and are checked against a JSON dump of the Swift catalog
 * (`tests/catalog.test.ts`).
 *
 * The Swift catalog does its arithmetic in 32-bit `Float`. Where that arithmetic decides which
 * props exist or where they sit (the stepped loops, `Int(p * 40) % 2`), this port rounds the same
 * way with `Math.fround`, so every course gets exactly the same props, in the same order, with the
 * same stable ids. Scenery that Swift scattered with the system random generator (building
 * offsets, pine sizes) is seeded here, so a course now looks the same on every launch; none of it
 * has a collision radius.
 */
import { seededRandom, type RGB } from './math';
import {
  LEVEL_IDS,
  levelOrder,
  type CourseEvent,
  type CurveKey,
  type ElevKey,
  type LevelDefinition,
  type LevelID,
  type LevelPalette,
  type LevelTheme,
  type Personality,
  type PlacedEntity,
  type PowerUpType,
  type PropKind,
  type RivalConfig,
  type WidthKey,
} from './models';
import { stableId } from './stableId';

// MARK: - 32-bit float helpers (Swift `Float` semantics)

export const f32 = Math.fround;
/** `a + b` in 32-bit float. */
export const fadd = (a: number, b: number): number => f32(f32(a) + f32(b));
/** `a * b` in 32-bit float. */
export const fmul = (a: number, b: number): number => f32(f32(a) * f32(b));
/** `sin(a)` in 32-bit float. */
export const fsin = (a: number): number => f32(Math.sin(f32(a)));
/** `cos(a)` in 32-bit float. */
export const fcos = (a: number): number => f32(Math.cos(f32(a)));
/** Swift's `Int(x)`: truncation toward zero. */
export const fint = (a: number): number => Math.trunc(a);
/** Swift's `Float.pi`, which is π rounded toward zero (one step below `Math.fround(Math.PI)`). */
export const FLOAT_PI = f32(3.1415925);

/**
 * Swift's `stride(from:through:by:)` over `Float`: each value is `start + i * step` rounded once
 * (Swift uses a fused multiply-add), and `end` itself is included when it is hit exactly.
 */
export function* strideThrough(start: number, end: number, step: number): Generator<number> {
  const s = f32(start);
  const e = f32(end);
  const d = f32(step);
  for (let i = 0; ; i += 1) {
    const v = i === 0 ? s : f32(s + i * d);
    if (v >= e) {
      if (v === e) yield v;
      return;
    }
    yield v;
  }
}

// MARK: - Builder

type EntitySpec = Omit<PlacedEntity, 'id'>;
type RivalSpec = Omit<RivalConfig, 'id'>;

interface CourseInfo {
  id: LevelID;
  name: string;
  subtitle: string;
  blurb: string;
  theme: LevelTheme;
  palette: LevelPalette;
}

export class LevelBuilder {
  length = 520;
  baseWidth = 16;
  slope = 0.11;
  parTime = 50;
  crystalStar = 24;
  readonly curves: CurveKey[] = [];
  readonly widths: WidthKey[] = [];
  readonly elevations: ElevKey[] = [];
  readonly entities: EntitySpec[] = [];
  readonly events: CourseEvent[] = [];
  private rivalConfigs: RivalSpec[] = [];

  constructor(
    readonly info: CourseInfo,
    /** Source of scenery randomness, 0 ≤ value < 1. */
    private readonly random: () => number,
  ) {}

  /** `Float.random(in: lo...hi)`. */
  private rand(lo: number, hi: number): number {
    return f32(lo + (hi - lo) * this.random());
  }

  private add(kind: PropKind, progress: number, lateral = 0, yaw = 0, scale = 1, radius = 1): void {
    this.entities.push({
      kind,
      progress: f32(progress),
      lateral: f32(lateral),
      yaw: f32(yaw),
      scale: f32(scale),
      radius: f32(radius),
    });
  }

  curve(start: number, end: number, yaw: number): void {
    this.curves.push({ start: f32(start), end: f32(end), yawRadians: f32(yaw) });
  }

  width(at: number, width: number, span: number): void {
    this.widths.push({ at: f32(at), width: f32(width), span: f32(span) });
  }

  elevation(at: number, height: number, span: number): void {
    this.elevations.push({ at: f32(at), height: f32(height), span: f32(span) });
  }

  arch(progress: number): void {
    this.add('arch', progress, 0, 0, 1, 0);
  }

  ramp(progress: number, lateral = 0): void {
    this.add('ramp', progress, lateral, 0, 1, 2.4);
  }

  turbo(progress: number, lateral = 0): void {
    this.add('turboPad', progress, lateral, 0, 1, 2.1);
  }

  crystalLane(from: number, to: number, lateral: number, count: number): void {
    if (count <= 1) return;
    const a = f32(from);
    const span = f32(f32(to) - a);
    for (let i = 0; i < count; i += 1) {
      const t = f32(i / (count - 1));
      this.add('crystal', f32(a + fmul(span, t)), lateral, 0, 1, 0.85);
    }
  }

  power(type: PowerUpType, progress: number, lateral: number): void {
    this.add(type, progress, lateral, 0, 1, 0.95);
  }

  hazard(kind: PropKind, progress: number, lateral: number, radius = 1.05): void {
    this.add(kind, progress, lateral, 0, 1, radius);
  }

  rivals(list: RivalSpec[]): void {
    this.rivalConfigs = list;
  }

  /**
   * A wall of snow that starts running when the player reaches `from` and dies out at `to`.
   * `pace` is its speed as a fraction of the player's cruising speed on this course, so 0.9 means
   * a clean run slowly pulls away while every crash gives the wall ground back. Set `length` and
   * `slope` before calling this.
   */
  avalanche(from: number, to: number, pace = 0.9): void {
    const cruise = fadd(13.5, fmul(this.slope, 22));
    this.events.push({
      kind: 'avalanche',
      start: f32(from),
      end: f32(to),
      lateral: 0,
      magnitude: f32(fmul(cruise, pace) / f32(this.length)),
    });
    this.add('avalanche', from, 0, 0, 1, 12);
  }

  shortcut(progress: number, lateral: number, skip = 0.03): void {
    this.events.push({
      kind: 'shortcut',
      start: f32(progress),
      end: fadd(progress, 0.02),
      lateral: f32(lateral),
      magnitude: f32(skip),
    });
    this.add('shortcut', progress, lateral, 0, 1, 1.55);
  }

  lineBuildings(step: number): void {
    const half = fmul(this.baseWidth, 0.5);
    let p = f32(0.03);
    let flip = false;
    while (p < f32(0.96)) {
      const clear = [0.16, 0.37, 0.61, 0.83].every((arch) => Math.abs(f32(p - f32(arch))) > f32(0.03));
      if (clear) {
        const side = flip ? 1 : -1;
        const lateral = fmul(side, fadd(fadd(half, 5.5), this.rand(0, 1.4)));
        const yaw = this.rand(-0.12, 0.12);
        const scale = this.rand(0.85, 1.25);
        this.add('building', p, lateral, yaw, scale, 0);
        if (fint(fmul(p, 100)) % 4 === 0) {
          this.add('chimney', fadd(p, 0.01), fmul(side, fadd(half, 3.2)), 0, 1, 0);
        }
      }
      flip = !flip;
      p = fadd(p, step);
    }
  }

  lineMarket(step: number): void {
    const half = fmul(this.baseWidth, 0.5);
    let p = f32(0.04);
    let flip = false;
    while (p < f32(0.95)) {
      const side = flip ? 1 : -1;
      this.add('stall', p, fmul(side, fadd(half, 2.8)), side > 0 ? FLOAT_PI : 0, this.rand(0.9, 1.15), 0);
      if (fint(fmul(p, 50)) % 3 === 0) {
        this.add('barrel', fadd(p, 0.015), fmul(side, fadd(half, 1.6)), 0, 1, 0.6);
      }
      flip = !flip;
      p = fadd(p, step);
    }
  }

  decorateCave(): void {
    for (const p of strideThrough(0.05, 0.95, 0.04)) {
      this.add('icicle', p, -6.5, 0, this.rand(0.8, 1.4), 0);
      this.add('icicle', fadd(p, 0.02), 6.5, 0, this.rand(0.8, 1.4), 0);
    }
  }

  decorateAurora(): void {
    for (const p of strideThrough(0.08, 0.92, 0.07)) {
      this.add('lantern', p, fint(fmul(p, 20)) % 2 === 0 ? -7 : 7, 0, 1, 0);
      this.add('auroraRibbon', p, 0, 0, 1, 0);
    }
    for (const p of strideThrough(0.1, 0.9, 0.12)) {
      this.add('pine', p, -11, 0, 1.1, 0);
      this.add('pine', fadd(p, 0.05), 11, 0, 1.2, 0);
    }
  }

  decorateHarbor(): void {
    for (const p of strideThrough(0.06, 0.94, 0.07)) {
      this.add('dock', p, 0, 0, 1, 0);
      if (fint(fmul(p, 100)) % 2 === 0) {
        this.add('boat', p, fint(fmul(p, 10)) % 2 === 0 ? -12 : 12, 0, 1, 0);
      }
      this.add('lamp', p, fint(fmul(p, 14)) % 2 === 0 ? -5.5 : 5.5, 0, 1, 0);
    }
  }

  decorateSummit(): void {
    for (const p of strideThrough(0.05, 0.95, 0.05)) {
      const leftLateral = f32(-12 - this.rand(0, 3));
      this.add('pine', p, leftLateral, 0, this.rand(1.0, 1.6), 0);
      const rightLateral = fadd(12, this.rand(0, 3));
      this.add('pine', fadd(p, 0.02), rightLateral, 0, this.rand(1.0, 1.6), 0);
    }
  }

  decorateForest(): void {
    for (const p of strideThrough(0.04, 0.96, 0.045)) {
      const leftLateral = f32(-10 - this.rand(0, 2.4));
      this.add('pine', p, leftLateral, 0, this.rand(0.95, 1.5), 0);
      const rightLateral = fadd(10, this.rand(0, 2.4));
      this.add('pine', fadd(p, 0.02), rightLateral, 0, this.rand(0.95, 1.5), 0);
    }
    for (const p of strideThrough(0.1, 0.9, 0.14)) {
      this.add('lantern', p, fint(fmul(p, 18)) % 2 === 0 ? -6.4 : 6.4, 0, 1, 0);
    }
  }

  decorateCanyon(): void {
    for (const p of strideThrough(0.06, 0.94, 0.06)) {
      this.add('crystalSpire', p, -8.5, 0, 1.3, 0);
      this.add('crystalSpire', fadd(p, 0.03), 8.5, 0, 1.4, 0);
    }
  }

  decorateSteam(): void {
    for (const p of strideThrough(0.08, 0.92, 0.07)) {
      this.add('geyser', p, fint(fmul(p, 12)) % 2 === 0 ? -7 : 7, 0, 1, 0);
      this.add('pine', p, -12, 0, 0.9, 0);
    }
  }

  decorateBlizzard(): void {
    this.decorateSummit();
    for (const p of strideThrough(0.1, 0.9, 0.1)) {
      this.add('wind', p, 0, 0, 1, 0);
    }
  }

  decorateNeon(): void {
    for (const p of strideThrough(0.08, 0.92, 0.07)) {
      this.add('neonArch', p, 0, 0, 1, 0);
      this.add('lantern', p, fint(fmul(p, 16)) % 2 === 0 ? -7.2 : 7.2, 0, 1, 0);
    }
  }

  decorateCarnival(): void {
    for (const p of strideThrough(0.07, 0.93, 0.08)) {
      this.add('carnivalFloat', p, fint(fmul(p, 10)) % 2 === 0 ? -9 : 9, 0, 1, 0);
      this.add('lantern', fadd(p, 0.03), fint(fmul(p, 14)) % 2 === 0 ? -6 : 6, 0, 1, 0);
    }
  }

  build(): LevelDefinition {
    const order = levelOrder(this.info.id);
    const all: EntitySpec[] = [...this.entities];
    const fixed = (kind: PropKind, progress: number, radius: number): EntitySpec => ({
      kind,
      progress: f32(progress),
      lateral: 0,
      yaw: 0,
      scale: 1,
      radius: f32(radius),
    });
    all.push(fixed('startBanner', 0.018, 0));
    all.push(fixed('finish', 0.992, 2.5));
    for (const cp of [0.25, 0.5, 0.75]) all.push(fixed('checkpoint', cp, 0));
    // Authored content gets stable ids. Rivals decide which obstacles they overlook from these,
    // so a course plays the same way on every launch instead of reshuffling itself.
    const entities: PlacedEntity[] = all.map((e, index) => ({ id: stableId(order, index), ...e }));
    const rivals: RivalConfig[] = this.rivalConfigs.map((r, index) => ({ id: stableId(order, 10_000 + index), ...r }));
    const length = f32(this.length);
    const slope = f32(this.slope);
    return {
      id: this.info.id,
      name: this.info.name,
      subtitle: this.info.subtitle,
      blurb: this.info.blurb,
      theme: this.info.theme,
      palette: this.info.palette,
      length,
      baseWidth: f32(this.baseWidth),
      slope,
      startHeight: fadd(fmul(length, slope), 10),
      curves: this.curves,
      widths: this.widths,
      elevations: this.elevations,
      entities,
      rivals,
      checkpoints: [0, 0.25, 0.5, 0.75],
      parTime: this.parTime,
      crystalTarget: entities.filter((e) => e.kind === 'crystal').length,
      crystalStar: this.crystalStar,
      events: this.events,
    };
  }
}

// MARK: - Rivals

const rivalPreset =
  (name: string, color: RGB, personality: Personality) =>
  (skill: number, lateral: number): RivalSpec => ({
    name,
    color,
    personality,
    skill: f32(skill),
    startLateral: f32(lateral),
  });

export const rival = {
  pico: rivalPreset('Pico', [0.22, 0.78, 0.42], 'aggressive'),
  ruby: rivalPreset('Ruby', [0.92, 0.24, 0.32], 'hoarder'),
  violet: rivalPreset('Violet', [0.58, 0.38, 0.86], 'cautious'),
  navy: rivalPreset('Navy', [0.16, 0.38, 0.78], 'cautious'),
  amber: rivalPreset('Amber', [0.96, 0.62, 0.18], 'aggressive'),
  frost: rivalPreset('Frost', [0.7, 0.88, 1.0], 'aggressive'),
  mint: rivalPreset('Mint', [0.32, 0.86, 0.62], 'cautious'),
  coral: rivalPreset('Coral', [1.0, 0.42, 0.48], 'hoarder'),
};

// MARK: - Palettes

export const PALETTES = {
  village: {
    snow: [0.96, 0.98, 1.0],
    ice: [0.55, 0.82, 1.0],
    skyTop: [0.72, 0.88, 0.98],
    skyBottom: [0.9, 0.95, 1.0],
    fog: [0.88, 0.93, 0.98],
    fogStart: 28,
    fogEnd: 140,
    ambient: [0.78, 0.82, 0.88],
    sunColor: [1.0, 0.96, 0.88],
    sunIntensity: 900,
    wall: [0.89, 0.7, 0.36],
    accent: [0.2, 0.62, 1.0],
    wood: [0.55, 0.36, 0.22],
    night: false,
  },
  market: {
    snow: [0.95, 0.96, 0.93],
    ice: [0.6, 0.8, 0.95],
    skyTop: [0.78, 0.86, 0.92],
    skyBottom: [0.94, 0.93, 0.88],
    fog: [0.9, 0.9, 0.86],
    fogStart: 22,
    fogEnd: 110,
    ambient: [0.8, 0.76, 0.7],
    sunColor: [1.0, 0.9, 0.72],
    sunIntensity: 800,
    wall: [0.82, 0.42, 0.28],
    accent: [0.95, 0.55, 0.18],
    wood: [0.5, 0.32, 0.18],
    night: false,
  },
  cave: {
    snow: [0.62, 0.82, 0.95],
    ice: [0.35, 0.72, 0.95],
    skyTop: [0.05, 0.12, 0.22],
    skyBottom: [0.1, 0.22, 0.34],
    fog: [0.18, 0.32, 0.46],
    fogStart: 8,
    fogEnd: 70,
    ambient: [0.22, 0.36, 0.48],
    sunColor: [0.45, 0.75, 1.0],
    sunIntensity: 400,
    wall: [0.22, 0.4, 0.55],
    accent: [0.35, 0.85, 1.0],
    wood: [0.3, 0.24, 0.22],
    night: true,
  },
  aurora: {
    snow: [0.78, 0.84, 0.95],
    ice: [0.45, 0.95, 0.75],
    skyTop: [0.05, 0.08, 0.18],
    skyBottom: [0.08, 0.16, 0.28],
    fog: [0.12, 0.16, 0.28],
    fogStart: 16,
    fogEnd: 90,
    ambient: [0.2, 0.28, 0.4],
    sunColor: [0.55, 0.8, 1.0],
    sunIntensity: 280,
    wall: [0.28, 0.24, 0.42],
    accent: [0.45, 1.0, 0.7],
    wood: [0.32, 0.26, 0.22],
    night: true,
  },
  harbor: {
    snow: [0.9, 0.93, 0.95],
    ice: [0.5, 0.72, 0.82],
    skyTop: [0.62, 0.74, 0.82],
    skyBottom: [0.82, 0.86, 0.88],
    fog: [0.74, 0.8, 0.84],
    fogStart: 20,
    fogEnd: 120,
    ambient: [0.62, 0.7, 0.76],
    sunColor: [0.9, 0.92, 0.95],
    sunIntensity: 650,
    wall: [0.46, 0.34, 0.26],
    accent: [0.18, 0.48, 0.7],
    wood: [0.46, 0.3, 0.18],
    night: false,
  },
  summit: {
    snow: [0.97, 0.98, 1.0],
    ice: [0.7, 0.88, 1.0],
    skyTop: [0.45, 0.7, 0.92],
    skyBottom: [0.86, 0.92, 0.98],
    fog: [0.9, 0.94, 0.98],
    fogStart: 30,
    fogEnd: 160,
    ambient: [0.82, 0.86, 0.92],
    sunColor: [1.0, 0.98, 0.94],
    sunIntensity: 1100,
    wall: [0.78, 0.82, 0.88],
    accent: [0.2, 0.62, 1.0],
    wood: [0.38, 0.26, 0.18],
    night: false,
  },
  forest: {
    snow: [0.9, 0.95, 0.92],
    ice: [0.45, 0.78, 0.62],
    skyTop: [0.42, 0.62, 0.58],
    skyBottom: [0.78, 0.88, 0.82],
    fog: [0.72, 0.82, 0.76],
    fogStart: 18,
    fogEnd: 110,
    ambient: [0.55, 0.68, 0.58],
    sunColor: [0.85, 0.95, 0.8],
    sunIntensity: 700,
    wall: [0.28, 0.42, 0.3],
    accent: [0.2, 0.72, 0.48],
    wood: [0.4, 0.26, 0.16],
    night: false,
  },
  forestNight: {
    snow: [0.7, 0.78, 0.82],
    ice: [0.4, 0.7, 0.78],
    skyTop: [0.06, 0.1, 0.16],
    skyBottom: [0.1, 0.16, 0.22],
    fog: [0.12, 0.16, 0.2],
    fogStart: 10,
    fogEnd: 70,
    ambient: [0.22, 0.3, 0.28],
    sunColor: [0.45, 0.7, 0.8],
    sunIntensity: 260,
    wall: [0.16, 0.24, 0.2],
    accent: [0.45, 0.9, 0.7],
    wood: [0.28, 0.2, 0.14],
    night: true,
  },
  canyon: {
    snow: [0.82, 0.9, 0.98],
    ice: [0.55, 0.8, 1.0],
    skyTop: [0.18, 0.32, 0.52],
    skyBottom: [0.42, 0.58, 0.78],
    fog: [0.4, 0.55, 0.72],
    fogStart: 14,
    fogEnd: 90,
    ambient: [0.4, 0.52, 0.68],
    sunColor: [0.7, 0.88, 1.0],
    sunIntensity: 620,
    wall: [0.42, 0.62, 0.82],
    accent: [0.45, 0.9, 1.0],
    wood: [0.36, 0.28, 0.22],
    night: false,
  },
  steam: {
    snow: [0.92, 0.94, 0.9],
    ice: [0.7, 0.86, 0.8],
    skyTop: [0.62, 0.7, 0.68],
    skyBottom: [0.88, 0.86, 0.78],
    fog: [0.82, 0.84, 0.78],
    fogStart: 8,
    fogEnd: 70,
    ambient: [0.7, 0.68, 0.6],
    sunColor: [1.0, 0.86, 0.62],
    sunIntensity: 540,
    wall: [0.62, 0.48, 0.36],
    accent: [0.95, 0.55, 0.28],
    wood: [0.48, 0.32, 0.2],
    night: false,
  },
  blizzard: {
    snow: [0.96, 0.98, 1.0],
    ice: [0.78, 0.9, 1.0],
    skyTop: [0.62, 0.7, 0.8],
    skyBottom: [0.88, 0.92, 0.96],
    fog: [0.9, 0.93, 0.97],
    fogStart: 6,
    fogEnd: 55,
    ambient: [0.78, 0.84, 0.9],
    sunColor: [0.9, 0.94, 1.0],
    sunIntensity: 380,
    wall: [0.8, 0.86, 0.92],
    accent: [0.55, 0.78, 1.0],
    wood: [0.4, 0.3, 0.22],
    night: false,
  },
  neon: {
    snow: [0.16, 0.18, 0.28],
    ice: [0.2, 0.9, 1.0],
    skyTop: [0.04, 0.04, 0.12],
    skyBottom: [0.1, 0.06, 0.2],
    fog: [0.08, 0.06, 0.16],
    fogStart: 12,
    fogEnd: 80,
    ambient: [0.18, 0.14, 0.28],
    sunColor: [0.8, 0.3, 1.0],
    sunIntensity: 220,
    wall: [0.18, 0.1, 0.32],
    accent: [1.0, 0.28, 0.72],
    wood: [0.22, 0.16, 0.28],
    night: true,
  },
  carnival: {
    snow: [0.96, 0.92, 0.88],
    ice: [1.0, 0.45, 0.62],
    skyTop: [0.28, 0.1, 0.32],
    skyBottom: [0.55, 0.18, 0.36],
    fog: [0.42, 0.18, 0.32],
    fogStart: 16,
    fogEnd: 100,
    ambient: [0.5, 0.28, 0.36],
    sunColor: [1.0, 0.7, 0.35],
    sunIntensity: 520,
    wall: [0.72, 0.22, 0.38],
    accent: [1.0, 0.82, 0.2],
    wood: [0.5, 0.28, 0.18],
    night: false,
  },
} satisfies Record<string, LevelPalette>;

// MARK: - Courses

function villageDash(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'villageDash',
      name: 'Village Dash',
      subtitle: 'Ice-crystal arches & wide streets',
      blurb:
        'Race the first snowfall through a painted alpine town. Thread the cyan arches, pop the ramps, and learn the carve.',
      theme: 'village',
      palette: PALETTES.village,
    },
    random,
  );
  b.length = 560;
  b.baseWidth = 17;
  b.slope = 0.11;
  b.parTime = 28;
  b.crystalStar = 29;
  b.curve(0.04, 0.22, 0.65);
  b.curve(0.22, 0.4, -1.05);
  b.curve(0.4, 0.58, 0.95);
  b.curve(0.58, 0.78, -0.85);
  b.curve(0.78, 0.96, 0.55);
  b.arch(0.16);
  b.arch(0.37);
  b.arch(0.61);
  b.arch(0.83);
  b.ramp(0.23);
  b.ramp(0.47, -2);
  b.ramp(0.71, 1.5);
  b.turbo(0.31);
  b.turbo(0.66);
  b.crystalLane(0.08, 0.18, 0, 7);
  b.crystalLane(0.26, 0.35, 3.2, 6);
  b.crystalLane(0.42, 0.54, -2.5, 8);
  b.crystalLane(0.62, 0.74, 0.8, 7);
  b.crystalLane(0.8, 0.9, -3, 6);
  b.power('magnet', 0.28, 4);
  b.power('banana', 0.44, -4);
  b.power('rocket', 0.58, 0);
  b.power('ghost', 0.76, 3.5);
  b.hazard('snowman', 0.19, -5);
  b.hazard('snowman', 0.33, 5.5);
  b.hazard('crate', 0.41, 0);
  b.hazard('snowman', 0.52, -4.5);
  b.hazard('crate', 0.64, 4);
  b.hazard('snowman', 0.73, -6);
  b.hazard('crate', 0.86, 2);
  b.lineBuildings(0.028);
  b.rivals([rival.pico(1.016, -3.2), rival.ruby(0.996, 3.4), rival.violet(0.966, 0.6)]);
  return b.build();
}

function marketMayhem(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'marketMayhem',
      name: 'Market Mayhem',
      subtitle: 'Tight alleys & darting stalls',
      blurb: 'Squeeze through a packed winter market. Crates, carts, and shopkeepers who never look both ways.',
      theme: 'market',
      palette: PALETTES.market,
    },
    random,
  );
  b.length = 520;
  b.baseWidth = 11.5;
  b.slope = 0.1;
  b.parTime = 28;
  b.crystalStar = 24;
  b.curve(0.0, 0.18, 0.9);
  b.curve(0.18, 0.34, -1.2);
  b.curve(0.34, 0.52, 1.15);
  b.curve(0.52, 0.7, -1.0);
  b.curve(0.7, 0.88, 0.85);
  b.width(0.2, 9.2, 0.1);
  b.width(0.48, 8.6, 0.12);
  b.width(0.74, 9.0, 0.1);
  b.ramp(0.29, 0);
  b.ramp(0.63, -1);
  b.turbo(0.17);
  b.turbo(0.55);
  b.turbo(0.81);
  b.crystalLane(0.06, 0.14, 0, 6);
  b.crystalLane(0.22, 0.32, 2.2, 6);
  b.crystalLane(0.38, 0.48, -2.0, 7);
  b.crystalLane(0.58, 0.68, 1.6, 6);
  b.crystalLane(0.78, 0.9, 0, 7);
  b.power('ghost', 0.24, -3);
  b.power('magnet', 0.46, 3);
  b.power('banana', 0.6, 0);
  b.power('rocket', 0.84, -2);
  for (const p of strideThrough(0.12, 0.9, 0.08)) {
    b.hazard('stall', p, fint(fmul(p, 40)) % 2 === 0 ? -4.4 : 4.4, 1.1);
  }
  b.hazard('crate', 0.21, 1.2);
  b.hazard('crate', 0.35, -1.4);
  b.hazard('cart', 0.42, 0, 1.15);
  b.hazard('npc', 0.31, 0, 0.8);
  b.hazard('npc', 0.5, 1.5, 0.8);
  b.hazard('cart', 0.67, -1, 1.15);
  b.hazard('npc', 0.73, -0.5, 0.8);
  b.hazard('crate', 0.79, 2);
  b.lineMarket(0.045);
  b.rivals([rival.pico(1.053, -2.4), rival.ruby(1.032, 2.6), rival.violet(0.992, 0.2), rival.navy(1.022, -0.8)]);
  return b.build();
}

function iceCaveSpiral(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'iceCaveSpiral',
      name: 'Ice Cave Spiral',
      subtitle: 'Blue tunnels & stalactites',
      blurb: 'A descending helix of glassy ice. Hold your line through the spiral or kiss a stalactite.',
      theme: 'cave',
      palette: PALETTES.cave,
    },
    random,
  );
  b.length = 600;
  b.baseWidth = 13;
  b.slope = 0.13;
  b.parTime = 30.5;
  b.crystalStar = 25;
  b.curve(0.0, 1.0, 5.2);
  b.width(0.3, 10.5, 0.14);
  b.width(0.62, 10.0, 0.12);
  b.ramp(0.26);
  b.ramp(0.54);
  b.ramp(0.78);
  b.turbo(0.2);
  b.turbo(0.48);
  b.turbo(0.73);
  b.crystalLane(0.07, 0.18, 2.2, 7);
  b.crystalLane(0.22, 0.34, -2.8, 7);
  b.crystalLane(0.4, 0.52, 0, 8);
  b.crystalLane(0.58, 0.7, 3.0, 7);
  b.crystalLane(0.8, 0.92, -2.2, 7);
  b.power('ghost', 0.18, 0);
  b.power('magnet', 0.4, -3.5);
  b.power('rocket', 0.66, 3.2);
  b.power('banana', 0.82, 0);
  for (const p of strideThrough(0.14, 0.9, 0.09)) {
    b.hazard('stalactite', p, fmul(fsin(fmul(p, 28)), 3.2), 0.85);
    b.hazard('icePatch', fadd(p, 0.03), 0, 3.4);
  }
  b.hazard('icePatch', 0.25, 2, 3.2);
  b.decorateCave();
  b.rivals([rival.violet(1.0, 2.8), rival.pico(1.03, -2.6), rival.ruby(0.97, 0.4)]);
  return b.build();
}

function auroraNight(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'auroraNight',
      name: 'Aurora Night',
      subtitle: 'Glow pads & low visibility',
      blurb: 'Night race under a living sky. Trust the glowing pads — the fog will lie to you.',
      theme: 'aurora',
      palette: PALETTES.aurora,
    },
    random,
  );
  b.length = 580;
  b.baseWidth = 15;
  b.slope = 0.105;
  b.parTime = 31;
  b.crystalStar = 26;
  b.curve(0.05, 0.25, -0.8);
  b.curve(0.25, 0.48, 1.25);
  b.curve(0.48, 0.7, -1.1);
  b.curve(0.7, 0.92, 0.75);
  b.ramp(0.21);
  b.ramp(0.49, 2);
  b.ramp(0.76, -1.5);
  b.turbo(0.14);
  b.turbo(0.36);
  b.turbo(0.58);
  b.turbo(0.8);
  b.crystalLane(0.08, 0.16, 0, 6);
  b.crystalLane(0.24, 0.34, -3.2, 6);
  b.crystalLane(0.4, 0.5, 3.4, 7);
  b.crystalLane(0.6, 0.7, 0, 6);
  b.crystalLane(0.82, 0.92, -2.4, 6);
  b.power('rocket', 0.27, 0);
  b.power('magnet', 0.45, 4);
  b.power('ghost', 0.68, -4);
  b.power('banana', 0.86, 2);
  b.hazard('snowman', 0.18, 5);
  b.hazard('crate', 0.32, -2);
  b.hazard('cart', 0.52, 0);
  b.hazard('snowman', 0.64, -5);
  b.hazard('crate', 0.74, 3);
  b.hazard('snowman', 0.88, 0);
  b.decorateAurora();
  b.rivals([rival.ruby(1.006, 3.0), rival.pico(0.976, -3.2), rival.violet(0.916, 0.8), rival.amber(0.956, -1.0)]);
  return b.build();
}

function harborFreeze(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'harborFreeze',
      name: 'Harbor Freeze',
      subtitle: 'Icy planks & black water',
      blurb:
        "Docks, boats, and no second chances if you kiss the drink. Fall in and you'll respawn with a three-second sting.",
      theme: 'harbor',
      palette: PALETTES.harbor,
    },
    random,
  );
  b.length = 540;
  b.baseWidth = 12;
  b.slope = 0.09;
  b.parTime = 30;
  b.crystalStar = 20;
  b.curve(0.06, 0.24, 0.55);
  b.curve(0.24, 0.44, -0.95);
  b.curve(0.44, 0.66, 0.85);
  b.curve(0.66, 0.9, -0.6);
  b.width(0.18, 8.0, 0.12);
  b.width(0.4, 7.2, 0.14);
  b.width(0.62, 7.6, 0.12);
  b.width(0.82, 8.4, 0.1);
  b.ramp(0.28);
  b.ramp(0.57);
  b.turbo(0.22);
  b.turbo(0.5);
  b.turbo(0.78);
  b.crystalLane(0.08, 0.16, 0, 5);
  b.crystalLane(0.26, 0.36, 1.8, 6);
  b.crystalLane(0.46, 0.56, -1.6, 6);
  b.crystalLane(0.68, 0.8, 0, 6);
  b.power('ghost', 0.2, 2.4);
  b.power('magnet', 0.38, -2.2);
  b.power('banana', 0.54, 0);
  b.power('rocket', 0.72, 1.8);
  b.hazard('crate', 0.17, 1);
  b.hazard('cart', 0.34, 0);
  b.hazard('crate', 0.48, -1.2);
  b.hazard('bridge', 0.6, 0, 1.4);
  b.hazard('crate', 0.7, 2);
  b.hazard('cart', 0.84, -0.6);
  for (const p of strideThrough(0.12, 0.92, 0.06)) {
    b.hazard('water', p, -9.5, 4.6);
    b.hazard('water', fadd(p, 0.02), 9.5, 4.6);
  }
  b.decorateHarbor();
  b.rivals([rival.navy(0.989, -2.2), rival.pico(0.978, 2.4), rival.violet(0.918, 0.3)]);
  return b.build();
}

function summitRush(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'summitRush',
      name: 'Summit Rush',
      subtitle: 'Steep faces & wild wind',
      blurb: 'The mountain wants you airborne. Big jumps, bigger gusts, and five hungry rivals on the same face.',
      theme: 'summit',
      palette: PALETTES.summit,
    },
    random,
  );
  b.length = 640;
  b.baseWidth = 18;
  b.slope = 0.16;
  b.parTime = 30;
  b.crystalStar = 25;
  b.curve(0.04, 0.2, 0.45);
  b.curve(0.2, 0.38, -0.7);
  b.curve(0.38, 0.58, 0.9);
  b.curve(0.58, 0.78, -0.75);
  b.curve(0.78, 0.96, 0.4);
  b.elevation(0.22, 3.4, 0.06);
  b.elevation(0.46, 5.2, 0.08);
  b.elevation(0.7, 6.0, 0.09);
  b.ramp(0.21);
  b.ramp(0.45);
  b.ramp(0.69);
  b.turbo(0.12);
  b.turbo(0.34);
  b.turbo(0.58);
  b.turbo(0.82);
  b.crystalLane(0.06, 0.14, 0, 6);
  b.crystalLane(0.24, 0.33, 4, 7);
  b.crystalLane(0.4, 0.5, -3.5, 8);
  b.crystalLane(0.56, 0.66, 2.2, 7);
  b.crystalLane(0.78, 0.9, 0, 8);
  b.power('rocket', 0.18, 0);
  b.power('magnet', 0.36, -5);
  b.power('ghost', 0.52, 5);
  b.power('banana', 0.64, 0);
  b.power('rocket', 0.86, 3);
  b.hazard('wind', 0.3, 0, 8);
  b.hazard('wind', 0.5, 0, 8);
  b.hazard('wind', 0.74, 0, 8);
  b.hazard('snowman', 0.16, -6);
  b.hazard('crate', 0.28, 3);
  b.hazard('snowman', 0.42, 6);
  b.hazard('crate', 0.6, -4);
  b.hazard('snowman', 0.8, 5);
  b.decorateSummit();
  b.rivals([
    rival.pico(1.082, -4.0),
    rival.ruby(1.063, 4.2),
    rival.violet(0.991, 1.2),
    rival.navy(1.032, -1.6),
    rival.amber(1.042, 0.2),
  ]);
  return b.build();
}

function alleySprint(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'alleySprint',
      name: 'Alley Sprint',
      subtitle: 'Squeeze + shortcut gates',
      blurb: "The market's back streets. Hit the cyan gate on the left for a dirty cut.",
      theme: 'market',
      palette: PALETTES.market,
    },
    random,
  );
  b.length = 500;
  b.baseWidth = 10.4;
  b.slope = 0.105;
  b.parTime = 26;
  b.crystalStar = 25;
  b.curve(0.0, 0.16, 1.15);
  b.curve(0.16, 0.34, -1.35);
  b.curve(0.34, 0.52, 1.05);
  b.curve(0.52, 0.72, -1.2);
  b.curve(0.72, 0.94, 0.8);
  b.width(0.28, 8.2, 0.1);
  b.width(0.6, 7.8, 0.1);
  b.ramp(0.22);
  b.ramp(0.58, 1.2);
  b.turbo(0.14);
  b.turbo(0.48);
  b.turbo(0.82);
  b.crystalLane(0.06, 0.14, 0, 6);
  b.crystalLane(0.2, 0.3, 2.0, 6);
  b.crystalLane(0.36, 0.46, -2.2, 7);
  b.crystalLane(0.56, 0.66, 1.4, 6);
  b.crystalLane(0.76, 0.88, 0, 7);
  b.power('ghost', 0.18, -2.6);
  b.power('magnet', 0.4, 2.8);
  b.power('banana', 0.62, 0);
  b.power('rocket', 0.8, -1.6);
  b.shortcut(0.41, -3.6, 0.028);
  b.hazard('stall', 0.15, -3.8, 1.0);
  b.hazard('crate', 0.26, 1.0);
  b.hazard('npc', 0.33, 0, 0.75);
  b.hazard('cart', 0.5, 0.6, 1.1);
  b.hazard('crate', 0.68, -1.2);
  b.hazard('npc', 0.77, 1.4, 0.75);
  b.hazard('stall', 0.88, 3.6, 1.0);
  b.lineMarket(0.05);
  b.rivals([rival.pico(0.984, -2.0), rival.ruby(0.954, 2.2), rival.coral(0.934, 0.2)]);
  return b.build();
}

function crystalGrotto(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'crystalGrotto',
      name: 'Crystal Grotto',
      subtitle: 'Spires & ice patches',
      blurb: 'A glittering chamber. Spires split the lane; ice patches steal your grip.',
      theme: 'canyon',
      palette: PALETTES.canyon,
    },
    random,
  );
  b.length = 590;
  b.baseWidth = 13.5;
  b.slope = 0.12;
  b.parTime = 30.5;
  b.crystalStar = 28;
  b.curve(0.0, 0.22, 0.85);
  b.curve(0.22, 0.48, -1.15);
  b.curve(0.48, 0.74, 1.05);
  b.curve(0.74, 1.0, -0.7);
  b.width(0.36, 11.0, 0.12);
  b.ramp(0.24);
  b.ramp(0.62, -1.5);
  b.turbo(0.16);
  b.turbo(0.44);
  b.turbo(0.78);
  b.crystalLane(0.06, 0.16, 2.4, 7);
  b.crystalLane(0.22, 0.34, -2.6, 7);
  b.crystalLane(0.42, 0.54, 0, 8);
  b.crystalLane(0.62, 0.74, 3.0, 7);
  b.crystalLane(0.82, 0.92, -2.0, 7);
  b.power('magnet', 0.2, 0);
  b.power('ghost', 0.48, -3.4);
  b.power('rocket', 0.7, 3.2);
  b.power('flare', 0.86, 0);
  for (const p of strideThrough(0.14, 0.88, 0.1)) {
    b.hazard('crystalSpire', p, fmul(fsin(fmul(p, 22)), 3.4), 0.9);
    b.hazard('icePatch', fadd(p, 0.04), 0, 3.0);
  }
  b.decorateCanyon();
  b.rivals([rival.violet(1.019, 2.6), rival.pico(1.039, -2.4), rival.mint(0.979, 0.3)]);
  return b.build();
}

function frozenHollow(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'frozenHollow',
      name: 'Frozen Hollow',
      subtitle: 'Tight helix + avalanche',
      blurb: 'The cave narrows and the ceiling lets go. Stay ahead of the white wall.',
      theme: 'cave',
      palette: PALETTES.cave,
    },
    random,
  );
  b.length = 620;
  b.baseWidth = 11.2;
  b.slope = 0.14;
  b.parTime = 31;
  b.crystalStar = 31;
  b.curve(0.0, 1.0, 6.4);
  b.width(0.24, 9.4, 0.1);
  b.width(0.58, 8.8, 0.12);
  b.ramp(0.2);
  b.ramp(0.52);
  b.ramp(0.8);
  b.turbo(0.12);
  b.turbo(0.4);
  b.turbo(0.68);
  b.crystalLane(0.06, 0.16, 1.8, 7);
  b.crystalLane(0.22, 0.34, -2.2, 7);
  b.crystalLane(0.4, 0.5, 0, 7);
  b.crystalLane(0.58, 0.7, 2.4, 7);
  b.crystalLane(0.78, 0.9, -1.6, 8);
  b.power('ghost', 0.18, 0);
  b.power('magnet', 0.46, -2.8);
  b.power('rocket', 0.64, 2.6);
  b.power('banana', 0.84, 0);
  b.avalanche(0.52, 0.9, 1.12);
  for (const p of strideThrough(0.12, 0.88, 0.08)) {
    b.hazard('stalactite', p, fmul(fcos(fmul(p, 30)), 2.6), 0.8);
  }
  b.decorateCave();
  b.rivals([rival.pico(1.06, -2.2), rival.ruby(1.02, 2.4), rival.navy(0.99, 0.2), rival.violet(0.97, 1.0)]);
  return b.build();
}

function polarVeil(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'polarVeil',
      name: 'Polar Veil',
      subtitle: 'Flares & hidden cut',
      blurb: 'Grab a flare or race blind. A shortcut hides under the left aurora.',
      theme: 'aurora',
      palette: PALETTES.aurora,
    },
    random,
  );
  b.length = 600;
  b.baseWidth = 14.5;
  b.slope = 0.11;
  b.parTime = 31.5;
  b.crystalStar = 27;
  b.curve(0.04, 0.26, -1.05);
  b.curve(0.26, 0.5, 1.3);
  b.curve(0.5, 0.74, -1.15);
  b.curve(0.74, 0.96, 0.7);
  b.ramp(0.2, 1.5);
  b.ramp(0.56);
  b.turbo(0.12);
  b.turbo(0.38);
  b.turbo(0.64);
  b.turbo(0.86);
  b.crystalLane(0.06, 0.14, 0, 6);
  b.crystalLane(0.22, 0.32, -3.0, 6);
  b.crystalLane(0.4, 0.5, 3.2, 7);
  b.crystalLane(0.58, 0.68, 0, 6);
  b.crystalLane(0.8, 0.92, -2.2, 7);
  b.power('flare', 0.16, 3.6);
  b.power('rocket', 0.34, 0);
  b.power('magnet', 0.52, -4);
  b.power('ghost', 0.74, 4);
  b.shortcut(0.47, -4.2, 0.032);
  b.hazard('snowman', 0.18, 5);
  b.hazard('crate', 0.36, -2);
  b.hazard('cart', 0.6, 0);
  b.hazard('snowman', 0.78, -5);
  b.decorateAurora();
  b.rivals([rival.ruby(1.041, 2.8), rival.pico(1.002, -3.0), rival.amber(0.983, 0.6), rival.frost(0.963, -1.0)]);
  return b.build();
}

function midnightRibbon(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'midnightRibbon',
      name: 'Midnight Ribbon',
      subtitle: 'Night chase',
      blurb: 'A thin glowing ribbon and an avalanche of powder at your back.',
      theme: 'aurora',
      palette: PALETTES.aurora,
    },
    random,
  );
  b.length = 610;
  b.baseWidth = 12.8;
  b.slope = 0.12;
  b.parTime = 31.5;
  b.crystalStar = 26;
  b.curve(0.0, 0.2, 0.95);
  b.curve(0.2, 0.42, -1.4);
  b.curve(0.42, 0.66, 1.2);
  b.curve(0.66, 0.9, -0.85);
  b.width(0.32, 10.2, 0.1);
  b.width(0.7, 9.8, 0.1);
  b.ramp(0.18);
  b.ramp(0.5, -1.2);
  b.ramp(0.78);
  b.turbo(0.1);
  b.turbo(0.36);
  b.turbo(0.62);
  b.turbo(0.84);
  b.crystalLane(0.06, 0.14, 1.6, 6);
  b.crystalLane(0.22, 0.32, -2.4, 7);
  b.crystalLane(0.4, 0.5, 2.6, 7);
  b.crystalLane(0.58, 0.68, 0, 6);
  b.crystalLane(0.8, 0.9, -1.8, 7);
  b.power('flare', 0.14, -3.2);
  b.power('ghost', 0.3, 0);
  b.power('rocket', 0.56, 3);
  b.power('banana', 0.8, 0);
  b.avalanche(0.48, 0.92, 1.14);
  b.hazard('crate', 0.24, 1.4);
  b.hazard('snowman', 0.44, -4);
  b.hazard('crate', 0.66, 3);
  b.hazard('snowman', 0.84, 0);
  b.decorateAurora();
  b.rivals([rival.pico(1.024, -2.6), rival.ruby(0.995, 2.8), rival.violet(0.955, 0.4), rival.frost(0.975, -0.8)]);
  return b.build();
}

function driftwoodDocks(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'driftwoodDocks',
      name: 'Driftwood Docks',
      subtitle: 'Narrow planks + cut',
      blurb: 'Skip the long pier through the hanging gate if you dare the edge.',
      theme: 'harbor',
      palette: PALETTES.harbor,
    },
    random,
  );
  b.length = 550;
  b.baseWidth = 11.0;
  b.slope = 0.095;
  b.parTime = 29.5;
  b.crystalStar = 22;
  b.curve(0.05, 0.26, 0.7);
  b.curve(0.26, 0.5, -1.05);
  b.curve(0.5, 0.74, 0.9);
  b.curve(0.74, 0.94, -0.55);
  b.width(0.22, 7.6, 0.12);
  b.width(0.48, 7.0, 0.12);
  b.width(0.76, 7.8, 0.1);
  b.ramp(0.3);
  b.ramp(0.64);
  b.turbo(0.18);
  b.turbo(0.46);
  b.turbo(0.8);
  b.crystalLane(0.08, 0.16, 0, 5);
  b.crystalLane(0.24, 0.34, 1.6, 6);
  b.crystalLane(0.44, 0.54, -1.4, 6);
  b.crystalLane(0.66, 0.8, 0, 7);
  b.power('ghost', 0.2, 2.0);
  b.power('magnet', 0.4, -2.0);
  b.power('banana', 0.58, 0);
  b.power('rocket', 0.76, 1.4);
  b.shortcut(0.39, 3.4, 0.026);
  b.hazard('crate', 0.16, 1);
  b.hazard('cart', 0.36, 0);
  b.hazard('bridge', 0.56, 0, 1.3);
  b.hazard('crate', 0.72, -1.6);
  for (const p of strideThrough(0.12, 0.9, 0.07)) {
    b.hazard('water', p, -8.8, 4.2);
    b.hazard('water', fadd(p, 0.02), 8.8, 4.2);
  }
  b.decorateHarbor();
  b.rivals([rival.navy(1.01, -2.0), rival.pico(0.99, 2.2), rival.violet(0.93, 0.3)]);
  return b.build();
}

function tideGate(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'tideGate',
      name: 'Tide Gate',
      subtitle: 'Moving bridges',
      blurb: 'The harbor gates swing. Time the moving bridges or kiss the drink.',
      theme: 'harbor',
      palette: PALETTES.harbor,
    },
    random,
  );
  b.length = 560;
  b.baseWidth = 10.6;
  b.slope = 0.1;
  b.parTime = 31;
  b.crystalStar = 24;
  b.curve(0.04, 0.28, 0.8);
  b.curve(0.28, 0.54, -1.1);
  b.curve(0.54, 0.8, 0.95);
  b.curve(0.8, 0.96, -0.5);
  b.width(0.2, 7.4, 0.1);
  b.width(0.5, 6.8, 0.12);
  b.width(0.78, 7.6, 0.1);
  b.ramp(0.26);
  b.ramp(0.6);
  b.turbo(0.14);
  b.turbo(0.42);
  b.turbo(0.74);
  b.crystalLane(0.06, 0.14, 0, 5);
  b.crystalLane(0.22, 0.32, 1.4, 6);
  b.crystalLane(0.4, 0.5, -1.2, 6);
  b.crystalLane(0.62, 0.74, 0.8, 6);
  b.crystalLane(0.82, 0.9, 0, 5);
  b.power('ghost', 0.18, 1.8);
  b.power('magnet', 0.36, -1.8);
  b.power('rocket', 0.58, 0);
  b.power('banana', 0.8, 1.2);
  b.hazard('movingBridge', 0.24, 0, 1.5);
  b.hazard('movingBridge', 0.48, 0, 1.5);
  b.hazard('movingBridge', 0.72, 0, 1.5);
  b.hazard('crate', 0.34, 1.2);
  b.hazard('cart', 0.64, -0.6);
  for (const p of strideThrough(0.1, 0.92, 0.06)) {
    b.hazard('water', p, -8.4, 4.0);
    b.hazard('water', fadd(p, 0.02), 8.4, 4.0);
  }
  b.decorateHarbor();
  b.rivals([rival.navy(1.071, -1.8), rival.pico(1.05, 2.0), rival.coral(1.02, 0.2), rival.violet(0.99, 1.0)]);
  return b.build();
}

function glacierDrop(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'glacierDrop',
      name: 'Glacier Drop',
      subtitle: 'Big air + cut',
      blurb: 'A hanging glacier with a high-line shortcut over the crevasse.',
      theme: 'summit',
      palette: PALETTES.summit,
    },
    random,
  );
  b.length = 660;
  b.baseWidth = 17.0;
  b.slope = 0.17;
  b.parTime = 31.5;
  b.crystalStar = 26;
  b.curve(0.04, 0.22, 0.55);
  b.curve(0.22, 0.44, -0.85);
  b.curve(0.44, 0.66, 1.0);
  b.curve(0.66, 0.9, -0.6);
  b.elevation(0.2, 4.2, 0.07);
  b.elevation(0.48, 6.4, 0.09);
  b.elevation(0.74, 5.0, 0.08);
  b.ramp(0.18);
  b.ramp(0.46);
  b.ramp(0.72);
  b.turbo(0.1);
  b.turbo(0.32);
  b.turbo(0.56);
  b.turbo(0.84);
  b.crystalLane(0.06, 0.14, 0, 6);
  b.crystalLane(0.24, 0.34, 4.2, 7);
  b.crystalLane(0.42, 0.52, -3.8, 8);
  b.crystalLane(0.6, 0.7, 2.0, 7);
  b.crystalLane(0.8, 0.92, 0, 8);
  b.power('rocket', 0.16, 0);
  b.power('magnet', 0.38, -5);
  b.power('ghost', 0.58, 5);
  b.power('banana', 0.78, 0);
  b.shortcut(0.5, 5.4, 0.034);
  b.hazard('wind', 0.28, 0, 8);
  b.hazard('wind', 0.62, 0, 8);
  b.hazard('snowman', 0.14, -6);
  b.hazard('crate', 0.36, 3);
  b.hazard('snowman', 0.68, 6);
  b.decorateSummit();
  b.rivals([rival.pico(1.074, -3.8), rival.ruby(1.064, 4.0), rival.amber(1.034, 0.4), rival.navy(0.994, -1.4)]);
  return b.build();
}

function icefallRun(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'icefallRun',
      name: 'Icefall Run',
      subtitle: 'Steep + white wall',
      blurb: 'The icefall calves. Five rivals and an avalanche share the face.',
      theme: 'summit',
      palette: PALETTES.summit,
    },
    random,
  );
  b.length = 680;
  b.baseWidth = 16.0;
  b.slope = 0.18;
  b.parTime = 31;
  b.crystalStar = 26;
  b.curve(0.02, 0.2, 0.4);
  b.curve(0.2, 0.4, -0.8);
  b.curve(0.4, 0.62, 1.05);
  b.curve(0.62, 0.82, -0.9);
  b.curve(0.82, 0.98, 0.45);
  b.elevation(0.24, 5.0, 0.07);
  b.elevation(0.52, 7.2, 0.1);
  b.elevation(0.76, 4.6, 0.07);
  b.ramp(0.22);
  b.ramp(0.5);
  b.ramp(0.74);
  b.turbo(0.1);
  b.turbo(0.34);
  b.turbo(0.58);
  b.turbo(0.82);
  b.crystalLane(0.06, 0.14, 0, 6);
  b.crystalLane(0.22, 0.32, 3.8, 7);
  b.crystalLane(0.4, 0.5, -3.4, 8);
  b.crystalLane(0.58, 0.68, 2.2, 7);
  b.crystalLane(0.8, 0.92, 0, 8);
  b.power('rocket', 0.16, 0);
  b.power('ghost', 0.36, 4.5);
  b.power('magnet', 0.54, -4.5);
  b.power('banana', 0.7, 0);
  b.power('rocket', 0.88, 2);
  b.avalanche(0.46, 0.94, 1.18);
  b.hazard('wind', 0.3, 0, 8);
  b.hazard('wind', 0.64, 0, 8);
  b.hazard('snowman', 0.18, 6);
  b.hazard('crate', 0.42, -3);
  b.decorateSummit();
  b.rivals([
    rival.pico(1.151, -4.0),
    rival.ruby(1.131, 4.2),
    rival.amber(1.101, 0.2),
    rival.navy(1.061, -1.6),
    rival.frost(1.111, 1.4),
  ]);
  return b.build();
}

function pineWhisper(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'pineWhisper',
      name: 'Pine Whisper',
      subtitle: 'Soft forest carve',
      blurb: 'A quiet pine corridor. Wide enough to breathe, tight enough to learn the woods.',
      theme: 'forest',
      palette: PALETTES.forest,
    },
    random,
  );
  b.length = 570;
  b.baseWidth = 15.0;
  b.slope = 0.11;
  b.parTime = 29;
  b.crystalStar = 29;
  b.curve(0.04, 0.24, 0.75);
  b.curve(0.24, 0.48, -1.0);
  b.curve(0.48, 0.72, 0.9);
  b.curve(0.72, 0.94, -0.6);
  b.ramp(0.22);
  b.ramp(0.54, 1.6);
  b.turbo(0.14);
  b.turbo(0.4);
  b.turbo(0.76);
  b.crystalLane(0.08, 0.16, 0, 6);
  b.crystalLane(0.24, 0.34, 3.0, 7);
  b.crystalLane(0.42, 0.52, -2.8, 7);
  b.crystalLane(0.6, 0.7, 1.4, 6);
  b.crystalLane(0.8, 0.9, 0, 7);
  b.power('magnet', 0.2, 4);
  b.power('ghost', 0.46, -4);
  b.power('banana', 0.64, 0);
  b.power('rocket', 0.84, 2);
  b.hazard('snowman', 0.18, -5);
  b.hazard('crate', 0.36, 2);
  b.hazard('snowman', 0.58, 5);
  b.hazard('crate', 0.78, -2);
  b.decorateForest();
  b.rivals([rival.mint(1.087, -3.0), rival.pico(1.057, 3.2), rival.violet(1.007, 0.4)]);
  return b.build();
}

function timberSwitchback(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'timberSwitchback',
      name: 'Timber Switchback',
      subtitle: 'Hairpins + gate',
      blurb: 'Stacked hairpins through old timber. Cut the last switch if you clip the gate.',
      theme: 'forest',
      palette: PALETTES.forest,
    },
    random,
  );
  b.length = 600;
  b.baseWidth = 13.0;
  b.slope = 0.125;
  b.parTime = 30.5;
  b.crystalStar = 27;
  b.curve(0.0, 0.16, 1.35);
  b.curve(0.16, 0.34, -1.55);
  b.curve(0.34, 0.52, 1.4);
  b.curve(0.52, 0.7, -1.45);
  b.curve(0.7, 0.88, 1.1);
  b.width(0.24, 10.4, 0.08);
  b.width(0.56, 9.8, 0.08);
  b.ramp(0.28);
  b.ramp(0.66);
  b.turbo(0.12);
  b.turbo(0.38);
  b.turbo(0.62);
  b.turbo(0.84);
  b.crystalLane(0.06, 0.14, 2.0, 6);
  b.crystalLane(0.2, 0.3, -2.4, 7);
  b.crystalLane(0.38, 0.48, 2.2, 7);
  b.crystalLane(0.56, 0.66, -1.8, 6);
  b.crystalLane(0.78, 0.9, 0, 8);
  b.power('ghost', 0.18, 0);
  b.power('magnet', 0.42, 3.4);
  b.power('rocket', 0.6, -3.2);
  b.power('banana', 0.82, 0);
  b.shortcut(0.71, -3.8, 0.03);
  b.hazard('crate', 0.16, 1.2);
  b.hazard('snowman', 0.32, -4);
  b.hazard('crate', 0.5, 3);
  b.hazard('snowman', 0.74, 4);
  b.decorateForest();
  b.rivals([rival.mint(1.104, -2.6), rival.pico(1.083, 2.8), rival.ruby(1.033, 0.2), rival.navy(1.012, -0.8)]);
  return b.build();
}

function owlHollow(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'owlHollow',
      name: 'Owl Hollow',
      subtitle: 'Dark timber chase',
      blurb: 'Night forest. Flares help. The hollow coughs an avalanche of snow.',
      theme: 'forest',
      palette: PALETTES.forestNight,
    },
    random,
  );
  b.length = 620;
  b.baseWidth = 12.4;
  b.slope = 0.13;
  b.parTime = 30.5;
  b.crystalStar = 28;
  b.curve(0.04, 0.26, 1.1);
  b.curve(0.26, 0.5, -1.25);
  b.curve(0.5, 0.74, 1.15);
  b.curve(0.74, 0.96, -0.8);
  b.width(0.4, 10.0, 0.1);
  b.ramp(0.2);
  b.ramp(0.48);
  b.ramp(0.76);
  b.turbo(0.12);
  b.turbo(0.36);
  b.turbo(0.6);
  b.turbo(0.84);
  b.crystalLane(0.06, 0.14, 0, 6);
  b.crystalLane(0.22, 0.32, 2.6, 7);
  b.crystalLane(0.4, 0.5, -2.4, 7);
  b.crystalLane(0.58, 0.68, 1.6, 6);
  b.crystalLane(0.8, 0.92, 0, 8);
  b.power('flare', 0.16, 3.2);
  b.power('ghost', 0.34, 0);
  b.power('rocket', 0.56, -3);
  b.power('magnet', 0.78, 3);
  b.avalanche(0.54, 0.92, 1.16);
  b.hazard('snowman', 0.18, -5);
  b.hazard('crate', 0.38, 2);
  b.hazard('snowman', 0.64, 5);
  b.hazard('crate', 0.82, -2);
  b.decorateForest();
  b.rivals([rival.mint(1.095, -2.8), rival.pico(1.065, 3.0), rival.frost(1.034, 0.2), rival.violet(0.996, -1.0)]);
  return b.build();
}

function canyonGlow(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'canyonGlow',
      name: 'Canyon Glow',
      subtitle: 'Crystal walls',
      blurb: 'A glowing slot canyon. Spires force you to pick a wall.',
      theme: 'canyon',
      palette: PALETTES.canyon,
    },
    random,
  );
  b.length = 600;
  b.baseWidth = 12.6;
  b.slope = 0.13;
  b.parTime = 31;
  b.crystalStar = 30;
  b.curve(0.0, 0.22, 0.7);
  b.curve(0.22, 0.46, -1.2);
  b.curve(0.46, 0.7, 1.1);
  b.curve(0.7, 0.94, -0.75);
  b.width(0.3, 10.0, 0.1);
  b.width(0.64, 9.6, 0.1);
  b.ramp(0.24);
  b.ramp(0.58);
  b.turbo(0.12);
  b.turbo(0.4);
  b.turbo(0.72);
  b.crystalLane(0.06, 0.16, 2.2, 7);
  b.crystalLane(0.22, 0.32, -2.4, 7);
  b.crystalLane(0.4, 0.5, 0, 8);
  b.crystalLane(0.58, 0.68, 2.8, 7);
  b.crystalLane(0.8, 0.9, -2.0, 7);
  b.power('magnet', 0.18, 0);
  b.power('ghost', 0.44, -3);
  b.power('rocket', 0.66, 3);
  b.power('flare', 0.84, 0);
  for (const p of strideThrough(0.14, 0.86, 0.09)) {
    b.hazard('crystalSpire', p, fint(fmul(p, 20)) % 2 === 0 ? -2.8 : 2.8, 0.95);
  }
  b.decorateCanyon();
  b.rivals([rival.frost(1.104, 2.4), rival.pico(1.085, -2.6), rival.ruby(1.045, 0.4), rival.mint(1.024, -0.8)]);
  return b.build();
}

function prismCut(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'prismCut',
      name: 'Prism Cut',
      subtitle: 'Razor lane + gate',
      blurb: 'The canyon pinches to a prism. The right wall hides a skip.',
      theme: 'canyon',
      palette: PALETTES.canyon,
    },
    random,
  );
  b.length = 610;
  b.baseWidth = 11.0;
  b.slope = 0.14;
  b.parTime = 30.5;
  b.crystalStar = 25;
  b.curve(0.0, 0.18, 1.05);
  b.curve(0.18, 0.4, -1.35);
  b.curve(0.4, 0.64, 1.25);
  b.curve(0.64, 0.9, -0.95);
  b.width(0.26, 8.6, 0.1);
  b.width(0.54, 8.2, 0.1);
  b.width(0.78, 9.0, 0.08);
  b.ramp(0.22);
  b.ramp(0.52, -1);
  b.ramp(0.8);
  b.turbo(0.1);
  b.turbo(0.36);
  b.turbo(0.62);
  b.turbo(0.86);
  b.crystalLane(0.06, 0.14, 1.6, 6);
  b.crystalLane(0.2, 0.3, -2.0, 7);
  b.crystalLane(0.38, 0.48, 2.2, 7);
  b.crystalLane(0.56, 0.66, 0, 7);
  b.crystalLane(0.78, 0.9, -1.6, 8);
  b.power('ghost', 0.16, 0);
  b.power('magnet', 0.4, 2.6);
  b.power('rocket', 0.58, -2.6);
  b.power('banana', 0.82, 0);
  b.shortcut(0.45, 3.6, 0.033);
  for (const p of strideThrough(0.12, 0.88, 0.08)) {
    b.hazard('crystalSpire', p, fmul(fsin(fmul(p, 26)), 2.4), 0.85);
  }
  b.decorateCanyon();
  b.rivals([rival.frost(1.094, 2.2), rival.pico(1.063, -2.4), rival.amber(1.023, 0.2), rival.navy(1.003, -0.8)]);
  return b.build();
}

function steamVeil(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'steamVeil',
      name: 'Steam Veil',
      subtitle: 'Geysers & mist',
      blurb: 'Hot springs under snow. Geysers hide the line; an avalanche rides the steam.',
      theme: 'steam',
      palette: PALETTES.steam,
    },
    random,
  );
  b.length = 590;
  b.baseWidth = 13.2;
  b.slope = 0.12;
  b.parTime = 31;
  b.crystalStar = 26;
  b.curve(0.04, 0.26, 0.8);
  b.curve(0.26, 0.5, -1.1);
  b.curve(0.5, 0.74, 1.0);
  b.curve(0.74, 0.94, -0.65);
  b.ramp(0.22);
  b.ramp(0.56);
  b.turbo(0.14);
  b.turbo(0.4);
  b.turbo(0.7);
  b.turbo(0.88);
  b.crystalLane(0.08, 0.16, 0, 6);
  b.crystalLane(0.24, 0.34, 2.8, 7);
  b.crystalLane(0.42, 0.52, -2.6, 7);
  b.crystalLane(0.6, 0.7, 1.6, 6);
  b.crystalLane(0.8, 0.9, 0, 7);
  b.power('ghost', 0.18, 3);
  b.power('magnet', 0.38, -3);
  b.power('rocket', 0.62, 0);
  b.power('flare', 0.8, 2.4);
  b.avalanche(0.56, 0.92, 1.18);
  for (const p of strideThrough(0.14, 0.86, 0.08)) {
    b.hazard('geyser', p, fmul(fsin(fmul(p, 18)), 3.0), 1.15);
  }
  b.hazard('crate', 0.3, 2);
  b.hazard('snowman', 0.68, -4);
  b.decorateSteam();
  b.rivals([rival.coral(1.144, -2.6), rival.pico(1.114, 2.8), rival.ruby(1.094, 0.3), rival.mint(1.064, -1.0)]);
  return b.build();
}

function whiteoutPeak(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'whiteoutPeak',
      name: 'Whiteout Peak',
      subtitle: 'Blizzard + flares',
      blurb: 'You cannot see the mountain. Flares punch holes in the white. Keep moving.',
      theme: 'blizzard',
      palette: PALETTES.blizzard,
    },
    random,
  );
  b.length = 640;
  b.baseWidth = 14.0;
  b.slope = 0.155;
  b.parTime = 30.5;
  b.crystalStar = 30;
  b.curve(0.02, 0.2, 0.6);
  b.curve(0.2, 0.42, -1.0);
  b.curve(0.42, 0.64, 1.15);
  b.curve(0.64, 0.86, -0.85);
  b.elevation(0.28, 4.0, 0.07);
  b.elevation(0.58, 5.6, 0.08);
  b.ramp(0.2);
  b.ramp(0.46);
  b.ramp(0.74);
  b.turbo(0.1);
  b.turbo(0.34);
  b.turbo(0.58);
  b.turbo(0.82);
  b.crystalLane(0.06, 0.14, 0, 6);
  b.crystalLane(0.22, 0.32, 3.4, 7);
  b.crystalLane(0.4, 0.5, -3.2, 8);
  b.crystalLane(0.6, 0.7, 1.8, 7);
  b.crystalLane(0.8, 0.9, 0, 8);
  b.power('flare', 0.12, -3.6);
  b.power('flare', 0.36, 3.6);
  b.power('rocket', 0.52, 0);
  b.power('ghost', 0.7, -4);
  b.power('magnet', 0.86, 3);
  b.avalanche(0.5, 0.94, 1.2);
  b.hazard('wind', 0.26, 0, 9);
  b.hazard('wind', 0.54, 0, 9);
  b.hazard('wind', 0.78, 0, 9);
  b.hazard('snowman', 0.18, 5);
  b.hazard('crate', 0.44, -2);
  b.decorateBlizzard();
  b.rivals([
    rival.frost(1.118, -3.4),
    rival.pico(1.089, 3.6),
    rival.ruby(1.049, 0.4),
    rival.amber(1.029, -1.2),
    rival.navy(1.01, 1.6),
  ]);
  return b.build();
}

function neonSlalom(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'neonSlalom',
      name: 'Neon Slalom',
      subtitle: 'Resort gates + cut',
      blurb: 'A night ski resort painted in cyan and magenta. Slalom the arches; clip the VIP gate.',
      theme: 'neon',
      palette: PALETTES.neon,
    },
    random,
  );
  b.length = 600;
  b.baseWidth = 13.6;
  b.slope = 0.135;
  b.parTime = 30;
  b.crystalStar = 27;
  b.curve(0.0, 0.18, 1.1);
  b.curve(0.18, 0.38, -1.3);
  b.curve(0.38, 0.58, 1.2);
  b.curve(0.58, 0.78, -1.15);
  b.curve(0.78, 0.96, 0.7);
  b.width(0.28, 10.6, 0.08);
  b.width(0.62, 10.2, 0.08);
  b.ramp(0.2);
  b.ramp(0.5, 1.4);
  b.ramp(0.78);
  b.turbo(0.1);
  b.turbo(0.34);
  b.turbo(0.58);
  b.turbo(0.84);
  b.crystalLane(0.06, 0.14, 2.0, 6);
  b.crystalLane(0.2, 0.3, -2.4, 7);
  b.crystalLane(0.38, 0.48, 2.2, 7);
  b.crystalLane(0.56, 0.66, -1.8, 7);
  b.crystalLane(0.78, 0.9, 0, 8);
  b.power('rocket', 0.16, 0);
  b.power('flare', 0.32, 3.4);
  b.power('ghost', 0.54, -3.4);
  b.power('magnet', 0.74, 0);
  b.power('banana', 0.88, 2);
  b.shortcut(0.43, 4.0, 0.031);
  for (const p of strideThrough(0.12, 0.88, 0.08)) {
    b.hazard('neonArch', p, 0, 0);
  }
  b.hazard('crate', 0.26, 1.6);
  b.hazard('cart', 0.6, 0);
  b.decorateNeon();
  b.rivals([rival.coral(1.129, -2.8), rival.pico(1.109, 3.0), rival.ruby(1.07, 0.2), rival.amber(1.039, -1.2)]);
  return b.build();
}

function carnivalParade(random: () => number): LevelDefinition {
  const b = new LevelBuilder(
    {
      id: 'carnivalParade',
      name: 'Carnival Parade',
      subtitle: 'Festive finale',
      blurb: 'Floats, lights, and a late avalanche of confetti-snow. The pack is hungry.',
      theme: 'carnival',
      palette: PALETTES.carnival,
    },
    random,
  );
  b.length = 630;
  b.baseWidth = 14.8;
  b.slope = 0.14;
  b.parTime = 30;
  b.crystalStar = 32;
  b.curve(0.02, 0.2, 0.85);
  b.curve(0.2, 0.4, -1.15);
  b.curve(0.4, 0.62, 1.2);
  b.curve(0.62, 0.82, -1.0);
  b.curve(0.82, 0.98, 0.55);
  b.ramp(0.18);
  b.ramp(0.44, -1.4);
  b.ramp(0.7);
  b.turbo(0.1);
  b.turbo(0.32);
  b.turbo(0.54);
  b.turbo(0.76);
  b.turbo(0.9);
  b.crystalLane(0.06, 0.14, 0, 7);
  b.crystalLane(0.2, 0.3, 3.2, 7);
  b.crystalLane(0.38, 0.48, -3.0, 8);
  b.crystalLane(0.56, 0.66, 2.0, 7);
  b.crystalLane(0.78, 0.9, 0, 8);
  b.power('rocket', 0.14, 0);
  b.power('magnet', 0.3, 4);
  b.power('ghost', 0.48, -4);
  b.power('flare', 0.64, 0);
  b.power('banana', 0.82, 3);
  b.avalanche(0.58, 0.95, 1.22);
  b.shortcut(0.36, -4.6, 0.028);
  for (const p of strideThrough(0.12, 0.86, 0.1)) {
    b.hazard('carnivalFloat', p, fint(fmul(p, 16)) % 2 === 0 ? -5.2 : 5.2, 1.3);
  }
  b.hazard('npc', 0.22, 0.8, 0.8);
  b.hazard('npc', 0.5, -1.0, 0.8);
  b.hazard('cart', 0.68, 0);
  b.decorateCarnival();
  b.rivals([
    rival.coral(1.167, -3.2),
    rival.pico(1.126, 3.4),
    rival.ruby(1.106, 0.2),
    rival.amber(1.086, -1.4),
    rival.frost(1.116, 1.6),
  ]);
  return b.build();
}

// MARK: - Catalog

const COURSES: Record<LevelID, (random: () => number) => LevelDefinition> = {
  villageDash,
  marketMayhem,
  alleySprint,
  iceCaveSpiral,
  crystalGrotto,
  frozenHollow,
  auroraNight,
  polarVeil,
  midnightRibbon,
  harborFreeze,
  driftwoodDocks,
  tideGate,
  summitRush,
  glacierDrop,
  icefallRun,
  pineWhisper,
  timberSwitchback,
  owlHollow,
  canyonGlow,
  prismCut,
  steamVeil,
  whiteoutPeak,
  neonSlalom,
  carnivalParade,
};

/**
 * Builds a course. Scenery randomness is seeded from the course, so the same course always looks
 * the same; pass `random` to override it (the Swift comparison test passes `() => 0`).
 */
export function buildLevel(id: LevelID, random?: () => number): LevelDefinition {
  return COURSES[id](random ?? seededRandom(0x5eed + levelOrder(id) * 7919));
}

const cache = new Map<LevelID, LevelDefinition>();

/**
 * A course definition, built once and shared. Treat it as read-only: the engine copies what it
 * changes (live entities), and the renderer only reads it.
 */
export function level(id: LevelID): LevelDefinition {
  let def = cache.get(id);
  if (!def) {
    def = buildLevel(id);
    cache.set(id, def);
  }
  return def;
}

export const allLevels = (): LevelDefinition[] => LEVEL_IDS.map(level);
