/**
 * The race simulation. A line-by-line port of `Engine/GameEngine.swift`: arcade physics on a
 * spline (progress along the track, lateral offset, height), rival AI, pickups, hazards, the
 * avalanche, ghosts and results.
 *
 * Differences from the Swift class, all at the edges:
 * - The engine does not own the renderer. The app ticks the engine, then draws from its state.
 * - Sounds and haptics go through an injected `EngineFx`, and tilt comes from an injected reader,
 *   so the engine runs in Node for tests.
 * - Live props copy their course definition (Swift structs are values; the magnet moves crystals
 *   and must not move them in the shared course).
 * - Dropped peels get repeatable ids instead of random UUIDs, so races are reproducible.
 */
import {
  add,
  addScaled,
  clamp,
  damp,
  damp3,
  lerp,
  saturate,
  scale,
  smoothstep,
  sub,
  vec3,
  wrapAngle,
  type Vec3,
} from '../core/math';
import {
  EMPTY_HUD,
  StarRules,
  crystalCount,
  levelOrder,
  type CourseEvent,
  type GameSettings,
  type HUDSnapshot,
  type LevelDefinition,
  type PlacedEntity,
  type PodiumEntry,
  type PropKind,
  type RacePhase,
  type RaceResult,
  DEFAULT_SETTINGS,
} from '../core/models';
import { isUsableGhost, type DailyGoal, type GhostSample, type GhostTake } from '../core/progression';
import { stableId, uuidByte } from '../core/stableId';
import { CollisionClass, RacerFactory, type LiveEntity, type Racer } from './racer';
import { TrackPath, type TrackSample } from './trackPath';

/** Every balance constant, in one place. */
export const Tuning = {
  // Steering: lateral acceleration at full lock, and how fast sideways speed bleeds off.
  // acceleration / drag = top sideways speed (about 6.8 m/s on snow, response ~0.12 s).
  steerAccel: 58,
  snowDrag: 8.5,
  airDrag: 3.0,
  iceDrag: 1.4,
  iceSteerScale: 0.55,
  airSteerScale: 0.35,
  stunSteerScale: 0.25,
  /** Ice patches are ellipses: the stretch multiplies their radius along the track. */
  icePatchStretch: 1.8,

  // Curves push the sled toward the outside wall; riding the wall costs speed.
  cornerPull: 3.0,
  cornerPullCap: 14,
  wallScrapeSpeed: 0.9,
  wallScrapeTime: 0.25,
  /** Limits on how much shorter (or longer) a racing line can be than the centre line. */
  lineFactorMin: 0.9,
  lineFactorMax: 1.1,

  // A crash: speed left after the hit, how long the sled is stunned, and the grace period after
  // that before it can be hit again. Together they cost roughly a second.
  crashSpeedFactor: 0.34,
  crashStun: 0.7,
  crashInvuln: 1.0,
  /** Top speed while stunned, as a fraction of normal. */
  stunSpeedFactor: 0.32,
  /** How far back a splash puts the sled, in metres (never behind the last checkpoint). */
  splashSetback: 30,

  // Rivals.
  aiSteerAuthority: 0.85,
  aiTurboRegen: 0.045,
  bandSlow: 0.08,
  bandCatchUp: 0.09,

  // Turbo. Crystals fuel it, holding BOOST burns it, and a pad or rocket gives a burst without
  // spending any. A full crystal run is worth about three seconds of boost over a course.
  boostSpeedMultiplier: 1.32,
  boostDrain: 0.26,
  boostPush: 20,
  crystalFuel: 0.09,
  comboFuel: 0.04,
  padBoostTime: 1.3,
  /** Powered speed outlives a frame of boosting by this long, so frame timing can't flicker it. */
  boostGrace: 0.05,
  rocketSpeedMultiplier: 1.36,

  /** Avalanche: how far behind the player the wall appears when it starts running. */
  avalancheHeadStart: 0.045,

  // Ghost recording.
  ghostInterval: 0.125,
  ghostMaxSamples: 1000,

  /** The HUD only needs to redraw about this often. */
  hudInterval: 1 / 30,
};

export type HapticStyle = 'light' | 'medium' | 'heavy';

/** Sounds and haptics the race asks for. */
export interface EngineFx {
  collect(): void;
  boost(): void;
  crash(): void;
  finish(): void;
  countdown(): void;
  go(): void;
  whoosh(): void;
  comboHit(): void;
  power(): void;
  tap(style: HapticStyle): void;
}

export const SILENT_FX: EngineFx = {
  collect() {},
  boost() {},
  crash() {},
  finish() {},
  countdown() {},
  go() {},
  whoosh() {},
  comboHit() {},
  power() {},
  tap() {},
};

export interface GhostPose {
  progress: number;
  lateral: number;
  height: number;
}

/** Swift's `rounded()`: halves go away from zero. */
const roundHalfAway = (x: number): number => {
  const r = Math.sign(x) * Math.round(Math.abs(x));
  return r === 0 ? 0 : r; // no negative zero
};

const COMBO_WINDOW = 1.65;
const MAX_PEELS = 3;
const PEEL_LIFETIME = 20;

export class GameEngine {
  hud: HUDSnapshot = EMPTY_HUD;
  phase: RacePhase = 'idle';
  /** The digit on screen while `phase` is `countdown`. */
  countdownDigit = 3;
  paused = false;

  onFinished: ((result: RaceResult) => void) | null = null;
  /** Called whenever a new HUD snapshot is published (about 30 times a second). */
  onHUD: ((hud: HUDSnapshot) => void) | null = null;

  level: LevelDefinition | null = null;
  path: TrackPath | null = null;
  racers: Racer[] = [];
  entities: LiveEntity[] = [];
  droppedBananas: PlacedEntity[] = [];
  raceTime = 0;
  cameraEye: Vec3 = vec3(0, 8, -8);
  cameraLook: Vec3 = vec3(0, 2, 8);
  cameraFOV = 50;
  landingPulse = 0;
  cameraShake = 0;
  toastTimer = 0;
  toastText = '';

  /** Swipe steering as set by the view: drag distance in points / 60, not yet clamped. */
  steerInput = 0;
  boostHeld = false;
  dropBananaRequested = false;

  combo = 0;
  comboMax = 0;
  nearMisses = 0;
  avalancheFront = 0;
  avalancheThreat = false;
  ghostPose: GhostPose | null = null;
  dailyGoal: DailyGoal | null = null;
  /** Counts calls to `start`, so a renderer can tell a new race (or a restart) from the last one. */
  raceId = 0;

  /**
   * Reads the phone's sideways lean in g (as `CMAccelerometerData.acceleration.x`), or null
   * when there is no reading. Only consulted while tilt steering is on.
   */
  tiltReader: (() => number | null) | null = null;

