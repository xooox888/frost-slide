import CoreMotion
import Foundation
import simd

/// Every number that shapes how a race feels, in one place, so tuning never means
/// hunting through the simulation. Speeds are m/s, accelerations m/s², times seconds.
enum Tuning {
    // Steering: lateral acceleration at full lock, and how fast sideways speed bleeds off.
    // acceleration / drag = top sideways speed (about 6.8 m/s on snow, response ~0.12 s).
    static let steerAccel: Float = 58
    static let snowDrag: Float = 8.5
    static let airDrag: Float = 3.0
    static let iceDrag: Float = 1.4
    static let iceSteerScale: Float = 0.55
    static let airSteerScale: Float = 0.35
    static let stunSteerScale: Float = 0.25
    /// Ice patches are ellipses: the stretch multiplies their radius along the track.
    static let icePatchStretch: Float = 1.8

    // Curves push the sled toward the outside wall; riding the wall costs speed.
    static let cornerPull: Float = 3.0
    static let cornerPullCap: Float = 14
    static let wallScrapeSpeed: Float = 0.9
    static let wallScrapeTime: Float = 0.25
    /// Limits on how much shorter (or longer) a racing line can be than the centre line.
    static let lineFactorRange: ClosedRange<Float> = 0.9...1.1

    // A crash. Speed left after the hit, how long the sled is stunned (steering and top speed
    // are crippled), and the grace period after that before it can be hit again. Together they
    // cost roughly a second, so a mistake is felt but a clean run is never out of reach.
    static let crashSpeedFactor: Float = 0.34
    static let crashStun: Float = 0.7
    static let crashInvuln: Float = 1.0
    /// Top speed while stunned, as a fraction of normal.
    static let stunSpeedFactor: Float = 0.32
    /// How far back a splash puts the sled, in metres (it never goes behind the last checkpoint).
    static let splashSetback: Float = 30

    // Rivals.
    static let aiSteerAuthority: Float = 0.85
    static let aiTurboRegen: Float = 0.045
    static let bandSlow: Float = 0.08
    static let bandCatchUp: Float = 0.09

    // Turbo. Crystals fuel it, holding BOOST burns it, and a pad or rocket gives a burst
    // without spending any. These numbers set how much driving well is worth: a full
    // crystal run is worth about three seconds of boost over a course.
    static let boostSpeedMultiplier: Float = 1.32
    static let boostDrain: Float = 0.26
    static let boostPush: Float = 20
    static let crystalFuel: Float = 0.09
    static let comboFuel: Float = 0.04
    static let padBoostTime: Float = 1.3
    /// Powered speed outlives a frame of boosting by this long, so frame timing can't flicker it.
    static let boostGrace: Float = 0.05
    static let rocketSpeedMultiplier: Float = 1.36

    // Avalanche: how far behind the player the wall appears when it starts running.
    static let avalancheHeadStart: Float = 0.045

    // Ghost recording.
    static let ghostInterval: Float = 0.125
    static let ghostMaxSamples = 1000

    // The HUD only needs to redraw about this often.
    static let hudInterval: Float = 1.0 / 30.0
}

final class GameEngine: ObservableObject {
    @Published private(set) var hud = HUDSnapshot.empty
    @Published private(set) var phase: RacePhase = .idle
    @Published var paused = false

    var onFinished: ((RaceResult) -> Void)?

    private(set) var level: LevelDefinition?
    private(set) var path: TrackPath?
    private(set) var racers: [Racer] = []
    private(set) var entities: [LiveEntity] = []
    private(set) var droppedBananas: [PlacedEntity] = []
    private(set) var raceTime: TimeInterval = 0
    private(set) var cameraEye = SIMD3<Float>(0, 8, -8)
    private(set) var cameraLook = SIMD3<Float>(0, 2, 8)
    private(set) var cameraFOV: Float = 50
    private(set) var landingPulse: Float = 0
    private(set) var cameraShake: Float = 0
    private(set) var toastTimer: Float = 0
    private(set) var toastText = ""

    /// Swipe steering as set by the view: drag distance in points / 60, not yet clamped.
    var steerInput: Float = 0
    var boostHeld: Bool = false
    var dropBananaRequested: Bool = false

    let worldController = WorldController()
    private var settings = GameSettings.default
    private var countdownLeft: TimeInterval = 3.2
    private var lastCountdownDigit = 4
    private var finishHold: TimeInterval = 0
    /// Time since the player crossed the line; rivals still racing keep their own clock.
    private var coastTime: TimeInterval = 0
    private var resultEmitted = false
    private var motion: CMMotionManager?
    private var tiltInput: Float = 0
    private var windPhase: Float = 0
    private var bobClock: Float = 0
    private var boostPrimed: Float = 0
    private var rewardedTurboUsed = false
    private var hudAccumulator: Float = 0
    private(set) var combo = 0
    private(set) var comboMax = 0
    private var comboTimer: Float = 0
    private static let comboWindow: Float = 1.65
    private(set) var nearMisses = 0
    private(set) var avalancheFront: Float = 0
    private(set) var avalancheThreat = false
    private var avalancheEvent: CourseEvent?
    private var avalancheActive = false
    private var avalancheSpent = false
    private var avalancheBuried: Set<UUID> = []
    private var avalancheRumble: Float = 0
    private(set) var ghostPose: (progress: Float, lateral: Float, height: Float)?
    private var recordedGhost: [GhostSample] = []
    private var playbackGhost: GhostTake?
    private var ghostClock: Float = 0
    private var nearMissed: Set<UUID> = []
    private var usedShortcuts: Set<UUID> = []
    private var peelBorn: [UUID: TimeInterval] = [:]
    private var bumpCooldown: Float = 0
    private var scrapeHaptic: Float = 0
    private(set) var dailyGoal: DailyChallenge.Goal?

    var dailyRun: Bool { dailyGoal != nil }

