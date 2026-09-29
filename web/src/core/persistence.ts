/**
 * Save data: unlocked courses, best records, settings and the daily streak. A port of
 * `Core/GamePersistence.swift` with the same JSON shape (`frostslide.save.v1`).
 *
 * Storage is injected: the app saves through Capacitor Preferences on iOS and localStorage in a
 * browser; tests keep everything in memory.
 */
import {
  DEFAULT_SETTINGS,
  decodeRecord,
  decodeSettings,
  emptyRecord,
  isLevelID,
  isPerfect,
  nextLevel,
  type GameSettings,
  type LevelID,
  type LevelRecord,
  type RaceResult,
} from './models';
import {
  SKIN_INFO,
  SLED_SKINS,
  dailyStreakAfter,
  dateKey,
  decodeGhost,
  goalMet,
  isSledSkin,
  type GhostTake,
  type SledSkin,
} from './progression';

export const SAVE_KEY = 'frostslide.save.v1';

/** What a finished race changed, for the results screen. */
export interface RecordOutcome {
  previousBestTime: number | null;
  newBestTime: boolean;
  dailyMet: boolean;
  dailyStreak: number;
}

interface SaveBlob {
  unlocked: LevelID[];
  records: Partial<Record<LevelID, LevelRecord>>;
  settings: GameSettings;
  lastDailyKey: string;
  lastDailyWins: number;
  dailyStreak: number;
}

export interface PersistenceOptions {
  /** Called with the JSON to store whenever something changes. */
  save?: (json: string) => void;
  /** Debug builds honour the "unlock all courses" setting; release builds ignore it. */
  debug?: boolean;
  /** Clock, for tests. */
  now?: () => Date;
}

export class GamePersistence {
  unlocked: Set<LevelID>;
  records: Map<LevelID, LevelRecord>;
  settings: GameSettings;
  /** UTC date of the last daily the player actually completed (goal met). */
  lastDailyKey: string;
  /** Lifetime count of completed dailies. */
  lastDailyWins: number;
  /** Consecutive UTC days with a completed daily, as of `lastDailyKey`. */
  dailyStreak: number;
  /** Called after every change, so the UI can refresh. */
  onChange: (() => void) | null = null;

  private readonly saveFn: (json: string) => void;
  private readonly debug: boolean;
  private readonly now: () => Date;

  constructor(
    state: {
      unlocked?: Iterable<LevelID>;
      records?: Map<LevelID, LevelRecord>;
      settings?: GameSettings;
      lastDailyKey?: string;
      lastDailyWins?: number;
      dailyStreak?: number;
    } = {},
    options: PersistenceOptions = {},
  ) {
    this.unlocked = new Set(state.unlocked ?? ['villageDash']);
    this.records = state.records ?? new Map();
    this.settings = state.settings ?? { ...DEFAULT_SETTINGS };
    this.lastDailyKey = state.lastDailyKey ?? '';
    this.lastDailyWins = state.lastDailyWins ?? 0;
    this.dailyStreak = state.dailyStreak ?? 0;
    this.saveFn = options.save ?? (() => {});
    this.debug = options.debug ?? false;
    this.now = options.now ?? (() => new Date());
  }

  /** Reads a save written by this app or by the Swift app. Anything unreadable starts fresh. */
  static fromJSON(json: string | null, options: PersistenceOptions = {}): GamePersistence {
    if (!json) return new GamePersistence({}, options);
    let blob: Record<string, unknown>;
    try {
      const parsed: unknown = JSON.parse(json);
      if (!parsed || typeof parsed !== 'object') return new GamePersistence({}, options);
      blob = parsed as Record<string, unknown>;
    } catch {
      return new GamePersistence({}, options);
    }
    const unlocked = Array.isArray(blob.unlocked) ? blob.unlocked.filter(isLevelID) : ['villageDash' as LevelID];
    const records = new Map<LevelID, LevelRecord>();
    if (blob.records && typeof blob.records === 'object') {
      for (const [key, value] of Object.entries(blob.records as Record<string, unknown>)) {
        if (isLevelID(key)) records.set(key, decodeRecord(value, decodeGhost));
      }
    }
    const settings = decodeSettings(blob.settings, isSledSkin);
    if (!options.debug) settings.unlockAll = false;
    return new GamePersistence(
      {
        unlocked,
        records,
        settings,
        lastDailyKey: typeof blob.lastDailyKey === 'string' ? blob.lastDailyKey : '',
        lastDailyWins: typeof blob.lastDailyWins === 'number' ? blob.lastDailyWins : 0,
        dailyStreak: typeof blob.dailyStreak === 'number' ? blob.dailyStreak : 0,
      },
      options,
    );
  }