  private settings: GameSettings = { ...DEFAULT_SETTINGS };
  private countdownLeft = 3.2;
  private lastCountdownDigit = 4;
  private finishHold = 0;
  /** Time since the player crossed the line; rivals still racing keep their own clock. */
  private coastTime = 0;
  private resultEmitted = false;
  private tiltInput = 0;
  private windPhase = 0;
  private bobClock = 0;
  private boostPrimed = 0;
  private rewardedTurboUsed = false;
  private hudAccumulator = 0;
  private comboTimer = 0;
  private avalancheEvent: CourseEvent | null = null;
  private avalancheActive = false;
  private avalancheSpent = false;
  private avalancheBuried = new Set<string>();
  private avalancheRumble = 0;
  private recordedGhost: GhostSample[] = [];
  private playbackGhost: GhostTake | null = null;
  private ghostClock = 0;
  private nearMissed = new Set<string>();
  private usedShortcuts = new Set<string>();
  private peelBorn = new Map<string, number>();
  private peelCounter = 0;
  private bumpCooldown = 0;
  private scrapeHaptic = 0;

  constructor(private readonly fx: EngineFx = SILENT_FX) {}

  get dailyRun(): boolean {
    return this.dailyGoal !== null;
  }

  get playerRacer(): Racer | undefined {
    return this.racers.find((r) => r.isPlayer);
  }

  start(
    level: LevelDefinition,
    settings: GameSettings,
    ghost: GhostTake | null = null,
    dailyGoal: DailyGoal | null = null,
  ): void {
    this.raceId += 1;
    this.settings = settings;
    this.level = level;
    const path = TrackPath.build(level);
    this.path = path;
    this.dailyGoal = dailyGoal;
    this.combo = 0;
    this.comboMax = 0;
    this.comboTimer = 0;
    this.nearMisses = 0;
    this.avalancheFront = 0;
    this.avalancheThreat = false;
    this.avalancheEvent = level.events.find((e) => e.kind === 'avalanche') ?? null;
    this.avalancheActive = false;
    this.avalancheSpent = false;
    this.avalancheBuried = new Set();
    this.avalancheRumble = 0;
    this.ghostPose = null;
    this.recordedGhost = [];
    this.playbackGhost = settings.showGhost && isUsableGhost(ghost) ? ghost : null;
    this.ghostClock = 0;
    this.nearMissed = new Set();
    this.usedShortcuts = new Set();
    this.racers = [RacerFactory.player(0, settings.selectedSkin), ...level.rivals.map(RacerFactory.rival)];
    this.spreadStartGrid(path);
    this.bumpCooldown = 0;
    this.scrapeHaptic = 0;
    this.entities = level.entities.map((e) => ({
      definition: { ...e },
      collected: false,
      destroyed: false,
      liveLateral: e.lateral,
      phase: e.progress * 17,
    }));
    this.droppedBananas = [];
    this.peelBorn = new Map();
    this.peelCounter = 0;
    this.raceTime = 0;
    this.coastTime = 0;
    this.bobClock = 0;
    this.boostPrimed = 0;
    this.tiltInput = 0;
    this.hudAccumulator = 0;
    this.countdownLeft = 3.25;
    this.lastCountdownDigit = 4;
    this.finishHold = 0;
    this.resultEmitted = false;
    this.rewardedTurboUsed = false;
    this.paused = false;
    this.phase = 'countdown';
    this.countdownDigit = 3;
    this.toastText = '';
    this.toastTimer = 0;
    this.landingPulse = 0;
    this.cameraShake = 0;
    this.cameraFOV = 50;
    const player = this.playerRacer;
    if (player) {
      const sample = path.sample(player.progress);
      const pos = path.worldPosition(player.progress, player.lateral, 0);
      this.cameraEye = addScaled(addScaled(pos, sample.tangent, -6.4), sample.normal, 3.15);
      this.cameraLook = addScaled(addScaled(pos, sample.tangent, 9.5), sample.normal, 0.35);
    }
    this.publishHUD(0, true);
  }

  restart(): void {
    if (!this.level) return;
    this.start(this.level, this.settings, this.playbackGhost, this.dailyGoal);
  }

  capturedGhost(): GhostTake | null {
    if (this.recordedGhost.length <= 8) return null;
    const samples = [...this.recordedGhost];
    // Close the take on the finish line so the replay ends where the run did.
    const player = this.playerRacer;
    if (player && player.finishTime !== null) {
      samples.push({ t: player.finishTime, p: player.progress, l: player.lateral, h: 0 });
    }
    return { time: player?.finishTime ?? this.raceTime, samples };
  }

  stop(): void {
    this.phase = 'idle';
    this.paused = false;
  }

  /** Called after a player-opted rewarded video. Once per race. */
  grantRewardedTurbo(): void {
    const player = this.playerRacer;
    if (this.rewardedTurboUsed || !player) return;
    this.rewardedTurboUsed = true;
    player.turbo = 1;
    player.trailBoost = 0.45;
    player.boostTime = 0.45;
    this.toast('Turbo refilled!');
    this.fx.power();
    this.publishHUD(0, true);
  }

  tick(rawDT: number): void {
    if (!this.level || !this.path || this.phase === 'idle') return;
    if (this.paused) return;
    // Rounded to 32 bits like the Swift engine's `Float` time step, so both count the same number
    // of frames (the 3.25 s countdown ends on the same frame, for instance).
    const dt = Math.fround(clamp(Math.fround(rawDT), Math.fround(1 / 240), Math.fround(1 / 20)));
    switch (this.phase) {
      case 'countdown':
        this.updateCountdown(dt);
        this.bobIdle(dt);
        this.publishHUD(dt);
        break;
      case 'racing':
        this.simulate(dt);
        this.publishHUD(dt);
        break;
      case 'finished':
        this.finishHold += dt;
        this.simulateCoasting(dt);
        this.publishHUD(dt);
        if (!this.resultEmitted && this.finishHold > 1.15) {
          this.resultEmitted = true;
          this.onFinished?.(this.makeResult());
        }
        break;
    }
  }

  makeResult(): RaceResult {
    const ranked = this.rankedRacers();
    const times = this.finishTimes(ranked);
    const playerPlace = ranked.findIndex((r) => r.isPlayer) + 1 || 1;
    const player = this.playerRacer;
    const time = player?.finishTime ?? this.raceTime;
    const crystals = player?.crystals ?? 0;
    const parTime = this.level?.parTime ?? 50;
    const crystalGoal = this.level?.crystalStar ?? 24;
    const points = StarRules.points(playerPlace, crystals, crystalGoal, time, parTime);
    const standings: PodiumEntry[] = ranked.map((racer, index) => ({
      id: racer.id,
      name: racer.name,
      place: index + 1,
      time: times[index],
      isPlayer: racer.isPlayer,
      color: racer.sledColor,
    }));
    return {
      level: this.level?.id ?? 'villageDash',
      place: playerPlace,
      fieldSize: this.racers.length,
      time,
      crystals,
      crystalTotal: this.level ? crystalCount(this.level) : 0,
      stars: StarRules.stars(points),
      podium: standings.slice(0, 3),
      comboMax: this.comboMax,
      nearMisses: this.nearMisses,
      unlockedSkin: null,
      daily: this.dailyGoal !== null,
      parTime,
      crystalGoal,
      crashes: player?.hits ?? 0,
      standings,
      previousBest: null,
      newBest: false,
      dailyGoal: this.dailyGoal,
      dailyMet: false,
      dailyStreak: 0,
    };
  }

