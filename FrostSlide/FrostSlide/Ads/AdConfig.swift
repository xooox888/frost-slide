import Foundation

/// Single place to swap Google test IDs for your production AdMob units.
///
/// 1. Create an app at https://apps.admob.com (iOS, bundle id `com.frostslide.FrostSlide`).
/// 2. Create Banner, Interstitial, and Rewarded ad units.
/// 3. Paste the real IDs below and set `useGoogleTestAds = false` before App Store review.
enum AdConfig {
    /// TODO: set to `false` and fill `production` before shipping live ads.
    static let useGoogleTestAds = true

    /// TODO: replace with your AdMob iOS app ID (`ca-app-pub-xxxxxxxx~yyyyyyyyyy`).
    static let productionAppID = "ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"
    /// TODO: replace with your banner / interstitial / rewarded unit IDs.
    static let productionBanner = "ca-app-pub-xxxxxxxxxxxxxxxx/bbbbbbbbbb"
    static let productionInterstitial = "ca-app-pub-xxxxxxxxxxxxxxxx/iiiiiiiiii"
    static let productionRewarded = "ca-app-pub-xxxxxxxxxxxxxxxx/rrrrrrrrrr"

    /// Official Google sample IDs — always safe in Simulator / debug.
    /// https://developers.google.com/admob/ios/test-ads
    private enum GoogleTest {
        static let appID = "ca-app-pub-3940256099942544~1458002511"
        static let banner = "ca-app-pub-3940256099942544/2934735716"
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"
    }

    static var appID: String { useGoogleTestAds ? GoogleTest.appID : productionAppID }
    static var bannerUnitID: String { useGoogleTestAds ? GoogleTest.banner : productionBanner }
    static var interstitialUnitID: String { useGoogleTestAds ? GoogleTest.interstitial : productionInterstitial }
    static var rewardedUnitID: String { useGoogleTestAds ? GoogleTest.rewarded : productionRewarded }

    /// TODO: host a real policy and replace this placeholder.
    static let privacyPolicyURL = URL(string: "https://example.com/frost-slide-privacy")!
}
