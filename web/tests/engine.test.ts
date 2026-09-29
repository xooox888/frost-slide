/**
 * Engine, progression and save checks, ported from the Swift harness's self-tests
 * (`tools/headless/Sources/SelfTests.swift`). They run the real engine with scripted bots.
 */
import { describe, expect, it } from 'vitest';
import { LevelBuilder, PALETTES, level } from '../src/core/levelCatalog';
import {
  DEFAULT_SETTINGS,
  LEVEL_IDS,
  StarRules,
  decodeRecord,
  decodeSettings,
  resultPoints,
  type GameSettings,
  type LevelDefinition,
  type LevelID,
  type RaceResult,
} from '../src/core/models';
import { GamePersistence } from '../src/core/persistence';
import {
  DAILY_GOALS,
  dailyStreakAfter,
  dateKey,
  decodeGhost,
  goalMet,
  isSledSkin,
  isUsableGhost,
  pickDaily,
  type DailyGoal,
  type GhostTake,
} from '../src/core/progression';
import { BOTS, Bot, SplitMix64, type BotProfile } from '../src/dev/bots';
import { GameEngine } from '../src/engine/gameEngine';
import { TrackPath } from '../src/engine/trackPath';

const DT = 1 / 60;

/** Runs a race with a bot until the result arrives. */
function play(
  def: LevelDefinition,
  {
    profile = BOTS.good,
    seed = 1,
    ghost = null,
    dailyGoal = null,
    settings = DEFAULT_SETTINGS,
    each,
  }: {
    profile?: BotProfile;
    seed?: number;
    ghost?: GhostTake | null;
    dailyGoal?: DailyGoal | null;
    settings?: GameSettings;
    each?: (engine: GameEngine) => void;
  } = {},
): { engine: GameEngine; result: RaceResult | null } {
  const engine = new GameEngine();
  let result: RaceResult | null = null;
  engine.onFinished = (r) => {
    result = r;
  };
  engine.start(def, { ...settings }, ghost, dailyGoal);
  const bot = new Bot(profile, seed);
  for (let ticks = 0; result === null && ticks < 60 * 200; ticks += 1) {
    bot.update(engine, DT);
    engine.tick(DT);
    each?.(engine);
  }
  return { engine, result };
}

function makeResult(overrides: Partial<RaceResult>): RaceResult {
  return {
    level: 'villageDash',
    place: 1,
    fieldSize: 4,
    time: 30,
    crystals: 30,
    crystalTotal: 34,
    stars: 1,
    podium: [],
    comboMax: 0,
    nearMisses: 0,
    unlockedSkin: null,
    daily: false,
    parTime: 40,
    crystalGoal: 28,
    crashes: 0,
    standings: [],
    previousBest: null,
    newBest: false,
    dailyGoal: null,
    dailyMet: false,
    dailyStreak: 0,
    ...overrides,
  };
}

describe('levels: authored ids are stable and unique', () => {
  for (const id of ['villageDash', 'carnivalParade'] as LevelID[]) {
    it(id, () => {
      const a = level(id);
      const all = [...a.entities.map((e) => e.id), ...a.rivals.map((r) => r.id)];
      expect(new Set(all).size).toBe(all.length);
    });
  }
  it('ids never collide across courses', () => {
    const v = new Set(level('villageDash').entities.map((e) => e.id));
    expect(level('carnivalParade').entities.some((e) => v.has(e.id))).toBe(false);
  });
});

describe('track: banking leans into turns, eases in and out', () => {
  for (const id of LEVEL_IDS) {
    it(id, () => {
      const path = TrackPath.build(level(id));
      let worstStep = 0;
      let wrong = 0;
      path.samples.forEach((s, i) => {
        if (i > 0) worstStep = Math.max(worstStep, Math.abs(s.bank - path.samples[i - 1].bank));
        if (Math.abs(s.curvature) > 0.004) {
          const half = s.width * 0.5;
          const leftY = s.position.y - s.binormal.y * half;
          const rightY = s.position.y + s.binormal.y * half;
          const leftTurn = s.curvature > 0;
          const insideY = leftTurn ? leftY : rightY;
          const outsideY = leftTurn ? rightY : leftY;
          if (insideY > outsideY) wrong += 1; // the inside should be lower
        }
      });
      expect(wrong).toBe(0);
      expect(worstStep).toBeLessThan(0.05);
      expect(path.samples.every((s) => Number.isFinite(s.position.x) && Number.isFinite(s.bank))).toBe(true);
    });
  }
});