  // MARK: - Simulation

  private updateCountdown(dt: number): void {
    this.countdownLeft -= dt;
    // Tapping BOOST as the light turns green launches the sled; holding it from the start of the
    // countdown does not.
    if (this.boostHeld) this.boostPrimed += dt;
    else this.boostPrimed = 0;
    let digit: number;
    if (this.countdownLeft > 2) digit = 3;
    else if (this.countdownLeft > 1) digit = 2;
    else if (this.countdownLeft > 0) digit = 1;
    else digit = 0;
    if (digit !== this.lastCountdownDigit) {
      this.lastCountdownDigit = digit;
      if (digit === 0) {
        this.launch();
      } else if (digit > 0) {
        this.fx.countdown();
        this.phase = 'countdown';
        this.countdownDigit = digit;
      }
    }
    if (this.countdownLeft <= 0) this.phase = 'racing';
  }

  private launch(): void {
    this.fx.go();
    this.phase = 'racing';
    this.toast('GO!');
    const player = this.playerRacer;
    if (this.boostPrimed > 0.05 && this.boostPrimed < 1.0 && player) {
      player.speed += 3.5;
      player.trailBoost = 0.8;
      player.boostTime = 0.8;
      this.fx.power();
    }
  }

  /** Idle sway while the countdown runs. It has its own clock: the race clock must stay at zero. */
  private bobIdle(dt: number): void {
    this.bobClock += dt;
    const path = this.path;
    this.racers.forEach((r, i) => {
      r.height = 0.04 + Math.sin(this.bobClock + i * 3) * 0.02;
      r.yaw = path ? path.sample(r.progress).heading : 0;
    });
    this.updateCamera(dt);
  }

  private simulate(dt: number): void {
    const path = this.path;
    const level = this.level;
    if (!path || !level) return;
    this.raceTime += dt;
    this.windPhase += dt;
    this.updateTilt(dt);
    this.animateMovers();
    for (let i = 0; i < this.racers.length; i += 1) {
      const r = this.racers[i];
      if (r.finished) continue;
      if (r.isPlayer) this.stepPlayer(i, dt, path);
      else this.stepAI(i, dt, path);
      this.integrateRacer(i, dt, path, level);
      this.resolveCollisions(i, path);
      if (r.isPlayer) {
        // Crystals and power-ups belong to the player; rivals earn turbo over time instead, so
        // they can never empty a lane before the player reaches it.
        this.collectPickups(i, path);
      }
      this.resolvePads(i, path);
      this.resolveCheckpoints(i);
      if (r.isPlayer) {
        this.detectNearMiss(i, path);
        this.resolveShortcuts(i, path, level);
        this.recordGhost(i, dt);
      }
      if (r.progress >= 0.992 && !r.finished) {
        r.finished = true;
        r.finishTime = this.raceTime;
        r.progress = 0.993;
        if (r.isPlayer) {
          this.fx.finish();
          this.toast('Finish!');
          this.phase = 'finished';
          this.finishHold = 0;
        }
      }
    }
    this.updateAvalanche(dt, path);
    this.updatePeels();
    this.bumpCooldown = Math.max(0, this.bumpCooldown - dt);
    this.scrapeHaptic = Math.max(0, this.scrapeHaptic - dt);
    this.cameraShake = Math.max(0, this.cameraShake - dt * 3);
    this.separateRacers(path);
    this.landingPulse = Math.max(0, this.landingPulse - dt * 2.4);
    this.tickCombo(dt);
    this.playbackGhostPose();
    if (this.toastTimer > 0) {
      this.toastTimer -= dt;
      if (this.toastTimer <= 0) this.toastText = '';
    }
    this.updateCamera(dt);
  }

  private simulateCoasting(dt: number): void {
    const path = this.path;
    const level = this.level;
    if (!path || !level) return;
    this.coastTime += dt;
    for (let i = 0; i < this.racers.length; i += 1) {
      const r = this.racers[i];
      if (r.finished) continue;
      this.stepAI(i, dt, path);
      this.integrateRacer(i, dt, path, level);
      if (r.progress >= 0.992) {
        r.finished = true;
        r.finishTime = this.raceTime + this.coastTime;
      }
    }
    for (const r of this.racers) {
      if (!r.finished) continue;
      r.speed = damp(r.speed, 8, 2.2, dt);
      r.progress = Math.min(0.997, r.progress + (r.speed * dt) / path.length);
    }
    this.separateRacers(path);
    // Nothing left to wait for once everyone is over the line.
    if (this.racers.every((r) => r.finished)) this.finishHold = Math.max(this.finishHold, 1.15);
    this.cameraShake = Math.max(0, this.cameraShake - dt * 3);
    this.landingPulse = Math.max(0, this.landingPulse - dt * 2.4);
    if (this.toastTimer > 0) {
      this.toastTimer -= dt;
      if (this.toastTimer <= 0) this.toastText = '';
    }
    this.updateCamera(dt);
  }

  /**
   * Spaces the pack evenly across the start line so no sled spawns inside another. Rivals keep
   * their authored left-to-right order; the player takes the middle slot.
   */
  private spreadStartGrid(path: TrackPath): void {
    const n = this.racers.length;
    if (n <= 1) return;
    const half = path.width(this.racers[0].progress) * 0.5 - 0.9;
    const spacing = Math.min(2.4, (2 * half) / (n - 1));
    const slots = Array.from({ length: n }, (_, k) => (k - (n - 1) / 2) * spacing);
    let playerSlot = 0;
    slots.forEach((s, k) => {
      if (Math.abs(s) < Math.abs(slots[playerSlot])) playerSlot = k;
    });
    const rivalSlots = slots.map((_, k) => k).filter((k) => k !== playerSlot);
    const rivalOrder = this.racers
      .map((r, k) => ({ r, k }))
      .filter(({ r }) => !r.isPlayer)
      .sort((a, b) => a.r.lateral - b.r.lateral)
      .map(({ k }) => k);
    rivalSlots.forEach((slot, n2) => {
      if (n2 < rivalOrder.length) this.racers[rivalOrder[n2]].lateral = slots[slot];
    });
    const player = this.playerRacer;
    if (player) player.lateral = slots[playerSlot];
  }

  /**
   * Soft sled-to-sled contact: overlapping racers are pushed apart sideways so nobody drives
   * through anyone. The player feels a light bump.
   */
  private separateRacers(path: TrackPath): void {
    const reach = 1.35;
    const racers = this.racers;
    for (let a = 0; a < racers.length; a += 1) {
      for (let b = a + 1; b < racers.length; b += 1) {
        const ra = racers[a];
        const rb = racers[b];
        if (Math.abs(ra.height - rb.height) > 0.6) continue;
        const along = (ra.progress - rb.progress) * path.length;
        const side = ra.lateral - rb.lateral;
        if (!(Math.abs(along) < reach && Math.abs(side) < reach)) continue;
        const dir = side === 0 ? (a % 2 === 0 ? 1 : -1) : side > 0 ? 1 : -1;
        const push = (reach - Math.abs(side)) * 0.5;
        ra.lateral += dir * push;
        rb.lateral -= dir * push;
        ra.lateralVel += dir * 3;
        rb.lateralVel -= dir * 3;
        if ((ra.isPlayer || rb.isPlayer) && this.bumpCooldown <= 0) {
          this.bumpCooldown = 0.35;
          this.cameraShake = Math.max(this.cameraShake, 0.3);
          this.fx.tap('light');
        }
      }
    }
    for (const r of racers) {
      const half = path.width(r.progress) * 0.5 - 0.7;
      r.lateral = clamp(r.lateral, -half, half);
    }
  }

