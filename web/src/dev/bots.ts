/**
 * Scripted players, ported from the Swift harness (`tools/headless/Sources/Bots.swift`). A bot
 * plans its lane with a small dynamic program over (metres ahead) x (lateral position): crystals,
 * power-ups and pads pay out, hazards cost, and the inside of a bend pays a little for the time it
 * saves. Skill levels differ in look-ahead, reaction time, aiming noise, clearance and turbo use.
 *
 * Used by the tests, the balance sweep (`npm run sweep`) and the in-app autopilot
 * (`?autopilot=good`), which the end-to-end tests use to play real races.
 */
import { level as courseLevel } from '../core/levelCatalog';
import { DEFAULT_SETTINGS, type GameSettings, type LevelID, type RaceResult } from '../core/models';
import { GameEngine, SILENT_FX, type EngineFx } from '../engine/gameEngine';
import { CollisionClass, type Racer } from '../engine/racer';
import type { TrackPath } from '../engine/trackPath';

const MASK = (1n << 64n) - 1n;

/** Swift's `SplitMix64`, with `Float.random(in: 0..<1, using:)` on top. */
export class SplitMix64 {
  private state: bigint;

  constructor(seed: number | bigint) {
    this.state = BigInt.asUintN(64, BigInt(seed));
  }

  next(): bigint {
    this.state = (this.state + 0x9e3779b97f4a7c15n) & MASK;
    let z = this.state;
    z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & MASK;
    z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & MASK;
    return z ^ (z >> 31n);
  }

  /** A float in 0..<1 built exactly as Swift's `Float.random(in: 0..<1, using:)` builds it. */
  nextUnit(): number {
    const low24 = Number(this.next() & 0xffffffn);
    return low24 * 2 ** -24;
  }
}

function gauss(rng: SplitMix64): number {
  const u1 = Math.max(rng.nextUnit(), 1e-6);
  const u2 = rng.nextUnit();
  return Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
}

/** Swift's `rounded()`: halves go away from zero. */
const roundHalfAway = (x: number): number => {
  const r = Math.sign(x) * Math.round(Math.abs(x));
  return r === 0 ? 0 : r; // no negative zero
};

export interface BotProfile {
  name: string;
  steers: boolean;
  /** Seconds between decisions. */
  reaction: number;
  /** Metres of hazard look-ahead. */
  lookahead: number;
  /** Extra clearance around hazards. */
  margin: number;
  crystalGreed: number;
  padGreed: number;
  /** Metres of aiming noise per decision. */
  noise: number;
  /** Chance of holding boost during a burst while the meter has charge. */
  boostUse: number;
  /** How much the bot values hugging the inside of a bend. */
  lineGreed: number;
}

export const BOTS: Record<'idle' | 'novice' | 'casual' | 'good' | 'expert', BotProfile> = {
  idle: {
    name: 'idle',
    steers: false,
    reaction: 1,
    lookahead: 0,
    margin: 0,
    crystalGreed: 0,
    padGreed: 0,
    noise: 0,
    boostUse: 1,
    lineGreed: 0,
  },
  novice: {
    name: 'novice',
    steers: true,
    reaction: 0.5,
    lookahead: 18,
    margin: 0,
    crystalGreed: 0.3,
    padGreed: 0.3,
    noise: 0.9,
    boostUse: 0.35,
    lineGreed: 0,
  },
  casual: {
    name: 'casual',
    steers: true,
    reaction: 0.3,
    lookahead: 26,
    margin: 0.2,
    crystalGreed: 0.6,
    padGreed: 0.6,
    noise: 0.45,
    boostUse: 0.6,
    lineGreed: 0.3,
  },
  good: {
    name: 'good',
    steers: true,
    reaction: 0.18,
    lookahead: 34,
    margin: 0.35,
    crystalGreed: 1,
    padGreed: 1,
    noise: 0.2,
    boostUse: 0.85,
    lineGreed: 0.7,
  },
  expert: {
    name: 'expert',
    steers: true,
    reaction: 0.08,
    lookahead: 44,
    margin: 0.4,
    crystalGreed: 1.5,
    padGreed: 1.5,
    noise: 0.08,
    boostUse: 1,
    lineGreed: 1,
  },
};

export const BOT_ORDER = ['idle', 'novice', 'casual', 'good', 'expert'] as const;
export type BotName = (typeof BOT_ORDER)[number];
export const isBotName = (v: unknown): v is BotName =>
  typeof v === 'string' && (BOT_ORDER as readonly string[]).includes(v);

const BIN_W = 0.5;
const LAT_CAP = 6.5;
const KP = 0.7;
const KD = 0.06;

export class Bot {
  private readonly rng: SplitMix64;
  private target = 0;
  private clock = 0;
  private nextDecision = 0;
  private boostOn = false;
  private nextBoostToggle = 0;