describe('steering: responsive on snow, slippery on ice', () => {
  it('reaches a brisk lane change on snow', () => {
    const e = new GameEngine();
    e.start({ ...level('villageDash'), rivals: [] }, { ...DEFAULT_SETTINGS });
    while (e.phase !== 'racing') e.tick(DT);
    e.steerInput = 1;
    let peak = 0;
    let t = 0;
    let shift4 = -1;
    const start = e.playerRacer!.lateral;
    while (t < 3) {
      e.tick(DT);
      t += DT;
      peak = Math.max(peak, e.playerRacer!.lateralVel);
      if (shift4 < 0 && e.playerRacer!.lateral - start >= 4) shift4 = t;
    }
    expect(peak).toBeGreaterThan(5.5);
    expect(peak).toBeLessThan(8.5);
    expect(shift4).toBeGreaterThan(0);
    expect(shift4).toBeLessThan(1);
  });

  it('keeps sliding sideways on ice after letting go', () => {
    const course = (ice: boolean): LevelDefinition => {
      const b = new LevelBuilder(
        { id: 'villageDash', name: 'T', subtitle: '', blurb: '', theme: 'village', palette: PALETTES.village },
        () => 0,
      );
      b.length = 400;
      b.baseWidth = 30;
      b.slope = 0.11;
      if (ice) b.hazard('icePatch', 0.3, 3, 8);
      return { ...b.build(), rivals: [] };
    };
    const slide = (ice: boolean): number => {
      const e = new GameEngine();
      e.start(course(ice), { ...DEFAULT_SETTINGS });
      while (e.phase !== 'racing') e.tick(DT);
      let lat0 = 0;
      let released = false;
      for (let n = 0; n < 60 * 25; n += 1) {
        const p = e.playerRacer!;
        const toPatch = (0.3 - p.progress) * 400;
        if (!released) {
          // Start steering about 0.8 s before the patch so the sled arrives at speed, mid-track.
          e.steerInput = toPatch < 13 ? 1 : 0;
          if (toPatch <= 0) {
            released = true;
            lat0 = p.lateral;
            e.steerInput = 0;
          }
        } else {
          e.steerInput = 0;
        }
        e.tick(DT);
        if (released && e.playerRacer!.progress >= 0.33) return e.playerRacer!.lateral - lat0;
      }
      return 0;
    };
    const snow = slide(false);
    const ice = slide(true);
    expect(ice).toBeGreaterThan(snow + 1);
  });
});

describe('pickups: rivals never take crystals or power-ups', () => {
  for (const id of ['villageDash', 'carnivalParade', 'icefallRun'] as LevelID[]) {
    it(id, () => {
      const { engine } = play(level(id));
      const rivalCrystals = engine.racers.filter((r) => !r.isPlayer).reduce((sum, r) => sum + r.crystals, 0);
      expect(rivalCrystals).toBe(0);
      const taken = engine.entities.filter((e) => e.collected).length;
      expect(taken).toBeGreaterThanOrEqual(engine.playerRacer!.crystals);
    });
  }
  it('the magnet never moves crystals in the shared course', () => {
    const before = level('villageDash').entities.map((e) => e.progress);
    play(level('villageDash'), { profile: BOTS.expert, seed: 5 });
    expect(level('villageDash').entities.map((e) => e.progress)).toEqual(before);
  });
});