  // MARK: - Input

  /** Swipe (scaled by the sensitivity setting, eased so small drags stay precise) plus tilt. */
  private effectiveSteer(): number {
    const raw = clamp(this.steerInput * this.settings.steerSensitivity, -1, 1);
    const shaped = raw * (0.55 + 0.45 * Math.abs(raw));
    return clamp(shaped + this.tiltInput, -1, 1);
  }

  private stepPlayer(i: number, dt: number, path: TrackPath): void {
    this.applySteering(i, this.effectiveSteer(), dt, path);
    if (this.dropBananaRequested) {
      this.dropBananaRequested = false;
      this.dropBanana(i);
    }
    if (this.boostHeld) this.tryBoost(i, dt);
  }

  private stepAI(i: number, dt: number, path: TrackPath): void {
    const racer = this.racers[i];
    const width = path.width(racer.progress);
    const half = width * 0.5 - 0.9;
    const here = path.sample(racer.progress);
    const ahead = path.sample(Math.min(1, racer.progress + 0.05));

    // Base line: lean toward the inside of the next bend.
    let targetLateral = -wrapAngle(ahead.heading - here.heading) * 5.0;

    // Keep clear of neighbours.
    let crowd = 0;
    for (let j = 0; j < this.racers.length; j += 1) {
      if (j === i) continue;
      const other = this.racers[j];
      if (Math.abs(other.progress - racer.progress) < 0.028) {
        const gap = other.lateral - racer.lateral;
        if (Math.abs(gap) < 2.5) crowd += gap > 0 ? -1 : 1;
      }
    }
    targetLateral += crowd * 1.6;

    const player = this.playerRacer;
    if (
      racer.personality === 'aggressive' &&
      player &&
      !player.finished &&
      Math.abs(player.progress - racer.progress) < 0.05
    ) {
      // Aggressive rivals lean on the player.
      targetLateral = lerp(targetLateral, player.lateral, 0.45);
    }

    // Hazards and peels ahead: steer to the nearer side that clears them. How far ahead a rival
    // looks, how wide a berth it takes and how often it misses one is personality.
    let notice: number;
    let berth: number;
    let missPercent: number;
    switch (racer.personality) {
      case 'cautious':
        notice = 0.09;
        berth = 1.0;
        missPercent = 3;
        break;
      case 'aggressive':
        notice = 0.05;
        berth = 0.4;
        missPercent = 10;
        break;
      case 'hoarder':
        notice = 0.07;
        berth = 0.7;
        missPercent = 7;
        break;
      default:
        notice = 0.07;
        berth = 0.7;
        missPercent = 6;
    }
    const threats: { dp: number; lateral: number; radius: number }[] = [];
    for (const entity of this.entities) {
      if (entity.collected || entity.destroyed) continue;
      const kind = entity.definition.kind;
      if (!CollisionClass.solidHazards.has(kind) && kind !== 'water') continue;
      if (!(entity.definition.radius > 0)) continue;
      const dp = entity.definition.progress - racer.progress;
      if (!(dp > 0 && dp < notice)) continue;
      if (GameEngine.overlooks(racer.id, entity.definition.id, missPercent)) continue;
      threats.push({ dp, lateral: entity.liveLateral, radius: entity.definition.radius });
    }
    // Peels are visible from a distance, but not every rival spots one in time.
    for (const peel of this.droppedBananas) {
      const dp = peel.progress - racer.progress;
      if (!(dp > 0 && dp < 0.06)) continue;
      if (GameEngine.overlooks(racer.id, peel.id, 35)) continue;
      threats.push({ dp, lateral: peel.lateral, radius: peel.radius });
    }
    threats.sort((a, b) => a.dp - b.dp);
    for (const threat of threats) {
      const clearance = threat.radius + 0.7 + berth;
      if (!(Math.abs(targetLateral - threat.lateral) < clearance)) continue;
      const left = threat.lateral - clearance;
      const right = threat.lateral + clearance;
      const canLeft = left >= -half;
      const canRight = right <= half;
      if (canLeft && canRight) {
        targetLateral = Math.abs(left - racer.lateral) <= Math.abs(right - racer.lateral) ? left : right;
      } else if (canLeft) {
        targetLateral = left;
      } else if (canRight) {
        targetLateral = right;
      }
    }

    targetLateral = clamp(targetLateral, -half, half);
    const error = targetLateral - racer.lateral;
    let input = clamp(error * 0.22, -1, 1);
    // Rivals lean into the bend against the pull, so they hold their line.
    input -= (0.8 * this.cornerPull(racer, here)) / (Tuning.steerAccel * Tuning.aiSteerAuthority);
    this.applySteering(i, clamp(input, -1, 1), dt, path, Tuning.aiSteerAuthority);
    racer.turbo = Math.min(1, racer.turbo + Tuning.aiTurboRegen * dt);
    this.decideAIBoost(i, dt);
  }

  /** A stable per-pair coin flip: does this rival fail to notice this obstacle? */
  static overlooks(racer: string, obstacle: string, percent: number): boolean {
    return (uuidByte(racer, 0) * 31 + uuidByte(obstacle, 0) * 17 + uuidByte(obstacle, 1)) % 100 < percent;
  }

  /** Sideways acceleration a bend puts on a sled (positive pushes toward the right wall). */
  private cornerPull(racer: Racer, sample: TrackSample): number {
    if (racer.airborne) return 0;
    const raw = sample.curvature * racer.speed * racer.speed * Tuning.cornerPull;
    return clamp(raw, -Tuning.cornerPullCap, Tuning.cornerPullCap);
  }

  private applySteering(i: number, input: number, dt: number, path: TrackPath, authority = 1): void {
    const r = this.racers[i];
    const ice = this.isOnIce(r);
    let accel = Tuning.steerAccel * authority;
    let drag = Tuning.snowDrag;
    if (ice) {
      accel *= Tuning.iceSteerScale;
      drag = Tuning.iceDrag;
    }
    if (r.airborne) {
      accel *= Tuning.airSteerScale;
      drag = Tuning.airDrag;
    }
    if (r.stunned > 0) accel *= Tuning.stunSteerScale;
    const sample = path.sample(r.progress);
    let pull = this.cornerPull(r, sample);
    if (ice) pull *= 1.4;
    r.lateralVel += (input * accel + pull) * dt;
    r.lateralVel *= Math.exp(-drag * dt);
    r.lateral += r.lateralVel * dt;
    const half = sample.width * 0.5 - 0.7;
    if (r.lateral > half) {
      r.lateral = half;
      if (r.lateralVel > 0.5) this.scrapeWall(i);
      r.lateralVel *= -0.3;
    } else if (r.lateral < -half) {
      r.lateral = -half;
      if (r.lateralVel < -0.5) this.scrapeWall(i);
      r.lateralVel *= -0.3;
    }
    r.roll = damp(r.roll, -input * 0.45 - r.lateralVel * 0.02, 8, dt);
    r.yaw = sample.heading;
  }

