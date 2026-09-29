/**
 * Browser implementations: what runs in `npm run dev`, in the end-to-end tests and anywhere the
 * native plugins are missing. There are no ads or purchases here; everything else works.
 */
import { signal, type ReadonlySignal } from '@preact/signals';
import type { GameSettings } from '../core/models';
import type { AdsService, HapticsService, HapticStyle, StorageService, StoreBusy, StoreService } from './services';

export class LocalStorageService implements StorageService {
  load(key: string): Promise<string | null> {
    try {
      return Promise.resolve(localStorage.getItem(key));
    } catch {
      return Promise.resolve(null);
    }
  }

  save(key: string, value: string): Promise<void> {
    try {
      localStorage.setItem(key, value);
    } catch {
      // Private browsing or a full quota: the race goes on, unsaved.
    }
    return Promise.resolve();
  }
}

/** `navigator.vibrate` where browsers allow it (not Safari); silent elsewhere. */
export class VibrationHaptics implements HapticsService {
  private enabled = true;
  private static readonly DURATION: Record<HapticStyle, number> = { light: 8, medium: 14, heavy: 24 };

  impact(style: HapticStyle): void {
    if (this.enabled) this.vibrate(VibrationHaptics.DURATION[style]);
  }

  success(): void {
    if (this.enabled) this.vibrate([12, 40, 18]);
  }

  apply(settings: GameSettings): void {
    this.enabled = settings.hapticsEnabled;
  }

  private vibrate(pattern: number | number[]): void {
    try {
      navigator.vibrate?.(pattern);
    } catch {
      // Not allowed before the first tap in some browsers.
    }
  }
}

export class NoAds implements AdsService {
  readonly rewardedReady = signal(false);
  readonly bannerHeight = signal(0);
  readonly privacyOptionsRequired = signal(false);

  start(): Promise<void> {
    return Promise.resolve();
  }

  setBannerVisible(): void {}

  showInterstitialThen(done: () => void): void {
    done();
  }

  showRewarded(_onReward: () => void, onSkip: () => void): void {
    onSkip();
  }

  showPrivacyOptions(): void {}
}

export class NoStore implements StoreService {
  readonly adsRemoved = signal(false);
  readonly price = signal<string | null>(null);
  readonly busy = signal<StoreBusy>('none');
  readonly message = signal<string | null>(null);
  readonly available = false;

  start(): Promise<void> {
    return Promise.resolve();
  }

  purchase(): Promise<void> {
    this.message.value = 'Purchases are available in the iPhone app.';
    return Promise.resolve();
  }

  restore(): Promise<void> {
    return this.purchase();
  }
}

/** Reduce Motion, following the OS setting as it changes. */
export function reduceMotionSignal(): ReadonlySignal<boolean> {
  const query = typeof matchMedia === 'function' ? matchMedia('(prefers-reduced-motion: reduce)') : null;
  const value = signal(query?.matches ?? false);
  query?.addEventListener('change', (event) => {
    value.value = event.matches;
  });
  return value;
}

/**
 * Tab hidden or window left: the same moments the Swift app pauses on (calls, notification
 * pulls, the app switcher).
 */
export function onPageBackground(handler: () => void): void {
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') handler();
  });
  window.addEventListener('blur', handler);
  window.addEventListener('pagehide', handler);
}