    func start(level: LevelDefinition, settings: GameSettings, ghost: GhostTake? = nil, dailyGoal: DailyChallenge.Goal? = nil) {
        self.settings = settings
        self.level = level
        AudioHaptics.shared.apply(settings: settings)
        path = TrackPath.build(from: level)
        self.dailyGoal = dailyGoal
        combo = 0
        comboMax = 0
        comboTimer = 0
        nearMisses = 0
        avalancheFront = 0
        avalancheThreat = false
        avalancheEvent = level.events.first { $0.kind == .avalanche }
        avalancheActive = false
        avalancheSpent = false
        avalancheBuried = []
        avalancheRumble = 0
        ghostPose = nil
        recordedGhost = []
        playbackGhost = (settings.showGhost && ghost?.isUsable == true) ? ghost : nil
        ghostClock = 0
        nearMissed = []
        usedShortcuts = []
        var pack: [Racer] = [RacerFactory.player(startLateral: 0, skin: settings.selectedSkin)]
        pack.append(contentsOf: level.rivals.map(RacerFactory.rival))
        racers = pack
        spreadStartGrid(path: path!)
        bumpCooldown = 0
        scrapeHaptic = 0
        entities = level.entities.map {
            LiveEntity(definition: $0, collected: false, destroyed: false, liveLateral: $0.lateral, phase: $0.progress * 17)
        }
        droppedBananas = []
        peelBorn = [:]
        raceTime = 0
        coastTime = 0
        bobClock = 0
        boostPrimed = 0
        tiltInput = 0
        hudAccumulator = 0
        countdownLeft = 3.25
        lastCountdownDigit = 4
        finishHold = 0
        resultEmitted = false
        rewardedTurboUsed = false
        paused = false
        phase = .countdown(3)
        toastText = ""
        toastTimer = 0
        landingPulse = 0
        cameraShake = 0
        cameraFOV = 50
        configureMotion()
        worldController.build(level: level, path: path!, racers: racers)
        if let path, let player = playerRacer {
            let sample = path.sample(at: player.progress)
            let pos = path.worldPosition(progress: player.progress, lateral: player.lateral, height: 0)
            cameraEye = pos - sample.tangent * 6.4 + sample.normal * 3.15
            cameraLook = pos + sample.tangent * 9.5 + sample.normal * 0.35
        }
        publishHUD(force: true)
    }

    func restart() {
        guard let level else { return }
        start(level: level, settings: settings, ghost: playbackGhost, dailyGoal: dailyGoal)
    }

    func capturedGhost() -> GhostTake? {
        guard recordedGhost.count > 8 else { return nil }
        var samples = recordedGhost
        // Close the take on the finish line so the replay ends where the run did.
        if let player = playerRacer, let finish = player.finishTime {
            samples.append(GhostSample(t: Float(finish), p: player.progress, l: player.lateral, h: 0))
        }
        return GhostTake(time: playerRacer?.finishTime ?? raceTime, samples: samples)
    }

    func stop() {
        phase = .idle
        paused = false
        teardownMotion()
    }

    /// Called after a user-opt-in rewarded video. Once per race.
    func grantRewardedTurbo() {
        guard !rewardedTurboUsed, let i = racers.firstIndex(where: \.isPlayer) else { return }
        rewardedTurboUsed = true
        racers[i].turbo = 1
        racers[i].trailBoost = 0.45
        racers[i].boostTime = 0.45
        toast("Turbo refilled!")
        AudioHaptics.shared.power()
        publishHUD(force: true)
    }

    func tick(dt rawDT: TimeInterval) {
        guard level != nil, path != nil, phase != .idle else { return }
        if paused { return }
        let dt = GameMath.clamp(Float(rawDT), 1.0 / 240.0, 1.0 / 20.0)
        switch phase {
        case .countdown:
            updateCountdown(TimeInterval(dt))
            bobIdle(dt)
            worldController.apply(engine: self, dt: dt)
            publishHUD(dt: dt)
        case .racing:
            simulate(dt: dt)
            worldController.apply(engine: self, dt: dt)
            publishHUD(dt: dt)
        case .finished:
            finishHold += TimeInterval(dt)
            simulateCoasting(dt: dt)
            worldController.apply(engine: self, dt: dt)
            publishHUD(dt: dt)
            if !resultEmitted && finishHold > 1.15 {
                resultEmitted = true
                onFinished?(makeResult())
            }
        case .idle:
            break
        }
    }

    func makeResult() -> RaceResult {
        let ranked = rankedRacers()
        let times = finishTimes(for: ranked)
        let playerPlace = (ranked.firstIndex(where: { $0.isPlayer }) ?? 0) + 1
        let player = racers.first(where: { $0.isPlayer })
        let time = player?.finishTime ?? raceTime
        let crystals = player?.crystals ?? 0
        let parTime = level?.parTime ?? 50
        let crystalGoal = level?.crystalStar ?? 24
        let points = StarRules.points(
            place: playerPlace,
            crystals: crystals,
            crystalGoal: crystalGoal,
            time: time,
            parTime: parTime
        )
        let standings = ranked.enumerated().map { index, racer in
            PodiumEntry(
                id: racer.id.uuidString,
                name: racer.name,
                place: index + 1,
                time: times[index],
                isPlayer: racer.isPlayer,
                color: racer.sledColor
            )
        }
        return RaceResult(
            level: level?.id ?? .villageDash,
            place: playerPlace,
            fieldSize: racers.count,
            time: time,
            crystals: crystals,
            crystalTotal: level?.crystalCount ?? 0,
            stars: StarRules.stars(points: points),
            podium: Array(standings.prefix(3)),
            comboMax: comboMax,
            nearMisses: nearMisses,
            unlockedSkin: nil,
            daily: dailyGoal != nil,
            parTime: parTime,
            crystalGoal: crystalGoal,
            crashes: player?.hits ?? 0,
            standings: standings,
            dailyGoal: dailyGoal
        )
    }

    var playerRacer: Racer? { racers.first(where: { $0.isPlayer }) }

    // MARK: - Simulation

    private func updateCountdown(_ dt: TimeInterval) {
        countdownLeft -= dt
        // Tapping BOOST as the light turns green launches the sled; holding it from the
        // start of the countdown does not.
        if boostHeld { boostPrimed += Float(dt) } else { boostPrimed = 0 }
        let digit: Int
        if countdownLeft > 2 { digit = 3 }
        else if countdownLeft > 1 { digit = 2 }
        else if countdownLeft > 0 { digit = 1 }
        else { digit = 0 }
        if digit != lastCountdownDigit {
            lastCountdownDigit = digit
            if digit == 0 {
                launch()
            } else if digit > 0 {
                AudioHaptics.shared.countdown()
                phase = .countdown(digit)
            }
        }
        if countdownLeft <= 0 {
            phase = .racing
        }
    }

    private func launch() {
        AudioHaptics.shared.go()
        phase = .racing
        toast("GO!")
        if boostPrimed > 0.05, boostPrimed < 1.0, let i = racers.firstIndex(where: \.isPlayer) {
            racers[i].speed += 3.5
            racers[i].trailBoost = 0.8
            racers[i].boostTime = 0.8
            AudioHaptics.shared.power()
        }
    }

    /// Idle sway while the countdown runs. It has its own clock: the race clock must stay
    /// at zero until the light turns green.
    private func bobIdle(_ dt: Float) {
        bobClock += dt
        for i in racers.indices {
            racers[i].height = 0.04 + sin(bobClock + Float(i) * 3) * 0.02
            racers[i].yaw = path?.sample(at: racers[i].progress).heading ?? 0
        }
        updateCamera(dt: dt)
    }