  /** Grinding along the wall bleeds speed for a moment after contact. */
  private scrapeWall(i: number): void {
    const r = this.racers[i];
    r.scrape = Tuning.wallScrapeTime;
    if (r.isPlayer && this.scrapeHaptic <= 0) {
      this.scrapeHaptic = 0.3;
      this.fx.tap('light');
    }
  }

  private integrateRacer(i: number, dt: number, path: TrackPath, level: LevelDefinition): void {
    const r = this.racers[i];
    r.stunned = Math.max(0, r.stunned - dt);
    r.invuln = Math.max(0, r.invuln - dt);
    r.ghostTime = Math.max(0, r.ghostTime - dt);
    r.magnetTime = Math.max(0, r.magnetTime - dt);
    r.rocketTime = Math.max(0, r.rocketTime - dt);
    r.flareTime = Math.max(0, r.flareTime - dt);
    r.bananaCooldown = Math.max(0, r.bananaCooldown - dt);
    r.trailBoost = Math.max(0, r.trailBoost - dt);
    r.boostTime = Math.max(0, r.boostTime - dt);
    r.scrape = Math.max(0, r.scrape - dt);
    r.squash = damp(r.squash, 1, 14, dt);

    const sample = path.sample(r.progress);
    let maxSpeed = 13.5 + sample.slope * 22;
    maxSpeed *= r.skill;
    const player = this.playerRacer;
    if (!r.isPlayer && player) maxSpeed *= this.rubberBand(r.progress - player.progress);
    if (r.rocketTime > 0) maxSpeed *= Tuning.rocketSpeedMultiplier;
    if (r.boostTime > 0) maxSpeed *= Tuning.boostSpeedMultiplier;
    if (r.stunned > 0) maxSpeed *= Tuning.stunSpeedFactor;
    if (r.scrape > 0) maxSpeed *= Tuning.wallScrapeSpeed;
    if (this.isOnIce(r)) maxSpeed *= 1.06;

    let accel = 10 + sample.slope * 16;
    if (r.airborne) accel *= 0.35;
    r.speed += accel * dt;
    r.speed = Math.min(r.speed, maxSpeed);

    // The inside of a bend is a shorter road: a sled hugging it covers the same stretch of track
    // with less distance. Positive curvature is a left turn and the inside is the left (negative
    // lateral), so curvature * lateral is negative on the inside line.
    const line = clamp(1 + sample.curvature * r.lateral, Tuning.lineFactorMin, Tuning.lineFactorMax);
    r.progress += (r.speed * dt) / (path.length * line);
    r.progress = Math.min(r.progress, 0.997);

    if (r.height > 0.04 || r.verticalVel > 0.1) {
      r.airborne = true;
      r.verticalVel -= 34 * dt;
      r.height += r.verticalVel * dt;
      if (r.height <= 0) {
        r.lateralVel *= 0.5;
        if (r.verticalVel < -5) {
          r.squash = 0.58;
          this.landingPulse = 1;
          if (r.isPlayer) this.fx.tap('medium');
        }
        r.height = 0;
        r.verticalVel = 0;
        r.airborne = false;
      }
    } else {
      r.airborne = false;
      r.height = 0;
    }
    r.pitch = damp(r.pitch, r.airborne ? r.verticalVel * 0.03 : sample.slope * 0.4, 6, dt);

    if (level.theme === 'summit') {
      for (const entity of this.entities) {
        if (entity.definition.kind !== 'wind') continue;
        if (Math.abs(entity.definition.progress - r.progress) < 0.05) {
          const gust = Math.sin(this.windPhase * 2.4 + entity.phase) * 10;
          r.lateralVel += gust * dt;
        }
      }
    }
  }

  /**
   * Keeps the pack together without stealing the win: a rival far ahead of the player eases off,
   * one far behind catches up. It blends smoothly, so nobody lurches at a threshold.
   */
  private rubberBand(lead: number): number {
    if (lead >= 0) return 1 - Tuning.bandSlow * smoothstep(0.02, 0.1, lead);
    return 1 + Tuning.bandCatchUp * smoothstep(0.02, 0.14, -lead);
  }

  private tryBoost(i: number, dt: number): void {
    const r = this.racers[i];
    if (!(r.turbo > 0.02) || r.stunned > 0) return;
    r.turbo = Math.max(0, r.turbo - Tuning.boostDrain * dt);
    r.speed += Tuning.boostPush * dt;
    r.trailBoost = 0.28;
    r.boostTime = Math.max(r.boostTime, Tuning.boostGrace);
    if (r.isPlayer && Math.trunc(this.raceTime * 8) % 8 === 0) this.fx.boost();
  }

  private decideAIBoost(i: number, dt: number): void {
    const r = this.racers[i];
    if (!(r.turbo > 0.08) || r.stunned > 0) return;
    let should: boolean;
    switch (r.personality) {
      case 'aggressive': {
        should = r.progress > 0.12 && r.turbo > 0.15;
        const player = this.playerRacer;
        if (player && player.progress > r.progress && player.progress - r.progress < 0.06) should = true;
        break;
      }
      case 'cautious':
        should = r.progress > 0.55 && this.isClearAhead(r);
        break;
      case 'hoarder':
        should = r.progress > 0.72 || r.rocketTime > 0;
        break;
      default:
        should = r.progress > 0.4;
    }
    if (should) this.tryBoost(i, dt);
  }

  private isClearAhead(racer: Racer): boolean {
    return !this.entities.some((entity) => {
      if (!CollisionClass.solidHazards.has(entity.definition.kind) || entity.destroyed) return false;
      if (!(entity.definition.radius > 0)) return false;
      const dp = entity.definition.progress - racer.progress;
      return dp > 0 && dp < 0.05 && Math.abs(entity.liveLateral - racer.lateral) < 2.4;
    });
  }

  private animateMovers(): void {
    const t = this.raceTime;
    for (const e of this.entities) {
      const kind = e.definition.kind;
      if (kind === 'cart' || kind === 'npc' || kind === 'movingBridge') {
        const amp = kind === 'movingBridge' ? 2.8 : kind === 'cart' ? 3.6 : 4.4;
        const rate = kind === 'movingBridge' ? 1.15 : 1.7;
        e.liveLateral = e.definition.lateral + Math.sin(t * rate + e.phase) * amp;
      } else {
        e.liveLateral = e.definition.lateral;
      }
    }
  }

