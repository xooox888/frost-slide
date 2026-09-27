import SwiftUI

struct PauseView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.38).ignoresSafeArea()
            FrostCard {
                VStack(spacing: 16) {
                    Text("Paused")
                        .font(.custom("AvenirNext-Heavy", size: 32))
                        .foregroundStyle(FrostTheme.ink)
                    Text(app.engine.hud.levelName)
                        .font(FrostTheme.bodyFont)
                        .foregroundStyle(FrostTheme.inkSoft)
                    FrostButton(title: "Resume", icon: "play.fill", color: FrostTheme.ice) {
                        app.resume()
                    }
                    FrostButton(title: "Restart", icon: "arrow.counterclockwise", color: FrostTheme.ochre, foreground: FrostTheme.ink) {
                        app.restart()
                    }
                    FrostButton(title: "Course Map", icon: "map", color: FrostTheme.inkSoft) {
                        app.backToMap()
                    }
                    FrostButton(title: "Main Menu", icon: "house.fill", color: FrostTheme.berry) {
                        app.backToMenu()
                    }
                }
                .frame(maxWidth: 300)
            }
        }
    }
}
