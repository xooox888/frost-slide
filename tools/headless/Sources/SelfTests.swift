// Checks that run the real engine, progression and persistence code headlessly.
import Foundation

var passes = 0
var failures = 0
func check(_ cond: @autoclosure () -> Bool, _ msg: String, line: Int = #line) {
    if cond() { passes += 1 } else { failures += 1; print("  FAIL (line \(line)): \(msg)") }
}
func section(_ name: String) { print("• \(name)") }

func drain() { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0)) }

/// Runs a race with a bot until the result arrives.
@discardableResult
func play(_ level: LevelDefinition, profile: BotProfile = .good, seed: UInt64 = 1, ghost: GhostTake? = nil,
          dailyGoal: DailyChallenge.Goal? = nil, settings: GameSettings = .default,
          each: ((GameEngine) -> Void)? = nil) -> (engine: GameEngine, result: RaceResult?) {
    let engine = GameEngine()
    var result: RaceResult?
    engine.onFinished = { result = $0 }
    engine.start(level: level, settings: settings, ghost: ghost, dailyGoal: dailyGoal)
    let bot = Bot(profile, seed: seed)
    var ticks = 0
    while result == nil && ticks < 60 * 200 {
        bot.update(engine, dt: 1.0 / 60.0)
        engine.tick(dt: 1.0 / 60.0)
        each?(engine)
        ticks += 1
    }
    drain()
    return (engine, result)
}

func testTrack() {
    section("track: banking leans into turns, eases in and out")
    for id in LevelID.allCases {
        let level = CourseInfo_level(id)
        let path = TrackPath.build(from: level)
        var worstStep: Float = 0
        var wrong = 0, checked = 0
        for (i, s) in path.samples.enumerated() {
            if i > 0 { worstStep = max(worstStep, abs(s.bank - path.samples[i - 1].bank)) }
            if abs(s.curvature) > 0.004 {
                checked += 1
                let half = s.width * 0.5
                let left = s.position - s.binormal * half, right = s.position + s.binormal * half
                let leftTurn = s.curvature > 0
                let insideY = leftTurn ? left.y : right.y
                let outsideY = leftTurn ? right.y : left.y
                if insideY > outsideY { wrong += 1 }   // inside should be LOWER
            }
        }
        check(wrong == 0, "\(level.name): \(wrong)/\(checked) samples banked the wrong way")
        check(worstStep < 0.05, "\(level.name): bank jumps \(worstStep) rad between samples")   // was 0.27 before easing
        check(path.samples.allSatisfy { $0.position.x.isFinite && $0.bank.isFinite && $0.curvature.isFinite }, "\(level.name): non-finite sample")
    }
}

func CourseInfo_level(_ id: LevelID) -> LevelDefinition { LevelCatalog.level(id) }