  private resolveCollisions(i: number, path: TrackPath): void {
    const r = this.racers[i];
    if (r.invuln > 0 || r.stunned > 0) return;
    for (const entity of this.entities) {
      if (entity.destroyed || entity.collected) continue;
      const def = entity.definition;
      if (def.kind === 'water') {
        if (this.overlap(r, def.progress, entity.liveLateral, def.radius, path)) {
          this.drown(i);
          return;
        }
        continue;
      }
      if (!CollisionClass.solidHazards.has(def.kind) || !(def.radius > 0)) continue;
      if (this.overlap(r, def.progress, entity.liveLateral, def.radius, path)) {
        if (r.ghostTime > 0) {
          r.ghostTime = 0;
          entity.destroyed = def.kind === 'crate' || def.kind === 'snowman';
          if (r.isPlayer) this.toast('Phased!');
          continue;
        }
        this.smash(i);
        if (def.kind === 'crate') entity.destroyed = true;
        return;
      }
    }
    // A peel is used up by whoever slips on it.
    const peel = this.droppedBananas.find((b) => this.overlap(r, b.progress, b.lateral, b.radius, path));
    if (peel) {
      this.droppedBananas = this.droppedBananas.filter((b) => b.id !== peel.id);
      this.peelBorn.delete(peel.id);
      this.smash(i, 0.55);
      if (r.isPlayer) this.toast('Banana!');
      return;
    }
    for (let j = 0; j < this.racers.length; j += 1) {
      if (j === i) continue;
      const other = this.racers[j];
      const ds = (r.progress - other.progress) * path.length;
      const dl = r.lateral - other.lateral;
      if (ds * ds + dl * dl < 2.1) {
        r.lateralVel += (dl >= 0 ? 1 : -1) * 2.8;
        r.speed *= 0.97;
      }
    }
  }

  private collectPickups(i: number, path: TrackPath): void {
    const r = this.racers[i];
    const magnet = r.magnetTime > 0;
    for (const entity of this.entities) {
      if (entity.collected || entity.destroyed) continue;
      const def = entity.definition;
      if (!CollisionClass.pickups.has(def.kind)) continue;
      let radius = def.radius;
      if (magnet && def.kind === 'crystal') radius = 5.5;
      if (this.overlap(r, def.progress, entity.liveLateral, radius, path)) {
        entity.collected = true;
        this.applyPickup(i, def.kind);
      } else if (magnet && def.kind === 'crystal') {
        const dp = def.progress - r.progress;
        if (Math.abs(dp) < 0.05) {
          def.progress = damp(def.progress, r.progress, 8, 1 / 60);
          entity.liveLateral = damp(entity.liveLateral, r.lateral, 8, 1 / 60);
        }
      }
    }
  }

  private applyPickup(i: number, kind: PropKind): void {
    const r = this.racers[i];
    switch (kind) {
      case 'crystal':
        r.crystals += 1;
        r.turbo = Math.min(1, r.turbo + Tuning.crystalFuel);
        if (r.isPlayer) {
          this.fx.collect();
          this.bumpCombo('Crystal');
        }
        break;
      case 'rocket':
        r.rocketTime = 1.8;
        r.speed += 8;
        r.trailBoost = 1.8;
        r.boostTime = Math.max(r.boostTime, 1.8);
        if (r.isPlayer) {
          this.fx.power();
          this.toast('Rocket!');
        }
        break;
      case 'magnet':
        r.magnetTime = 6;
        if (r.isPlayer) {
          this.fx.power();
          this.toast('Magnet!');
        }
        break;
      case 'ghost':
        r.ghostTime = 4;
        if (r.isPlayer) {
          this.fx.power();
          this.toast('Ghost!');
        }
        break;
      case 'banana':
        r.bananaArmed = true;
        if (r.isPlayer) {
          this.fx.power();
          this.toast('Peel ready');
        }
        break;
      case 'flare':
        r.flareTime = 8;
        if (r.isPlayer) {
          this.fx.power();
          this.toast('Flare!');
        }
        break;
      default:
        break;
    }
  }

  private resolvePads(i: number, path: TrackPath): void {
    const r = this.racers[i];
    if (r.airborne && !(r.height < 0.4)) return;
    for (const e of this.entities) {
      if (!CollisionClass.pads.has(e.definition.kind)) continue;
      if (!this.overlap(r, e.definition.progress, e.liveLateral, e.definition.radius, path)) continue;
      if (e.definition.kind === 'ramp') {
        r.verticalVel = 14.8;
        r.height = Math.max(r.height, 0.22);
        r.speed += 5.5;
        r.trailBoost = 0.5;
        r.boostTime = Math.max(r.boostTime, 0.5);
        r.airborne = true;
        if (r.isPlayer) this.fx.whoosh();
      } else if (e.definition.kind === 'turboPad') {
        r.speed += 7.5;
        r.trailBoost = Math.max(r.trailBoost, Tuning.padBoostTime);
        r.boostTime = Math.max(r.boostTime, Tuning.padBoostTime);
        if (r.isPlayer) this.fx.boost();
      }
    }
  }

  private resolveCheckpoints(i: number): void {
    const level = this.level;
    if (!level) return;
    const r = this.racers[i];
    for (const cp of level.checkpoints) {
      if (!(cp > r.lastCheckpoint + 0.001)) continue;
      if (r.progress >= cp) {
        r.lastCheckpoint = cp;
        if (r.isPlayer && cp > 0) {
          this.toast('Checkpoint');
          this.fx.tap('light');
        }
      }
    }
  }

  // MARK: - Peels

  private dropBanana(index: number): void {
    const r = this.racers[index];
    if (!r.bananaArmed || r.bananaCooldown > 0) return;
    r.bananaArmed = false;
    r.bananaCooldown = 1.2;
    const peel: PlacedEntity = {
      id: stableId(90_000 + (this.level ? levelOrder(this.level.id) : 0), this.peelCounter),
      kind: 'banana',
      progress: Math.max(0.01, r.progress - 0.012),
      lateral: r.lateral,
      yaw: 0,
      scale: 1,
      radius: 1.1,
    };
    this.peelCounter += 1;
    this.droppedBananas = [...this.droppedBananas, peel];
    this.peelBorn.set(peel.id, this.raceTime);
    // The oldest peel makes room for a new one.
    while (this.droppedBananas.length > MAX_PEELS) {
      const old = this.droppedBananas[0];
      this.droppedBananas = this.droppedBananas.slice(1);
      this.peelBorn.delete(old.id);
    }
    if (r.isPlayer) this.toast('Peel dropped');
  }

  /** Peels that nobody slipped on fade after a while. */
  private updatePeels(): void {
    if (this.droppedBananas.length === 0) return;
    const expired = this.droppedBananas.filter(
      (b) => this.raceTime - (this.peelBorn.get(b.id) ?? this.raceTime) > PEEL_LIFETIME,
    );
    if (expired.length === 0) return;
    const ids = new Set(expired.map((b) => b.id));
    this.droppedBananas = this.droppedBananas.filter((b) => !ids.has(b.id));
    for (const id of ids) this.peelBorn.delete(id);
  }

  private smash(i: number, factor = Tuning.crashSpeedFactor): void {
    const r = this.racers[i];
    r.speed *= factor;
    r.stunned = Tuning.crashStun;
    r.invuln = Tuning.crashInvuln;
    r.squash = 0.7;
    r.lateralVel *= -0.6;
    r.hits += 1;
    if (r.isPlayer) {
      this.cameraShake = 1;
      this.fx.crash();
      this.toast('Oof!');
    }
  }