  constructor(
    readonly profile: BotProfile,
    seed: number | bigint,
  ) {
    this.rng = new SplitMix64(seed);
  }

  update(engine: GameEngine, dt: number): void {
    const me = engine.playerRacer;
    const path = engine.path;
    if (engine.phase !== 'racing' || !me || !path) {
      engine.steerInput = 0;
      return;
    }
    const p = this.profile;
    // The Swift bot keeps its clock in 32-bit floats; its 0.7 s boost toggle is exactly 42 frames
    // at 60 fps, so the rounding decides which frame it lands on. Round the same way.
    this.clock = Math.fround(this.clock + dt);
    if (p.steers) {
      if (this.clock >= this.nextDecision) {
        this.nextDecision = Math.fround(this.clock + p.reaction);
        this.target = this.decide(engine, me, path);
      }
      const e = this.target - me.lateral;
      engine.steerInput = Math.max(-1, Math.min(1, KP * e - KD * me.lateralVel));
    } else {
      engine.steerInput = 0;
    }
    // Boost in bursts.
    if (this.clock >= this.nextBoostToggle) {
      this.nextBoostToggle = Math.fround(this.clock + 0.7);
      this.boostOn = me.turbo > 0.03 && this.rng.nextUnit() < p.boostUse;
    }
    engine.boostHeld = this.boostOn && me.turbo > 0.02;
    // Drop the peel when someone is right behind.
    if (me.bananaArmed) {
      for (const r of engine.racers) {
        if (r.isPlayer) continue;
        const d = (me.progress - r.progress) * path.length;
        if (d > 2 && d < 30 && Math.abs(r.lateral - me.lateral) < 3.5) engine.dropBananaRequested = true;
      }
    }
  }

  /**
   * Lane planner: a grid of (metres ahead) x (lateral bin). Each step the sled can shift a
   * limited number of bins; the best path's first steps give the steering target.
   */
  private decide(engine: GameEngine, me: Racer, path: TrackPath): number {
    const p = this.profile;
    const len = path.length;
    const sp = Math.max(me.speed, 10);
    const half = path.width(me.progress) * 0.5 - 0.9;
    const stepLen = 3.0;
    const steps = Math.max(2, Math.trunc(p.lookahead / stepLen));
    const nBins = roundHalfAway((2 * half) / BIN_W) + 1;
    const lat = (j: number): number => -half + j * BIN_W;
    const maxShift = Math.max(1, Math.floor((LAT_CAP * (stepLen / sp)) / BIN_W));
    const stepIndex = (ds: number): number => roundHalfAway(ds / stepLen);

    // reward[k][j]: what the cell at step k (1...steps), bin j is worth.
    const reward = Array.from({ length: steps + 1 }, () => new Float64Array(nBins));
    for (const e of engine.entities) {
      if (e.collected || e.destroyed) continue;
      const d = e.definition;
      const ds = (d.progress - me.progress) * len;
      if (ds < -3 || ds > p.lookahead + 8) continue;
      if ((CollisionClass.solidHazards.has(d.kind) || d.kind === 'water') && d.radius > 0) {
        const clear = d.radius + 0.7 + p.margin;
        const k0 = stepIndex(ds - (d.radius + 0.7));
        const k1 = stepIndex(ds + (d.radius + 0.7));
        if (k1 < 1 || k0 > steps) continue;
        for (let k = Math.max(1, k0); k <= Math.min(steps, Math.max(k0, k1)); k += 1) {
          for (let j = 0; j < nBins; j += 1) if (Math.abs(lat(j) - e.liveLateral) < clear) reward[k][j] -= 40;
        }
      } else if (CollisionClass.pickups.has(d.kind)) {
        const w = d.kind === 'crystal' ? 1 : 3;
        const k = stepIndex(ds);
        if (k < 1 || k > steps) continue;
        for (let j = 0; j < nBins; j += 1)
          if (Math.abs(lat(j) - e.liveLateral) < 1.3) reward[k][j] += p.crystalGreed * w;
      } else if (d.kind === 'turboPad' || d.kind === 'ramp') {
        const w = d.kind === 'turboPad' ? 3 : 1.5;
        const k = stepIndex(ds);
        if (k < 1 || k > steps) continue;
        for (let j = 0; j < nBins; j += 1) {
          if (Math.abs(lat(j) - e.liveLateral) < d.radius + 0.3) reward[k][j] += p.padGreed * w;
        }
      }
    }
    // Racing line: cells on the inside of a bend save time; crystal-equivalents are ~0.09 s each.
    if (p.lineGreed > 0) {
      for (let k = 1; k <= steps; k += 1) {
        const kappa = path.curvature(me.progress + (k * stepLen) / len);
        for (let j = 0; j < nBins; j += 1) reward[k][j] += (p.lineGreed * (-kappa * lat(j)) * (stepLen / sp)) / 0.09;
      }
    }
    // Backward dynamic programme.
    const value = Array.from({ length: steps + 2 }, () => new Float64Array(nBins));
    for (let k = steps; k >= 1; k -= 1) {
      for (let j = 0; j < nBins; j += 1) {
        let best = -Number.MAX_VALUE;
        for (let dj = -maxShift; dj <= maxShift; dj += 1) {
          const nj = j + dj;
          if (nj < 0 || nj >= nBins) continue;
          const v = reward[k][nj] + value[k + 1][nj] - 0.04 * Math.abs(dj);
          if (v > best) best = v;
        }
        value[k][j] = best;
      }
    }
    // Choose the first move from the current bin.
    const j0 = Math.max(0, Math.min(nBins - 1, roundHalfAway((me.lateral + half) / BIN_W)));
    let bestJ = j0;
    let bestV = -Number.MAX_VALUE;
    for (let dj = -maxShift; dj <= maxShift; dj += 1) {
      const nj = j0 + dj;
      if (nj < 0 || nj >= nBins) continue;
      const v = reward[1][nj] + value[2][nj] - 0.04 * Math.abs(dj) - (Math.abs(lat(nj)) > half - 0.4 ? 0.3 : 0);
      if (v > bestV) {
        bestV = v;
        bestJ = nj;
      }
    }
    // Aim a couple of steps out so the sled commits to the line rather than dithering.
    let aim = lat(bestJ);
    if (steps >= 3) {
      let j = bestJ;
      for (let k = 2; k <= Math.min(3, steps); k += 1) {
        let bj = j;
        let bv = -Number.MAX_VALUE;
        for (let dj = -maxShift; dj <= maxShift; dj += 1) {
          const nj = j + dj;
          if (nj < 0 || nj >= nBins) continue;
          const v = reward[k][nj] + value[k + 1][nj] - 0.04 * Math.abs(dj);
          if (v > bv) {
            bv = v;
            bj = nj;
          }
        }
        j = bj;
      }
      aim = lat(j);
    }
    return Math.max(-half, Math.min(half, aim + gauss(this.rng) * p.noise));
  }
}

