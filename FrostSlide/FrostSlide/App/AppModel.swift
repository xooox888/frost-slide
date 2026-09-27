import SwiftUI

enum AppScreen: Equatable {
    case menu
    case levelSelect
    case settings
    case playing
    case results
}

@MainActor
final class AppModel: ObservableObject {
    @Published var screen: AppScreen = .menu
    @Published var selectedLevel: LevelID = .villageDash
    @Published var lastResult: RaceResult?
    @Published var persistence: GamePersistence

    let engine = GameEngine()

    init(persistence: GamePersistence = .load()) {
        self.persistence = persistence
        AudioHaptics.shared.apply(settings: persistence.settings)
        engine.onFinished = { [weak self] result in
            Task { @MainActor in
                self?.handleFinished(result)
            }
        }
    }

    func play(_ id: LevelID, daily: Bool = false) {
        guard persistence.isUnlocked(id) else { return }
        selectedLevel = id
        lastResult = nil
        let ghost = persistence.settings.showGhost ? persistence.records[id]?.ghost : nil
        engine.start(level: LevelCatalog.level(id), settings: persistence.settings, ghost: ghost, daily: daily)
        screen = .playing
    }

    func playDaily() {
        let unlocked = LevelID.allCases.filter { persistence.isUnlocked($0) }
        let pick = DailyChallenge.pick(unlocked: unlocked)
        play(pick.level, daily: true)
    }

    func resume() {
        engine.paused = false
    }

    func pause() {
        engine.paused = true
    }

    func restart() {
        engine.restart()
        screen = .playing
    }

    func backToMap() {
        engine.stop()
        screen = .levelSelect
    }

    func backToMenu() {
        engine.stop()
        screen = .menu
    }

    func nextLevel() {
        if let next = selectedLevel.next, persistence.isUnlocked(next) {
            play(next)
        } else {
            screen = .levelSelect
        }
    }

    func handleFinished(_ result: RaceResult) {
        var finished = result
        let before = persistence.totalStars
        persistence.record(finished, ghost: engine.capturedGhost())
        finished.unlockedSkin = persistence.newlyUnlockedSkin(before: before, after: persistence.totalStars)
        lastResult = finished
        persistence.persist()
        screen = .results
    }
}
