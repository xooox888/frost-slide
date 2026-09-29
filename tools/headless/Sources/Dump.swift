// Machine-readable dumps of the Swift game, used to prove the TypeScript port in web/ matches it.
//
//   catalog   every course as JSON (run through `run.sh catalog`, which makes the scenery that
//             Swift scatters with the system random generator deterministic first)
//   trace     one scripted race per course, sampled every half second
import Foundation

private func num(_ v: Float) -> String { v.description }
private func num(_ v: Double) -> String { v.description }
private func rgb(_ c: SIMD3<Float>) -> String { "[\(num(c.x)),\(num(c.y)),\(num(c.z))]" }
private func str(_ s: String) -> String {
    let data = try! JSONSerialization.data(withJSONObject: [s], options: [])
    let text = String(data: data, encoding: .utf8)!
    return String(text.dropFirst().dropLast())
}

func dumpCatalog() {
    var levels: [String] = []
    for id in LevelID.allCases {
        let l = LevelCatalog.level(id)
        let p = l.palette
        let palette = "{\"snow\":\(rgb(p.snow)),\"ice\":\(rgb(p.ice)),\"skyTop\":\(rgb(p.skyTop)),\"skyBottom\":\(rgb(p.skyBottom)),"
            + "\"fog\":\(rgb(p.fog)),\"fogStart\":\(num(p.fogStart)),\"fogEnd\":\(num(p.fogEnd)),\"ambient\":\(rgb(p.ambient)),"
            + "\"sunColor\":\(rgb(p.sunColor)),\"sunIntensity\":\(num(p.sunIntensity)),\"wall\":\(rgb(p.wall)),"
            + "\"accent\":\(rgb(p.accent)),\"wood\":\(rgb(p.wood)),\"night\":\(p.night)}"
        let curves = l.curves.map { "[\(num($0.start)),\(num($0.end)),\(num($0.yawRadians))]" }.joined(separator: ",")
        let widths = l.widths.map { "[\(num($0.at)),\(num($0.width)),\(num($0.span))]" }.joined(separator: ",")
        let elevations = l.elevations.map { "[\(num($0.at)),\(num($0.height)),\(num($0.span))]" }.joined(separator: ",")
        let events = l.events.map { "[\(str($0.kind.rawValue)),\(num($0.start)),\(num($0.end)),\(num($0.lateral)),\(num($0.magnitude))]" }.joined(separator: ",")
        let rivals = l.rivals.map {
            "[\(str($0.id.uuidString)),\(str($0.name)),\(rgb($0.color)),\(str($0.personality.rawValue)),\(num($0.skill)),\(num($0.startLateral))]"
        }.joined(separator: ",")
        let entities = l.entities.map {
            "[\(str($0.kind.rawValue)),\(num($0.progress)),\(num($0.lateral)),\(num($0.yaw)),\(num($0.scale)),\(num($0.radius))]"
        }.joined(separator: ",\n")
        // The first three entity ids pin down the stable-id generator.
        let ids = l.entities.prefix(3).map { str($0.id.uuidString) }.joined(separator: ",")
        levels.append(
            "{\"id\":\(str(id.rawValue)),\"name\":\(str(l.name)),\"subtitle\":\(str(l.subtitle)),\"blurb\":\(str(l.blurb)),"
            + "\"theme\":\(str(l.theme.rawValue)),\"length\":\(num(l.length)),\"baseWidth\":\(num(l.baseWidth)),"
            + "\"slope\":\(num(l.slope)),\"startHeight\":\(num(l.startHeight)),\"parTime\":\(num(l.parTime)),"
            + "\"crystalTarget\":\(l.crystalTarget),\"crystalStar\":\(l.crystalStar),"
            + "\"checkpoints\":[\(l.checkpoints.map(num).joined(separator: ","))],\n\"palette\":\(palette),\n"
            + "\"curves\":[\(curves)],\"widths\":[\(widths)],\"elevations\":[\(elevations)],\"events\":[\(events)],\n"
            + "\"rivals\":[\(rivals)],\n\"firstIds\":[\(ids)],\n\"entities\":[\n\(entities)]}"
        )
    }
    print("[\n" + levels.joined(separator: ",\n") + "\n]")
}

/// A scripted race with no randomness: a slow weave, boost in bursts. Prints the player and the
/// first rival every half second so the TypeScript engine can be compared step by step. `solo`
/// removes the rivals, so sled-to-sled contact (where float rounding decides whether a push
/// happens at all) cannot make the two engines part ways.
func dumpTrace(courses first: Int, _ last: Int, solo: Bool = false) {
    for index in first...last {
        let id = LevelID.allCases[index]
        let engine = GameEngine()
        var level = LevelCatalog.level(id)
        if solo { level.rivals = [] }
        engine.start(level: level, settings: .default)
        // At exactly 60 fps many timers (a 0.8 s launch boost is 48 frames) land on zero, where
        // 32-bit and 64-bit rounding disagree by a frame. TRACE_FPS=61 avoids that for comparisons.
        let dt: TimeInterval = 1.0 / (Double(ProcessInfo.processInfo.environment["TRACE_FPS"] ?? "") ?? 60)
        var clock = 0.0
        var nextSample = 0.0
        let step = Double(ProcessInfo.processInfo.environment["TRACE_STEP"] ?? "") ?? 0.5
        let until = Double(ProcessInfo.processInfo.environment["TRACE_UNTIL"] ?? "") ?? 40
        while clock < until, !(engine.phase == .finished && clock > 36) {
            engine.steerInput = Float(sin(clock * 1.3) * 0.8)
            engine.boostHeld = clock.truncatingRemainder(dividingBy: 3) < 1
            engine.tick(dt: dt)
            clock += dt
            if clock >= nextSample {
                nextSample += step
                guard let me = engine.playerRacer else { continue }
                let rival = engine.racers.first(where: { !$0.isPlayer }) ?? me
                print(String(
                    format: "TRACE %d %.2f %.6f %.5f %.5f %.5f %d %d %.6f %.5f %.5f",
                    index, clock, me.progress, me.lateral, me.speed, me.turbo, me.crystals, me.hits,
                    rival.progress, rival.lateral, rival.speed
                ))
            }
        }
    }
}

/// One bot race, sampled every `step` seconds: `bottrace <course> <bot> <seed>`.
func dumpBotTrace(course index: Int, profile: BotProfile, seed: UInt64) {
    let engine = GameEngine()
    engine.start(level: LevelCatalog.level(LevelID.allCases[index]), settings: .default)
    let bot = Bot(profile, seed: seed)
    let dt: Float = 1.0 / 60.0
    let step = Double(ProcessInfo.processInfo.environment["TRACE_STEP"] ?? "") ?? 0.5
    var next = 0.0
    var clock = 0.0
    for _ in 0..<(60 * 60) {
        bot.update(engine, dt: dt)
        engine.tick(dt: TimeInterval(dt))
        clock += Double(dt)
        if engine.phase == .finished { break }
        if clock >= next, let me = engine.playerRacer {
            next += step
            print(String(format: "BOT %.2f %.6f %.5f %.5f %.5f %d %d", clock, me.progress, me.lateral, me.speed, me.turbo, me.crystals, me.hits))
        }
    }
}
