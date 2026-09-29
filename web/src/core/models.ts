/**
 * Game data types and rules shared by the engine, the UI and saves. A port of
 * `Core/GameModels.swift`; names and numbers match the Swift app.
 */
import type { RGB } from './math';
import type { DailyGoal, GhostTake, SledSkin } from './progression';

export const LEVEL_IDS = [
  'villageDash',
  'marketMayhem',
  'alleySprint',
  'iceCaveSpiral',
  'crystalGrotto',
  'frozenHollow',
  'auroraNight',
  'polarVeil',
  'midnightRibbon',
  'harborFreeze',
  'driftwoodDocks',
  'tideGate',
  'summitRush',
  'glacierDrop',
  'icefallRun',
  'pineWhisper',
  'timberSwitchback',
  'owlHollow',
  'canyonGlow',
  'prismCut',
  'steamVeil',
  'whiteoutPeak',
  'neonSlalom',
  'carnivalParade',
] as const;

export type LevelID = (typeof LEVEL_IDS)[number];

export const isLevelID = (value: unknown): value is LevelID =>
  typeof value === 'string' && (LEVEL_IDS as readonly string[]).includes(value);

/** Position in the course list, 0 for the first course. */
export const levelOrder = (id: LevelID): number => LEVEL_IDS.indexOf(id);

export const nextLevel = (id: LevelID): LevelID | null => LEVEL_IDS[levelOrder(id) + 1] ?? null;

export type LevelTheme =
  | 'village'
  | 'market'
  | 'cave'
  | 'aurora'
  | 'harbor'
  | 'summit'
  | 'forest'
  | 'canyon'
  | 'steam'
  | 'blizzard'
  | 'neon'
  | 'carnival';

export type Personality = 'aggressive' | 'cautious' | 'hoarder';

export type PropKind =
  | 'building'
  | 'arch'
  | 'stall'
  | 'crateStack'
  | 'pine'
  | 'dock'
  | 'boat'
  | 'icicle'
  | 'auroraRibbon'
  | 'lantern'
  | 'chimney'
  | 'barrel'
  | 'lamp'
  | 'snowman'
  | 'crate'
  | 'icePatch'
  | 'cart'
  | 'bridge'
  | 'stalactite'
  | 'water'
  | 'wind'
  | 'npc'
  | 'crystal'
  | 'turboPad'
  | 'ramp'
  | 'rocket'
  | 'magnet'
  | 'ghost'
  | 'banana'
  | 'flare'
  | 'checkpoint'
  | 'finish'
  | 'startBanner'
  | 'avalanche'
  | 'shortcut'
  | 'movingBridge'
  | 'geyser'
  | 'carnivalFloat'
  | 'neonArch'
  | 'crystalSpire';

export type PowerUpType = 'rocket' | 'magnet' | 'ghost' | 'banana' | 'flare';

export const POWER_UP_TITLES: Record<PowerUpType, string> = {
  rocket: 'Rocket',
  magnet: 'Magnet',
  ghost: 'Ghost',
  banana: 'Peel',
  flare: 'Flare',
};

export interface CourseEvent {
  kind: 'avalanche' | 'shortcut';
  start: number;
  end: number;
  lateral: number;
  magnitude: number;
}

export type RacePhase = 'idle' | 'countdown' | 'racing' | 'finished';

export interface PlacedEntity {
  id: string;
  kind: PropKind;
  progress: number;
  lateral: number;
  yaw: number;
  scale: number;
  radius: number;
}

export interface RivalConfig {
  id: string;
  name: string;
  color: RGB;
  personality: Personality;
  skill: number;
  startLateral: number;
}

export interface CurveKey {
  start: number;
  end: number;
  yawRadians: number;
}

export interface WidthKey {
  at: number;
  width: number;
  span: number;
}

export interface ElevKey {
  at: number;
  height: number;
  span: number;
}

export interface LevelPalette {
  snow: RGB;
  ice: RGB;
  skyTop: RGB;
  skyBottom: RGB;
  fog: RGB;
  fogStart: number;
  fogEnd: number;
  ambient: RGB;
  sunColor: RGB;
  sunIntensity: number;
  wall: RGB;
  accent: RGB;
  wood: RGB;
  night: boolean;
}

