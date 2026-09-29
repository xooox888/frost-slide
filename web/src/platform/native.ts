/**
 * iOS implementations through Capacitor plugins. Ports of `Ads/AdManager.swift` and
 * `Store/StoreManager.swift`, plus native haptics and storage. Loaded only inside the native app.
 *
 * Every call fails soft: a missing plugin, a denied permission or an empty ad fill never blocks
 * racing. None of this can run in the Linux container this was written in; it is written against
 * the plugins' published APIs and gets its first real run on a Mac.
 */
import {
  AdMob,
  AdmobConsentStatus,
  BannerAdPluginEvents,
  BannerAdPosition,
  BannerAdSize,
  InterstitialAdPluginEvents,
  RewardAdPluginEvents,
} from '@capacitor-community/admob';
import { App } from '@capacitor/app';
import { Haptics, ImpactStyle, NotificationType } from '@capacitor/haptics';
import { Preferences } from '@capacitor/preferences';
import { SplashScreen } from '@capacitor/splash-screen';
import { StatusBar } from '@capacitor/status-bar';
import { NativePurchases, PURCHASE_TYPE, type Transaction } from '@capgo/native-purchases';
import { effect, signal, type ReadonlySignal } from '@preact/signals';
import type { GameSettings } from '../core/models';
import { REMOVE_ADS_PRODUCT_ID, adUnits, AD_CONFIG } from './config';
import type {
  AdsService,
  AnalyticsService,
  HapticsService,
  HapticStyle,
  StorageService,
  StoreBusy,
  StoreService,
} from './services';

/** UserDefaults through Capacitor Preferences: iOS never clears it, unlike web view storage. */
export class PreferencesStorage implements StorageService {
  async load(key: string): Promise<string | null> {
    try {
      return (await Preferences.get({ key })).value;
    } catch {
      return null;
    }
  }

  async save(key: string, value: string): Promise<void> {
    try {
      await Preferences.set({ key, value });
    } catch {
      // Nothing to do: the next save tries again.
    }
  }
}

export class NativeHaptics implements HapticsService {
  private enabled = true;
  private static readonly STYLE: Record<HapticStyle, ImpactStyle> = {
    light: ImpactStyle.Light,
    medium: ImpactStyle.Medium,
    heavy: ImpactStyle.Heavy,
  };

  impact(style: HapticStyle): void {
    if (this.enabled) Haptics.impact({ style: NativeHaptics.STYLE[style] }).catch(() => {});
  }

  success(): void {
    if (this.enabled) Haptics.notification({ type: NotificationType.Success }).catch(() => {});
  }

  apply(settings: GameSettings): void {
    this.enabled = settings.hapticsEnabled;
  }
}

/** Full screen, like the Swift app (the status bar is also hidden in Info.plist for launch). */
export function hideStatusBar(): void {
  StatusBar.hide().catch(() => {});
}

export function hideSplash(): void {
  SplashScreen.hide({ fadeOutDuration: 200 }).catch(() => {});
}

/** Calls, notification pulls and the app switcher all make the app inactive. */
export function onAppInactive(handler: () => void): void {
  App.addListener('appStateChange', ({ isActive }) => {
    if (!isActive) handler();
  }).catch(() => {});
}

// MARK: - Ads

type BannerState = 'none' | 'shown' | 'hidden';

export class AdMobAds implements AdsService {
  readonly rewardedReady = signal(false);
  readonly bannerHeight = signal(0);
  readonly privacyOptionsRequired = signal(false);

  private started = false;
  private ready = false;
  private interstitialReady = false;
  private loadingInterstitial = false;
  private loadingRewarded = false;
  private bannerWanted = false;
  private banner: BannerState = 'none';
  private afterInterstitial: (() => void) | null = null;
  private reward: { onReward: () => void; onSkip: () => void; earned: boolean } | null = null;

  constructor(private readonly adsRemoved: ReadonlySignal<boolean>) {
    effect(() => {
      if (this.adsRemoved.value) this.removeBanner();
    });
  }

  async start(): Promise<void> {
    if (this.started) return;
    this.started = true;
    try {
      await AdMob.initialize({ initializeForTesting: AD_CONFIG.useTestAds });
      await this.listen();
      await this.askConsent();
      this.ready = true;
      this.loadInterstitial();
      this.loadRewarded();
      if (this.bannerWanted) this.setBannerVisible(true);
    } catch {
      // No ads this session; racing is unaffected.
    }
  }

