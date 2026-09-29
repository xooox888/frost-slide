/**
 * Every id the app needs from outside services, in one place. Ports of `Ads/AdConfig.swift`,
 * `Analytics/AnalyticsConfig.swift` and the product id in `Store/StoreManager.swift`.
 */

export const AD_CONFIG = {
  /**
   * TODO: set to `false` and fill in the production ids before App Store review.
   *
   * 1. Create an app at https://apps.admob.com (iOS, bundle id `com.frostslide.FrostSlide`).
   * 2. Create Banner, Interstitial and Rewarded ad units.
   * 3. Paste the ids below. The app id also goes into `ios/App/App/Info.plist`
   *    (`GADApplicationIdentifier`).
   */
  useTestAds: true,
  production: {
    banner: 'ca-app-pub-xxxxxxxxxxxxxxxx/bbbbbbbbbb',
    interstitial: 'ca-app-pub-xxxxxxxxxxxxxxxx/iiiiiiiiii',
    rewarded: 'ca-app-pub-xxxxxxxxxxxxxxxx/rrrrrrrrrr',
  },
  /** Google's sample ids, always safe in the simulator and in debug builds. */
  test: {
    banner: 'ca-app-pub-3940256099942544/2934735716',
    interstitial: 'ca-app-pub-3940256099942544/4411468910',
    rewarded: 'ca-app-pub-3940256099942544/1712485313',
  },
};

export function adUnits(): { banner: string; interstitial: string; rewarded: string } {
  return AD_CONFIG.useTestAds ? AD_CONFIG.test : AD_CONFIG.production;
}

/** TODO: host a real policy and replace this placeholder (also used in App Store Connect). */
export const PRIVACY_POLICY_URL = 'https://example.com/frost-slide-privacy';

/** Create a non-consumable in-app purchase with this product id in App Store Connect. */
export const REMOVE_ADS_PRODUCT_ID = 'com.frostslide.FrostSlide.removeads';

export const ANALYTICS_CONFIG = {
  /**
   * TODO: replace with your TelemetryDeck App ID (a UUID). Until you do, analytics stays off.
   *
   * 1. Create an app at https://dashboard.telemetrydeck.com.
   * 2. Paste its App ID here.
   * 3. Update the App Privacy answers in App Store Connect: usage data (product interaction)
   *    and a device identifier, both for analytics only, neither linked to the player.
   */
  appID: 'YOUR-TELEMETRYDECK-APP-ID',
};

export const analyticsConfigured = (): boolean => !ANALYTICS_CONFIG.appID.startsWith('YOUR-');