describe('ghost: covers the whole run, replays in step, stays small', () => {
  const def = level('villageDash');
  const { engine, result } = play(def, { seed: 3 });
  const ghost = engine.capturedGhost();

  it('records the whole run', () => {
    expect(result).not.toBeNull();
    expect(ghost).not.toBeNull();
    expect(isUsableGhost(ghost)).toBe(true);
    expect(ghost!.samples[0].t).toBeLessThan(0.3);
    expect(Math.abs(ghost!.samples[ghost!.samples.length - 1].t - result!.time)).toBeLessThan(0.2);
    expect(ghost!.samples.length).toBeGreaterThan(Math.trunc(result!.time * 7));
    expect(JSON.stringify(ghost).length).toBeLessThan(20_000);
  });

  it('ignores an old truncated take', () => {
    const stale: GhostTake = {
      time: 30,
      samples: Array.from({ length: 200 }, (_, i) => ({ t: 15 + i * 0.08, p: 0.4 + i * 0.001, l: 0, h: 0 })),
    };
    expect(isUsableGhost(stale)).toBe(false);
  });

  it('replays in step with the recording', () => {
    const replay = new GameEngine();
    replay.start(def, { ...DEFAULT_SETTINGS }, ghost);
    const bot = new Bot(BOTS.idle, 1);
    let maxErr = 0;
    for (let ticks = 0; replay.phase !== 'finished' && ticks < 60 * 100; ticks += 1) {
      bot.update(replay, DT);
      replay.tick(DT);
      const pose = replay.ghostPose;
      if (replay.phase === 'racing' && pose) {
        const t = replay.raceTime;
        let nearest = ghost!.samples[0];
        for (const s of ghost!.samples) if (Math.abs(s.t - t) < Math.abs(nearest.t - t)) nearest = s;
        if (Math.abs(nearest.t - t) < 0.07) maxErr = Math.max(maxErr, Math.abs(nearest.p - pose.progress));
      }
    }
    expect(maxErr).toBeLessThan(0.01);
  });

  it('survives a save and load', () => {
    expect(decodeGhost(JSON.parse(JSON.stringify(ghost)))).toEqual(ghost);
  });
});

describe('avalanche: launches behind the player, buries once, ends', () => {
  for (const id of ['frozenHollow', 'whiteoutPeak', 'carnivalParade'] as LevelID[]) {
    it(id, () => {
      const def = level(id);
      const event = def.events.find((e) => e.kind === 'avalanche')!;
      let lastFront = -1;
      let monotonic = true;
      let everThreat = false;
      let launchedAt = -1;
      let gapAtLaunch = -1;
      const { engine, result } = play(def, {
        profile: BOTS.novice,
        seed: 4,
        each: (e) => {
          if (!e.avalancheThreat) return;
          everThreat = true;
          if (e.avalancheFront < lastFront - 1e-6) monotonic = false;
          lastFront = e.avalancheFront;
          const p = e.playerRacer;
          if (launchedAt < 0 && p && e.path) {
            launchedAt = p.progress;
            gapAtLaunch = (p.progress - e.avalancheFront) * e.path.length;
          }
        },
      });
      expect(result).not.toBeNull();
      expect(everThreat).toBe(true);
      expect(monotonic).toBe(true);
      expect(launchedAt).toBeGreaterThanOrEqual(event.start - 0.02);
      expect(gapAtLaunch).toBeGreaterThan(15);
      expect(gapAtLaunch).toBeLessThan(60);
      expect(engine.avalancheThreat).toBe(false);
    });
  }
});

describe('results: consistent standings, stars and clocks', () => {
  for (const id of ['villageDash', 'harborFreeze', 'prismCut', 'carnivalParade'] as LevelID[]) {
    it(id, () => {
      const { engine, result: r } = play(level(id), { profile: BOTS.casual, seed: 8 });
      expect(r).not.toBeNull();
      if (!r) return;
      expect(r.standings.length).toBe(r.fieldSize);
      const times = r.standings.map((s) => s.time!);
      expect(times).toEqual([...times].sort((a, b) => a - b));
      expect(new Set(r.standings.map((s) => s.place)).size).toBe(r.fieldSize);
      const me = r.standings.find((s) => s.isPlayer)!;
      expect(me.place).toBe(r.place);
      expect(Math.abs(me.time! - r.time)).toBeLessThan(0.02);
      expect(r.stars).toBe(StarRules.stars(resultPoints(r)));
      expect(r.stars).toBeGreaterThanOrEqual(1);
      expect(r.stars).toBeLessThanOrEqual(3);
      expect(r.parTime).toBeGreaterThan(0);
      expect(r.crystalGoal).toBeGreaterThan(0);
      expect(r.time).toBeGreaterThan(15);
      expect(r.time).toBeLessThan(90);
      expect(r.crashes).toBe(engine.playerRacer!.hits);

      // The race clock starts at zero at the light, not part-way through the countdown.
      const e2 = new GameEngine();
      e2.start(level(id), { ...DEFAULT_SETTINGS });
      let goTime = -1;
      for (let n = 0; n < 600; n += 1) {
        e2.tick(DT);
        if (e2.phase === 'racing') {
          goTime = e2.raceTime;
          break;
        }
      }
      expect(goTime).toBeGreaterThanOrEqual(0);
      expect(goTime).toBeLessThan(0.05);
    });
  }
});

