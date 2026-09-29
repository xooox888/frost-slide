/**
 * What the game needs from the platform, behind small interfaces. Each service has a browser
 * implementation and, where it matters, a native one (Capacitor plugins on iOS). The rest of the
 * app only ever talks to these interfaces, and every call fails soft: a missing plugin, a denied
 * permission or an empty ad fill never blocks racing.
 */
import type { ReadonlySignal } from '@preact/signals';
import type { GameSettings } from '../core/models';

export type { HapticStyle } from '../engine/gameEngine';
import type { HapticStyle } from '../engine/gameEngine';

/** Short sound effects (the eight WAVs from the Swift app). */
export interface AudioService {
  /** Loads the sounds; safe to call more than once. */
  preload(): Promise<void>;
  /** Browsers keep audio muted until a touch; call from the first pointer event. */
  unlock(): void;
  play(name: SoundName, volume?: number): void;
  apply(settings: GameSettings): void;
}

export type SoundName = 'collect' | 'boost' | 'crash' | 'finish' | 'tick' | 'go' | 'whoosh' | 'power';

export interface HapticsService {
  impact(style: HapticStyle): void;
  success(): void;
  apply(settings: GameSettings): void;
}

/** Key-value storage for the save file. */
export interface StorageService {
  load(key: string): Promise<string | null>;
  save(key: string, value: string): Promise<void>;
}

/** AdMob: banners on the menus, a full-screen ad between screens, an opt-in rewarded refill. */
export interface AdsService {
  /** A rewarded video is loaded and can be offered. */
  readonly rewardedReady: ReadonlySignal<boolean>;
  /** Height in CSS pixels that a banner currently covers at the bottom of the screen. */
  readonly bannerHeight: ReadonlySignal<number>;
  /** The ad consent form must stay reachable (EEA and UK players): Settings shows a button. */
  readonly privacyOptionsRequired: ReadonlySignal<boolean>;
  /** Asks for consent and tracking permission if needed, then starts the ad SDK. */
  start(): Promise<void>;
  /** Shows or hides the menu banner. */
  setBannerVisible(visible: boolean): void;
  /** A full-screen ad, then `done` (right away if there is none to show). */
  showInterstitialThen(done: () => void): void;
  /** A rewarded video; `onReward` only if the viewer earns it, `onSkip` otherwise. */
  showRewarded(onReward: () => void, onSkip: () => void): void;
  /** Opens the ad consent form again. */
  showPrivacyOptions(): void;
}

export type StoreBusy = 'none' | 'buying' | 'restoring';

/** The "Remove Ads" in-app purchase. */
export interface StoreService {
  readonly adsRemoved: ReadonlySignal<boolean>;
  /** Localised price for the button, once the store has answered. */
  readonly price: ReadonlySignal<string | null>;
  readonly busy: ReadonlySignal<StoreBusy>;
  /** A short result for the settings card ("Purchase restored", ...). */
  readonly message: ReadonlySignal<string | null>;
  /** Whether purchases are possible here at all (false in a plain browser). */
  readonly available: boolean;
  start(): Promise<void>;
  purchase(): Promise<void>;
  restore(): Promise<void>;
}

export type AnalyticsEvent =
  | { name: 'Race.started'; course: number; daily: boolean }
  | {
      name: 'Race.finished';
      course: number;
      place: number;
      stars: number;
      perfect: boolean;
      seconds: number;
      crashes: number;
    }
  | { name: 'Race.abandoned'; course: number; progress: number }
  | { name: 'Daily.completed'; streak: number }
  | { name: 'Store.adsRemoved' };

/** Anonymous usage stats (TelemetryDeck), off until an app id is configured. */
export interface AnalyticsService {
  apply(settings: GameSettings): void;
  track(event: AnalyticsEvent): void;
}

/** Sideways lean of the phone, for tilt steering. */
export interface TiltService {
  /** Starts listening; asks for permission where the platform requires it. Resolves false if denied. */
  enable(): Promise<boolean>;
  disable(): void;
  /** Lean in g (-1...1, positive to the right), or null with no reading. */
  read(): number | null;
}

export interface Services {
  isNative: boolean;
  audio: AudioService;
  haptics: HapticsService;
  storage: StorageService;
  ads: AdsService;
  store: StoreService;
  analytics: AnalyticsService;
  tilt: TiltService;
  /** Reduce Motion (the OS accessibility setting). */
  reduceMotion: ReadonlySignal<boolean>;
  /** Called when the app goes to the background (calls, notification pulls, the app switcher). */
  onBackground(handler: () => void): void;
  /** The first screen has rendered: hide the native launch screen. */
  ready(): void;
}
