// Scripted players. A bot plans its lane with a small dynamic program over (metres ahead) x (lateral
// position): crystals, power-ups and pads pay out, hazards cost, and the inside of a bend pays a
// little for the time it saves. Skill levels differ in look-ahead, reaction time, aiming noise,
// clearance and how they use turbo, which is enough to spread their finish times the way real
// players spread.
import Foundation

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

func gauss(_ rng: inout SplitMix64) -> Float {
    let u1 = max(Float.random(in: 0..<1, using: &rng), 1e-6)
    let u2 = Float.random(in: 0..<1, using: &rng)
    return (-2 * log(u1)).squareRoot() * cos(2 * Float.pi * u2)
}

struct BotProfile {
    var name: String
    var steers: Bool = true
    var reaction: Float        // seconds between decisions
    var lookahead: Float       // metres of hazard look-ahead
    var margin: Float          // extra clearance around hazards
    var crystalGreed: Float
    var padGreed: Float
    var noise: Float           // metres of aiming noise per decision
    var boostUse: Float        // chance of holding boost during a burst while the meter has charge
    var lineGreed: Float = 0   // how much the bot values hugging the inside of a bend

    static let idle = BotProfile(name: "idle", steers: false, reaction: 1, lookahead: 0, margin: 0, crystalGreed: 0, padGreed: 0, noise: 0, boostUse: 1)
    static let novice = BotProfile(name: "novice", reaction: 0.50, lookahead: 18, margin: 0.0, crystalGreed: 0.3, padGreed: 0.3, noise: 0.9, boostUse: 0.35, lineGreed: 0)
    static let casual = BotProfile(name: "casual", reaction: 0.30, lookahead: 26, margin: 0.2, crystalGreed: 0.6, padGreed: 0.6, noise: 0.45, boostUse: 0.6, lineGreed: 0.3)
    static let good = BotProfile(name: "good", reaction: 0.18, lookahead: 34, margin: 0.35, crystalGreed: 1.0, padGreed: 1.0, noise: 0.2, boostUse: 0.85, lineGreed: 0.7)
    static let expert = BotProfile(name: "expert", reaction: 0.08, lookahead: 44, margin: 0.4, crystalGreed: 1.5, padGreed: 1.5, noise: 0.08, boostUse: 1.0, lineGreed: 1.0)
    static let all: [BotProfile] = [.idle, .novice, .casual, .good, .expert]
    static func named(_ n: String) -> BotProfile? { all.first { $0.name == n } }
}

let botBinW: Float = 0.5
let botLatCap: Float = 6.5
let botKP: Float = 0.7
let botKD: Float = 0.06

final class Bot {
    let p: BotProfile
    var rng: SplitMix64
    var target: Float = 0
    var clock: Float = 0
    var nextDecision: Float = 0
    var boostOn = false
    var nextBoostToggle: Float = 0

    init(_ profile: BotProfile, seed: UInt64) {
        p = profile
        rng = SplitMix64(seed: seed)
    }

    func update(_ engine: GameEngine, dt: Float) {
        guard engine.phase == .racing, let me = engine.playerRacer, let path = engine.path else {
            engine.steerInput = 0
            return
        }
        clock += dt
        if p.steers {
            if clock >= nextDecision {
                nextDecision = clock + p.reaction
                target = decide(engine: engine, me: me, path: path)
            }
            let e = target - me.lateral
            engine.steerInput = max(-1, min(1, botKP * e - botKD * me.lateralVel))
        } else {
            engine.steerInput = 0
        }
        // boost in bursts
        if clock >= nextBoostToggle {
            nextBoostToggle = clock + 0.7
            boostOn = me.turbo > 0.03 && Float.random(in: 0..<1, using: &rng) < p.boostUse
        }
        engine.boostHeld = boostOn && me.turbo > 0.02
        // drop the peel when someone is right behind
        if me.bananaArmed {
            for r in engine.racers where !r.isPlayer {
                let d = (me.progress - r.progress) * path.length
                if d > 2 && d < 30 && abs(r.lateral - me.lateral) < 3.5 { engine.dropBananaRequested = true }
            }
        }
    }

