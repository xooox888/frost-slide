import Foundation

// Command line for the headless harness. `run.sh` drives this; the subcommands take course
// indices 0-23 so it can split the work across processes.
//
//   selftest
//   balance <bot|all> <runs> [first last]     win / podium / par / crystal-goal rates
//   solo <runs> [first last]                  each bot alone on the course
//   margin <bot> <runs> <first> <last>        mean winning margin (used by calibrate.py)
//   rivals                                    each rival's pace against an idle player
//   avalanche <runs>                          burial rates on the avalanche courses
//   standings <course> <bot>                  one race, with times and crash counts
//   catalog                                   every course as JSON (see Dump.swift)
//   trace [first last] [solo]                 a scripted race per course, sampled twice a second

let args = CommandLine.arguments
let courses = LevelID.allCases

func intArg(_ index: Int, default fallback: Int) -> Int {
    args.count > index ? Int(args[index]) ?? fallback : fallback
}

guard args.count >= 2 else {
    print("usage: headless <selftest|balance|solo|margin|rivals|avalanche|standings> ...")
    exit(1)
}

switch args[1] {
case "selftest":
    runSelfTests()

case "balance":
    let profiles: [BotProfile] = args.count > 2 && args[2] == "all"
        ? BotProfile.all
        : (args.count > 2 ? BotProfile.named(args[2]).map { [$0] } ?? [] : [])
    let runs = intArg(3, default: 10)
    let first = intArg(4, default: 0)
    let last = intArg(5, default: courses.count - 1)
    for profile in profiles {
        for index in first...last {
            let id = courses[index]
            let level = LevelCatalog.level(id)
            var wins = 0, podium = 0, par = 0, crystalGoal = 0, unfinished = 0, finished = 0
            var place = 0.0, time = 0.0, crystals = 0.0, crashes = 0.0, stars = 0.0, combo = 0.0
            for k in 0..<runs {
                let (stat, _) = runRace(level: id, profile: profile, seed: UInt64(1000 + index * 131 + k * 7919))
                guard stat.finished else { unfinished += 1; continue }
                finished += 1
                if stat.place == 1 { wins += 1 }
                if stat.place <= 3 { podium += 1 }
                if stat.time <= level.parTime { par += 1 }
                if stat.crystals >= level.crystalStar { crystalGoal += 1 }
                place += Double(stat.place)
                time += stat.time
                crystals += Double(stat.crystals)
                crashes += Double(stat.crashes)
                stars += Double(stat.stars)
                combo += Double(stat.comboMax)
            }
            let n = Double(max(1, finished))
            print(String(
                format: "%@ %02d %-17@ win %3.0f%% top3 %3.0f%% place %.2f time %5.1f (par %2.0f, made %3.0f%%) crys %4.1f/%d (star %2d: %3.0f%%) crashes %.1f stars %.2f combo %.1f dnf %d",
                profile.name.padding(toLength: 6, withPad: " ", startingAt: 0), index + 1, level.name as NSString,
                Double(wins) / n * 100, Double(podium) / n * 100, place / n, time / n, level.parTime,
                Double(par) / n * 100, crystals / n, level.crystalCount, level.crystalStar, Double(crystalGoal) / n * 100,
                crashes / n, stars / n, combo / n, unfinished
            ))
        }
    }

case "solo":
    let runs = intArg(2, default: 6)
    let first = intArg(3, default: 0)
    let last = intArg(4, default: courses.count - 1)
    for index in first...last {
        let level = LevelCatalog.level(courses[index])
        var line = String(format: "%02d %-17@ par %2.0f |", index + 1, level.name as NSString, level.parTime)
        for profile in BotProfile.all {
            let r = probeSolo(courses[index], profile: profile, runs: profile.name == "idle" ? 1 : runs)
            line += String(format: " %@ %5.2fs/%2.0fc/%.1fx", profile.name as NSString, r.time, r.crystals, r.crashes)
        }
        print(line)
    }

case "margin":
    guard args.count > 2, let profile = BotProfile.named(args[2]) else { print("unknown bot"); exit(1) }
    let runs = intArg(3, default: 12)
    for index in intArg(4, default: 0)...intArg(5, default: courses.count - 1) {
        let r = meanMargin(courses[index], profile: profile, runs: runs)
        print(String(format: "MARGIN %d %.3f %.2f %.2f", index + 1, r.margin, r.win, r.sd))
    }

case "rivals":
    for id in courses {
        let level = LevelCatalog.level(id)
        let skills = level.rivals.map { String(format: "%.2f", $0.skill) }.joined(separator: "/")
        let times = probeRivalPace(id).map { String(format: "%@ %.1f(%dh)", $0.name, $0.time, $0.hits) }.joined(separator: "  ")
        print(String(format: "%02d %-17@ skills %@ | %@", id.order + 1, level.name as NSString, skills as NSString, times as NSString))
    }

case "avalanche":
    let runs = intArg(2, default: 12)
    for id in courses {
        guard let event = LevelCatalog.level(id).events.first(where: { $0.kind == .avalanche }) else { continue }
        let level = LevelCatalog.level(id)
        let pace = Double(event.magnitude * level.length / (13.5 + level.slope * 22))
        var line = String(format: "%02d %-16@ pace %.2f |", id.order + 1, level.name as NSString, pace)
        for name in ["idle", "novice", "casual", "good"] {
            let r = avalancheStats(id, profile: BotProfile.named(name)!, runs: runs)
            line += String(format: " %@ buried %3.0f%% gap %4.0fm |", name as NSString, r.buried * 100, r.minGap)
        }
        print(line)
    }

case "standings":
    guard args.count > 3, let index = Int(args[2]), courses.indices.contains(index), let profile = BotProfile.named(args[3]) else {
        print("usage: standings <course index 0-23> <bot>")
        exit(1)
    }
    probeStandings(courses[index], profile: profile, seed: 9)

case "catalog":
    dumpCatalog()

case "bottrace":
    guard args.count > 4, let index = Int(args[2]), let profile = BotProfile.named(args[3]), let seed = UInt64(args[4]) else {
        print("usage: bottrace <course index 0-23> <bot> <seed>")
        exit(1)
    }
    dumpBotTrace(course: index, profile: profile, seed: seed)

case "trace":
    dumpTrace(courses: intArg(2, default: 0), intArg(3, default: courses.count - 1), solo: args.contains("solo"))

default:
    print("unknown command \(args[1])")
    exit(1)
}