    private func simulate(dt: Float) {
        guard let path, let level else { return }
        raceTime += TimeInterval(dt)
        windPhase += dt
        updateTilt(dt: dt)
        animateMovers(dt: dt)
        for i in racers.indices {
            if racers[i].finished { continue }
            if racers[i].isPlayer {
                stepPlayer(index: i, dt: dt, path: path)
            } else {
                stepAI(index: i, dt: dt, path: path)
            }
            integrateRacer(index: i, dt: dt, path: path, level: level)
            resolveCollisions(index: i, path: path)
            if racers[i].isPlayer {
                // Crystals and power-ups belong to the player; rivals earn turbo over time
                // instead, so they can never empty a lane before the player reaches it.
                collectPickups(index: i, path: path)
            }
            resolvePads(index: i, path: path)
            resolveCheckpoints(index: i)
            if racers[i].isPlayer {
                detectNearMiss(index: i, path: path)
                resolveShortcuts(index: i, path: path, level: level)
                recordGhost(index: i, dt: dt)
            }
            if racers[i].progress >= 0.992 && !racers[i].finished {
                racers[i].finished = true
                racers[i].finishTime = raceTime
                racers[i].progress = 0.993
                if racers[i].isPlayer {
                    AudioHaptics.shared.finish()
                    toast("Finish!")
                    phase = .finished
                    finishHold = 0
                }
            }
        }
        updateAvalanche(dt: dt, path: path)
        updatePeels()
        bumpCooldown = max(0, bumpCooldown - dt)
        scrapeHaptic = max(0, scrapeHaptic - dt)
        cameraShake = max(0, cameraShake - dt * 3)
        separateRacers(path: path)
        landingPulse = max(0, landingPulse - dt * 2.4)
        tickCombo(dt: dt)
        playbackGhostPose()
        if toastTimer > 0 {
            toastTimer -= dt
            if toastTimer <= 0 { toastText = "" }
        }
        updateCamera(dt: dt)
    }

    private func simulateCoasting(dt: Float) {
        guard let path, let level else { return }
        coastTime += TimeInterval(dt)
        for i in racers.indices where !racers[i].finished {
            stepAI(index: i, dt: dt, path: path)
            integrateRacer(index: i, dt: dt, path: path, level: level)
            if racers[i].progress >= 0.992 {
                racers[i].finished = true
                racers[i].finishTime = raceTime + coastTime
            }
        }
        for i in racers.indices where racers[i].finished {
            racers[i].speed = GameMath.damp(racers[i].speed, 8, lambda: 2.2, dt: dt)
            racers[i].progress = min(0.997, racers[i].progress + racers[i].speed * dt / path.length)
        }
        separateRacers(path: path)
        // Nothing left to wait for once everyone is over the line.
        if racers.allSatisfy(\.finished) { finishHold = max(finishHold, 1.15) }
        cameraShake = max(0, cameraShake - dt * 3)
        landingPulse = max(0, landingPulse - dt * 2.4)
        if toastTimer > 0 {
            toastTimer -= dt
            if toastTimer <= 0 { toastText = "" }
        }
        updateCamera(dt: dt)
    }

    /// Spaces the pack evenly across the start line so no sled spawns inside another.
    /// Rivals keep their authored left-to-right order; the player takes the middle slot.
    private func spreadStartGrid(path: TrackPath) {
        let n = racers.count
        guard n > 1 else { return }
        let half = path.width(at: racers[0].progress) * 0.5 - 0.9
        let spacing = min(2.4, 2 * half / Float(n - 1))
        let slots = (0..<n).map { (Float($0) - Float(n - 1) / 2) * spacing }
        let playerSlot = slots.indices.min(by: { abs(slots[$0]) < abs(slots[$1]) }) ?? 0
        let rivalSlots = slots.indices.filter { $0 != playerSlot }
        let rivalOrder = racers.indices
            .filter { !racers[$0].isPlayer }
            .sorted { racers[$0].lateral < racers[$1].lateral }
        for (slot, i) in zip(rivalSlots, rivalOrder) {
            racers[i].lateral = slots[slot]
        }
        if let p = racers.firstIndex(where: \.isPlayer) {
            racers[p].lateral = slots[playerSlot]
        }
    }

    /// Soft sled-to-sled contact: overlapping racers are pushed apart sideways so
    /// nobody drives through anyone. The player feels a light bump.
    private func separateRacers(path: TrackPath) {
        let reach: Float = 1.35
        for a in racers.indices {
            for b in racers.indices where b > a {
                if abs(racers[a].height - racers[b].height) > 0.6 { continue }
                let along = (racers[a].progress - racers[b].progress) * path.length
                let side = racers[a].lateral - racers[b].lateral
                guard abs(along) < reach, abs(side) < reach else { continue }
                let dir: Float = side == 0 ? (a % 2 == 0 ? 1 : -1) : (side > 0 ? 1 : -1)
                let push = (reach - abs(side)) * 0.5
                racers[a].lateral += dir * push
                racers[b].lateral -= dir * push
                racers[a].lateralVel += dir * 3
                racers[b].lateralVel -= dir * 3
                if (racers[a].isPlayer || racers[b].isPlayer) && bumpCooldown <= 0 {
                    bumpCooldown = 0.35
                    cameraShake = max(cameraShake, 0.3)
                    AudioHaptics.shared.tap(.light)
                }
            }
        }
        for i in racers.indices {
            let half = path.width(at: racers[i].progress) * 0.5 - 0.7
            racers[i].lateral = GameMath.clamp(racers[i].lateral, -half, half)
        }
    }

    // MARK: - Input

    /// Swipe (scaled by the sensitivity setting, eased so small drags stay precise) plus tilt.
    private func effectiveSteer() -> Float {
        let raw = GameMath.clamp(steerInput * settings.steerSensitivity, -1, 1)
        let shaped = raw * (0.55 + 0.45 * abs(raw))
        return GameMath.clamp(shaped + tiltInput, -1, 1)
    }

    private func stepPlayer(index i: Int, dt: Float, path: TrackPath) {
        applySteering(index: i, input: effectiveSteer(), dt: dt, path: path)
        if dropBananaRequested {
            dropBananaRequested = false
            dropBanana(from: i)
        }
        if boostHeld {
            tryBoost(index: i, dt: dt)
        }
    }

