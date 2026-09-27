import Foundation

final class GamePersistence: ObservableObject {
    @Published private(set) var unlocked: Set<LevelID>
    @Published private(set) var records: [LevelID: LevelRecord]
    @Published var settings: GameSettings

    private let defaults = UserDefaults.standard
    private let saveKey = "frostslide.save.v1"

    private struct SaveBlob: Codable {
        var unlocked: [LevelID]
        var records: [String: LevelRecord]
        var settings: GameSettings
    }

    init(unlocked: Set<LevelID>, records: [LevelID: LevelRecord], settings: GameSettings) {
        self.unlocked = unlocked
        self.records = records
        self.settings = settings
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
        return GamePersistence(
            unlocked: Set(blob.unlocked),
            records: recs,
            settings: blob.settings
        )
    }

    func isUnlocked(_ id: LevelID) -> Bool {
        settings.unlockAll || unlocked.contains(id)
    }

    func record(_ result: RaceResult) {
        unlocked.insert(result.level)
        if let next = result.level.next {
            unlocked.insert(next)
        }
        var rec = records[result.level] ?? .empty
        rec.timesPlayed += 1
        rec.bestPlace = min(rec.bestPlace, result.place)
        rec.bestStars = max(rec.bestStars, result.stars)
        rec.bestTime = min(rec.bestTime, result.time)
        rec.bestCrystals = max(rec.bestCrystals, result.crystals)
        records[result.level] = rec
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
            settings: settings
        )
        if let data = try? JSONEncoder().encode(blob) {
            defaults.set(data, forKey: saveKey)
        }
        objectWillChange.send()
    }
}