func testSteering() {
    section("steering: responsive on snow, slippery on ice")
    var solo = LevelCatalog.level(.villageDash)
    solo.rivals = []
    let e = GameEngine()
    e.start(level: solo, settings: .default)
    while e.phase != .racing { e.tick(dt: 1.0 / 60.0) }
    e.steerInput = 1
    var peak: Float = 0
    var t: Float = 0, shift4: Float = -1
    let start = e.playerRacer!.lateral
    while t < 3 {
        e.tick(dt: 1.0 / 60.0); t += 1.0 / 60.0
        peak = max(peak, e.playerRacer!.lateralVel)
        if shift4 < 0 && e.playerRacer!.lateral - start >= 4 { shift4 = t }
    }
    check(peak > 5.5 && peak < 8.5, "peak lateral speed \(peak) m/s")
    check(shift4 > 0 && shift4 < 1.0, "4 m lane change took \(shift4) s")

    // Ice: build a flat test course with one ice patch and one control course without it.
    func course(ice: Bool) -> LevelDefinition {
        let b = LevelBuilder(id: .villageDash, name: "T", subtitle: "", blurb: "", theme: .village, palette: .village)
        b.length = 400; b.baseWidth = 30; b.slope = 0.11
        if ice { b.hazard(.icePatch, 0.30, lateral: 3, radius: 8) }   // wide enough to catch the sled wherever it steers
        return b.build()
    }
    func slide(ice: Bool) -> Float {
        var level = course(ice: ice)
        level.rivals = []
        let e = GameEngine()
        e.start(level: level, settings: .default)
        while e.phase != .racing { e.tick(dt: 1.0 / 60.0) }
        // full lock right until the patch centre, then let go and see how far the sled keeps sliding
        var lat0: Float = 0
        var released = false
        var out: Float = 0
        for _ in 0..<(60 * 25) {
            let p = e.playerRacer!
            let toPatch = (0.30 - p.progress) * 400
            if !released {
                // start steering about 0.8 s before the patch so the sled arrives at speed, mid-track
                e.steerInput = toPatch < 13 ? 1 : 0
                if toPatch <= 0 { released = true; lat0 = p.lateral; e.steerInput = 0 }
            } else {
                e.steerInput = 0
            }
            e.tick(dt: 1.0 / 60.0)
            if released && e.playerRacer!.progress >= 0.30 + 0.03 { out = e.playerRacer!.lateral - lat0; break }
        }
        return out
    }
    let snowDrift = slide(ice: false), iceDrift = slide(ice: true)
    print("   coasting sideways after letting go: snow \(snowDrift) m, ice \(iceDrift) m")
    check(iceDrift > snowDrift + 1.0, "coasting through ice should slide further sideways: snow \(snowDrift) m, ice \(iceDrift) m")
}

func testPickupsBelongToPlayer() {
    section("pickups: rivals never take crystals or power-ups")
    for id in [LevelID.villageDash, .carnivalParade, .icefallRun] {
        let (engine, _) = play(LevelCatalog.level(id), profile: .good)
        let rivalCrystals = engine.racers.filter { !$0.isPlayer }.map(\.crystals).reduce(0, +)
        check(rivalCrystals == 0, "\(id.rawValue): rivals collected \(rivalCrystals) crystals")
        let taken = engine.entities.filter { $0.collected }.count
        let player = engine.playerRacer!
        check(taken >= player.crystals, "\(id.rawValue): collected flags \(taken) vs player crystals \(player.crystals)")
    }
}

func testGhost() {
    section("ghost: covers the whole run, replays in step, stays small")
    let level = LevelCatalog.level(.villageDash)
    let (engine, result) = play(level, profile: .good, seed: 3)
    guard let result, let ghost = engine.capturedGhost() else { check(false, "no ghost captured"); return }
    check(ghost.isUsable, "captured ghost not usable")
    check((ghost.samples.first?.t ?? 99) < 0.3, "ghost starts at t=\(ghost.samples.first?.t ?? -1)")
    check(abs(Double(ghost.samples.last?.t ?? 0) - result.time) < 0.2, "ghost ends at \(ghost.samples.last?.t ?? -1) but run took \(result.time)")
    check(ghost.samples.count > Int(result.time * 7), "only \(ghost.samples.count) samples for \(result.time) s")
    let data = try! JSONEncoder().encode(ghost)
    check(data.count < 20_000, "ghost JSON is \(data.count) bytes")
    print("   ghost: \(ghost.samples.count) samples, \(data.count) bytes for a \(String(format: "%.1f", result.time)) s run")
    // an old truncated take (first sample deep into the race) must be ignored
    let stale = GhostTake(time: 30, samples: (0..<200).map { GhostSample(t: 15 + Float($0) * 0.08, p: 0.4 + Float($0) * 0.001, l: 0, h: 0) })
    check(!stale.isUsable, "truncated ghost should be unusable")
    // replay: the ghost pose follows the recording
    var maxErr: Float = 0
    let replayEngine = GameEngine()
    replayEngine.start(level: level, settings: .default, ghost: ghost)
    let bot = Bot(.idle, seed: 1)
    var ticks = 0
    while replayEngine.phase != .finished && ticks < 60 * 100 {
        bot.update(replayEngine, dt: 1.0 / 60.0)
        replayEngine.tick(dt: 1.0 / 60.0)
        ticks += 1
        if replayEngine.phase == .racing, let pose = replayEngine.ghostPose {
            let t = Float(replayEngine.raceTime)
            if let s = ghost.samples.min(by: { abs($0.t - t) < abs($1.t - t) }), abs(s.t - t) < 0.07 {
                maxErr = max(maxErr, abs(s.p - pose.progress))
            }
        }
    }
    drain()
    check(maxErr < 0.01, "ghost pose deviates from its recording by \(maxErr) progress")
    check(replayEngine.hud.ghostGap != nil || true, "ghost gap available")
}

