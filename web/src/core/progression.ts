/**
 * Worlds, sled skins, ghost takes and the daily challenge. A port of `Core/Progression.swift`.
 */
import type { RGB } from './math';
import { LEVEL_IDS, levelOrder, type LevelID, type RaceResult, beatPar, hitCrystalGoal } from './models';

// MARK: - Worlds

export type CourseWorld =
  'villageMarket' | 'iceCaves' | 'aurora' | 'harbor' | 'summit' | 'forest' | 'canyonSteam' | 'spectacle';

/** Icon names used by the UI (see `ui/icons.tsx`). */
export type WorldIcon = 'lodge' | 'triangle' | 'sparkles' | 'sailboat' | 'mountain' | 'tree' | 'diamond' | 'party';

export interface WorldInfo {
  id: CourseWorld;
  title: string;
  blurb: string;
  courses: LevelID[];
  icon: WorldIcon;
}

export const WORLDS: readonly WorldInfo[] = [
  {
    id: 'villageMarket',
    title: 'Village & Market',
    blurb: 'Wide streets. Learn to carve.',
    courses: ['villageDash', 'marketMayhem', 'alleySprint'],
    icon: 'lodge',
  },
  {
    id: 'iceCaves',
    title: 'Ice Caves',
    blurb: 'Helix ice and tight walls.',
    courses: ['iceCaveSpiral', 'crystalGrotto', 'frozenHollow'],
    icon: 'triangle',
  },
  {
    id: 'aurora',
    title: 'Aurora Night',
    blurb: 'Night fog. Trust the glow.',
    courses: ['auroraNight', 'polarVeil', 'midnightRibbon'],
    icon: 'sparkles',
  },
  {
    id: 'harbor',
    title: 'Harbor',
    blurb: 'Planks, boats, black water.',
    courses: ['harborFreeze', 'driftwoodDocks', 'tideGate'],
    icon: 'sailboat',
  },
  {
    id: 'summit',
    title: 'Summit & Glacier',
    blurb: 'Steep faces and wind.',
    courses: ['summitRush', 'glacierDrop', 'icefallRun'],
    icon: 'mountain',
  },
  {
    id: 'forest',
    title: 'Frozen Forest',
    blurb: 'Pines, switchbacks, owls.',
    courses: ['pineWhisper', 'timberSwitchback', 'owlHollow'],
    icon: 'tree',
  },
  {
    id: 'canyonSteam',
    title: 'Canyon & Steam',
    blurb: 'Prisms, shards, mist.',
    courses: ['canyonGlow', 'prismCut', 'steamVeil'],
    icon: 'diamond',
  },
  {
    id: 'spectacle',
    title: 'Storm & Spectacle',
    blurb: 'Blizzard, neon, carnival.',
    courses: ['whiteoutPeak', 'neonSlalom', 'carnivalParade'],
    icon: 'party',
  },
];

export const worldOf = (id: LevelID): WorldInfo => WORLDS.find((w) => w.courses.includes(id)) ?? WORLDS[0];

// MARK: - Sled skins

export const SLED_SKINS = ['cyan', 'ember', 'forest', 'violet', 'gold', 'midnight', 'carnival', 'aurora'] as const;
export type SledSkin = (typeof SLED_SKINS)[number];

export const isSledSkin = (v: unknown): v is SledSkin =>
  typeof v === 'string' && (SLED_SKINS as readonly string[]).includes(v);

export const SKIN_INFO: Record<SledSkin, { title: string; starsRequired: number; color: RGB }> = {
  cyan: { title: 'Classic Cyan', starsRequired: 0, color: [0.12, 0.55, 1.0] },
  ember: { title: 'Ember', starsRequired: 6, color: [0.95, 0.28, 0.18] },
  forest: { title: 'Pine', starsRequired: 12, color: [0.18, 0.72, 0.38] },
  violet: { title: 'Royal', starsRequired: 18, color: [0.58, 0.32, 0.92] },
  gold: { title: 'Summit Gold', starsRequired: 27, color: [0.98, 0.78, 0.22] },
  midnight: { title: 'Midnight', starsRequired: 36, color: [0.16, 0.18, 0.34] },
  carnival: { title: 'Carnival', starsRequired: 48, color: [1.0, 0.35, 0.62] },
  aurora: { title: 'Aurora Fade', starsRequired: 60, color: [0.35, 0.95, 0.72] },
};

// MARK: - Ghosts

export interface GhostSample {
  t: number;
  p: number;
  l: number;
  h: number;
}

