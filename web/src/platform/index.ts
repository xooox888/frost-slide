/**
 * Builds the platform services: Capacitor plugins inside the iOS app, browser fallbacks
 * everywhere else. The native module is loaded only on iOS, so the browser build never pulls in
 * the ad or purchase plugins.
 */
import { Capacitor } from '@capacitor/core';
import { TelemetryDeckAnalytics } from './analytics';
import type { Services } from './services';
import { OrientationTilt } from './tilt';
import { LocalStorageService, NoAds, NoStore, VibrationHaptics, onPageBackground, reduceMotionSignal } from './web';
import { WebAudioService } from './webAudio';

export async function createServices(): Promise<Services> {
  const audio = new WebAudioService();
  const tilt = new OrientationTilt();
  const reduceMotion = reduceMotionSignal();
  // Signals from development builds land in TelemetryDeck's test mode.
  const testMode = import.meta.env.DEV;

  if (Capacitor.isNativePlatform()) {
    const native = await import('./native');
    const storage = new native.PreferencesStorage();
    const analytics = new TelemetryDeckAnalytics(storage, testMode);
    const store = new native.NativeStore(storage, analytics);
    await store.restoreCachedState();
    native.hideStatusBar();
    return {
      isNative: true,
      audio,
      haptics: new native.NativeHaptics(),
      storage,
      ads: new native.AdMobAds(store.adsRemoved),
      store,
      analytics,
      tilt,
      reduceMotion,
      onBackground: native.onAppInactive,
      ready: native.hideSplash,
    };
  }

  const storage = new LocalStorageService();
  return {
    isNative: false,
    audio,
    haptics: new VibrationHaptics(),
    storage,
    ads: new NoAds(),
    store: new NoStore(),
    analytics: new TelemetryDeckAnalytics(storage, testMode),
    tilt,
    reduceMotion,
    onBackground: onPageBackground,
    ready: () => {},
  };
}