  setBannerVisible(visible: boolean): void {
    this.bannerWanted = visible;
    if (!this.ready) return;
    if (visible && !this.adsRemoved.value) {
      if (this.banner === 'none') {
        this.banner = 'shown';
        AdMob.showBanner({
          adId: adUnits().banner,
          adSize: BannerAdSize.ADAPTIVE_BANNER,
          position: BannerAdPosition.BOTTOM_CENTER,
          margin: 0,
        }).catch(() => {
          this.banner = 'none';
        });
      } else if (this.banner === 'hidden') {
        this.banner = 'shown';
        AdMob.resumeBanner().catch(() => {});
      }
    } else if (!visible && this.banner === 'shown') {
      this.banner = 'hidden';
      this.bannerHeight.value = 0;
      AdMob.hideBanner().catch(() => {});
    }
  }

  showInterstitialThen(done: () => void): void {
    if (this.adsRemoved.value || !this.ready || !this.interstitialReady || this.afterInterstitial) {
      done();
      this.loadInterstitial();
      return;
    }
    this.interstitialReady = false;
    this.afterInterstitial = done;
    AdMob.showInterstitial().catch(() => this.finishInterstitial());
  }

  showRewarded(onReward: () => void, onSkip: () => void): void {
    if (!this.ready || !this.rewardedReady.value || this.reward) {
      onSkip();
      this.loadRewarded();
      return;
    }
    this.rewardedReady.value = false;
    this.reward = { onReward, onSkip, earned: false };
    // The promise only settles when the reward is earned; the outcome is decided on dismissal
    // so the race resumes after the ad has closed, not behind it.
    AdMob.showRewardVideoAd().catch(() => this.finishRewarded());
  }

  showPrivacyOptions(): void {
    AdMob.showPrivacyOptionsForm().catch(() => {});
  }

  private async listen(): Promise<void> {
    await AdMob.addListener(BannerAdPluginEvents.SizeChanged, (size) => {
      this.bannerHeight.value = this.banner === 'shown' ? size.height : 0;
    });
    await AdMob.addListener(BannerAdPluginEvents.FailedToLoad, () => {
      this.bannerHeight.value = 0;
    });
    await AdMob.addListener(InterstitialAdPluginEvents.Dismissed, () => this.finishInterstitial());
    await AdMob.addListener(InterstitialAdPluginEvents.FailedToShow, () => this.finishInterstitial());
    await AdMob.addListener(RewardAdPluginEvents.Rewarded, () => {
      if (this.reward) this.reward.earned = true;
    });
    await AdMob.addListener(RewardAdPluginEvents.Dismissed, () => this.finishRewarded());
    await AdMob.addListener(RewardAdPluginEvents.FailedToShow, () => this.finishRewarded());
  }

  /**
   * The EEA and UK consent form (Google's User Messaging Platform) when it applies, then the
   * iOS tracking prompt. Both are skipped once answered.
   */
  private async askConsent(): Promise<void> {
    try {
      let consent = await AdMob.requestConsentInfo();
      if (consent.isConsentFormAvailable && consent.status === AdmobConsentStatus.REQUIRED) {
        consent = await AdMob.showConsentForm();
      }
      // The plugin doesn't export this enum; its values are plain strings.
      this.privacyOptionsRequired.value = String(consent.privacyOptionsRequirementStatus) === 'REQUIRED';
    } catch {
      // Consent is best effort; ads fall back to non-personalised.
    }
    try {
      const { status } = await AdMob.trackingAuthorizationStatus();
      if (status === 'notDetermined') await AdMob.requestTrackingAuthorization();
    } catch {
      // The prompt is optional; ads work without it.
    }
  }

  private finishInterstitial(): void {
    const done = this.afterInterstitial;
    this.afterInterstitial = null;
    this.loadInterstitial();
    done?.();
  }

  private finishRewarded(): void {
    const reward = this.reward;
    this.reward = null;
    this.loadRewarded();
    if (!reward) return;
    if (reward.earned) reward.onReward();
    else reward.onSkip();
  }

  private loadInterstitial(): void {
    if (!this.ready || this.adsRemoved.value || this.interstitialReady || this.loadingInterstitial) return;
    this.loadingInterstitial = true;
    AdMob.prepareInterstitial({ adId: adUnits().interstitial })
      .then(() => {
        this.interstitialReady = true;
      })
      .catch(() => {})
      .finally(() => {
        this.loadingInterstitial = false;
      });
  }

  private loadRewarded(): void {
    if (!this.ready || this.rewardedReady.value || this.loadingRewarded) return;
    this.loadingRewarded = true;
    AdMob.prepareRewardVideoAd({ adId: adUnits().rewarded })
      .then(() => {
        this.rewardedReady.value = true;
      })
      .catch(() => {
        this.rewardedReady.value = false;
      })
      .finally(() => {
        this.loadingRewarded = false;
      });
  }

  private removeBanner(): void {
    if (this.banner === 'none') return;
    this.banner = 'none';
    this.bannerHeight.value = 0;
    AdMob.removeBanner().catch(() => {});
  }
}

// MARK: - Store

const ADS_REMOVED_KEY = 'frostslide.adsRemoved';