    private func stepAI(index i: Int, dt: Float, path: TrackPath) {
        let racer = racers[i]
        let width = path.width(at: racer.progress)
        let half = width * 0.5 - 0.9
        let here = path.sample(at: racer.progress)
        let ahead = path.sample(at: min(1, racer.progress + 0.05))

        // Base line: lean toward the inside of the next bend.
        var targetLateral = -GameMath.wrapAngle(ahead.heading - here.heading) * 5.0

        // Keep clear of neighbours.
        var crowd: Float = 0
        for j in racers.indices where j != i {
            let other = racers[j]
            if abs(other.progress - racer.progress) < 0.028 {
                let gap = other.lateral - racer.lateral
                if abs(gap) < 2.5 { crowd += gap > 0 ? -1 : 1 }
            }
        }
        targetLateral += crowd * 1.6

        if racer.personality == .aggressive, let player = playerRacer, !player.finished,
           abs(player.progress - racer.progress) < 0.05 {
            // Aggressive rivals lean on the player.
            targetLateral = GameMath.lerp(targetLateral, player.lateral, 0.45)
        }

        // Hazards and peels ahead: steer to the nearer side that clears them. How far ahead a
        // rival looks, how wide a berth it takes and how often it misses one is personality.
        let notice: Float
        let berth: Float
        let missPercent: Int
        switch racer.personality {
        case .cautious: notice = 0.09; berth = 1.0; missPercent = 3
        case .aggressive: notice = 0.05; berth = 0.4; missPercent = 10
        case .hoarder: notice = 0.07; berth = 0.7; missPercent = 7
        case .none: notice = 0.07; berth = 0.7; missPercent = 6
        }
        var threats: [(dp: Float, lateral: Float, radius: Float)] = []
        for entity in entities where !entity.collected && !entity.destroyed {
            let kind = entity.definition.kind
            guard CollisionClass.solidHazards.contains(kind) || kind == .water else { continue }
            guard entity.definition.radius > 0 else { continue }
            let dp = entity.definition.progress - racer.progress
            guard dp > 0 && dp < notice else { continue }
            if Self.overlooks(racer.id, entity.definition.id, percent: missPercent) { continue }
            threats.append((dp, entity.liveLateral, entity.definition.radius))
        }
        // Peels are visible from a distance, but not every rival spots one in time.
        for peel in droppedBananas {
            let dp = peel.progress - racer.progress
            guard dp > 0 && dp < 0.06 else { continue }
            if Self.overlooks(racer.id, peel.id, percent: 35) { continue }
            threats.append((dp, peel.lateral, peel.radius))
        }
        threats.sort { $0.dp < $1.dp }
        for threat in threats {
            let clear = threat.radius + 0.7 + berth
            guard abs(targetLateral - threat.lateral) < clear else { continue }
            let left = threat.lateral - clear
            let right = threat.lateral + clear
            let canLeft = left >= -half
            let canRight = right <= half
            if canLeft && canRight {
                targetLateral = abs(left - racer.lateral) <= abs(right - racer.lateral) ? left : right
            } else if canLeft {
                targetLateral = left
            } else if canRight {
                targetLateral = right
            }
        }

        targetLateral = GameMath.clamp(targetLateral, -half, half)
        let error = targetLateral - racer.lateral
        var input = GameMath.clamp(error * 0.22, -1, 1)
        // Rivals lean into the bend against the pull, so they hold their line.
        input -= 0.8 * cornerPull(for: racers[i], sample: here) / (Tuning.steerAccel * Tuning.aiSteerAuthority)
        applySteering(index: i, input: GameMath.clamp(input, -1, 1), dt: dt, path: path, authority: Tuning.aiSteerAuthority)
        racers[i].turbo = min(1, racers[i].turbo + Tuning.aiTurboRegen * dt)
        decideAIBoost(index: i, dt: dt)
    }

    /// A stable per-pair coin flip: does this rival fail to notice this obstacle?
    private static func overlooks(_ racer: UUID, _ obstacle: UUID, percent: Int) -> Bool {
        (Int(racer.uuid.0) &* 31 &+ Int(obstacle.uuid.0) &* 17 &+ Int(obstacle.uuid.1)) % 100 < percent
    }

    /// Sideways acceleration a bend puts on a sled (positive pushes toward the right wall).
    private func cornerPull(for racer: Racer, sample: TrackSample) -> Float {
        if racer.airborne { return 0 }
        let raw = sample.curvature * racer.speed * racer.speed * Tuning.cornerPull
        return GameMath.clamp(raw, -Tuning.cornerPullCap, Tuning.cornerPullCap)
    }

    private func applySteering(index i: Int, input: Float, dt: Float, path: TrackPath, authority: Float = 1) {
        let ice = isOnIce(racers[i])
        var accel = Tuning.steerAccel * authority
        var drag = Tuning.snowDrag
        if ice {
            accel *= Tuning.iceSteerScale
            drag = Tuning.iceDrag
        }
        if racers[i].airborne {
            accel *= Tuning.airSteerScale
            drag = Tuning.airDrag
        }
        if racers[i].stunned > 0 {
            accel *= Tuning.stunSteerScale
        }
        let sample = path.sample(at: racers[i].progress)
        var pull = cornerPull(for: racers[i], sample: sample)
        if ice { pull *= 1.4 }
        racers[i].lateralVel += (input * accel + pull) * dt
        racers[i].lateralVel *= exp(-drag * dt)
        racers[i].lateral += racers[i].lateralVel * dt
        let half = sample.width * 0.5 - 0.7
        if racers[i].lateral > half {
            racers[i].lateral = half
            if racers[i].lateralVel > 0.5 { scrapeWall(index: i) }
            racers[i].lateralVel *= -0.3
        } else if racers[i].lateral < -half {
            racers[i].lateral = -half
            if racers[i].lateralVel < -0.5 { scrapeWall(index: i) }
            racers[i].lateralVel *= -0.3
        }
        racers[i].roll = GameMath.damp(racers[i].roll, -input * 0.45 - racers[i].lateralVel * 0.02, lambda: 8, dt: dt)
        racers[i].yaw = sample.heading
    }

    /// Grinding along the wall bleeds speed for a moment after contact.
    private func scrapeWall(index i: Int) {
        racers[i].scrape = Tuning.wallScrapeTime
        if racers[i].isPlayer && scrapeHaptic <= 0 {
            scrapeHaptic = 0.3
            AudioHaptics.shared.tap(.light)
        }
    }

