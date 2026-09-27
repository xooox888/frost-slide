import Foundation
import simd
import SwiftUI

enum CourseWorld: String, CaseIterable, Identifiable {
    case villageMarket
    case iceCaves
    case aurora
    case harbor
    case summit
    case forest
    case canyonSteam
    case spectacle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .villageMarket: return "Village & Market"
        case .iceCaves: return "Ice Caves"
        case .aurora: return "Aurora Night"
        case .harbor: return "Harbor"
        case .summit: return "Summit & Glacier"
        case .forest: return "Frozen Forest"
        case .canyonSteam: return "Canyon & Steam"
        case .spectacle: return "Storm & Spectacle"
        }
    }

    var blurb: String {
        switch self {
        case .villageMarket: return "Wide streets. Learn to carve."
        case .iceCaves: return "Helix ice and tight walls."
        case .aurora: return "Night fog. Trust the glow."
        case .harbor: return "Planks, boats, black water."
        case .summit: return "Steep faces and wind."
        case .forest: return "Pines, switchbacks, owls."
        case .canyonSteam: return "Prisms, shards, mist."
        case .spectacle: return "Blizzard, neon, carnival."
        }
    }

    var courses: [LevelID] {
        switch self {
        case .villageMarket: return [.villageDash, .marketMayhem, .alleySprint]
        case .iceCaves: return [.iceCaveSpiral, .crystalGrotto, .frozenHollow]
        case .aurora: return [.auroraNight, .polarVeil, .midnightRibbon]
        case .harbor: return [.harborFreeze, .driftwoodDocks, .tideGate]
        case .summit: return [.summitRush, .glacierDrop, .icefallRun]
        case .forest: return [.pineWhisper, .timberSwitchback, .owlHollow]
        case .canyonSteam: return [.canyonGlow, .prismCut, .steamVeil]
        case .spectacle: return [.whiteoutPeak, .neonSlalom, .carnivalParade]
        }
    }

    var symbol: String {
        switch self {
        case .villageMarket: return "house.lodge.fill"
        case .iceCaves: return "triangle.fill"
        case .aurora: return "sparkles"
        case .harbor: return "sailboat.fill"
        case .summit: return "mountain.2.fill"
        case .forest: return "tree.fill"
        case .canyonSteam: return "diamond.fill"
        case .spectacle: return "party.popper.fill"
        }
    }
}

enum SledSkin: String, CaseIterable, Codable, Identifiable {
    case cyan, ember, forest, violet, gold, midnight, carnival, aurora

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cyan: return "Classic Cyan"
        case .ember: return "Ember"
        case .forest: return "Pine"
        case .violet: return "Royal"
        case .gold: return "Summit Gold"
        case .midnight: return "Midnight"
        case .carnival: return "Carnival"
        case .aurora: return "Aurora Fade"
        }
    }

    var starsRequired: Int {
        switch self {
        case .cyan: return 0
        case .ember: return 6
        case .forest: return 12
        case .violet: return 18
        case .gold: return 27
        case .midnight: return 36
        case .carnival: return 48
        case .aurora: return 60
        }
    }

    var color: SIMD3<Float> {
        switch self {
        case .cyan: return SIMD3(0.12, 0.55, 1.0)
        case .ember: return SIMD3(0.95, 0.28, 0.18)
        case .forest: return SIMD3(0.18, 0.72, 0.38)
        case .violet: return SIMD3(0.58, 0.32, 0.92)
        case .gold: return SIMD3(0.98, 0.78, 0.22)
        case .midnight: return SIMD3(0.16, 0.18, 0.34)
        case .carnival: return SIMD3(1.0, 0.35, 0.62)
        case .aurora: return SIMD3(0.35, 0.95, 0.72)
        }
    }

    var swatch: Color { color.color }
}

struct GhostSample: Codable, Equatable {
    var t: Float
    var p: Float
    var l: Float
    var h: Float
}

struct GhostTake: Codable, Equatable {
    var time: TimeInterval
    var samples: [GhostSample]
}

enum DailyChallenge {
    static func dateKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func pick(unlocked: [LevelID], date: Date = Date()) -> (level: LevelID, tag: String) {
        let pool = unlocked.isEmpty ? [LevelID.villageDash] : unlocked.sorted()
        var hash: UInt64 = 2166136261
        for byte in dateKey(date).utf8 {
            hash ^= UInt64(byte)
            hash &*= 16777619
        }
        let level = pool[Int(hash % UInt64(pool.count))]
        let tags = ["Beat par", "Top 2 finish", "Crystal hunt", "Clean run"]
        return (level, tags[Int(hash / 7) % tags.count])
    }
}