  toJSON(): string {
    const records: Partial<Record<LevelID, LevelRecord>> = {};
    for (const [key, value] of this.records) records[key] = value;
    const blob: SaveBlob = {
      unlocked: [...this.unlocked],
      records,
      settings: this.settings,
      lastDailyKey: this.lastDailyKey,
      lastDailyWins: this.lastDailyWins,
      dailyStreak: this.dailyStreak,
    };
    return JSON.stringify(blob);
  }

  get totalStars(): number {
    let sum = 0;
    for (const r of this.records.values()) sum += r.bestStars;
    return sum;
  }

  get totalRaces(): number {
    let sum = 0;
    for (const r of this.records.values()) sum += r.timesPlayed;
    return sum;
  }

  get dailyDoneToday(): boolean {
    return this.lastDailyKey === dateKey(this.now());
  }

  /** The streak the player can still extend today: it lapses if yesterday was missed. */
  get activeDailyStreak(): number {
    const now = this.now();
    const today = dateKey(now);
    const yesterday = dateKey(new Date(now.getTime() - 86_400_000));
    return this.lastDailyKey === today || this.lastDailyKey === yesterday ? this.dailyStreak : 0;
  }

  /** Next skin the player has not earned yet, with the stars still missing. */
  get nextSkinGoal(): { skin: SledSkin; starsToGo: number } | null {
    const stars = this.totalStars;
    const next = SLED_SKINS.find((s) => SKIN_INFO[s].starsRequired > stars);
    return next ? { skin: next, starsToGo: SKIN_INFO[next].starsRequired - stars } : null;
  }

  isSkinUnlocked(skin: SledSkin): boolean {
    return this.totalStars >= SKIN_INFO[skin].starsRequired;
  }

  newlyUnlockedSkin(starsBefore: number, starsAfter: number): SledSkin | null {
    return (
      SLED_SKINS.find((s) => SKIN_INFO[s].starsRequired > starsBefore && SKIN_INFO[s].starsRequired <= starsAfter) ??
      null
    );
  }

  isUnlocked(id: LevelID): boolean {
    if (this.debug && this.settings.unlockAll) return true;
    return id === 'villageDash' || this.unlocked.has(id);
  }

  record(result: RaceResult, ghost: GhostTake | null = null): RecordOutcome {
    this.unlocked.add(result.level);
    const next = nextLevel(result.level);
    if (next) this.unlocked.add(next);
    const rec = { ...(this.records.get(result.level) ?? emptyRecord()) };
    const previousBest = rec.bestTime < 9000 ? rec.bestTime : null;
    rec.timesPlayed += 1;
    rec.bestPlace = Math.min(rec.bestPlace, result.place);
    rec.bestStars = Math.max(rec.bestStars, result.stars);
    rec.bestCrystals = Math.max(rec.bestCrystals, result.crystals);
    if (isPerfect(result)) rec.perfect = true;
    const newBest = result.time < rec.bestTime;
    if (newBest) {
      rec.bestTime = result.time;
      if (ghost) rec.ghost = ghost;
    }
    this.records.set(result.level, rec);

    // A daily only counts when its own goal was met; a miss can be retried.
    let dailyMet = false;
    if (result.dailyGoal) {
      dailyMet = goalMet(result.dailyGoal, result);
      const now = this.now();
      const today = dateKey(now);
      if (dailyMet && this.lastDailyKey !== today) {
        this.dailyStreak = dailyStreakAfter(today, this.lastDailyKey, this.dailyStreak, now);
        this.lastDailyKey = today;
        this.lastDailyWins += 1;
      }
    }
    this.persist();
    return { previousBestTime: previousBest, newBestTime: newBest, dailyMet, dailyStreak: this.dailyStreak };
  }

  updateSettings(mutate: (settings: GameSettings) => void): void {
    const copy = { ...this.settings };
    mutate(copy);
    this.settings = copy;
    this.persist();
  }

  resetProgress(): void {
    this.unlocked = new Set(['villageDash']);
    this.records = new Map();
    this.lastDailyKey = '';
    this.lastDailyWins = 0;
    this.dailyStreak = 0;
    this.persist();
  }

  persist(): void {
    this.saveFn(this.toJSON());
    this.onChange?.();
  }
}