export interface LevelDefinition {
  id: LevelID;
  name: string;
  subtitle: string;
  blurb: string;
  theme: LevelTheme;
  palette: LevelPalette;
  length: number;
  baseWidth: number;
  slope: number;
  startHeight: number;
  curves: CurveKey[];
  widths: WidthKey[];
  elevations: ElevKey[];
  entities: PlacedEntity[];
  rivals: RivalConfig[];
  checkpoints: number[];
  parTime: number;
  crystalTarget: number;
  crystalStar: number;
  events: CourseEvent[];
}

export const crystalCount = (level: LevelDefinition): number =>
  level.entities.filter((e) => e.kind === 'crystal').length;

// MARK: - Settings

export interface GameSettings {
  tiltSteering: boolean;
  unlockAll: boolean;
  hapticsEnabled: boolean;
  soundEnabled: boolean;
  showGhost: boolean;
  selectedSkin: SledSkin;
  /** Multiplies swipe distance before it becomes steering (1 = a 60 pt drag is full lock). */
  steerSensitivity: number;
  /** Anonymous usage stats. On by default; the player can turn it off. */
  shareUsageData: boolean;
}

export const STEER_SENSITIVITY_RANGE = { min: 0.6, max: 1.6 } as const;

export const DEFAULT_SETTINGS: GameSettings = {
  tiltSteering: false,
  unlockAll: false,
  hapticsEnabled: true,
  soundEnabled: true,
  showGhost: true,
  selectedSkin: 'cyan',
  steerSensitivity: 1,
  shareUsageData: true,
};

const boolOr = (v: unknown, fallback: boolean): boolean => (typeof v === 'boolean' ? v : fallback);
const numOr = (v: unknown, fallback: number): number => (typeof v === 'number' && Number.isFinite(v) ? v : fallback);

/** Reads settings from a save, filling anything missing (older saves) with the defaults. */
export function decodeSettings(raw: unknown, isSkin: (v: unknown) => v is SledSkin): GameSettings {
  const o = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const sens = numOr(o.steerSensitivity, 1);
  return {
    tiltSteering: boolOr(o.tiltSteering, false),
    unlockAll: boolOr(o.unlockAll, false),
    hapticsEnabled: boolOr(o.hapticsEnabled, true),
    soundEnabled: boolOr(o.soundEnabled, true),
    showGhost: boolOr(o.showGhost, true),
    selectedSkin: isSkin(o.selectedSkin) ? o.selectedSkin : 'cyan',
    steerSensitivity: Math.min(Math.max(sens, STEER_SENSITIVITY_RANGE.min), STEER_SENSITIVITY_RANGE.max),
    shareUsageData: boolOr(o.shareUsageData, true),
  };
}

// MARK: - Records

export interface LevelRecord {
  bestPlace: number;
  bestStars: number;
  bestTime: number;
  bestCrystals: number;
  timesPlayed: number;
  ghost: GhostTake | null;
  /** Every objective met in a single run: won, hit the crystal goal and beat par. */
  perfect: boolean;
}

export const emptyRecord = (): LevelRecord => ({
  bestPlace: 99,
  bestStars: 0,
  bestTime: 9999,
  bestCrystals: 0,
  timesPlayed: 0,
  ghost: null,
  perfect: false,
});

export function decodeRecord(raw: unknown, decodeGhost: (v: unknown) => GhostTake | null): LevelRecord {
  const o = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  return {
    bestPlace: numOr(o.bestPlace, 99),
    bestStars: numOr(o.bestStars, 0),
    bestTime: numOr(o.bestTime, 9999),
    bestCrystals: numOr(o.bestCrystals, 0),
    timesPlayed: numOr(o.timesPlayed, 0),
    ghost: o.ghost == null ? null : decodeGhost(o.ghost),
    perfect: boolOr(o.perfect, false),
  };
}

// MARK: - Stars