    private func integrateRacer(index i: Int, dt: Float, path: TrackPath, level: LevelDefinition) {
        racers[i].stunned = max(0, racers[i].stunned - dt)
        racers[i].invuln = max(0, racers[i].invuln - dt)
        racers[i].ghostTime = max(0, racers[i].ghostTime - dt)
        racers[i].magnetTime = max(0, racers[i].magnetTime - dt)
        racers[i].rocketTime = max(0, racers[i].rocketTime - dt)
        racers[i].flareTime = max(0, racers[i].flareTime - dt)
        racers[i].bananaCooldown = max(0, racers[i].bananaCooldown - dt)
        racers[i].trailBoost = max(0, racers[i].trailBoost - dt)
        racers[i].boostTime = max(0, racers[i].boostTime - dt)
        racers[i].scrape = max(0, racers[i].scrape - dt)
        racers[i].squash = GameMath.damp(racers[i].squash, 1, lambda: 14, dt: dt)

        let sample = path.sample(at: racers[i].progress)
        var maxSpeed: Float = 13.5 + sample.slope * 22
        maxSpeed *= racers[i].skill
        if !racers[i].isPlayer, let player = playerRacer {
            maxSpeed *= rubberBand(lead: racers[i].progress - player.progress)
        }
        if racers[i].rocketTime > 0 { maxSpeed *= Tuning.rocketSpeedMultiplier }
        if racers[i].boostTime > 0 { maxSpeed *= Tuning.boostSpeedMultiplier }
        if racers[i].stunned > 0 { maxSpeed *= Tuning.stunSpeedFactor }
        if racers[i].scrape > 0 { maxSpeed *= Tuning.wallScrapeSpeed }
        if isOnIce(racers[i]) { maxSpeed *= 1.06 }

        var accel: Float = 10 + sample.slope * 16
        if racers[i].airborne { accel *= 0.35 }
        racers[i].speed += accel * dt
        racers[i].speed = min(racers[i].speed, maxSpeed)

        // The inside of a bend is a shorter road: a sled hugging it covers the same stretch of
        // track with less distance. Positive curvature is a left turn and the inside is the
        // left (negative lateral), so curvature * lateral is negative on the inside line.
        let line = GameMath.clamp(1 + sample.curvature * racers[i].lateral, Tuning.lineFactorRange.lowerBound, Tuning.lineFactorRange.upperBound)
        racers[i].progress += (racers[i].speed * dt) / (path.length * line)
        racers[i].progress = min(racers[i].progress, 0.997)

        if racers[i].height > 0.04 || racers[i].verticalVel > 0.1 {
            racers[i].airborne = true
            racers[i].verticalVel -= 34 * dt
            racers[i].height += racers[i].verticalVel * dt
            if racers[i].height <= 0 {
                racers[i].lateralVel *= 0.50
                if racers[i].verticalVel < -5 {
                    racers[i].squash = 0.58
                    landingPulse = 1
                    if racers[i].isPlayer { AudioHaptics.shared.tap(.medium) }
                }
                racers[i].height = 0
                racers[i].verticalVel = 0
                racers[i].airborne = false
            }
        } else {
            racers[i].airborne = false
            racers[i].height = 0
        }
        racers[i].pitch = GameMath.damp(racers[i].pitch, racers[i].airborne ? racers[i].verticalVel * 0.03 : sample.slope * 0.4, lambda: 6, dt: dt)

        if level.theme == .summit {
            for entity in entities where entity.definition.kind == .wind {
                if abs(entity.definition.progress - racers[i].progress) < 0.05 {
                    let gust = sin(windPhase * 2.4 + entity.phase) * 10
                    racers[i].lateralVel += gust * dt
                }
            }
        }
    }

    /// Keeps the pack together without stealing the win: a rival far ahead of the player
    /// eases off, one far behind catches up. It blends smoothly, so nobody lurches when
    /// they cross a threshold.
    private func rubberBand(lead: Float) -> Float {
        if lead >= 0 {
            return 1 - Tuning.bandSlow * GameMath.smoothstep(0.02, 0.10, lead)
        }
        return 1 + Tuning.bandCatchUp * GameMath.smoothstep(0.02, 0.14, -lead)
    }

    private func tryBoost(index i: Int, dt: Float) {
        guard racers[i].turbo > 0.02, racers[i].stunned <= 0 else { return }
        racers[i].turbo = max(0, racers[i].turbo - Tuning.boostDrain * dt)
        racers[i].speed += Tuning.boostPush * dt
        racers[i].trailBoost = 0.28
        racers[i].boostTime = max(racers[i].boostTime, Tuning.boostGrace)
        if racers[i].isPlayer && Int(raceTime * 8) % 8 == 0 {
            AudioHaptics.shared.boost()
        }
    }

    private func decideAIBoost(index i: Int, dt: Float) {
        let r = racers[i]
        guard r.turbo > 0.08, r.stunned <= 0 else { return }
        var should = false
        switch r.personality {
        case .aggressive:
            should = r.progress > 0.12 && r.turbo > 0.15
            if let player = playerRacer, player.progress > r.progress, player.progress - r.progress < 0.06 {
                should = true
            }
        case .cautious:
            should = r.progress > 0.55 && isClearAhead(r)
        case .hoarder:
            should = r.progress > 0.72 || r.rocketTime > 0
        case .none:
            should = r.progress > 0.4
        }
        if should { tryBoost(index: i, dt: dt) }
    }

    private func isClearAhead(_ racer: Racer) -> Bool {
        !entities.contains { entity in
            guard CollisionClass.solidHazards.contains(entity.definition.kind), !entity.destroyed else { return false }
            guard entity.definition.radius > 0 else { return false }
            let dp = entity.definition.progress - racer.progress
            return dp > 0 && dp < 0.05 && abs(entity.liveLateral - racer.lateral) < 2.4
        }
    }

    private func animateMovers(dt: Float) {
        _ = dt
        let t = Float(raceTime)
        for i in entities.indices {
            let kind = entities[i].definition.kind
            if kind == .cart || kind == .npc || kind == .movingBridge {
                let amp: Float = kind == .movingBridge ? 2.8 : (kind == .cart ? 3.6 : 4.4)
                let rate: Float = kind == .movingBridge ? 1.15 : 1.7
                entities[i].liveLateral = entities[i].definition.lateral + sin(t * rate + entities[i].phase) * amp
            } else {
                entities[i].liveLateral = entities[i].definition.lateral
            }
        }
    }

    private func resolveCollisions(index i: Int, path: TrackPath) {
        guard racers[i].invuln <= 0, racers[i].stunned <= 0 else { return }
        let r = racers[i]
        for e in entities.indices {
            guard !entities[e].destroyed && !entities[e].collected else { continue }
            let def = entities[e].definition
            if def.kind == .water {
                if overlap(racer: r, progress: def.progress, lateral: entities[e].liveLateral, radius: def.radius, path: path) {
                    drown(index: i)
                    return
                }
                continue
            }
            guard CollisionClass.solidHazards.contains(def.kind), def.radius > 0 else { continue }
            if overlap(racer: r, progress: def.progress, lateral: entities[e].liveLateral, radius: def.radius, path: path) {
                if racers[i].ghostTime > 0 {
                    racers[i].ghostTime = 0
                    entities[e].destroyed = def.kind == .crate || def.kind == .snowman
                    if racers[i].isPlayer { toast("Phased!") }
                    continue
                }
                smash(index: i)
                if def.kind == .crate { entities[e].destroyed = true }
                return
            }
        }
        // A peel is used up by whoever slips on it.
        if let peel = droppedBananas.first(where: {
            overlap(racer: r, progress: $0.progress, lateral: $0.lateral, radius: $0.radius, path: path)
        }) {
            droppedBananas.removeAll { $0.id == peel.id }
            peelBorn[peel.id] = nil
            smash(index: i, factor: 0.55)
            if racers[i].isPlayer { toast("Banana!") }
            return
        }
        for j in racers.indices where j != i {
            let other = racers[j]
            let ds = (r.progress - other.progress) * path.length
            let dl = r.lateral - other.lateral
            if ds * ds + dl * dl < 2.1 {
                racers[i].lateralVel += (dl >= 0 ? 1 : -1) * 2.8
                racers[i].speed *= 0.97
            }
        }
    }

