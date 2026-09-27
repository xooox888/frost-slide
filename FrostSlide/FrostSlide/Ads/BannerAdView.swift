import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Adaptive banner for menus only. Renders an empty reserved strip if ads fail.
struct BannerAdView: View {
    var body: some View {
        BannerAdRepresentable()
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(FrostTheme.ink.opacity(0.08))
            .accessibilityLabel("Advertisement")
    }
}

private struct BannerAdRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        #if canImport(GoogleMobileAds)
        let host = UIView()
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.rootViewController = AdManager.presenter
        banner.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: host.centerYAnchor)
        ])
        banner.load(GADRequest())
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
        var banner: GADBannerView?
        #endif
    }
}
