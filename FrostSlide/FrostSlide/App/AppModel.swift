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

    func play(_ id: LevelID) {
        guard persistence.isUnlocked(id) else { return }
        selectedLevel = id
        lastResult = nil
        engine.start(level: LevelCatalog.level(id), settings: persistence.settings)
        screen = .playing
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
        lastResult = result
        persistence.record(result)
        persistence.persist()
        screen = .results
    }
}