    private func collectPickups(index i: Int, path: TrackPath) {
        let magnet = racers[i].magnetTime > 0
        for e in entities.indices {
            guard !entities[e].collected && !entities[e].destroyed else { continue }
            let def = entities[e].definition
            guard CollisionClass.pickups.contains(def.kind) else { continue }
            var radius = def.radius
            if magnet && def.kind == .crystal { radius = 5.5 }
            if overlap(racer: racers[i], progress: def.progress, lateral: entities[e].liveLateral, radius: radius, path: path) {
                entities[e].collected = true
                applyPickup(index: i, kind: def.kind)
            } else if magnet && def.kind == .crystal {
                let dp = def.progress - racers[i].progress
                if abs(dp) < 0.05 {
                    entities[e].definition.progress = GameMath.damp(def.progress, racers[i].progress, lambda: 8, dt: 1.0 / 60.0)
                    entities[e].liveLateral = GameMath.damp(entities[e].liveLateral, racers[i].lateral, lambda: 8, dt: 1.0 / 60.0)
                }
            }
        }
    }

    private func applyPickup(index i: Int, kind: PropKind) {
        switch kind {
        case .crystal:
            racers[i].crystals += 1
            racers[i].turbo = min(1, racers[i].turbo + Tuning.crystalFuel)
            if racers[i].isPlayer {
                AudioHaptics.shared.collect()
                bumpCombo("Crystal")
            }
        case .rocket:
            racers[i].rocketTime = 1.8
            racers[i].speed += 8
            racers[i].trailBoost = 1.8
            racers[i].boostTime = max(racers[i].boostTime, 1.8)
            if racers[i].isPlayer { AudioHaptics.shared.power(); toast("Rocket!") }
        case .magnet:
            racers[i].magnetTime = 6
            if racers[i].isPlayer { AudioHaptics.shared.power(); toast("Magnet!") }
        case .ghost:
            racers[i].ghostTime = 4
            if racers[i].isPlayer { AudioHaptics.shared.power(); toast("Ghost!") }
        case .banana:
            racers[i].bananaArmed = true
            if racers[i].isPlayer { AudioHaptics.shared.power(); toast("Peel ready") }
        case .flare:
            racers[i].flareTime = 8
            if racers[i].isPlayer { AudioHaptics.shared.power(); toast("Flare!") }
        default:
            break
        }
    }

    private func resolvePads(index i: Int, path: TrackPath) {
        guard !racers[i].airborne || racers[i].height < 0.4 else { return }
        for e in entities where CollisionClass.pads.contains(e.definition.kind) {
            if overlap(racer: racers[i], progress: e.definition.progress, lateral: e.liveLateral, radius: e.definition.radius, path: path) {
                if e.definition.kind == .ramp {
                    racers[i].verticalVel = 14.8
                    racers[i].height = max(racers[i].height, 0.22)
                    racers[i].speed += 5.5
                    racers[i].trailBoost = 0.5
                    racers[i].boostTime = max(racers[i].boostTime, 0.5)
                    racers[i].airborne = true
                    if racers[i].isPlayer { AudioHaptics.shared.whoosh() }
                } else if e.definition.kind == .turboPad {
                    racers[i].speed += 7.5
                    racers[i].trailBoost = max(racers[i].trailBoost, Tuning.padBoostTime)
                    racers[i].boostTime = max(racers[i].boostTime, Tuning.padBoostTime)
                    if racers[i].isPlayer {
                        AudioHaptics.shared.boost()
                    }
                }
            }
        }
    }

    private func resolveCheckpoints(index i: Int) {
        guard let level else { return }
        for cp in level.checkpoints where cp > racers[i].lastCheckpoint + 0.001 {
            if racers[i].progress >= cp {
                racers[i].lastCheckpoint = cp
                if racers[i].isPlayer && cp > 0 {
                    toast("Checkpoint")
                    AudioHaptics.shared.tap(.light)
                }
            }
        }
    }

    // MARK: - Peels

    private static let maxPeels = 3
    private static let peelLifetime: TimeInterval = 20

    private func dropBanana(from index: Int) {
        guard racers[index].bananaArmed, racers[index].bananaCooldown <= 0 else { return }
        racers[index].bananaArmed = false
        racers[index].bananaCooldown = 1.2
        let peel = PlacedEntity(
            kind: .banana,
            progress: max(0.01, racers[index].progress - 0.012),
            lateral: racers[index].lateral,
            scale: 1,
            radius: 1.1
        )
        droppedBananas.append(peel)
        peelBorn[peel.id] = raceTime
        // The oldest peel makes room for a new one.
        while droppedBananas.count > Self.maxPeels {
            let old = droppedBananas.removeFirst()
            peelBorn[old.id] = nil
        }
        if racers[index].isPlayer { toast("Peel dropped") }
    }

    /// Peels that nobody slipped on fade after a while.
    private func updatePeels() {
        guard !droppedBananas.isEmpty else { return }
        let expired = droppedBananas.filter { raceTime - (peelBorn[$0.id] ?? raceTime) > Self.peelLifetime }
        guard !expired.isEmpty else { return }
        let ids = Set(expired.map(\.id))
        droppedBananas.removeAll { ids.contains($0.id) }
        for id in ids { peelBorn[id] = nil }
    }

    private func smash(index i: Int, factor: Float = Tuning.crashSpeedFactor) {
        racers[i].speed *= factor
        racers[i].stunned = Tuning.crashStun
        racers[i].invuln = Tuning.crashInvuln
        racers[i].squash = 0.7
        racers[i].lateralVel *= -0.6
        racers[i].hits += 1
        if racers[i].isPlayer {
            cameraShake = 1
            AudioHaptics.shared.crash()
            toast("Oof!")
        }
    }

