import AppTrackingTransparency
import Combine
import Foundation
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Owns AdMob lifecycle. Every public call fails soft so a missing SDK or
/// empty fill never blocks racing.
@MainActor
final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    @Published private(set) var sdkReady = false
    @Published private(set) var rewardedReady = false
    @Published private(set) var lastError: String?

    #if canImport(GoogleMobileAds)
    private var interstitial: GADInterstitialAd?
    private var rewarded: GADRewardedAd?
    #endif

    private var started = false

    func start() {
        guard !started else { return }
        started = true
        requestTrackingThenInitialize()
    }

    func preload() {
        loadInterstitial()
        loadRewarded()
    }

    /// Full-screen ad after the player leaves the results screen.
    func showInterstitialThen(_ completion: @escaping () -> Void) {
        #if canImport(GoogleMobileAds)
        guard let ad = interstitial, let host = Self.presenter else {
            completion()
            loadInterstitial()
            return
        }
        interstitial = nil
        pendingAfterInterstitial = completion
        ad.fullScreenContentDelegate = self
        ad.present(fromRootViewController: host)
        #else
        completion()
        #endif
    }

    /// User-tapped rewarded refill. Calls `onReward` only if the viewer earns it.
    func showRewarded(onReward: @escaping () -> Void, onSkip: @escaping () -> Void = {}) {
        #if canImport(GoogleMobileAds)
        guard let ad = rewarded, let host = Self.presenter else {
            onSkip()
            loadRewarded()
            return
        }
        rewarded = nil
        rewardedReady = false
        ad.present(fromRootViewController: host) {
            onReward()
        }
        loadRewarded()
        #else
        onSkip()
        #endif
    }

    private var pendingAfterInterstitial: (() -> Void)?

    private func requestTrackingThenInitialize() {
        let boot = { [weak self] in
            self?.initializeSDK()
        }
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                Task { @MainActor in
                    boot()
                }
            }
        } else {
            boot()
        }
    }

    private func initializeSDK() {
        #if canImport(GoogleMobileAds)
        GADMobileAds.sharedInstance().start { [weak self] _ in
            Task { @MainActor in
                self?.sdkReady = true
                self?.preload()
            }
        }
        #else
        lastError = "GoogleMobileAds not linked"
        #endif
    }

    private func loadInterstitial() {
        #if canImport(GoogleMobileAds)
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: AdConfig.interstitialUnitID, request: request) { [weak self] ad, error in
            Task { @MainActor in
                if let error {
                    self?.lastError = error.localizedDescription
                    return
                }
                self?.interstitial = ad
                ad?.fullScreenContentDelegate = self
            }
        }
        #endif
    }

    private func loadRewarded() {
        #if canImport(GoogleMobileAds)
        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: AdConfig.rewardedUnitID, request: request) { [weak self] ad, error in
            Task { @MainActor in
                if let error {
                    self?.lastError = error.localizedDescription
                    self?.rewardedReady = false
                    return
                }
                self?.rewarded = ad
                self?.rewardedReady = ad != nil
            }
        }
        #endif
    }

    static var presenter: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

#if canImport(GoogleMobileAds)
extension AdManager: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            let done = pendingAfterInterstitial
            pendingAfterInterstitial = nil
            loadInterstitial()
            done?()
        }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            lastError = error.localizedDescription
            let done = pendingAfterInterstitial
            pendingAfterInterstitial = nil
            loadInterstitial()
            done?()
        }
    }
}
#endif