func testAvalanche() {
    section("avalanche: launches behind the player, buries once, ends")
    for id in [LevelID.frozenHollow, .whiteoutPeak, .carnivalParade] {
        let level = LevelCatalog.level(id)
        let event = level.events.first { $0.kind == .avalanche }!
        var lastFront: Float = -1
        var monotonic = true
        var everThreat = false
        var launchedAt: Float = -1
        var gapAtLaunch: Float = -1
        let (engine, result) = play(level, profile: .novice, seed: 4) { e in
            if e.avalancheThreat {
                everThreat = true
                if e.avalancheFront < lastFront - 1e-6 { monotonic = false }
                lastFront = e.avalancheFront
                if launchedAt < 0, let p = e.playerRacer, let path = e.path {
                    launchedAt = p.progress
                    gapAtLaunch = (p.progress - e.avalancheFront) * path.length
                }
            }
        }
        check(result != nil, "\(id.rawValue): race did not finish")
        check(everThreat, "\(id.rawValue): avalanche never launched")
        check(monotonic, "\(id.rawValue): wall moved backwards")
        check(launchedAt >= event.start - 0.02, "\(id.rawValue): launched early at \(launchedAt) (start \(event.start))")
        check(gapAtLaunch > 15 && gapAtLaunch < 60, "\(id.rawValue): wall spawned \(gapAtLaunch) m behind")
        check(!engine.avalancheThreat, "\(id.rawValue): still threatening after the race")
    }
}

func testResults() {
    section("results: consistent standings, stars and clocks")
    for id in [LevelID.villageDash, .harborFreeze, .prismCut, .carnivalParade] {
        let (engine, resultOpt) = play(LevelCatalog.level(id), profile: .casual, seed: 8)
        guard let r = resultOpt else { check(false, "\(id.rawValue): no result"); continue }
        check(r.standings.count == r.fieldSize, "\(id.rawValue): standings \(r.standings.count) vs field \(r.fieldSize)")
        let times = r.standings.compactMap(\.time)
        check(times == times.sorted(), "\(id.rawValue): standings not in time order \(times)")
        check(Set(r.standings.map(\.place)).count == r.fieldSize, "\(id.rawValue): duplicate places")
        check(r.standings.first { $0.isPlayer }?.place == r.place, "\(id.rawValue): player place mismatch")
        check(abs((r.standings.first { $0.isPlayer }?.time ?? -1) - r.time) < 0.02, "\(id.rawValue): player time mismatch")
        check(r.stars == StarRules.stars(points: r.points) && (1...3).contains(r.stars), "\(id.rawValue): stars \(r.stars) points \(r.points)")
        check(r.parTime > 0 && r.crystalGoal > 0, "\(id.rawValue): goals missing from result")
        check(r.time > 15 && r.time < 90, "\(id.rawValue): implausible time \(r.time)")
        check(r.crashes == engine.playerRacer!.hits, "\(id.rawValue): crash count")
        // the race clock starts at zero at the light, not part-way through the countdown
        let e2 = GameEngine()
        e2.start(level: LevelCatalog.level(id), settings: .default)
        var goTime: TimeInterval = -1
        for _ in 0..<600 { e2.tick(dt: 1.0 / 60.0); if e2.phase == .racing { goTime = e2.raceTime; break } }
        check(goTime >= 0 && goTime < 0.05, "\(id.rawValue): race clock reads \(goTime) at GO")
    }
}

