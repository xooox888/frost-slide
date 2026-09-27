import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            Image("KeyArt")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            FrostTheme.iceDeep.opacity(0.35),
                            FrostTheme.ink.opacity(0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            SnowfallOverlay(density: 36)

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 6) {
                    Text("FROST")
                        .font(.custom("AvenirNext-Heavy", size: 52))
                        .foregroundStyle(.white)
                        .shadow(color: FrostTheme.iceDeep.opacity(0.45), radius: 8, y: 3)
                    Text("SLIDE")
                        .font(.custom("AvenirNext-Heavy", size: 52))
                        .foregroundStyle(FrostTheme.ice)
                        .shadow(color: FrostTheme.iceDeep.opacity(0.5), radius: 8, y: 3)
                    Text("Downhill disc racing")
                        .font(.custom("AvenirNext-DemiBold", size: 16))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.top, 4)
                }
                .padding(.bottom, 28)

                VStack(spacing: 12) {
                    FrostButton(title: "Race", icon: "flag.checkered", color: FrostTheme.berry) {
                        app.screen = .levelSelect
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
                    .padding(.top, 22)
                    .padding(.bottom, 36)
            }
        }
    }
}
