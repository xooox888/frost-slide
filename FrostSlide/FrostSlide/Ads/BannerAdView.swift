import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Adaptive banner for menus only. Renders an empty reserved strip if ads fail, and nothing
/// at all once the player has bought "Remove Ads".
struct BannerAdView: View {
    @EnvironmentObject private var store: StoreManager

    var body: some View {
        if !store.adsRemoved {
            BannerAdRepresentable()
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(FrostTheme.ink.opacity(0.08))
                .accessibilityLabel("Advertisement")
        }
    }
}

private struct BannerAdRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        #if canImport(GoogleMobileAds)
        let host = UIView()
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.rootViewController = AdManager.presenter
        banner.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: host.centerYAnchor)
        ])
        banner.load(Request())
        context.coordinator.banner = banner
        return host
        #else
        return UIView()
        #endif
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        #if canImport(GoogleMobileAds)
        context.coordinator.banner?.rootViewController = AdManager.presenter
        #endif
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        #if canImport(GoogleMobileAds)
        var banner: BannerView?
        #endif
    }
}