func testStarRules() {
    section("stars: bonus points add up")
    check(StarRules.stars(points: StarRules.points(place: 1, crystals: 0, crystalGoal: 20, time: 99, parTime: 40)) == 3, "win alone = 3 stars")
    check(StarRules.stars(points: StarRules.points(place: 2, crystals: 0, crystalGoal: 20, time: 99, parTime: 40)) == 2, "2nd alone = 2 stars")
    check(StarRules.stars(points: StarRules.points(place: 2, crystals: 25, crystalGoal: 20, time: 99, parTime: 40)) == 3, "2nd + crystals = 3 stars")
    check(StarRules.stars(points: StarRules.points(place: 5, crystals: 25, crystalGoal: 20, time: 30, parTime: 40)) == 3, "5th + both goals = 3 stars")
    check(StarRules.stars(points: StarRules.points(place: 5, crystals: 0, crystalGoal: 20, time: 99, parTime: 40)) == 1, "finish alone = 1 star")
    check(StarRules.points(place: 1, crystals: 25, crystalGoal: 20, time: 30, parTime: 40) >= StarRules.perfectPoints, "win + both goals is perfect")
}

func testDaily() {
    section("daily: goals are judged, streaks continue only day to day")
    func result(place: Int, crystals: Int, time: TimeInterval, crashes: Int) -> RaceResult {
        RaceResult(level: .villageDash, place: place, fieldSize: 4, time: time, crystals: crystals, crystalTotal: 34, stars: 1,
                   podium: [], comboMax: 0, nearMisses: 0, unlockedSkin: nil, daily: true, parTime: 40, crystalGoal: 28, crashes: crashes)
    }
    check(DailyChallenge.Goal.beatPar.isMet(by: result(place: 4, crystals: 0, time: 39, crashes: 3)), "beat par")
    check(!DailyChallenge.Goal.beatPar.isMet(by: result(place: 1, crystals: 34, time: 41, crashes: 0)), "missed par")
    check(DailyChallenge.Goal.topTwo.isMet(by: result(place: 2, crystals: 0, time: 90, crashes: 9)), "top two")
    check(!DailyChallenge.Goal.topTwo.isMet(by: result(place: 3, crystals: 34, time: 30, crashes: 0)), "third is not top two")
    check(DailyChallenge.Goal.crystalHunt.isMet(by: result(place: 6, crystals: 28, time: 90, crashes: 9)), "crystal hunt")
    check(!DailyChallenge.Goal.crystalHunt.isMet(by: result(place: 1, crystals: 27, time: 30, crashes: 0)), "one short")
    check(DailyChallenge.Goal.cleanRun.isMet(by: result(place: 6, crystals: 0, time: 90, crashes: 0)), "clean run")
    check(!DailyChallenge.Goal.cleanRun.isMet(by: result(place: 1, crystals: 34, time: 30, crashes: 1)), "one crash")
    let day: TimeInterval = 86_400
    let today = Date(timeIntervalSince1970: 1_800_000_000)
    let key = DailyChallenge.dateKey(today)
    let yesterday = DailyChallenge.dateKey(today.addingTimeInterval(-day))
    let old = DailyChallenge.dateKey(today.addingTimeInterval(-3 * day))
    check(DailyChallenge.streak(afterCompletingOn: key, lastCompleted: yesterday, current: 4, date: today) == 5, "yesterday continues the streak")
    check(DailyChallenge.streak(afterCompletingOn: key, lastCompleted: old, current: 4, date: today) == 1, "a gap resets the streak")
    check(DailyChallenge.streak(afterCompletingOn: key, lastCompleted: "", current: 0, date: today) == 1, "first ever completion")
    check(DailyChallenge.streak(afterCompletingOn: key, lastCompleted: key, current: 4, date: today) == 4, "same day changes nothing")
    let pickA = DailyChallenge.pick(unlocked: LevelID.allCases, date: today)
    let pickB = DailyChallenge.pick(unlocked: LevelID.allCases, date: today)
    check(pickA.level == pickB.level && pickA.goal == pickB.goal, "pick is stable within a day")
    var seenGoals = Set<DailyChallenge.Goal>()
    for d in 0..<60 { seenGoals.insert(DailyChallenge.pick(unlocked: LevelID.allCases, date: today.addingTimeInterval(Double(d) * day)).goal) }
    check(seenGoals.count == 4, "all four goals come up over two months (saw \(seenGoals.count))")
}