const errorText = (error: unknown): string => (error instanceof Error ? error.message : String(error));

/**
 * The one purchase: a non-consumable "Remove Ads" that switches off the menu banners and the
 * full-screen ads between screens. The optional rewarded refill stays, because the player asks
 * for it.
 */
export class NativeStore implements StoreService {
  readonly adsRemoved = signal(false);
  readonly price = signal<string | null>(null);
  readonly busy = signal<StoreBusy>('none');
  readonly message = signal<string | null>(null);
  readonly available = true;

  private started = false;
  private hasProduct = false;

  constructor(
    private readonly storage: StorageService,
    private readonly analytics: AnalyticsService,
  ) {}

  /** Cached between launches so a paying player never sees an ad flash up while StoreKit starts. */
  async restoreCachedState(): Promise<void> {
    this.adsRemoved.value = (await this.storage.load(ADS_REMOVED_KEY)) === 'true';
  }

  /**
   * Listens for transactions made elsewhere (Ask to Buy approvals, refunds), then loads the
   * product and checks what the player already owns.
   */
  async start(): Promise<void> {
    if (this.started) return;
    this.started = true;
    try {
      await NativePurchases.addListener('transactionUpdated', (transaction) => this.handle(transaction));
    } catch {
      // Purchases made on another device still arrive through the entitlement check below.
    }
    await this.loadProduct();
    await this.refreshEntitlements();
  }

  async purchase(): Promise<void> {
    if (this.busy.value !== 'none') return;
    if (!this.hasProduct) await this.loadProduct();
    if (!this.hasProduct) {
      this.message.value = "The App Store isn't available right now. Please try again in a moment.";
      return;
    }
    this.busy.value = 'buying';
    this.message.value = null;
    try {
      const transaction = await NativePurchases.purchaseProduct({
        productIdentifier: REMOVE_ADS_PRODUCT_ID,
        productType: PURCHASE_TYPE.INAPP,
      });
      this.handle(transaction);
      if (this.adsRemoved.value) {
        this.message.value = 'Thank you! Ads are removed.';
        this.analytics.track({ name: 'Store.adsRemoved' });
      } else {
        this.message.value = "The purchase couldn't be verified.";
      }
    } catch (error) {
      const text = errorText(error);
      if (/pending/i.test(text)) {
        this.message.value = 'Waiting for approval. Ads go away once the purchase is approved.';
      } else if (!/cancel/i.test(text)) {
        this.message.value = "The purchase didn't go through. Please try again.";
      }
    } finally {
      this.busy.value = 'none';
    }
  }

  /** Asks the App Store for the player's purchases again (required for apps with purchases). */
  async restore(): Promise<void> {
    if (this.busy.value !== 'none') return;
    this.busy.value = 'restoring';
    this.message.value = null;
    try {
      await NativePurchases.restorePurchases();
      await this.refreshEntitlements();
      this.message.value = this.adsRemoved.value
        ? 'Purchase restored. Ads are removed.'
        : 'No earlier purchase was found for this Apple ID.';
    } catch (error) {
      if (!/cancel/i.test(errorText(error))) this.message.value = "Couldn't reach the App Store. Please try again.";
    } finally {
      this.busy.value = 'none';
    }
  }

  private async loadProduct(): Promise<void> {
    try {
      const { products } = await NativePurchases.getProducts({
        productIdentifiers: [REMOVE_ADS_PRODUCT_ID],
        productType: PURCHASE_TYPE.INAPP,
      });
      const product = products.find((p) => p.identifier === REMOVE_ADS_PRODUCT_ID);
      this.hasProduct = product !== undefined;
      this.price.value = product?.priceString ?? null;
    } catch {
      this.hasProduct = false;
      this.price.value = null;
    }
  }

  /**
   * Only ever switches ads off: a refund arrives as a revoked transaction through `handle`, so an
   * offline launch can't wrongly bring the ads back for someone who paid.
   */
  private async refreshEntitlements(): Promise<void> {
    try {
      const { purchases } = await NativePurchases.getPurchases({
        productType: PURCHASE_TYPE.INAPP,
        onlyCurrentEntitlements: true,
      });
      if (purchases.some((t) => t.productIdentifier === REMOVE_ADS_PRODUCT_ID && !t.revocationDate)) {
        this.setAdsRemoved(true);
      }
    } catch {
      // Offline: keep the cached state.
    }
  }

  private handle(transaction: Transaction): void {
    if (transaction.productIdentifier === REMOVE_ADS_PRODUCT_ID) this.setAdsRemoved(!transaction.revocationDate);
  }

  private setAdsRemoved(removed: boolean): void {
    if (removed === this.adsRemoved.value) return;
    this.adsRemoved.value = removed;
    void this.storage.save(ADS_REMOVED_KEY, removed ? 'true' : 'false');
  }
}
