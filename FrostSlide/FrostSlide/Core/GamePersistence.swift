import Foundation

final class GamePersistence: ObservableObject {
    @Published private(set) var unlocked: Set<LevelID>
    @Published private(set) var records: [LevelID: LevelRecord]
    @Published var settings: GameSettings
    /// UTC date of the last daily the player actually completed (goal met).
    @Published var lastDailyKey: String = ""
    /// Lifetime count of completed dailies.
    @Published var lastDailyWins: Int = 0
    /// Consecutive UTC days with a completed daily, as of `lastDailyKey`.
    @Published var dailyStreak: Int = 0

    private let defaults = UserDefaults.standard
    private let saveKey = "frostslide.save.v1"

    private struct SaveBlob: Codable {
        var unlocked: [LevelID]
        var records: [String: LevelRecord]
        var settings: GameSettings
        var lastDailyKey: String?
        var lastDailyWins: Int?
        var dailyStreak: Int?
    }

    /// What a finished race changed, for the results screen.
    struct RecordOutcome {
        var previousBestTime: TimeInterval?
        var newBestTime: Bool
        var dailyMet: Bool
        var dailyStreak: Int
    }

    init(
        unlocked: Set<LevelID>,
        records: [LevelID: LevelRecord],
        settings: GameSettings,
        lastDailyKey: String = "",
        lastDailyWins: Int = 0,
        dailyStreak: Int = 0
    ) {
        self.unlocked = unlocked
        self.records = records
        self.settings = settings
        self.lastDailyKey = lastDailyKey
        self.lastDailyWins = lastDailyWins
        self.dailyStreak = dailyStreak
    }

    static func load() -> GamePersistence {
        let defaults = UserDefaults.standard
        guard
            let data = defaults.data(forKey: "frostslide.save.v1"),
            let blob = try? JSONDecoder().decode(SaveBlob.self, from: data)
        else {
            return GamePersistence(
                unlocked: [.villageDash],
                records: [:],
                settings: .default
            )
        }
        var recs: [LevelID: LevelRecord] = [:]
        for (key, value) in blob.records {
            if let id = LevelID(rawValue: key) {
                recs[id] = value
            }
        }
        var settings = blob.settings
        #if !DEBUG
        settings.unlockAll = false
        #endif
        return GamePersistence(
            unlocked: Set(blob.unlocked),
            records: recs,
            settings: settings,
            lastDailyKey: blob.lastDailyKey ?? "",
            lastDailyWins: blob.lastDailyWins ?? 0,
            dailyStreak: blob.dailyStreak ?? 0
        )
    }

    var totalStars: Int {
        records.values.reduce(0) { $0 + $1.bestStars }
    }

    var totalRaces: Int {
        records.values.reduce(0) { $0 + $1.timesPlayed }
    }

    var dailyDoneToday: Bool {
        lastDailyKey == DailyChallenge.dateKey()
    }

    /// The streak the player can still extend today: it lapses if yesterday was missed.
    var activeDailyStreak: Int {
        let today = DailyChallenge.dateKey()
        let yesterday = DailyChallenge.dateKey(Date().addingTimeInterval(-86_400))
        return (lastDailyKey == today || lastDailyKey == yesterday) ? dailyStreak : 0
    }

    /// Next skin the player has not earned yet, with the stars still missing.
    var nextSkinGoal: (skin: SledSkin, starsToGo: Int)? {
        let stars = totalStars
        guard let next = SledSkin.allCases.first(where: { $0.starsRequired > stars }) else { return nil }
        return (next, next.starsRequired - stars)
    }

    func isSkinUnlocked(_ skin: SledSkin) -> Bool {
        totalStars >= skin.starsRequired
    }

    func newlyUnlockedSkin(before starsBefore: Int, after starsAfter: Int) -> SledSkin? {
        SledSkin.allCases.first { $0.starsRequired > starsBefore && $0.starsRequired <= starsAfter }
    }

    func isUnlocked(_ id: LevelID) -> Bool {
        #if DEBUG
        if settings.unlockAll { return true }
        #endif
        return id == .villageDash || unlocked.contains(id)
    }

    @discardableResult
    func record(_ result: RaceResult, ghost: GhostTake? = nil) -> RecordOutcome {
        unlocked.insert(result.level)
        if let next = result.level.next {
            unlocked.insert(next)
        }
        var rec = records[result.level] ?? .empty
        let previousBest: TimeInterval? = rec.bestTime < 9000 ? rec.bestTime : nil
        rec.timesPlayed += 1
        rec.bestPlace = min(rec.bestPlace, result.place)
        rec.bestStars = max(rec.bestStars, result.stars)
        rec.bestCrystals = max(rec.bestCrystals, result.crystals)
        if result.perfect { rec.perfect = true }
        let newBest = result.time < rec.bestTime
        if newBest {
            rec.bestTime = result.time
            if let ghost { rec.ghost = ghost }
        }
        records[result.level] = rec

        // A daily only counts when its own goal was met; a miss can be retried.
        var dailyMet = false
        if let goal = result.dailyGoal {
            dailyMet = goal.isMet(by: result)
            let today = DailyChallenge.dateKey()
            if dailyMet && lastDailyKey != today {
                dailyStreak = DailyChallenge.streak(afterCompletingOn: today, lastCompleted: lastDailyKey, current: dailyStreak)
                lastDailyKey = today
                lastDailyWins += 1
            }
        }
        persist()
        return RecordOutcome(
            previousBestTime: previousBest,
            newBestTime: newBest,
            dailyMet: dailyMet,
            dailyStreak: dailyStreak
        )
    }

    func updateSettings(_ mutate: (inout GameSettings) -> Void) {
        mutate(&settings)
        persist()
    }

    func resetProgress() {
        unlocked = [.villageDash]
        records = [:]
        lastDailyKey = ""
        lastDailyWins = 0
        dailyStreak = 0
        persist()
    }

    func persist() {
        let blob = SaveBlob(
            unlocked: Array(unlocked),
            records: Dictionary(uniqueKeysWithValues: records.map { ($0.key.rawValue, $0.value) }),
            settings: settings,
            lastDailyKey: lastDailyKey,
            lastDailyWins: lastDailyWins,
            dailyStreak: dailyStreak
        )
        if let data = try? JSONEncoder().encode(blob) {
            defaults.set(data, forKey: saveKey)
        }
        objectWillChange.send()
    }
}
