import CoreMotion
import Foundation
import simd

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
    private(set) var toastTimer: Float = 0
    private(set) var toastText = ""

    var steerInput: Float = 0
    var boostHeld: Bool = false
    var dropBananaRequested: Bool = false

    let worldController = WorldController()
    private var settings = GameSettings.default
    private var countdownLeft: TimeInterval = 3.2
    private var lastCountdownDigit = 4
    private var finishHold: TimeInterval = 0
    private var resultEmitted = false
    private var motion: CMMotionManager?
    private var windPhase: Float = 0
    private var timePenalty: TimeInterval = 0
    private var rewardedTurboUsed = false
    private(set) var combo = 0
    private(set) var comboMax = 0
    private var comboTimer: Float = 0
    private(set) var nearMisses = 0
    private(set) var avalancheFront: Float = 0
    private(set) var avalancheThreat = false
    private(set) var ghostPose: (progress: Float, lateral: Float, height: Float)?
    private var recordedGhost: [GhostSample] = []
    private var playbackGhost: GhostTake?
    private var ghostClock: Float = 0
    private var nearMissed: Set<UUID> = []
    private var usedShortcuts: Set<UUID> = []
    private(set) var dailyRun = false

    func start(level: LevelDefinition, settings: GameSettings, ghost: GhostTake? = nil, daily: Bool = false) {
        self.settings = settings
        self.level = level
        AudioHaptics.shared.apply(settings: settings)
        path = TrackPath.build(from: level)
        dailyRun = daily
        combo = 0
        comboMax = 0
        comboTimer = 0
        nearMisses = 0
        avalancheFront = 0
        avalancheThreat = false
        ghostPose = nil
        recordedGhost = []
        playbackGhost = settings.showGhost ? ghost : nil
        ghostClock = 0
        nearMissed = []
        usedShortcuts = []
        var pack: [Racer] = [RacerFactory.player(startLateral: 0, skin: settings.selectedSkin)]
        pack.append(contentsOf: level.rivals.map(RacerFactory.rival))
        racers = pack
        entities = level.entities.map {
            LiveEntity(definition: $0, collected: false, destroyed: false, liveLateral: $0.lateral, phase: $0.progress * 17)
        }
        droppedBananas = []
        raceTime = 0
        timePenalty = 0
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
        cameraFOV = 50
        configureMotion()
        worldController.build(level: level, path: path!, racers: racers)
        if let path, let player = playerRacer {
            let sample = path.sample(at: player.progress)
            let pos = path.worldPosition(progress: player.progress, lateral: player.lateral, height: 0)
            cameraEye = pos - sample.tangent * 6.4 + sample.normal * 3.15
            cameraLook = pos + sample.tangent * 9.5 + sample.normal * 0.35
        }
        publishHUD()
    }

    func restart() {
        guard let level else { return }
        start(level: level, settings: settings, ghost: playbackGhost, daily: dailyRun)
    }

    func capturedGhost() -> GhostTake? {
        guard recordedGhost.count > 8 else { return nil }
        return GhostTake(time: playerRacer?.finishTime ?? raceTime, samples: recordedGhost)
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
        toast("Turbo refilled!")
        AudioHaptics.shared.power()
        publishHUD()
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
            publishHUD()
        case .racing:
            simulate(dt: dt)
            worldController.apply(engine: self, dt: dt)
            publishHUD()
        case .finished:
            finishHold += TimeInterval(dt)
            simulateCoasting(dt: dt)
            worldController.apply(engine: self, dt: dt)
            publishHUD()
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
        let playerPlace = (ranked.firstIndex(where: { $0.isPlayer }) ?? 0) + 1
        let player = racers.first(where: { $0.isPlayer })
        let time = player?.finishTime ?? raceTime
        let crystals = player?.crystals ?? 0
        let stars = starRating(place: playerPlace, crystals: crystals, time: time)
        let podium = ranked.prefix(3).enumerated().map { index, racer in
            PodiumEntry(
                id: racer.id.uuidString,
                name: racer.name,
                place: index + 1,
                time: racer.finishTime,
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
            stars: stars,
            podium: Array(podium),
            comboMax: comboMax,
            nearMisses: nearMisses,
            unlockedSkin: nil,
            daily: dailyRun
        )
    }

    var playerRacer: Racer? { racers.first(where: { $0.isPlayer }) }

    // MARK: - Simulation

    private func updateCountdown(_ dt: TimeInterval) {
        countdownLeft -= dt
        let digit: Int
        if countdownLeft > 2 { digit = 3 }
        else if countdownLeft > 1 { digit = 2 }
        else if countdownLeft > 0 { digit = 1 }
        else { digit = 0 }
        if digit != lastCountdownDigit {
            lastCountdownDigit = digit
            if digit == 0 {
                AudioHaptics.shared.go()
                phase = .racing
                toast("GO!")
            } else if digit > 0 {
                AudioHaptics.shared.countdown()
                phase = .countdown(digit)
            }
        }
        if countdownLeft <= 0 {
            phase = .racing
        }
    }

    private func bobIdle(_ dt: Float) {
        for i in racers.indices {
            racers[i].height = 0.04 + sin(Float(raceTime + Double(i)) * 3) * 0.02
            racers[i].yaw = path?.sample(at: racers[i].progress).heading ?? 0
        }
        raceTime += TimeInterval(dt) * 0.15
        updateCamera(dt: dt)
    }

    private func simulate(dt: Float) {
        guard let path, let level else { return }
        raceTime += TimeInterval(dt)
        windPhase += dt
        applyTiltIfNeeded()
        animateMovers(dt: dt)
        for i in racers.indices {
            if racers[i].finished { continue }
            if racers[i].isPlayer {
                stepPlayer(index: i, dt: dt, path: path, level: level)
            } else {
                stepAI(index: i, dt: dt, path: path, level: level)
            }
            integrateRacer(index: i, dt: dt, path: path, level: level)
            resolveCollisions(index: i, path: path)
            collectPickups(index: i, path: path)
            resolvePads(index: i, path: path)
            resolveCheckpoints(index: i)
            if racers[i].isPlayer {
                detectNearMiss(index: i, path: path)
                resolveEvents(index: i, dt: dt, path: path, level: level)
                recordGhost(index: i, dt: dt)
            }
            if racers[i].progress >= 0.992 && !racers[i].finished {
                racers[i].finished = true
                racers[i].finishTime = raceTime + timePenalty
                racers[i].progress = 0.993
                if racers[i].isPlayer {
                    AudioHaptics.shared.finish()
                    toast("Finish!")
                    phase = .finished
                    finishHold = 0
                }
            }
        }
        if playerRacer?.finished == true {
            let allDone = racers.allSatisfy(\.finished)
            if allDone { finishHold = max(finishHold, 1.0) }
        }
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
        for i in racers.indices where !racers[i].finished {
            stepAI(index: i, dt: dt, path: path, level: level)
            integrateRacer(index: i, dt: dt, path: path, level: level)
            if racers[i].progress >= 0.992 {
                racers[i].finished = true
                racers[i].finishTime = raceTime + timePenalty
            }
        }
        for i in racers.indices where racers[i].finished {
            racers[i].speed = GameMath.damp(racers[i].speed, 8, lambda: 2.2, dt: dt)
            racers[i].progress = min(0.997, racers[i].progress + racers[i].speed * dt / path.length)
        }
        updateCamera(dt: dt)
    }

    private func stepPlayer(index i: Int, dt: Float, path: TrackPath, level: LevelDefinition) {
        _ = level
        let steer = GameMath.clamp(steerInput, -1, 1)
        applySteering(index: i, input: steer, dt: dt, path: path)
        if dropBananaRequested {
            dropBananaRequested = false
            dropBanana(from: i)
        }
        if boostHeld {
            tryBoost(index: i, dt: dt)
        }
    }

    private func stepAI(index i: Int, dt: Float, path: TrackPath, level: LevelDefinition) {
        let racer = racers[i]
        let look = min(1, racer.progress + 0.045)
        var targetLateral: Float = 0
        var avoid: Float = 0
        for j in racers.indices where j != i {
            let other = racers[j]
            if abs(other.progress - racer.progress) < 0.028 {
                let gap = other.lateral - racer.lateral
                if abs(gap) < 2.5 { avoid += gap > 0 ? -1.15 : 1.15 }
            }
        }
        for entity in entities where !entity.collected && !entity.destroyed {
            let kind = entity.definition.kind
            guard CollisionClass.solidHazards.contains(kind) || kind == .water else { continue }
            let dp = entity.definition.progress - racer.progress
            if dp > 0 && dp < 0.08 {
                let gap = entity.liveLateral - racer.lateral
                let caution: Float = racer.personality == .cautious ? 1.5 : (racer.personality == .aggressive ? 0.7 : 1.0)
                if abs(gap) < entity.definition.radius + 2.2 * caution {
                    avoid += gap > 0 ? -1 : 1
                }
            }
        }
        if let sample = Optional(path.sample(at: look)) {
            targetLateral -= sample.heading * 0.35
        }
        switch racer.personality {
        case .aggressive:
            if let player = playerRacer, !player.finished {
                if abs(player.progress - racer.progress) < 0.05 {
                    targetLateral = GameMath.lerp(targetLateral, player.lateral, 0.45)
                }
            }
            targetLateral += avoid * 2.4
        case .cautious:
            targetLateral += avoid * 3.6
        case .hoarder:
            targetLateral += avoid * 2.8
        case .none:
            targetLateral += avoid * 2.5
        }
        let width = path.width(at: racer.progress)
        targetLateral = GameMath.clamp(targetLateral, -width * 0.32, width * 0.32)
        let error = targetLateral - racer.lateral
        let input = GameMath.clamp(error * 0.22, -1, 1)
        applySteering(index: i, input: input, dt: dt, path: path)
        decideAIBoost(index: i, dt: dt)
        _ = level
    }

    private func applySteering(index i: Int, input: Float, dt: Float, path: TrackPath) {
        let ice = isOnIce(racers[i])
        var steerPower: Float = racers[i].airborne ? 14 : 38
        var friction: Float = ice ? 0.18 : 0.68
        if racers[i].stunned > 0 {
            steerPower *= 0.25
        }
        racers[i].lateralVel += input * steerPower * dt
        racers[i].lateralVel *= pow(friction, dt * 60)
        racers[i].lateral += racers[i].lateralVel * dt
        let half = path.width(at: racers[i].progress) * 0.5 - 0.7
        if racers[i].lateral > half {
            racers[i].lateral = half
            racers[i].lateralVel *= -0.3
        } else if racers[i].lateral < -half {
            racers[i].lateral = -half
            racers[i].lateralVel *= -0.3
        }
        racers[i].roll = GameMath.damp(racers[i].roll, -input * 0.45 - racers[i].lateralVel * 0.02, lambda: 8, dt: dt)
        racers[i].yaw = path.sample(at: racers[i].progress).heading
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
        racers[i].squash = GameMath.damp(racers[i].squash, 1, lambda: 14, dt: dt)

        let sample = path.sample(at: racers[i].progress)
        var maxSpeed: Float = 13.5 + sample.slope * 22
        maxSpeed *= racers[i].skill
        if !racers[i].isPlayer, let player = playerRacer {
            let lead = racers[i].progress - player.progress
            if lead > 0.07 { maxSpeed *= 0.90 }
            else if lead < -0.12 { maxSpeed *= 1.08 }
            else if lead < -0.06 { maxSpeed *= 1.05 }
        }
        if racers[i].rocketTime > 0 { maxSpeed *= 1.55 }
        if racers[i].trailBoost > 0 { maxSpeed *= 1.22 }
        if racers[i].stunned > 0 { maxSpeed *= 0.42 }
        if isOnIce(racers[i]) { maxSpeed *= 1.06 }

        var accel: Float = 10 + sample.slope * 16
        if racers[i].airborne { accel *= 0.35 }
        racers[i].speed += accel * dt
        racers[i].speed = min(racers[i].speed, maxSpeed)
        racers[i].speed = GameMath.damp(racers[i].speed, min(racers[i].speed, maxSpeed), lambda: 1.2, dt: dt)

        racers[i].progress += (racers[i].speed * dt) / path.length
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
        _ = level
    }

    private func tryBoost(index i: Int, dt: Float) {
        guard racers[i].turbo > 0.02, racers[i].stunned <= 0 else { return }
        racers[i].turbo = max(0, racers[i].turbo - 0.30 * dt)
        racers[i].speed += 18 * dt
        racers[i].trailBoost = 0.28
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
            guard CollisionClass.solidHazards.contains(def.kind) else { continue }
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
        for banana in droppedBananas {
            if overlap(racer: r, progress: banana.progress, lateral: banana.lateral, radius: 1.1, path: path) {
                smash(index: i, factor: 0.55)
                if racers[i].isPlayer { toast("Banana!") }
            }
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
            racers[i].turbo = min(1, racers[i].turbo + 0.07)
            if racers[i].isPlayer {
                AudioHaptics.shared.collect()
                bumpCombo("Crystal")
            }
        case .rocket:
            racers[i].rocketTime = 1.8
            racers[i].speed += 8
            racers[i].trailBoost = 1.8
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
                    racers[i].airborne = true
                    if racers[i].isPlayer { AudioHaptics.shared.whoosh() }
                } else if e.definition.kind == .turboPad {
                    racers[i].speed += 7.5
                    racers[i].trailBoost = 0.9
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
        if racers[index].isPlayer { toast("Peel dropped") }
    }

    private func smash(index i: Int, factor: Float = 0.48) {
        racers[i].speed *= factor
        racers[i].stunned = 0.38
        racers[i].invuln = 0.55
        racers[i].squash = 0.7
        racers[i].lateralVel *= -0.6
        if racers[i].isPlayer {
            AudioHaptics.shared.crash()
            toast("Oof!")
        }
    }

    private func drown(index i: Int) {
        guard let path else { return }
        racers[i].progress = racers[i].lastCheckpoint + 0.01
        racers[i].lateral = 0
        racers[i].lateralVel = 0
        racers[i].speed *= 0.45
        racers[i].height = 0.5
        racers[i].verticalVel = 0
        racers[i].invuln = 1.3
        racers[i].stunned = 0.4
        if racers[i].isPlayer {
            timePenalty += 3
            AudioHaptics.shared.crash()
            toast("+3s splash")
        }
        _ = path
    }

    private func overlap(racer: Racer, progress: Float, lateral: Float, radius: Float, path: TrackPath) -> Bool {
        let ds = (racer.progress - progress) * path.length
        let dl = racer.lateral - lateral
        let dh = racer.height
        let rad = radius + 0.7
        return ds * ds + dl * dl + dh * dh * 0.35 < rad * rad
    }

    private func isOnIce(_ racer: Racer) -> Bool {
        entities.contains { entity in
            entity.definition.kind == .icePatch
                && abs(entity.definition.progress - racer.progress) < 0.018
                && abs(entity.liveLateral - racer.lateral) < entity.definition.radius
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

    private func starRating(place: Int, crystals: Int, time: TimeInterval) -> Int {
        var score = 1
        if place == 1 { score += 2 }
        else if place == 2 { score += 1 }
        if crystals >= (level?.crystalStar ?? 24) { score += 1 }
        if time <= (level?.parTime ?? 50) { score += 1 }
        return GameMath.clamp(Float(score), 1, 3).rounded(.down).intStars
    }

    private func toast(_ text: String) {
        toastText = text
        toastTimer = 1.35
    }

    private func publishHUD() {
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
        let snap = HUDSnapshot(
            place: playerPlace,
            fieldSize: racers.count,
            progress: player?.progress ?? 0,
            rivalProgress: racers.filter { !$0.isPlayer }.map(\.progress),
            crystals: player?.crystals ?? 0,
            crystalTotal: level?.crystalCount ?? 0,
            turbo: player?.turbo ?? 0,
            time: raceTime + timePenalty,
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
            avalancheProgress: avalancheFront
        )
        DispatchQueue.main.async { [weak self] in
            self?.hud = snap
        }
    }

    private func updateCamera(dt: Float) {
        guard let path, let player = playerRacer else { return }
        let sample = path.sample(at: player.progress)
        let pos = path.worldPosition(progress: player.progress, lateral: player.lateral, height: player.height)
        let back: Float = player.rocketTime > 0 ? 7.4 : 6.4
        let up: Float = 3.15
        let desiredEye = pos - sample.tangent * back + sample.normal * up
        let desiredLook = pos + sample.tangent * 9.5 + sample.normal * 0.35
        cameraEye = GameMath.damp3(cameraEye, desiredEye, lambda: 7.5, dt: dt)
        cameraLook = GameMath.damp3(cameraLook, desiredLook, lambda: 9, dt: dt)
        let targetFOV: Float = (player.trailBoost > 0 || player.rocketTime > 0) ? 58 : 50
        cameraFOV = GameMath.damp(cameraFOV, targetFOV, lambda: 5, dt: dt)
    }

    private func bumpCombo(_ reason: String) {
        combo += 1
        comboTimer = 1.65
        comboMax = max(comboMax, combo)
        if combo >= 2 {
            if let i = racers.firstIndex(where: \.isPlayer) {
                racers[i].turbo = min(1, racers[i].turbo + 0.035)
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

    private func resolveEvents(index i: Int, dt: Float, path: TrackPath, level: LevelDefinition) {
        _ = dt
        avalancheThreat = false
        for event in level.events where event.kind == .avalanche {
            let span = max(0.08, event.end - event.start)
            let travel = min(span, Float(raceTime) * event.magnitude)
            avalancheFront = event.start + travel
            if racers[i].progress > event.start - 0.04 && racers[i].progress < event.end {
                avalancheThreat = true
                if racers[i].progress + 0.012 < avalancheFront && racers[i].invuln <= 0 {
                    smash(index: i, factor: 0.62)
                    racers[i].progress = min(racers[i].progress + 0.01, avalancheFront + 0.004)
                    toast("Avalanche!")
                }
            }
        }
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

    private func recordGhost(index i: Int, dt: Float) {
        ghostClock += dt
        guard ghostClock >= 0.08 else { return }
        ghostClock = 0
        let r = racers[i]
        recordedGhost.append(GhostSample(t: Float(raceTime), p: r.progress, l: r.lateral, h: r.height))
        if recordedGhost.count > 280 {
            recordedGhost.removeFirst(recordedGhost.count - 280)
        }
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

    private func applyTiltIfNeeded() {
        guard settings.tiltSteering, let data = motion?.accelerometerData else { return }
        let x = Float(data.acceleration.x)
        steerInput = GameMath.clamp(steerInput * 0.35 + x * 1.6, -1, 1)
    }

    private func teardownMotion() {
        motion?.stopAccelerometerUpdates()
        motion = nil
    }
}

private extension Float {
    var intStars: Int { Int(self) }
}