export interface RunStat {
  place: number;
  fieldSize: number;
  time: number;
  crystals: number;
  crystalTotal: number;
  stars: number;
  crashes: number;
  finished: boolean;
  comboMax: number;
  nearMisses: number;
}

/** Counts the sounds the engine asked for; the crash count is what the harness reports. */
export class CountingFx implements EngineFx {
  counts = new Map<string, number>();
  private note(name: string): void {
    this.counts.set(name, (this.counts.get(name) ?? 0) + 1);
  }
  collect(): void {
    this.note('collect');
  }
  boost(): void {
    this.note('boost');
  }
  crash(): void {
    this.note('crash');
  }
  finish(): void {
    this.note('finish');
  }
  countdown(): void {
    this.note('countdown');
  }
  go(): void {
    this.note('go');
  }
  whoosh(): void {
    this.note('whoosh');
  }
  comboHit(): void {
    this.note('combo');
  }
  power(): void {
    this.note('power');
  }
  tap(): void {
    this.note('tap');
  }
}

/** One race with a bot at 60 fps, as the Swift harness's `runRace`. */
export function runRace(
  id: LevelID,
  profile: BotProfile,
  seed: number | bigint,
  settings: GameSettings = DEFAULT_SETTINGS,
): { stat: RunStat; result: RaceResult | null; engine: GameEngine } {
  const fx = new CountingFx();
  const engine = new GameEngine(fx);
  let result: RaceResult | null = null;
  engine.onFinished = (r) => {
    result = r;
  };
  engine.start(courseLevel(id), { ...settings });
  const bot = new Bot(profile, seed);
  const dt = 1 / 60;
  for (let ticks = 0; result === null && ticks < 60 * 240; ticks += 1) {
    bot.update(engine, dt);
    engine.tick(dt);
  }
  const r = result as RaceResult | null;
  const stat: RunStat = {
    place: r?.place ?? 0,
    fieldSize: r?.fieldSize ?? 0,
    time: r?.time ?? 0,
    crystals: r?.crystals ?? 0,
    crystalTotal: r?.crystalTotal ?? 0,
    stars: r?.stars ?? 0,
    crashes: fx.counts.get('crash') ?? 0,
    finished: r !== null,
    comboMax: r?.comboMax ?? 0,
    nearMisses: r?.nearMisses ?? 0,
  };
  return { stat, result: r, engine };
}

export { SILENT_FX };