/**
 * How stars are earned, in one place so the engine, the results screen and the pre-race
 * briefing can never disagree.
 *
 * Finishing is worth 1 star. Bonus points add up: 1st place is 2, 2nd is 1, and the crystal goal
 * and par time are 1 each. Two bonus points make 3 stars; a fourth is a "perfect" run.
 */
export const StarRules = {
  points(place: number, crystals: number, crystalGoal: number, time: number, parTime: number): number {
    let points = 0;
    if (place === 1) points += 2;
    else if (place === 2) points += 1;
    if (crystals >= crystalGoal) points += 1;
    if (time <= parTime) points += 1;
    return points;
  },
  stars(points: number): number {
    return 1 + Math.min(2, Math.max(0, points));
  },
  perfectPoints: 4,
} as const;

export interface PodiumEntry {
  id: string;
  name: string;
  place: number;
  time: number | null;
  isPlayer: boolean;
  color: RGB;
}

export interface RaceResult {
  level: LevelID;
  place: number;
  fieldSize: number;
  time: number;
  crystals: number;
  crystalTotal: number;
  stars: number;
  podium: PodiumEntry[];
  comboMax: number;
  nearMisses: number;
  unlockedSkin: SledSkin | null;
  daily: boolean;
  // Goals the stars were judged against, so the results screen can show the breakdown.
  parTime: number;
  crystalGoal: number;
  crashes: number;
  /** Every racer, in finishing order. */
  standings: PodiumEntry[];
  // Filled in by the app once the save has been written.
  previousBest: number | null;
  newBest: boolean;
  dailyGoal: DailyGoal | null;
  dailyMet: boolean;
  dailyStreak: number;
}

export const beatPar = (r: RaceResult): boolean => r.time <= r.parTime;
export const hitCrystalGoal = (r: RaceResult): boolean => r.crystals >= r.crystalGoal;
export const resultPoints = (r: RaceResult): number =>
  StarRules.points(r.place, r.crystals, r.crystalGoal, r.time, r.parTime);
export const isPerfect = (r: RaceResult): boolean => resultPoints(r) >= StarRules.perfectPoints;

// MARK: - HUD

export interface HUDSnapshot {
  place: number;
  fieldSize: number;
  progress: number;
  rivalProgress: number[];
  crystals: number;
  crystalTotal: number;
  turbo: number;
  time: number;
  countdown: number | null;
  goFlash: boolean;
  magnetActive: boolean;
  ghostActive: boolean;
  rocketActive: boolean;
  bananaArmed: boolean;
  toast: string;
  checkpoints: number[];
  speedKph: number;
  levelName: string;
  rewardedTurboUsed: boolean;
  racing: boolean;
  combo: number;
  nearMisses: number;
  flareActive: boolean;
  avalancheThreat: boolean;
  avalancheProgress: number;
  /** Fraction of the combo window still open (1 = just chained, 0 = about to drop). */
  comboFraction: number;
  /** Metres between the avalanche wall and the player; negative when no wall is running. */
  avalancheGap: number;
  /** Sled colours, parallel to `rivalProgress`, so the progress rail can tell rivals apart. */
  rivalColors: RGB[];
  parTime: number;
  crystalGoal: number;
  courseNumber: number;
  /** Seconds ahead (negative) or behind (positive) the best-run ghost; null without a ghost. */
  ghostGap: number | null;
}

export const EMPTY_HUD: HUDSnapshot = {
  place: 1,
  fieldSize: 4,
  progress: 0,
  rivalProgress: [],
  crystals: 0,
  crystalTotal: 0,
  turbo: 0,
  time: 0,
  countdown: 3,
  goFlash: false,
  magnetActive: false,
  ghostActive: false,
  rocketActive: false,
  bananaArmed: false,
  toast: '',
  checkpoints: [0.25, 0.5, 0.75],
  speedKph: 0,
  levelName: '',
  rewardedTurboUsed: false,
  racing: false,
  combo: 0,
  nearMisses: 0,
  flareActive: false,
  avalancheThreat: false,
  avalancheProgress: 0,
  comboFraction: 0,
  avalancheGap: -1,
  rivalColors: [],
  parTime: 0,
  crystalGoal: 0,
  courseNumber: 0,
  ghostGap: null,
};