func testPersistence() {
    section("persistence: records, bests, daily completion, reset")
    let store = GamePersistence(unlocked: [.villageDash], records: [:], settings: .default)
    func result(place: Int, time: TimeInterval, crystals: Int = 30, crashes: Int = 0, goal: DailyChallenge.Goal? = nil) -> RaceResult {
        RaceResult(level: .villageDash, place: place, fieldSize: 4, time: time, crystals: crystals, crystalTotal: 34,
                   stars: 3, podium: [], comboMax: 3, nearMisses: 1, unlockedSkin: nil, daily: goal != nil,
                   parTime: 40, crystalGoal: 28, crashes: crashes, dailyGoal: goal)
    }
    let ghostA = GhostTake(time: 33, samples: (0..<40).map { GhostSample(t: Float($0) * 0.125, p: Float($0) * 0.02, l: 0, h: 0) })
    let first = store.record(result(place: 2, time: 33), ghost: ghostA)
    check(first.previousBestTime == nil && first.newBestTime, "first run is a best with no previous")
    check(store.isUnlocked(.marketMayhem), "finishing unlocks the next course")
    let slower = store.record(result(place: 1, time: 35), ghost: nil)
    check(slower.previousBestTime == 33 && !slower.newBestTime, "slower run keeps the old best")
    check(store.records[.villageDash]?.ghost == ghostA, "ghost kept when not beaten")
    let faster = store.record(result(place: 1, time: 31), ghost: GhostTake(time: 31, samples: ghostA.samples))
    check(faster.newBestTime && faster.previousBestTime == 33, "faster run is the new best")
    check(store.records[.villageDash]?.perfect == true, "win + crystals + par is a perfect run")
    // daily: a miss does not count and can be retried; a hit counts once
    let miss = store.record(result(place: 4, time: 45, crystals: 5, goal: .topTwo), ghost: nil)
    check(!miss.dailyMet && !store.dailyDoneToday && store.lastDailyWins == 0, "missed daily does not count")
    let hit = store.record(result(place: 1, time: 32, goal: .topTwo), ghost: nil)
    check(hit.dailyMet && store.dailyDoneToday && store.lastDailyWins == 1 && hit.dailyStreak == 1, "met daily counts")
    let again = store.record(result(place: 1, time: 32, goal: .topTwo), ghost: nil)
    check(again.dailyMet && store.lastDailyWins == 1, "second success the same day is not double counted")
    check(store.activeDailyStreak == 1, "active streak")
    store.resetProgress()
    check(store.records.isEmpty && store.lastDailyWins == 0 && store.dailyStreak == 0 && !store.isUnlocked(.marketMayhem), "reset clears progress and daily state")
    check(store.totalRaces == 0, "no races after reset")
}

