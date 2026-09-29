import Foundation

// Measurements built on the bots. Each one races the real engine; none of them touches game code.

/// Solo pace: each bot alone on the course (no rivals), to see how much driving skill is worth in seconds.
func probeSolo(_ id: LevelID, profile: BotProfile, runs: Int) -> (time: Double, crystals: Double, crashes: Double) {
    var sumT = 0.0, sumC = 0.0, sumK = 0.0
    for k in 0..<runs {
        let engine = GameEngine()
        var result: RaceResult?
        engine.onFinished = { result = $0 }
        var solo = LevelCatalog.level(id)
        solo.rivals = []
        AudioHaptics.shared.reset()
        engine.start(level: solo, settings: .default)
        let bot = Bot(profile, seed: UInt64(77 + k * 31 + id.order * 1009))
        var ticks = 0
        while result == nil && ticks < 60 * 240 {
            bot.update(engine, dt: 1.0 / 60.0)
            engine.tick(dt: 1.0 / 60.0)
            ticks += 1
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0))
        sumT += result?.time ?? 240
        sumC += Double(result?.crystals ?? 0)
        sumK += Double(AudioHaptics.shared.counts["crash", default: 0])
    }
    return (sumT / Double(runs), sumC / Double(runs), sumK / Double(runs))
}

/// Rival pace: an idle player far behind, run until every rival finishes. With the rubber band on,
/// leaders are throttled, so `run.sh rivals` builds a variant with the band off to show raw pace.
func probeRivalPace(_ id: LevelID) -> [(name: String, time: Double, hits: Int)] {
    let engine = GameEngine()
    engine.start(level: LevelCatalog.level(id), settings: .default)
    let bot = Bot(.idle, seed: 1)
    var ticks = 0
    while !engine.racers.dropFirst().allSatisfy({ $0.finished }) && ticks < 60 * 300 {
        bot.update(engine, dt: 1.0 / 60.0)
        engine.tick(dt: 1.0 / 60.0)
        ticks += 1
    }
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0))
    return engine.racers.dropFirst().map { r in
            return (r.name, r.finishTime ?? 999, r.hits)
    }
}

func probeStandings(_ id: LevelID, profile: BotProfile, seed: UInt64) {
    let engine = GameEngine()
    var result: RaceResult?
    engine.onFinished = { result = $0 }
    engine.start(level: LevelCatalog.level(id), settings: .default)
    let bot = Bot(profile, seed: seed)
    var ticks = 0
    var lead: [String: Int] = [:]
    while result == nil && ticks < 60 * 240 {
        bot.update(engine, dt: 1.0 / 60.0)
        engine.tick(dt: 1.0 / 60.0)
        ticks += 1
        if ticks % 60 == 0, engine.phase == .racing {
            let ranked = engine.racers.sorted { $0.progress > $1.progress }
            if let f = ranked.first { lead[f.name, default: 0] += 1 }
        }
    }
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0))
    guard let r = result else { print("no result"); return }
    print("\(LevelCatalog.level(id).name) [\(profile.name)]  place \(r.place)  seconds-in-lead: \(lead.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))")
    for s in r.standings {
        let hits = engine.racers.first { $0.id.uuidString == s.id }?.hits ?? -1
        print(String(format: "   %d. %-7@ %6.2f s  hits %d", s.place, s.name as NSString, s.time ?? 0, hits))
    }
}

/// Mean winning margin of a bot over `runs` real races: (fastest rival's finish time) - (bot's finish time).
/// Positive means the bot beat every rival. Also reports the win rate.
func meanMargin(_ id: LevelID, profile: BotProfile, runs: Int) -> (margin: Double, win: Double, sd: Double) {
    var margins: [Double] = []
    var wins = 0
    for k in 0..<runs {
        let (s, result) = runRace(level: id, profile: profile, seed: UInt64(5000 + id.order * 211 + k * 7717))
        guard s.finished, let r = result else { continue }
        let rivalBest = r.standings.filter { !$0.isPlayer }.compactMap(\.time).min() ?? r.time
        margins.append(rivalBest - r.time)
        if r.place == 1 { wins += 1 }
    }
    let n = Double(max(1, margins.count))
    let mean = margins.reduce(0, +) / n
    let variance = margins.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / n
    return (mean, Double(wins) / n, variance.squareRoot())
}

/// How dangerous is the avalanche? Burial rate of the player and of rivals, and the closest approach.
func avalancheStats(_ id: LevelID, profile: BotProfile, runs: Int) -> (buried: Double, rivalsBuried: Double, minGap: Double) {
    var buried = 0, rivalsBuried = 0, rivalCount = 0
    var gaps: [Double] = []
    for k in 0..<runs {
        let engine = GameEngine()
        var result: RaceResult?
        engine.onFinished = { result = $0 }
        engine.start(level: LevelCatalog.level(id), settings: .default)
        let bot = Bot(profile, seed: UInt64(300 + k * 41 + id.order * 17))
        var ticks = 0
        var minGap = Double.greatestFiniteMagnitude
        var playerBuried = false
        let hitsBefore = engine.racers.map(\.hits)
        _ = hitsBefore
        while result == nil && ticks < 60 * 240 {
            bot.update(engine, dt: 1.0 / 60.0)
            engine.tick(dt: 1.0 / 60.0)
            ticks += 1
            if engine.avalancheThreat, let p = engine.playerRacer, let path = engine.path {
                let gap = Double((p.progress - engine.avalancheFront) * path.length)
                if gap < 0 { playerBuried = true } else { minGap = min(minGap, gap) }
            }
        }
        drain()
        if playerBuried { buried += 1 }
        if minGap < 1e6 { gaps.append(minGap) }
        // rivals that were behind the wall's front while it ran: count via speed penalties is indirect,
        // so compare their finishing gap instead — here just count rivals finishing after the player by > 2 s
        if let r = result {
            for s in r.standings where !s.isPlayer { rivalCount += 1; if (s.time ?? 0) - r.time > 3 { rivalsBuried += 1 } }
        }
    }
    let meanGap = gaps.isEmpty ? -1 : gaps.reduce(0, +) / Double(gaps.count)
    return (Double(buried) / Double(runs), Double(rivalsBuried) / Double(max(1, rivalCount)), meanGap)
}