describe('stars: bonus points add up', () => {
  const stars = (place: number, crystals: number, time: number): number =>
    StarRules.stars(StarRules.points(place, crystals, 20, time, 40));
  it('adds up as documented', () => {
    expect(stars(1, 0, 99)).toBe(3);
    expect(stars(2, 0, 99)).toBe(2);
    expect(stars(2, 25, 99)).toBe(3);
    expect(stars(5, 25, 30)).toBe(3);
    expect(stars(5, 0, 99)).toBe(1);
    expect(StarRules.points(1, 25, 20, 30, 40)).toBeGreaterThanOrEqual(StarRules.perfectPoints);
  });
});

describe('daily: goals are judged, streaks continue only day to day', () => {
  const r = (place: number, crystals: number, time: number, crashes: number): RaceResult =>
    makeResult({ place, crystals, time, crashes, daily: true });
  it('judges each goal from the result', () => {
    expect(goalMet('beatPar', r(4, 0, 39, 3))).toBe(true);
    expect(goalMet('beatPar', r(1, 34, 41, 0))).toBe(false);
    expect(goalMet('topTwo', r(2, 0, 90, 9))).toBe(true);
    expect(goalMet('topTwo', r(3, 34, 30, 0))).toBe(false);
    expect(goalMet('crystalHunt', r(6, 28, 90, 9))).toBe(true);
    expect(goalMet('crystalHunt', r(1, 27, 30, 0))).toBe(false);
    expect(goalMet('cleanRun', r(6, 0, 90, 0))).toBe(true);
    expect(goalMet('cleanRun', r(1, 34, 30, 1))).toBe(false);
  });
  it('continues a streak only from yesterday', () => {
    const day = 86_400_000;
    const today = new Date(1_800_000_000_000);
    const key = dateKey(today);
    const yesterday = dateKey(new Date(today.getTime() - day));
    const old = dateKey(new Date(today.getTime() - 3 * day));
    expect(dailyStreakAfter(key, yesterday, 4, today)).toBe(5);
    expect(dailyStreakAfter(key, old, 4, today)).toBe(1);
    expect(dailyStreakAfter(key, '', 0, today)).toBe(1);
    expect(dailyStreakAfter(key, key, 4, today)).toBe(4);
  });
  it('picks the same course all day, and every goal over two months', () => {
    const today = new Date(1_800_000_000_000);
    expect(pickDaily([...LEVEL_IDS], today)).toEqual(pickDaily([...LEVEL_IDS], today));
    const seen = new Set<DailyGoal>();
    for (let d = 0; d < 60; d += 1)
      seen.add(pickDaily([...LEVEL_IDS], new Date(today.getTime() + d * 86_400_000)).goal);
    expect(seen.size).toBe(DAILY_GOALS.length);
  });
  it('uses the UTC date', () => {
    expect(dateKey(new Date(Date.UTC(2026, 0, 31, 23, 59, 59)))).toBe('2026-01-31');
  });
});