    /// A splash puts the racer back on the track a little way behind the water (never
    /// behind their last checkpoint), slowed and stunned. The lost ground is the sting:
    /// about three seconds, as the harbor courses promise.
    private func drown(index i: Int) {
        guard let path else { return }
        let floor = max(racers[i].lastCheckpoint + 0.005, 0.012)
        racers[i].progress = max(floor, racers[i].progress - Tuning.splashSetback / path.length)
        racers[i].lateral = 0
        racers[i].lateralVel = 0
        racers[i].speed *= 0.45
        racers[i].height = 0.5
        racers[i].verticalVel = 0
        racers[i].invuln = 1.3
        racers[i].stunned = Tuning.crashStun
        racers[i].hits += 1
        if racers[i].isPlayer {
            cameraShake = 0.8
            AudioHaptics.shared.crash()
            toast("Splash!")
        }
    }

    private func overlap(racer: Racer, progress: Float, lateral: Float, radius: Float, path: TrackPath) -> Bool {
        let ds = (racer.progress - progress) * path.length
        let dl = racer.lateral - lateral
        let dh = racer.height
        let rad = radius + 0.7
        return ds * ds + dl * dl + dh * dh * 0.35 < rad * rad
    }

    /// Ice patches are drawn as stretched ellipses, and the grip test uses the same shape.
    private func isOnIce(_ racer: Racer) -> Bool {
        guard let length = path?.length else { return false }
        return entities.contains { entity in
            guard entity.definition.kind == .icePatch else { return false }
            let across = entity.definition.radius
            let along = across * Tuning.icePatchStretch
            let ds = (entity.definition.progress - racer.progress) * length
            let dl = entity.liveLateral - racer.lateral
            return (ds * ds) / (along * along) + (dl * dl) / (across * across) < 1
        }
    }

    private func rankedRacers() -> [Racer] {
        racers.sorted { a, b in
            if a.finished && b.finished {
                return (a.finishTime ?? 999) < (b.finishTime ?? 999)
            }
            if a.finished != b.finished { return a.finished }
            return a.progress > b.progress
        }
    }

    /// Finish times in ranked order. Anyone still on the course gets an estimate from
    /// where they are and how fast they are moving, so the standings always have gaps.
    private func finishTimes(for ranked: [Racer]) -> [TimeInterval] {
        let clock = raceTime + coastTime
        let length = path?.length ?? 0
        var previous: TimeInterval = 0
        return ranked.map { racer in
            var t: TimeInterval
            if let finish = racer.finishTime {
                t = finish
            } else {
                let remaining = Double(max(0, 0.992 - racer.progress) * length)
                t = clock + remaining / Double(max(racer.speed, 8))
            }
            t = max(t, previous + 0.01)
            previous = t
            return t
        }
    }

    private func toast(_ text: String) {
        toastText = text
        toastTimer = 1.35
    }

    private func publishHUD(dt: Float = 0, force: Bool = false) {
        hudAccumulator += dt
        guard force || hudAccumulator >= Tuning.hudInterval else { return }
        hudAccumulator = 0
        let ranked = rankedRacers()
        let playerPlace = (ranked.firstIndex(where: { $0.isPlayer }) ?? 0) + 1
        let player = playerRacer
        let digit: Int?
        let go: Bool
        if case .countdown(let n) = phase {
            digit = n
            go = false
        } else if toastText == "GO!" {
            digit = 0
            go = true
        } else {
            digit = nil
            go = false
        }
        var gap: Float = -1
        if avalancheActive, let player, let path, !avalancheBuried.contains(player.id) {
            gap = max(0, (player.progress - avalancheFront) * path.length)
        }
        let snap = HUDSnapshot(
            place: playerPlace,
            fieldSize: racers.count,
            progress: player?.progress ?? 0,
            rivalProgress: racers.filter { !$0.isPlayer }.map(\.progress),
            crystals: player?.crystals ?? 0,
            crystalTotal: level?.crystalCount ?? 0,
            turbo: player?.turbo ?? 0,
            time: raceTime,
            countdown: digit,
            goFlash: go,
            magnetActive: (player?.magnetTime ?? 0) > 0,
            ghostActive: (player?.ghostTime ?? 0) > 0,
            rocketActive: (player?.rocketTime ?? 0) > 0,
            bananaArmed: player?.bananaArmed ?? false,
            toast: toastText,
            checkpoints: level?.checkpoints.filter { $0 > 0 } ?? [],
            speedKph: Int((player?.speed ?? 0) * 4.2),
            levelName: level?.name ?? "",
            rewardedTurboUsed: rewardedTurboUsed,
            racing: phase == .racing,
            combo: combo,
            nearMisses: nearMisses,
            flareActive: (player?.flareTime ?? 0) > 0,
            avalancheThreat: avalancheThreat,
            avalancheProgress: avalancheFront,
            comboFraction: combo > 0 ? GameMath.saturate(comboTimer / Self.comboWindow) : 0,
            avalancheGap: gap,
            rivalColors: racers.filter { !$0.isPlayer }.map(\.sledColor),
            parTime: level?.parTime ?? 0,
            crystalGoal: level?.crystalStar ?? 0,
            courseNumber: (level?.id.order ?? 0) + 1,
            ghostGap: ghostGapSeconds()
        )
        DispatchQueue.main.async { [weak self] in
            self?.hud = snap
        }
    }

    /// Seconds the best-run ghost is ahead of the player (positive) or behind (negative).
    private func ghostGapSeconds() -> Float? {
        guard phase == .racing, let pose = ghostPose, let player = playerRacer, let path else { return nil }
        let metres = (pose.progress - player.progress) * path.length
        return metres / max(player.speed, 8)
    }

    private func updateCamera(dt: Float) {
        guard let path, let player = playerRacer else { return }
        let sample = path.sample(at: player.progress)
        let pos = path.worldPosition(progress: player.progress, lateral: player.lateral, height: player.height)
        // Faster = lower, closer and wider, so speed reads on screen; boost punches the FOV.
        let rush = GameMath.saturate((player.speed - 11) / 9)
        let boosting = player.trailBoost > 0 || player.rocketTime > 0
        let back: Float = (player.rocketTime > 0 ? 7.4 : 6.4) - rush * 0.7
        let up: Float = 3.15 - rush * 0.45
        let desiredEye = pos - sample.tangent * back + sample.normal * up
        let desiredLook = pos + sample.tangent * 9.5 + sample.normal * 0.35
        cameraEye = GameMath.damp3(cameraEye, desiredEye, lambda: 7.5, dt: dt)
        cameraLook = GameMath.damp3(cameraLook, desiredLook, lambda: 9, dt: dt)
        let targetFOV: Float = 50 + rush * 6 + (boosting ? 9 : 0)
        cameraFOV = GameMath.damp(cameraFOV, targetFOV, lambda: boosting ? 7 : 4, dt: dt)
    }

    // MARK: - Combo and near misses

    private func bumpCombo(_ reason: String) {
        combo += 1
        comboTimer = Self.comboWindow
        comboMax = max(comboMax, combo)
        if combo >= 2 {
            if let i = racers.firstIndex(where: \.isPlayer) {
                racers[i].turbo = min(1, racers[i].turbo + Tuning.comboFuel)
            }
            toast("\(reason) x\(combo)")
            AudioHaptics.shared.comboHit()
        }
    }