export interface GhostTake {
  time: number;
  samples: GhostSample[];
}

/**
 * A take is only worth replaying if it covers the run from the start. Takes saved by the first
 * Swift recorder kept just the last 22 seconds; those are ignored until they are beaten.
 */
export const isUsableGhost = (take: GhostTake | null | undefined): take is GhostTake =>
  !!take && take.samples.length > 8 && take.samples[0].t < 1.5;

export function decodeGhost(raw: unknown): GhostTake | null {
  if (!raw || typeof raw !== 'object') return null;
  const o = raw as Record<string, unknown>;
  if (typeof o.time !== 'number' || !Array.isArray(o.samples)) return null;
  const samples: GhostSample[] = [];
  for (const s of o.samples) {
    if (!s || typeof s !== 'object') return null;
    const { t, p, l, h } = s as Record<string, unknown>;
    if (typeof t !== 'number' || typeof p !== 'number' || typeof l !== 'number' || typeof h !== 'number') return null;
    samples.push({ t, p, l, h });
  }
  return { time: o.time, samples };
}

// MARK: - Daily challenge

/**
 * What today's run has to achieve. Every goal is judged from the race result, so the tag shown
 * on the menu is the rule that actually decides whether the day counts.
 */
export const DAILY_GOALS = ['beatPar', 'topTwo', 'crystalHunt', 'cleanRun'] as const;
export type DailyGoal = (typeof DAILY_GOALS)[number];

export const isDailyGoal = (v: unknown): v is DailyGoal =>
  typeof v === 'string' && (DAILY_GOALS as readonly string[]).includes(v);

export type GoalIcon = 'timer' | 'medal' | 'diamond' | 'seal';

export const GOAL_INFO: Record<DailyGoal, { title: string; icon: GoalIcon }> = {
  beatPar: { title: 'Beat par', icon: 'timer' },
  topTwo: { title: 'Top 2 finish', icon: 'medal' },
  crystalHunt: { title: 'Crystal hunt', icon: 'diamond' },
  cleanRun: { title: 'Clean run', icon: 'seal' },
};

/** One-line rule, with the course's own numbers filled in. */
export function goalDetail(goal: DailyGoal, parTime: number, crystalGoal: number): string {
  switch (goal) {
    case 'beatPar': {
      const whole = Math.round(parTime);
      return `Finish in under ${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, '0')}`;
    }
    case 'topTwo':
      return 'Finish 1st or 2nd';
    case 'crystalHunt':
      return `Collect ${crystalGoal} crystals`;
    case 'cleanRun':
      return 'Finish without a single crash';
  }
}

export function goalMet(goal: DailyGoal, result: RaceResult): boolean {
  switch (goal) {
    case 'beatPar':
      return beatPar(result);
    case 'topTwo':
      return result.place <= 2;
    case 'crystalHunt':
      return hitCrystalGoal(result);
    case 'cleanRun':
      return result.crashes === 0;
  }
}

/** The UTC calendar day, `yyyy-MM-dd`. */
export function dateKey(date: Date = new Date()): string {
  return date.toISOString().slice(0, 10);
}

/**
 * Today's course and goal, from a 64-bit FNV-style hash of the UTC date so every player gets
 * the same pick as the Swift app on the same day.
 */
export function pickDaily(unlocked: LevelID[], date: Date = new Date()): { level: LevelID; goal: DailyGoal } {
  const pool =
    unlocked.length === 0
      ? (['villageDash'] as LevelID[])
      : [...unlocked].sort((a, b) => levelOrder(a) - levelOrder(b));
  let hash = 2166136261n;
  for (const ch of dateKey(date)) {
    hash ^= BigInt(ch.charCodeAt(0));
    hash = BigInt.asUintN(64, hash * 16777619n);
  }
  const level = pool[Number(hash % BigInt(pool.length))];
  const goal = DAILY_GOALS[Number((hash / 7n) % BigInt(DAILY_GOALS.length))];
  return { level, goal };
}

/**
 * Streak after completing the daily on `today`: it continues only if the previous completion was
 * yesterday (UTC); anything older starts over at 1.
 */
export function dailyStreakAfter(
  today: string,
  lastCompleted: string,
  current: number,
  date: Date = new Date(),
): number {
  if (lastCompleted === today) return Math.max(1, current);
  const yesterday = dateKey(new Date(date.getTime() - 86_400_000));
  return lastCompleted === yesterday ? current + 1 : 1;
}

export const ALL_LEVELS: readonly LevelID[] = LEVEL_IDS;
