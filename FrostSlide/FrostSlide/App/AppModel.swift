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
        Analytics.apply(settings: persistence.settings)
        engine.onFinished = { [weak self] result in
            Task { @MainActor in
                self?.handleFinished(result)
            }
        }
    }

    /// The course the menu's Race button starts: the first open course the player has never
    /// finished, or, once everything open has been raced, the course they played last.
    var nextCourse: LevelID {
        let open = LevelID.allCases.filter { persistence.isUnlocked($0) }
        if let fresh = open.first(where: { persistence.records[$0] == nil }) {
            return fresh
        }
        return open.contains(selectedLevel) ? selectedLevel : (open.first ?? .villageDash)
    }

    /// Today's daily: which open course and what it asks for.
    var dailyPick: (level: LevelID, goal: DailyChallenge.Goal) {
        let unlocked = LevelID.allCases.filter { persistence.isUnlocked($0) }
        return DailyChallenge.pick(unlocked: unlocked)
    }

    func play(_ id: LevelID, dailyGoal: DailyChallenge.Goal? = nil) {
        guard persistence.isUnlocked(id) else { return }
        selectedLevel = id
        lastResult = nil
        let ghost = persistence.settings.showGhost ? persistence.records[id]?.ghost : nil
        engine.start(
            level: LevelCatalog.level(id),
            settings: persistence.settings,
            ghost: ghost,
            dailyGoal: dailyGoal
        )
        screen = .playing
        Analytics.track(.raceStarted(course: id.order + 1, daily: dailyGoal != nil))
    }

    func quickRace() {
        play(nextCourse)
    }

    func playDaily() {
        let pick = dailyPick
        play(pick.level, dailyGoal: pick.goal)
    }

    func resume() {
        engine.paused = false
    }

    func pause() {
        engine.paused = true
    }

    /// Phone calls, notification pulls, the app switcher: stop the race instead of letting it
    /// run unattended, and let the player resume from the pause menu.
    func pauseForInterruption() {
        guard screen == .playing, !engine.paused else { return }
        switch engine.phase {
        case .countdown, .racing:
            engine.paused = true
        default:
            break
        }
    }

    /// Restarts the current course. Going through `play` (rather than the engine's own
    /// restart) means a rematch races the ghost of the run that was just saved.
    func restart() {
        play(selectedLevel, dailyGoal: engine.dailyGoal)
    }

    func backToMap() {
        trackAbandonIfRacing()
        engine.stop()
        screen = .levelSelect
    }

    func backToMenu() {
        trackAbandonIfRacing()
        engine.stop()
        screen = .menu
    }

    /// Leaving a race that is still on (from the pause menu) tells us where players give up.
    private func trackAbandonIfRacing() {
        switch engine.phase {
        case .countdown, .racing:
            Analytics.track(.raceAbandoned(course: selectedLevel.order + 1, progress: Int((engine.hud.progress * 100).rounded())))
        default:
            break
        }
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
        let outcome = persistence.record(finished, ghost: engine.capturedGhost())
        finished.unlockedSkin = persistence.newlyUnlockedSkin(before: before, after: persistence.totalStars)
        finished.previousBest = outcome.previousBestTime
        finished.newBest = outcome.newBestTime
        finished.dailyMet = outcome.dailyMet
        finished.dailyStreak = outcome.dailyStreak
        lastResult = finished
        persistence.persist()
        screen = .results
        Analytics.track(.raceFinished(
            course: finished.level.order + 1,
            place: finished.place,
            stars: finished.stars,
            perfect: finished.perfect,
            seconds: finished.time,
            crashes: finished.crashes
        ))
        if finished.daily && finished.dailyMet {
            Analytics.track(.dailyCompleted(streak: finished.dailyStreak))
        }
    }
}