    private func tickCombo(dt: Float) {
        guard comboTimer > 0 else { return }
        comboTimer -= dt
        if comboTimer <= 0 { combo = 0 }
    }

    private func detectNearMiss(index i: Int, path: TrackPath) {
        let r = racers[i]
        for entity in entities where !entity.destroyed && !entity.collected {
            guard CollisionClass.solidHazards.contains(entity.definition.kind) else { continue }
            // Scenery that shares a prop kind with a hazard has no radius and never counts.
            guard entity.definition.radius > 0 else { continue }
            let ds = (r.progress - entity.definition.progress) * path.length
            let dl = abs(r.lateral - entity.liveLateral)
            let inner = entity.definition.radius + 0.65
            let outer = entity.definition.radius + 2.2
            if ds > 0.12 && ds < 1.85 && dl > inner && dl < outer {
                if nearMissed.insert(entity.definition.id).inserted {
                    nearMisses += 1
                    bumpCombo("Near miss")
                }
            }
        }
    }

    // MARK: - Avalanche

    /// The wall launches when the player reaches the start of its zone and appears a short
    /// way behind them. If it catches a racer it buries them once (a big loss of speed, and
    /// a stun), then runs on ahead until the end of the zone.
    private func updateAvalanche(dt: Float, path: TrackPath) {
        guard let event = avalancheEvent, let player = playerRacer else {
            avalancheThreat = false
            return
        }
        if !avalancheActive && !avalancheSpent && player.progress >= event.start {
            avalancheActive = true
            avalancheFront = max(0, player.progress - Tuning.avalancheHeadStart)
            cameraShake = max(cameraShake, 0.8)
            toast("AVALANCHE!")
            AudioHaptics.shared.whoosh()
        }
        guard avalancheActive else {
            avalancheThreat = false
            return
        }
        avalancheFront += event.magnitude * dt
        if avalancheFront >= event.end || player.finished {
            avalancheActive = false
            avalancheSpent = true
            avalancheThreat = false
            return
        }
        avalancheThreat = true
        for i in racers.indices where !racers[i].finished {
            guard racers[i].progress < avalancheFront, !avalancheBuried.contains(racers[i].id) else { continue }
            avalancheBuried.insert(racers[i].id)
            racers[i].speed *= 0.3
            racers[i].stunned = 1.0
            racers[i].invuln = 1.6
            racers[i].squash = 0.6
            racers[i].hits += 1
            if racers[i].isPlayer {
                cameraShake = 1
                AudioHaptics.shared.crash()
                toast("Buried!")
            }
        }
        // Rumble builds as the wall closes in, so the danger registers without looking back.
        let gap = (player.progress - avalancheFront) * path.length
        if gap > 0 && gap < 30 && !avalancheBuried.contains(player.id) {
            let closeness = 1 - gap / 30
            cameraShake = max(cameraShake, closeness * 0.35)
            avalancheRumble -= dt
            if gap < 18 && avalancheRumble <= 0 {
                avalancheRumble = 0.35
                AudioHaptics.shared.tap(.light)
            }
        }
    }

    // MARK: - Shortcuts

    private func resolveShortcuts(index i: Int, path: TrackPath, level: LevelDefinition) {
        for entity in entities where entity.definition.kind == .shortcut && !entity.collected {
            if overlap(
                racer: racers[i],
                progress: entity.definition.progress,
                lateral: entity.liveLateral,
                radius: entity.definition.radius,
                path: path
            ), usedShortcuts.insert(entity.definition.id).inserted {
                let skip = level.events.first {
                    $0.kind == .shortcut && abs($0.start - entity.definition.progress) < 0.01
                }?.magnitude ?? 0.028
                racers[i].progress = min(0.97, racers[i].progress + skip)
                racers[i].speed += 4
                toast("Shortcut!")
                bumpCombo("Cut")
                AudioHaptics.shared.whoosh()
            }
        }
    }

    // MARK: - Ghost

    private func recordGhost(index i: Int, dt: Float) {
        ghostClock += dt
        guard ghostClock >= Tuning.ghostInterval else { return }
        ghostClock -= Tuning.ghostInterval
        guard recordedGhost.count < Tuning.ghostMaxSamples else { return }
        let r = racers[i]
        // Rounded so a saved take stays small once it is encoded.
        recordedGhost.append(GhostSample(
            t: (Float(raceTime) * 100).rounded() / 100,
            p: (r.progress * 10_000).rounded() / 10_000,
            l: (r.lateral * 20).rounded() / 20,
            h: (r.height * 20).rounded() / 20
        ))
    }

    private func playbackGhostPose() {
        guard settings.showGhost, let take = playbackGhost, !take.samples.isEmpty else {
            ghostPose = nil
            return
        }
        let t = Float(raceTime)
        if t <= take.samples[0].t {
            let s = take.samples[0]
            ghostPose = (s.p, s.l, s.h)
            return
        }
        if t >= take.samples[take.samples.count - 1].t {
            let s = take.samples[take.samples.count - 1]
            ghostPose = (s.p, s.l, s.h)
            return
        }
        var lo = 0
        var hi = take.samples.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if take.samples[mid].t <= t { lo = mid } else { hi = mid }
        }
        let a = take.samples[lo]
        let b = take.samples[hi]
        let span = max(0.001, b.t - a.t)
        let u = (t - a.t) / span
        ghostPose = (
            GameMath.lerp(a.p, b.p, u),
            GameMath.lerp(a.l, b.l, u),
            GameMath.lerp(a.h, b.h, u)
        )
    }

    // MARK: - Tilt

    private func configureMotion() {
        teardownMotion()
        guard settings.tiltSteering else { return }
        let mgr = CMMotionManager()
        if mgr.isAccelerometerAvailable {
            mgr.accelerometerUpdateInterval = 1.0 / 30.0
            mgr.startAccelerometerUpdates()
            motion = mgr
        }
    }

    /// Lean the phone to steer, added to whatever the finger is doing. A small dead zone
    /// keeps hand tremor from steering, and full lock is reached at roughly 25 degrees.
    private func updateTilt(dt: Float) {
        guard settings.tiltSteering, let data = motion?.accelerometerData else {
            tiltInput = 0
            return
        }
        let x = Float(data.acceleration.x)
        let dead: Float = 0.06
        let magnitude = GameMath.saturate((abs(x) - dead) / (0.42 - dead))
        let target: Float = x < 0 ? -magnitude : magnitude
        tiltInput = GameMath.damp(tiltInput, target, lambda: 14, dt: dt)
    }

    private func teardownMotion() {
        motion?.stopAccelerometerUpdates()
        motion = nil
        tiltInput = 0
    }
}