describe('persistence: records, bests, daily completion, reset', () => {
  it('keeps records, ghosts and the daily streak like the Swift app', () => {
    let saved = '';
    const store = new GamePersistence({}, { save: (json) => (saved = json) });
    const result = (place: number, time: number, crystals = 30, goal: DailyGoal | null = null): RaceResult =>
      makeResult({
        place,
        time,
        crystals,
        stars: 3,
        comboMax: 3,
        nearMisses: 1,
        daily: goal !== null,
        dailyGoal: goal,
      });
    const ghostA: GhostTake = {
      time: 33,
      samples: Array.from({ length: 40 }, (_, i) => ({ t: i * 0.125, p: i * 0.02, l: 0, h: 0 })),
    };
    const first = store.record(result(2, 33), ghostA);
    expect(first.previousBestTime).toBeNull();
    expect(first.newBestTime).toBe(true);
    expect(store.isUnlocked('marketMayhem')).toBe(true);
    const slower = store.record(result(1, 35));
    expect(slower.previousBestTime).toBe(33);
    expect(slower.newBestTime).toBe(false);
    expect(store.records.get('villageDash')?.ghost).toEqual(ghostA);
    const faster = store.record(result(1, 31), { time: 31, samples: ghostA.samples });
    expect(faster.newBestTime).toBe(true);
    expect(faster.previousBestTime).toBe(33);
    expect(store.records.get('villageDash')?.perfect).toBe(true);
    // A daily miss does not count and can be retried; a hit counts once.
    const miss = store.record(result(4, 45, 5, 'topTwo'));
    expect(miss.dailyMet).toBe(false);
    expect(store.dailyDoneToday).toBe(false);
    expect(store.lastDailyWins).toBe(0);
    const hit = store.record(result(1, 32, 30, 'topTwo'));
    expect(hit.dailyMet && store.dailyDoneToday && store.lastDailyWins === 1 && hit.dailyStreak === 1).toBe(true);
    const again = store.record(result(1, 32, 30, 'topTwo'));
    expect(again.dailyMet && store.lastDailyWins === 1).toBe(true);
    expect(store.activeDailyStreak).toBe(1);

    // What was written reads back the same.
    const reloaded = GamePersistence.fromJSON(saved);
    expect(reloaded.toJSON()).toBe(store.toJSON());

    store.resetProgress();
    expect(store.records.size).toBe(0);
    expect(store.lastDailyWins).toBe(0);
    expect(store.dailyStreak).toBe(0);
    expect(store.isUnlocked('marketMayhem')).toBe(false);
    expect(store.totalRaces).toBe(0);
  });

  it('reads a save written by the Swift app', () => {
    const swiftSave = JSON.stringify({
      unlocked: ['villageDash', 'marketMayhem'],
      records: {
        villageDash: { bestPlace: 1, bestStars: 3, bestTime: 27.5, bestCrystals: 31, timesPlayed: 4, perfect: true },
        nonsense: { bestStars: 3 },
      },
      settings: {
        tiltSteering: false,
        unlockAll: true,
        hapticsEnabled: true,
        soundEnabled: true,
        showGhost: true,
        selectedSkin: 'ember',
        steerSensitivity: 1.2,
      },
      lastDailyKey: '2026-09-28',
      lastDailyWins: 3,
      dailyStreak: 2,
    });
    const store = GamePersistence.fromJSON(swiftSave, { now: () => new Date('2026-09-29T08:00:00Z') });
    expect(store.totalStars).toBe(3);
    expect(store.isUnlocked('marketMayhem')).toBe(true);
    expect(store.settings.selectedSkin).toBe('ember');
    expect(store.settings.unlockAll).toBe(false); // release builds ignore the debug switch
    expect(store.activeDailyStreak).toBe(2);
    expect([...store.records.keys()]).toEqual(['villageDash']);
  });

  it('starts fresh from a damaged save', () => {
    expect(GamePersistence.fromJSON('{not json').totalStars).toBe(0);
    expect(GamePersistence.fromJSON('null').isUnlocked('villageDash')).toBe(true);
  });
});

