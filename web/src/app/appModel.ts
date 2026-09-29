/**
 * App state and navigation. A port of `App/AppModel.swift`, with Preact signals instead of
 * `@Published`: components read `app.screen.value`, `app.hud.value` and friends and re-render when
 * they change. The save file is a plain object; `app.save` reads it and subscribes the caller to
 * `saveVersion`, which is bumped after every change.
 */
import { batch, computed, signal } from '@preact/signals';
import { level } from '../core/levelCatalog';
import {
  EMPTY_HUD,
  LEVEL_IDS,
  isPerfect,
  levelOrder,
  nextLevel,
  type GameSettings,
  type HUDSnapshot,
  type LevelID,
  type RaceResult,
} from '../core/models';
import { SAVE_KEY, type GamePersistence } from '../core/persistence';
import { pickDaily, type DailyGoal } from '../core/progression';
import { GameEngine, type EngineFx } from '../engine/gameEngine';
import type { Services } from '../platform/services';
import { engineFx } from './engineFx';

export type Screen = 'menu' | 'levelSelect' | 'settings' | 'playing' | 'results';

export class AppModel {
  readonly screen = signal<Screen>('menu');
  readonly selectedLevel = signal<LevelID>('villageDash');
  readonly lastResult = signal<RaceResult | null>(null);
  /** The latest HUD snapshot from the engine, about 30 per second while racing. */
  readonly hud = signal<HUDSnapshot>(EMPTY_HUD);
  readonly paused = signal(false);
  /** Bumped after every change to the save, so views that read it refresh. */
  readonly saveVersion = signal(0);
  readonly engine: GameEngine;
  /** Sounds and haptics; the results screen uses it for the star reveal. */
  readonly fx: EngineFx;
  /** Test hooks (the `?autopilot` bot): run before every engine tick, and ticks per frame. */
  readonly dev: { beforeTick: ((engine: GameEngine, dt: number) => void) | null; ticksPerFrame: number } = {
    beforeTick: null,
    ticksPerFrame: 1,
  };

  /** The course the menu's Race button starts. */
  readonly nextCourse = computed<LevelID>(() => {
    const save = this.save;
    const open = LEVEL_IDS.filter((id) => save.isUnlocked(id));
    const fresh = open.find((id) => !save.records.has(id));
    if (fresh) return fresh;
    const selected = this.selectedLevel.value;
    return open.includes(selected) ? selected : (open[0] ?? 'villageDash');
  });

  /** Today's daily: which open course and what it asks for. */
  readonly dailyPick = computed<{ level: LevelID; goal: DailyGoal }>(() => {
    const save = this.save;
    return pickDaily(LEVEL_IDS.filter((id) => save.isUnlocked(id)));
  });

  constructor(
    private readonly persistence: GamePersistence,
    readonly services: Services,
  ) {
    this.fx = engineFx(services);
    this.engine = new GameEngine(this.fx);
    this.engine.tiltReader = () => services.tilt.read();
    this.engine.onHUD = (hud) => {
      this.hud.value = hud;
    };
    this.engine.onFinished = (result) => this.handleFinished(result);
    persistence.onChange = () => {
      this.saveVersion.value += 1;
    };
    services.audio.apply(persistence.settings);
    services.haptics.apply(persistence.settings);
    services.analytics.apply(persistence.settings);
    if (persistence.settings.tiltSteering) void services.tilt.enable();
    services.onBackground(() => this.pauseForInterruption());
    // The app opens on the menu, which shows a banner; goTo only runs on later screen changes.
    // (The ad service remembers this until its SDK has started.)
    services.ads.setBannerVisible(true);
  }

  /** The save data. Reading it subscribes the calling component to changes. */
  get save(): GamePersistence {
    void this.saveVersion.value;
    return this.persistence;
  }

  get settings(): GameSettings {
    return this.save.settings;
  }

  // MARK: - Racing

  play(id: LevelID, dailyGoal: DailyGoal | null = null): void {
    if (!this.persistence.isUnlocked(id)) return;
    const ghost = this.persistence.settings.showGhost ? (this.persistence.records.get(id)?.ghost ?? null) : null;
    batch(() => {
      this.selectedLevel.value = id;
      this.lastResult.value = null;
      this.engine.steerInput = 0;
      this.engine.boostHeld = false;
      this.engine.start(level(id), { ...this.persistence.settings }, ghost, dailyGoal);
      this.paused.value = false;
      this.screen.value = 'playing';
    });
    this.services.ads.setBannerVisible(false);
    this.services.analytics.track({ name: 'Race.started', course: levelOrder(id) + 1, daily: dailyGoal !== null });
  }

  quickRace(): void {
    this.play(this.nextCourse.value);
  }