  /**
   * A splash puts the racer back on the track a little way behind the water (never behind their
   * last checkpoint), slowed and stunned. The lost ground is the sting: about three seconds.
   */
  private drown(i: number): void {
    const path = this.path;
    if (!path) return;
    const r = this.racers[i];
    const floor = Math.max(r.lastCheckpoint + 0.005, 0.012);
    r.progress = Math.max(floor, r.progress - Tuning.splashSetback / path.length);
    r.lateral = 0;
    r.lateralVel = 0;
    r.speed *= 0.45;
    r.height = 0.5;
    r.verticalVel = 0;
    r.invuln = 1.3;
    r.stunned = Tuning.crashStun;
    r.hits += 1;
    if (r.isPlayer) {
      this.cameraShake = 0.8;
      this.fx.crash();
      this.toast('Splash!');
    }
  }

  private overlap(racer: Racer, progress: number, lateral: number, radius: number, path: TrackPath): boolean {
    const ds = (racer.progress - progress) * path.length;
    const dl = racer.lateral - lateral;
    const dh = racer.height;
    const rad = radius + 0.7;
    return ds * ds + dl * dl + dh * dh * 0.35 < rad * rad;
  }

  /** Ice patches are drawn as stretched ellipses, and the grip test uses the same shape. */
  private isOnIce(racer: Racer): boolean {
    const length = this.path?.length;
    if (length === undefined) return false;
    for (const entity of this.entities) {
      if (entity.definition.kind !== 'icePatch') continue;
      const across = entity.definition.radius;
      const along = across * Tuning.icePatchStretch;
      const ds = (entity.definition.progress - racer.progress) * length;
      const dl = entity.liveLateral - racer.lateral;
      if ((ds * ds) / (along * along) + (dl * dl) / (across * across) < 1) return true;
    }
    return false;
  }

  rankedRacers(): Racer[] {
    return [...this.racers].sort((a, b) => {
      if (a.finished && b.finished) return (a.finishTime ?? 999) - (b.finishTime ?? 999);
      if (a.finished !== b.finished) return a.finished ? -1 : 1;
      return b.progress - a.progress;
    });
  }

  /**
   * Finish times in ranked order. Anyone still on the course gets an estimate from where they are
   * and how fast they are moving, so the standings always have gaps.
   */
  private finishTimes(ranked: Racer[]): number[] {
    const clock = this.raceTime + this.coastTime;
    const length = this.path?.length ?? 0;
    let previous = 0;
    return ranked.map((racer) => {
      let t: number;
      if (racer.finishTime !== null) {
        t = racer.finishTime;
      } else {
        const remaining = Math.max(0, 0.992 - racer.progress) * length;
        t = clock + remaining / Math.max(racer.speed, 8);
      }
      t = Math.max(t, previous + 0.01);
      previous = t;
      return t;
    });
  }

  private toast(text: string): void {
    this.toastText = text;
    this.toastTimer = 1.35;
  }

  private publishHUD(dt = 0, force = false): void {
    this.hudAccumulator += dt;
    if (!force && this.hudAccumulator < Tuning.hudInterval) return;
    this.hudAccumulator = 0;
    const ranked = this.rankedRacers();
    const playerPlace = ranked.findIndex((r) => r.isPlayer) + 1 || 1;
    const player = this.playerRacer;
    let digit: number | null;
    let go: boolean;
    if (this.phase === 'countdown') {
      digit = this.countdownDigit;
      go = false;
    } else if (this.toastText === 'GO!') {
      digit = 0;
      go = true;
    } else {
      digit = null;
      go = false;
    }
    let gap = -1;
    if (this.avalancheActive && player && this.path && !this.avalancheBuried.has(player.id)) {
      gap = Math.max(0, (player.progress - this.avalancheFront) * this.path.length);
    }
    const rivals = this.racers.filter((r) => !r.isPlayer);
    const level = this.level;
    const snap: HUDSnapshot = {
      place: playerPlace,
      fieldSize: this.racers.length,
      progress: player?.progress ?? 0,
      rivalProgress: rivals.map((r) => r.progress),
      crystals: player?.crystals ?? 0,
      crystalTotal: level ? crystalCount(level) : 0,
      turbo: player?.turbo ?? 0,
      time: this.raceTime,
      countdown: digit,
      goFlash: go,
      magnetActive: (player?.magnetTime ?? 0) > 0,
      ghostActive: (player?.ghostTime ?? 0) > 0,
      rocketActive: (player?.rocketTime ?? 0) > 0,
      bananaArmed: player?.bananaArmed ?? false,
      toast: this.toastText,
      checkpoints: level ? level.checkpoints.filter((c) => c > 0) : [],
      speedKph: Math.trunc((player?.speed ?? 0) * 4.2),
      levelName: level?.name ?? '',
      rewardedTurboUsed: this.rewardedTurboUsed,
      racing: this.phase === 'racing',
      combo: this.combo,
      nearMisses: this.nearMisses,
      flareActive: (player?.flareTime ?? 0) > 0,
      avalancheThreat: this.avalancheThreat,
      avalancheProgress: this.avalancheFront,
      comboFraction: this.combo > 0 ? saturate(this.comboTimer / COMBO_WINDOW) : 0,
      avalancheGap: gap,
      rivalColors: rivals.map((r) => r.sledColor),
      parTime: level?.parTime ?? 0,
      crystalGoal: level?.crystalStar ?? 0,
      courseNumber: (level ? levelOrder(level.id) : 0) + 1,
      ghostGap: this.ghostGapSeconds(),
    };
    this.hud = snap;
    this.onHUD?.(snap);
  }

  /** Seconds the best-run ghost is ahead of the player (positive) or behind (negative). */
  private ghostGapSeconds(): number | null {
    const pose = this.ghostPose;
    const player = this.playerRacer;
    if (this.phase !== 'racing' || !pose || !player || !this.path) return null;
    const metres = (pose.progress - player.progress) * this.path.length;
    return metres / Math.max(player.speed, 8);
  }

  private updateCamera(dt: number): void {
    const path = this.path;
    const player = this.playerRacer;
    if (!path || !player) return;
    const sample = path.sample(player.progress);
    const pos = path.worldPosition(player.progress, player.lateral, player.height);
    // Faster = lower, closer and wider, so speed reads on screen; boost punches the FOV.
    const rush = saturate((player.speed - 11) / 9);
    const boosting = player.trailBoost > 0 || player.rocketTime > 0;
    const back = (player.rocketTime > 0 ? 7.4 : 6.4) - rush * 0.7;
    const up = 3.15 - rush * 0.45;
    const desiredEye = add(sub(pos, scale(sample.tangent, back)), scale(sample.normal, up));
    const desiredLook = addScaled(addScaled(pos, sample.tangent, 9.5), sample.normal, 0.35);
    this.cameraEye = damp3(this.cameraEye, desiredEye, 7.5, dt);
    this.cameraLook = damp3(this.cameraLook, desiredLook, 9, dt);
    const targetFOV = 50 + rush * 6 + (boosting ? 9 : 0);
    this.cameraFOV = damp(this.cameraFOV, targetFOV, boosting ? 7 : 4, dt);
  }

  // MARK: - Combo and near misses

