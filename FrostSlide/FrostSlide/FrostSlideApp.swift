import SwiftUI

@main
struct FrostSlideApp: App {
    @StateObject private var app = AppModel()
    @StateObject private var ads = AdManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(ads)
                .preferredColorScheme(.light)
                .statusBarHidden(true)
                .onAppear {
                    ads.start()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.scenePhase) private var scenePhase

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
        // A call, a notification pull or the app switcher must not leave a race running.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                app.pauseForInterruption()
            }
        }
    }
}