  playDaily(): void {
    const pick = this.dailyPick.value;
    this.play(pick.level, pick.goal);
  }

  pause(): void {
    this.engine.paused = true;
    this.paused.value = true;
    this.engine.boostHeld = false;
    this.engine.steerInput = 0;
  }

  resume(): void {
    this.engine.paused = false;
    this.paused.value = false;
  }

  /**
   * Calls, notification pulls, the app switcher: stop the race instead of letting it run
   * unattended, and let the player resume from the pause menu.
   */
  pauseForInterruption(): void {
    if (this.screen.value !== 'playing' || this.engine.paused) return;
    if (this.engine.phase === 'countdown' || this.engine.phase === 'racing') this.pause();
  }

  /** Restarts the current course; going through `play` means a rematch races the new ghost. */
  restart(): void {
    this.play(this.selectedLevel.value, this.engine.dailyGoal);
  }

  backToMap(): void {
    this.trackAbandonIfRacing();
    this.engine.stop();
    this.paused.value = false;
    this.goTo('levelSelect');
  }

  backToMenu(): void {
    this.trackAbandonIfRacing();
    this.engine.stop();
    this.paused.value = false;
    this.goTo('menu');
  }

  nextLevel(): void {
    const next = nextLevel(this.selectedLevel.value);
    if (next && this.persistence.isUnlocked(next)) this.play(next);
    else this.goTo('levelSelect');
  }

  /** Menus show a banner; racing and results never do. */
  goTo(screen: Screen): void {
    this.screen.value = screen;
    this.services.ads.setBannerVisible(screen === 'menu' || screen === 'levelSelect');
  }

  /** Interstitial only when leaving results: never mid-race, never on a rematch. */
  leaveResults(action: () => void): void {
    this.services.ads.showInterstitialThen(action);
  }

  /** The player asked for the rewarded video refill (once per race). */
  requestRewardedTurbo(): void {
    this.engine.paused = true;
    this.services.ads.showRewarded(
      () => {
        this.engine.grantRewardedTurbo();
        this.engine.paused = this.paused.value;
      },
      () => {
        this.engine.paused = this.paused.value;
      },
    );
  }

  // MARK: - Input from the race screen

  setSteer(value: number): void {
    this.engine.steerInput = value;
  }

  setBoost(held: boolean): void {
    this.engine.boostHeld = held;
  }

  dropPeel(): void {
    this.engine.dropBananaRequested = true;
  }

  // MARK: - Settings

  updateSettings(mutate: (settings: GameSettings) => void): void {
    const before = this.persistence.settings;
    this.persistence.updateSettings(mutate);
    const after = this.persistence.settings;
    this.services.audio.apply(after);
    this.services.haptics.apply(after);
    this.services.analytics.apply(after);
    if (after.tiltSteering && !before.tiltSteering) {
      // iOS asks for motion permission from a tap; if the player says no, the switch goes back.
      void this.services.tilt.enable().then((granted) => {
        if (!granted) this.persistence.updateSettings((s) => (s.tiltSteering = false));
      });
    } else if (!after.tiltSteering && before.tiltSteering) {
      this.services.tilt.disable();
    }
  }

  resetProgress(): void {
    this.persistence.resetProgress();
  }

  // MARK: - Results

  private trackAbandonIfRacing(): void {
    const phase = this.engine.phase;
    if (phase === 'countdown' || phase === 'racing') {
      this.services.analytics.track({
        name: 'Race.abandoned',
        course: levelOrder(this.selectedLevel.value) + 1,
        progress: Math.round(this.engine.hud.progress * 100),
      });
    }
  }

  private handleFinished(result: RaceResult): void {
    const store = this.persistence;
    const before = store.totalStars;
    const outcome = store.record(result, this.engine.capturedGhost());
    const finished: RaceResult = {
      ...result,
      unlockedSkin: store.newlyUnlockedSkin(before, store.totalStars),
      previousBest: outcome.previousBestTime,
      newBest: outcome.newBestTime,
      dailyMet: outcome.dailyMet,
      dailyStreak: outcome.dailyStreak,
    };
    batch(() => {
      this.lastResult.value = finished;
      this.paused.value = false;
      this.screen.value = 'results';
    });
    this.services.analytics.track({
      name: 'Race.finished',
      course: levelOrder(finished.level) + 1,
      place: finished.place,
      stars: finished.stars,
      perfect: isPerfect(finished),
      seconds: finished.time,
      crashes: finished.crashes,
    });
    if (finished.daily && finished.dailyMet) {
      this.services.analytics.track({ name: 'Daily.completed', streak: finished.dailyStreak });
    }
  }
}

export { SAVE_KEY };