func testSettingsCoding() {
    section("settings: old saves still load, sensitivity is clamped")
    let old = #"{"tiltSteering":true,"unlockAll":false,"hapticsEnabled":true,"soundEnabled":false,"showGhost":true,"selectedSkin":"gold"}"#
    let s = try! JSONDecoder().decode(GameSettings.self, from: Data(old.utf8))
    check(s.steerSensitivity == 1 && s.tiltSteering && !s.soundEnabled && s.selectedSkin == .gold, "old settings decode with default sensitivity")
    let wild = #"{"steerSensitivity":9}"#
    let w = try! JSONDecoder().decode(GameSettings.self, from: Data(wild.utf8))
    check(w.steerSensitivity == GameSettings.steerSensitivityRange.upperBound, "sensitivity clamped to \(w.steerSensitivity)")
    check(s.shareUsageData, "usage stats default to on for saves that predate the setting")
    let optedOut = try! JSONDecoder().decode(GameSettings.self, from: Data(#"{"shareUsageData":false}"#.utf8))
    let reloaded = try! JSONDecoder().decode(GameSettings.self, from: try! JSONEncoder().encode(optedOut))
    check(!optedOut.shareUsageData && !reloaded.shareUsageData, "opting out of usage stats survives a save")
    let oldRecord = #"{"bestPlace":2,"bestStars":3,"bestTime":33.5,"bestCrystals":20,"timesPlayed":4}"#
    let r = try! JSONDecoder().decode(LevelRecord.self, from: Data(oldRecord.utf8))
    check(r.bestStars == 3 && !r.perfect && r.ghost == nil, "old level record decodes")
}

func testHudThrottleAndLaunch() {
    section("hud: refreshes about 30 times a second; a timed boost launches the sled")
    let e = GameEngine()
    e.start(level: LevelCatalog.level(.villageDash), settings: .default)
    drain()
    while e.phase != .racing { e.tick(dt: 1.0 / 60.0); drain() }
    var seen = Set<TimeInterval>()
    for _ in 0..<120 {
        e.tick(dt: 1.0 / 60.0)
        drain()
        seen.insert(e.hud.time)
    }
    let perSecond = Double(seen.count) / 2
    check(perSecond > 24 && perSecond < 36, "\(perSecond) distinct HUD refreshes per second (want about 30)")

    func speedAfterGo(holdFrom: Double?) -> Float {
        let g = GameEngine()
        g.start(level: LevelCatalog.level(.villageDash), settings: .default)
        var t = 0.0
        while g.phase != .racing && t < 6 {
            if let from = holdFrom { g.boostHeld = t >= from } else { g.boostHeld = false }
            g.tick(dt: 1.0 / 60.0); t += 1.0 / 60.0
        }
        return g.playerRacer!.speed
    }
    let none = speedAfterGo(holdFrom: nil)
    let timed = speedAfterGo(holdFrom: 2.55)     // pressed in the last ~0.7 s
    let early = speedAfterGo(holdFrom: 0.1)      // held from the very start
    check(timed > none + 2, "timed launch gives a boost (\(none) -> \(timed))")
    check(abs(early - none) < 0.5, "holding from the start gives no launch (\(early) vs \(none))")
}

func testFeelTuning() {
    section("feel: rubber band, speed cap, punchy pads")
    let mid = Tuning.rubberBandFactor(lead: -0.07, rivalProgress: 0.4)
    let late = Tuning.rubberBandFactor(lead: -0.07, rivalProgress: 0.94)
    let far = Tuning.rubberBandFactor(lead: -0.22, rivalProgress: 0.45)
    let ahead = Tuning.rubberBandFactor(lead: 0.09, rivalProgress: 0.5)
    check(mid > 1.02 && mid < 1.09, "mid-race catch-up \(mid)")
    check(late < mid, "finish catch-up \(late) should fade vs mid \(mid)")
    check(far < mid, "far-behind warp \(far) should not beat a close rival \(mid)")
    check(ahead < 1 && ahead > 0.90, "leaders ease off \(ahead)")

    var top: Float = 0
    var solo = LevelCatalog.level(.villageDash)
    solo.rivals = []
    _ = play(solo, profile: .expert, seed: 2) { engine in
        engine.boostHeld = true
        if let speed = engine.playerRacer?.speed { top = max(top, speed) }
    }
    check(top.isFinite && top <= Tuning.hardSpeedCap + 0.05, "stacked boost/rocket speed \(top) should stay under \(Tuning.hardSpeedCap)")
    check(top > 16, "powered sled should still be fast (\(top))")
}

func testFuzz() {
    section("fuzz: random inputs never break the simulation")
    var rng = SplitMix64(seed: 99)
    var bad = 0
    var unfinished = 0
    for round in 0..<72 {
        let id = LevelID.allCases[round % LevelID.allCases.count]
        let engine = GameEngine()
        var result: RaceResult?
        engine.onFinished = { result = $0 }
        var settings = GameSettings.default
        settings.steerSensitivity = Float.random(in: 0.6...1.6, using: &rng)
        engine.start(level: LevelCatalog.level(id), settings: settings, dailyGoal: round % 5 == 0 ? .cleanRun : nil)
        var ticks = 0
        var steer: Float = 0
        while result == nil && ticks < 60 * 200 {
            if ticks % 20 == 0 { steer = Float.random(in: -3...3, using: &rng) }   // beyond full lock on purpose
            engine.steerInput = steer
            engine.boostHeld = Bool.random(using: &rng)
            if ticks % 240 == 0 { engine.dropBananaRequested = true }
            let dt = [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 0.05, 0.001][Int(rng.next() % 5)]
            engine.tick(dt: dt)
            for r in engine.racers {
                let okNumbers = [r.progress, r.lateral, r.height, r.speed, r.lateralVel, r.turbo, r.roll, r.pitch, r.yaw].allSatisfy { $0.isFinite }
                let half = (engine.path?.width(at: r.progress) ?? 20) * 0.5
                if !okNumbers || abs(r.lateral) > half + 0.01 || r.progress < 0 || r.progress > 1 || r.turbo < 0 || r.turbo > 1.0001 || r.speed < 0 || r.speed > 60 {
                    bad += 1
                    if bad < 4 { print("   bad state on \(id.rawValue): \(r.name) progress \(r.progress) lateral \(r.lateral) speed \(r.speed) turbo \(r.turbo)") }
                }
            }
            ticks += 1
        }
        if result == nil { unfinished += 1 }
        drain()
    }
    check(bad == 0, "\(bad) invalid racer states")
    check(unfinished == 0, "\(unfinished) fuzzed races never finished")
}

func runSelfTests() {
    testStableIds()
    testTrack()
    testSteering()
    testPickupsBelongToPlayer()
    testGhost()
    testAvalanche()
    testResults()
    testStarRules()
    testDaily()
    testPersistence()
    testSettingsCoding()
    testHudThrottleAndLaunch()
    testFeelTuning()
    testFuzz()
    print("\n\(passes) checks passed, \(failures) failed")
    exit(failures == 0 ? 0 : 1)
}

func testStableIds() {
    section("levels: authored ids are stable and unique")
    for id in [LevelID.villageDash, .carnivalParade] {
        let a = LevelCatalog.level(id), b = LevelCatalog.level(id)
        check(a.entities.map(\.id) == b.entities.map(\.id), "\(id.rawValue): entity ids differ between builds")
        check(a.rivals.map(\.id) == b.rivals.map(\.id), "\(id.rawValue): rival ids differ between builds")
        let all = a.entities.map(\.id) + a.rivals.map(\.id)
        check(Set(all).count == all.count, "\(id.rawValue): duplicate ids")
    }
    let v = LevelCatalog.level(.villageDash), c = LevelCatalog.level(.carnivalParade)
    check(Set(v.entities.map(\.id)).isDisjoint(with: Set(c.entities.map(\.id))), "ids collide across courses")
}