describe('settings: old saves still load, sensitivity is clamped', () => {
  it('decodes like the Swift app', () => {
    const s = decodeSettings(
      {
        tiltSteering: true,
        unlockAll: false,
        hapticsEnabled: true,
        soundEnabled: false,
        showGhost: true,
        selectedSkin: 'gold',
      },
      isSledSkin,
    );
    expect(s.steerSensitivity).toBe(1);
    expect(s.tiltSteering).toBe(true);
    expect(s.soundEnabled).toBe(false);
    expect(s.selectedSkin).toBe('gold');
    expect(s.shareUsageData).toBe(true);
    expect(decodeSettings({ steerSensitivity: 9 }, isSledSkin).steerSensitivity).toBe(1.6);
    expect(decodeSettings({ shareUsageData: false }, isSledSkin).shareUsageData).toBe(false);
    const r = decodeRecord(
      { bestPlace: 2, bestStars: 3, bestTime: 33.5, bestCrystals: 20, timesPlayed: 4 },
      decodeGhost,
    );
    expect(r.bestStars).toBe(3);
    expect(r.perfect).toBe(false);
    expect(r.ghost).toBeNull();
  });
});

describe('hud: refreshes about 30 times a second; a timed boost launches the sled', () => {
  it('publishes about 30 snapshots a second', () => {
    const e = new GameEngine();
    let published = 0;
    e.onHUD = () => (published += 1);
    e.start(level('villageDash'), { ...DEFAULT_SETTINGS });
    while (e.phase !== 'racing') e.tick(DT);
    published = 0;
    for (let n = 0; n < 120; n += 1) e.tick(DT);
    const perSecond = published / 2;
    expect(perSecond).toBeGreaterThan(24);
    expect(perSecond).toBeLessThan(36);
  });

  it('launches only on a well-timed press', () => {
    const speedAfterGo = (holdFrom: number | null): number => {
      const g = new GameEngine();
      g.start(level('villageDash'), { ...DEFAULT_SETTINGS });
      let t = 0;
      while (g.phase !== 'racing' && t < 6) {
        g.boostHeld = holdFrom !== null && t >= holdFrom;
        g.tick(DT);
        t += DT;
      }
      return g.playerRacer!.speed;
    };
    const none = speedAfterGo(null);
    expect(speedAfterGo(2.55)).toBeGreaterThan(none + 2);
    expect(Math.abs(speedAfterGo(0.1) - none)).toBeLessThan(0.5);
  });
});

describe('fuzz: random inputs never break the simulation', () => {
  it('stays finite and on the track, and every race finishes', () => {
    const rng = new SplitMix64(99);
    let bad = 0;
    let unfinished = 0;
    const firstBad: string[] = [];
    for (let round = 0; round < 72; round += 1) {
      const id = LEVEL_IDS[round % LEVEL_IDS.length];
      const engine = new GameEngine();
      let result: RaceResult | null = null;
      engine.onFinished = (r) => (result = r);
      const settings = { ...DEFAULT_SETTINGS, steerSensitivity: 0.6 + rng.nextUnit() };
      engine.start(level(id), settings, null, round % 5 === 0 ? 'cleanRun' : null);
      let steer = 0;
      for (let ticks = 0; result === null && ticks < 60 * 200; ticks += 1) {
        if (ticks % 20 === 0) steer = -3 + 6 * rng.nextUnit(); // beyond full lock on purpose
        engine.steerInput = steer;
        engine.boostHeld = rng.nextUnit() < 0.5;
        if (ticks % 240 === 0) engine.dropBananaRequested = true;
        const dt = [1 / 30, 1 / 60, 1 / 120, 0.05, 0.001][Number(rng.next() % 5n)];
        engine.tick(dt);
        for (const r of engine.racers) {
          const numbers = [r.progress, r.lateral, r.height, r.speed, r.lateralVel, r.turbo, r.roll, r.pitch, r.yaw];
          const half = (engine.path?.width(r.progress) ?? 20) * 0.5;
          const ok =
            numbers.every(Number.isFinite) &&
            Math.abs(r.lateral) <= half + 0.01 &&
            r.progress >= 0 &&
            r.progress <= 1 &&
            r.turbo >= 0 &&
            r.turbo <= 1.0001 &&
            r.speed >= 0 &&
            r.speed <= 60;
          if (!ok) {
            bad += 1;
            if (firstBad.length < 3) firstBad.push(`${id}: ${r.name} p=${r.progress} l=${r.lateral} v=${r.speed}`);
          }
        }
      }
      if (result === null) unfinished += 1;
    }
    expect(firstBad).toEqual([]);
    expect(bad).toBe(0);
    expect(unfinished).toBe(0);
  });
});