    /// Dynamic-programming lane planner: a grid of (metres ahead) x (lateral bin). Each step the sled can
    /// shift a limited number of bins; crystals, power-ups and pads pay out, hazards cost. The best path's
    /// first step is the steering target. Lookahead, aiming noise and reaction time degrade it for weaker bots.
    private func decide(engine: GameEngine, me: Racer, path: TrackPath) -> Float {
        let len = path.length
        let sp = max(me.speed, 10)
        let half = path.width(at: me.progress) * 0.5 - 0.9
        let stepLen: Float = 3.0
        let binW: Float = botBinW
        let steps = max(2, Int(p.lookahead / stepLen))
        let nBins = Int((2 * half / binW).rounded()) + 1
        func lat(_ j: Int) -> Float { -half + Float(j) * binW }
        let maxShiftBins = max(1, Int((botLatCap * (stepLen / sp) / binW).rounded(.down)))

        // reward[k][j]: what the cell at step k (1...steps), bin j is worth
        var reward = [[Float]](repeating: [Float](repeating: 0, count: nBins), count: steps + 1)
        func stepIndex(_ ds: Float) -> Int { Int((ds / stepLen).rounded()) }
        for e in engine.entities where !e.collected && !e.destroyed {
            let d = e.definition
            let ds = (d.progress - me.progress) * len
            if ds < -3 || ds > p.lookahead + 8 { continue }
            switch d.kind {
            case let k where (CollisionClass.solidHazards.contains(k) || k == .water) && d.radius > 0:
                let clear = d.radius + 0.7 + p.margin
                let k0 = stepIndex(ds - (d.radius + 0.7)), k1 = stepIndex(ds + (d.radius + 0.7))
                if k1 < 1 || k0 > steps { continue }
                for k in max(1, k0)...min(steps, max(k0, k1)) {
                    for j in 0..<nBins where abs(lat(j) - e.liveLateral) < clear { reward[k][j] -= 40 }
                }
            case .crystal, .rocket, .magnet, .ghost, .banana, .flare:
                let w: Float = d.kind == .crystal ? 1 : 3
                let k = stepIndex(ds)
                if k < 1 || k > steps { continue }
                for j in 0..<nBins where abs(lat(j) - e.liveLateral) < 1.3 { reward[k][j] += p.crystalGreed * w }
            case .turboPad, .ramp:
                let w: Float = d.kind == .turboPad ? 3 : 1.5
                let k = stepIndex(ds)
                if k < 1 || k > steps { continue }
                for j in 0..<nBins where abs(lat(j) - e.liveLateral) < d.radius + 0.3 { reward[k][j] += p.padGreed * w }
            default:
                break
            }
        }
        // racing line: cells on the inside of a bend save time. Time saved per step is
        // (step time) * -(curvature * lateral); crystal-equivalents are ~0.09 s each.
        if p.lineGreed > 0 {
            for k in 1...steps {
                let kappa = path.curvature(at: me.progress + Float(k) * stepLen / len)
                for j in 0..<nBins {
                    reward[k][j] += p.lineGreed * (-kappa * lat(j)) * (stepLen / sp) / 0.09
                }
            }
        }
        // backward DP
        var value = [[Float]](repeating: [Float](repeating: 0, count: nBins), count: steps + 2)
        for k in stride(from: steps, through: 1, by: -1) {
            for j in 0..<nBins {
                var best = -Float.greatestFiniteMagnitude
                for dj in -maxShiftBins...maxShiftBins {
                    let nj = j + dj
                    if nj < 0 || nj >= nBins { continue }
                    let v = reward[k][nj] + value[k + 1][nj] - 0.04 * Float(abs(dj))
                    if v > best { best = v }
                }
                value[k][j] = best
            }
        }
        // choose the first move from the current bin
        let j0 = max(0, min(nBins - 1, Int(((me.lateral + half) / binW).rounded())))
        var bestJ = j0
        var bestV = -Float.greatestFiniteMagnitude
        for dj in -maxShiftBins...maxShiftBins {
            let nj = j0 + dj
            if nj < 0 || nj >= nBins { continue }
            let v = reward[1][nj] + value[2][nj] - 0.04 * Float(abs(dj)) - (abs(lat(nj)) > half - 0.4 ? 0.3 : 0)
            if v > bestV { bestV = v; bestJ = nj }
        }
        // aim a couple of steps out so the sled commits to the line rather than dithering
        var aim = lat(bestJ)
        if steps >= 3 {
            var j = bestJ
            for k in 2...min(3, steps) {
                var bj = j
                var bv = -Float.greatestFiniteMagnitude
                for dj in -maxShiftBins...maxShiftBins {
                    let nj = j + dj
                    if nj < 0 || nj >= nBins { continue }
                    let v = reward[k][nj] + value[k + 1][nj] - 0.04 * Float(abs(dj))
                    if v > bv { bv = v; bj = nj }
                }
                j = bj
            }
            aim = lat(j)
        }
        return max(-half, min(half, aim + gauss(&rng) * p.noise))
    }
}

struct RunStat {
    var place = 0
    var fieldSize = 0
    var time: Double = 0
    var crystals = 0
    var crystalTotal = 0
    var stars = 0
    var crashes = 0
    var finished = false
    var comboMax = 0
    var nearMisses = 0
}

func runRace(level id: LevelID, profile: BotProfile, seed: UInt64, settings: GameSettings = .default) -> (RunStat, RaceResult?) {
    let engine = GameEngine()
    var result: RaceResult?
    engine.onFinished = { result = $0 }
    AudioHaptics.shared.reset()
    engine.start(level: LevelCatalog.level(id), settings: settings)
    let bot = Bot(profile, seed: seed)
    let dt: Float = 1.0 / 60.0
    var ticks = 0
    while result == nil && ticks < 60 * 240 {
        bot.update(engine, dt: dt)
        engine.tick(dt: TimeInterval(dt))
        ticks += 1
    }
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0))
    var s = RunStat()
    s.crashes = AudioHaptics.shared.counts["crash", default: 0]
    if let r = result {
        s.place = r.place; s.fieldSize = r.fieldSize; s.time = r.time; s.crystals = r.crystals
        s.crystalTotal = r.crystalTotal; s.stars = r.stars; s.finished = true
        s.comboMax = r.comboMax; s.nearMisses = r.nearMisses
    }
    return (s, result)
}