  private bumpCombo(reason: string): void {
    this.combo += 1;
    this.comboTimer = COMBO_WINDOW;
    this.comboMax = Math.max(this.comboMax, this.combo);
    if (this.combo >= 2) {
      const player = this.playerRacer;
      if (player) player.turbo = Math.min(1, player.turbo + Tuning.comboFuel);
      this.toast(`${reason} x${this.combo}`);
      this.fx.comboHit();
    }
  }

  private tickCombo(dt: number): void {
    if (!(this.comboTimer > 0)) return;
    this.comboTimer -= dt;
    if (this.comboTimer <= 0) this.combo = 0;
  }

  private detectNearMiss(i: number, path: TrackPath): void {
    const r = this.racers[i];
    for (const entity of this.entities) {
      if (entity.destroyed || entity.collected) continue;
      if (!CollisionClass.solidHazards.has(entity.definition.kind)) continue;
      // Scenery that shares a prop kind with a hazard has no radius and never counts.
      if (!(entity.definition.radius > 0)) continue;
      const ds = (r.progress - entity.definition.progress) * path.length;
      const dl = Math.abs(r.lateral - entity.liveLateral);
      const inner = entity.definition.radius + 0.65;
      const outer = entity.definition.radius + 2.2;
      if (ds > 0.12 && ds < 1.85 && dl > inner && dl < outer) {
        if (!this.nearMissed.has(entity.definition.id)) {
          this.nearMissed.add(entity.definition.id);
          this.nearMisses += 1;
          this.bumpCombo('Near miss');
        }
      }
    }
  }

  // MARK: - Avalanche

  /**
   * The wall launches when the player reaches the start of its zone and appears a short way
   * behind them. If it catches a racer it buries them once (a big loss of speed and a stun), then
   * runs on ahead until the end of the zone.
   */
  private updateAvalanche(dt: number, path: TrackPath): void {
    const event = this.avalancheEvent;
    const player = this.playerRacer;
    if (!event || !player) {
      this.avalancheThreat = false;
      return;
    }
    if (!this.avalancheActive && !this.avalancheSpent && player.progress >= event.start) {
      this.avalancheActive = true;
      this.avalancheFront = Math.max(0, player.progress - Tuning.avalancheHeadStart);
      this.cameraShake = Math.max(this.cameraShake, 0.8);
      this.toast('AVALANCHE!');
      this.fx.whoosh();
    }
    if (!this.avalancheActive) {
      this.avalancheThreat = false;
      return;
    }
    this.avalancheFront += event.magnitude * dt;
    if (this.avalancheFront >= event.end || player.finished) {
      this.avalancheActive = false;
      this.avalancheSpent = true;
      this.avalancheThreat = false;
      return;
    }
    this.avalancheThreat = true;
    for (const r of this.racers) {
      if (r.finished) continue;
      if (!(r.progress < this.avalancheFront) || this.avalancheBuried.has(r.id)) continue;
      this.avalancheBuried.add(r.id);
      r.speed *= 0.3;
      r.stunned = 1.0;
      r.invuln = 1.6;
      r.squash = 0.6;
      r.hits += 1;
      if (r.isPlayer) {
        this.cameraShake = 1;
        this.fx.crash();
        this.toast('Buried!');
      }
    }
    // Rumble builds as the wall closes in, so the danger registers without looking back.
    const gap = (player.progress - this.avalancheFront) * path.length;
    if (gap > 0 && gap < 30 && !this.avalancheBuried.has(player.id)) {
      const closeness = 1 - gap / 30;
      this.cameraShake = Math.max(this.cameraShake, closeness * 0.35);
      this.avalancheRumble -= dt;
      if (gap < 18 && this.avalancheRumble <= 0) {
        this.avalancheRumble = 0.35;
        this.fx.tap('light');
      }
    }
  }

  // MARK: - Shortcuts

  private resolveShortcuts(i: number, path: TrackPath, level: LevelDefinition): void {
    const r = this.racers[i];
    for (const entity of this.entities) {
      if (entity.definition.kind !== 'shortcut' || entity.collected) continue;
      if (!this.overlap(r, entity.definition.progress, entity.liveLateral, entity.definition.radius, path)) continue;
      if (this.usedShortcuts.has(entity.definition.id)) continue;
      this.usedShortcuts.add(entity.definition.id);
      const skip =
        level.events.find((e) => e.kind === 'shortcut' && Math.abs(e.start - entity.definition.progress) < 0.01)
          ?.magnitude ?? 0.028;
      r.progress = Math.min(0.97, r.progress + skip);
      r.speed += 4;
      this.toast('Shortcut!');
      this.bumpCombo('Cut');
      this.fx.whoosh();
    }
  }

  // MARK: - Ghost

  private recordGhost(i: number, dt: number): void {
    this.ghostClock += dt;
    if (this.ghostClock < Tuning.ghostInterval) return;
    this.ghostClock -= Tuning.ghostInterval;
    if (this.recordedGhost.length >= Tuning.ghostMaxSamples) return;
    const r = this.racers[i];
    // Rounded so a saved take stays small once it is encoded.
    this.recordedGhost.push({
      t: roundHalfAway(this.raceTime * 100) / 100,
      p: roundHalfAway(r.progress * 10_000) / 10_000,
      l: roundHalfAway(r.lateral * 20) / 20,
      h: roundHalfAway(r.height * 20) / 20,
    });
  }

  private playbackGhostPose(): void {
    const take = this.playbackGhost;
    if (!this.settings.showGhost || !take || take.samples.length === 0) {
      this.ghostPose = null;
      return;
    }
    const t = this.raceTime;
    const samples = take.samples;
    if (t <= samples[0].t) {
      const s = samples[0];
      this.ghostPose = { progress: s.p, lateral: s.l, height: s.h };
      return;
    }
    const last = samples[samples.length - 1];
    if (t >= last.t) {
      this.ghostPose = { progress: last.p, lateral: last.l, height: last.h };
      return;
    }
    let lo = 0;
    let hi = samples.length - 1;
    while (hi - lo > 1) {
      const mid = (lo + hi) >> 1;
      if (samples[mid].t <= t) lo = mid;
      else hi = mid;
    }
    const a = samples[lo];
    const b = samples[hi];
    const span = Math.max(0.001, b.t - a.t);
    const u = (t - a.t) / span;
    this.ghostPose = { progress: lerp(a.p, b.p, u), lateral: lerp(a.l, b.l, u), height: lerp(a.h, b.h, u) };
  }

  // MARK: - Tilt

  /**
   * Lean the phone to steer, added to whatever the finger is doing. A small dead zone keeps hand
   * tremor from steering, and full lock is reached at roughly 25 degrees.
   */
  private updateTilt(dt: number): void {
    const x = this.settings.tiltSteering && this.tiltReader ? this.tiltReader() : null;
    if (x === null) {
      this.tiltInput = 0;
      return;
    }
    const dead = 0.06;
    const magnitude = saturate((Math.abs(x) - dead) / (0.42 - dead));
    const target = x < 0 ? -magnitude : magnitude;
    this.tiltInput = damp(this.tiltInput, target, 14, dt);
  }
}
