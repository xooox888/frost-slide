import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Overlay on a screen-sized clear view so the fill-scaled hero
            // cannot widen the ZStack and push the buttons off-screen.
            Color.clear
                .overlay(
                    Image("MenuHero")
                        .resizable()
                        .scaledToFill()
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            FrostTheme.night.opacity(0.15),
                            FrostTheme.iceDeep.opacity(0.28),
                            FrostTheme.night.opacity(0.72)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipped()
                .ignoresSafeArea()

            SnowfallOverlay(density: 36)

            VStack(spacing: 0) {
                Spacer()
                Image("BrandBadge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: reduceMotion ? 88 : 104, height: reduceMotion ? 88 : 104)
                    .shadow(color: FrostTheme.ice.opacity(0.45), radius: 16, y: 6)
                    .padding(.bottom, 10)
                VStack(spacing: 2) {
                    Text("FROST")
                        .font(.custom("AvenirNext-Heavy", size: 50))
                        .foregroundStyle(.white)
                        .shadow(color: FrostTheme.iceDeep.opacity(0.55), radius: 8, y: 3)
                    Text("SLIDE")
                        .font(.custom("AvenirNext-Heavy", size: 50))
                        .foregroundStyle(FrostTheme.ice)
                        .shadow(color: FrostTheme.ice.opacity(0.45), radius: 8, y: 3)
                    Text("Ice-crystal downhill racing")
                        .font(.custom("AvenirNext-DemiBold", size: 15))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.top, 6)
                }
                .padding(.bottom, 24)

                VStack(spacing: 12) {
                    FrostButton(title: "Race", icon: "flag.checkered", color: FrostTheme.berry) {
                        app.screen = .levelSelect
                    }
                    FrostButton(title: "Daily Challenge", icon: "calendar", color: FrostTheme.ochre, foreground: FrostTheme.ink) {
                        app.playDaily()
                    }
                    FrostButton(title: "Course Map", icon: "map.fill", color: FrostTheme.ice) {
                        app.screen = .levelSelect
                    }
                    FrostButton(title: "Settings", icon: "slider.horizontal.3", color: FrostTheme.inkSoft) {
                        app.screen = .settings
                    }
                }
                .padding(.horizontal, 28)

                Text("Swipe to steer  ·  Hold turbo to boost")
                    .font(FrostTheme.captionFont)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, 16)

                BannerAdView()
                    .padding(.top, 14)
                    .padding(.bottom, 8)
            }
        }
    }
}
