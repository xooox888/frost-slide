import Foundation

final class GamePersistence: ObservableObject {
    @Published private(set) var unlocked: Set<LevelID>
    @Published private(set) var records: [LevelID: LevelRecord]
    @Published var settings: GameSettings
    @Published var lastDailyKey: String = ""
    @Published var lastDailyWins: Int = 0

    private let defaults = UserDefaults.standard
    private let saveKey = "frostslide.save.v1"

    private struct SaveBlob: Codable {
        var unlocked: [LevelID]
        var records: [String: LevelRecord]
        var settings: GameSettings
        var lastDailyKey: String?
        var lastDailyWins: Int?
    }

    init(
        unlocked: Set<LevelID>,
        records: [LevelID: LevelRecord],
        settings: GameSettings,
        lastDailyKey: String = "",
        lastDailyWins: Int = 0
    ) {
        self.unlocked = unlocked
        self.records = records
        self.settings = settings
        self.lastDailyKey = lastDailyKey
        self.lastDailyWins = lastDailyWins
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
            lastDailyWins: blob.lastDailyWins ?? 0
        )
    }

    var totalStars: Int {
        records.values.reduce(0) { $0 + $1.bestStars }
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

    func record(_ result: RaceResult, ghost: GhostTake? = nil) {
        unlocked.insert(result.level)
        if let next = result.level.next {
            unlocked.insert(next)
        }
        var rec = records[result.level] ?? .empty
        rec.timesPlayed += 1
        rec.bestPlace = min(rec.bestPlace, result.place)
        rec.bestStars = max(rec.bestStars, result.stars)
        rec.bestCrystals = max(rec.bestCrystals, result.crystals)
        if result.time < rec.bestTime {
            rec.bestTime = result.time
            if let ghost { rec.ghost = ghost }
        }
        records[result.level] = rec
        if result.daily {
            let key = DailyChallenge.dateKey()
            if lastDailyKey != key {
                lastDailyKey = key
                if result.place <= 2 { lastDailyWins += 1 }
            }
        }
        persist()
    }

    func updateSettings(_ mutate: (inout GameSettings) -> Void) {
        mutate(&settings)
        persist()
    }

    func resetProgress() {
        unlocked = [.villageDash]
        records = [:]
        persist()
    }

    func persist() {
        let blob = SaveBlob(
            unlocked: Array(unlocked),
            records: Dictionary(uniqueKeysWithValues: records.map { ($0.key.rawValue, $0.value) }),
            settings: settings,
            lastDailyKey: lastDailyKey,
            lastDailyWins: lastDailyWins
        )
        if let data = try? JSONEncoder().encode(blob) {
            defaults.set(data, forKey: saveKey)
        }
        objectWillChange.send()
    }
}
