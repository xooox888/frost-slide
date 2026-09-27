import SwiftUI

@main
struct FrostSlideApp: App {
    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.light)
                .statusBarHidden(true)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            switch app.screen {
            case .menu:
                MainMenuView()
            case .levelSelect:
                LevelSelectView()
            case .settings:
                SettingsView()
            case .playing:
                GameContainerView()
            case .results:
                ResultsView()
            }
        }
        .animation(.easeInOut(duration: 0.28), value: app.screen)
    }
}
