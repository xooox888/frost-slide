import Foundation
import simd
import SwiftUI

enum LevelID: String, CaseIterable, Codable, Identifiable, Comparable {
    case villageDash
    case marketMayhem
    case iceCaveSpiral
    case auroraNight
    case harborFreeze
    case summitRush

    var id: String { rawValue }

    var order: Int {
        switch self {
        case .villageDash: return 0
        case .marketMayhem: return 1
        case .iceCaveSpiral: return 2
        case .auroraNight: return 3
        case .harborFreeze: return 4
        case .summitRush: return 5
        }
    }

    static func < (lhs: LevelID, rhs: LevelID) -> Bool {
        lhs.order < rhs.order
    }

    var next: LevelID? {
        LevelID.allCases.first { $0.order == order + 1 }
    }
}

enum LevelTheme: String, Codable {
    case village, market, cave, aurora, harbor, summit
}

enum Personality: String, Codable {
    case aggressive
    case cautious
    case hoarder
}

enum PropKind: String, Codable {
    case building, arch, stall, crateStack, pine, dock, boat
    case icicle, auroraRibbon, lantern, chimney, barrel, lamp
    case snowman, crate, icePatch, cart, bridge, stalactite, water, wind, npc
    case crystal, turboPad, ramp
    case rocket, magnet, ghost, banana
    case checkpoint, finish, startBanner
}

enum PowerUpType: String, Codable, CaseIterable {
    case rocket, magnet, ghost, banana

    var title: String {
        switch self {
        case .rocket: return "Rocket"
        case .magnet: return "Magnet"
        case .ghost: return "Ghost"
        case .banana: return "Peel"
        }
    }

    var symbol: String {
        switch self {
        case .rocket: return "flame.fill"
        case .magnet: return "magnet"
        case .ghost: return "sparkles"
        case .banana: return "leaf.fill"
        }
    }
}

enum SurfaceKind: String, Codable {
    case snow, ice, wood, water
}

enum RacePhase: Equatable {
    case idle
    case countdown(Int)
    case racing
    case finished
}

struct PlacedEntity: Identifiable, Codable {
    var id: UUID
    var kind: PropKind
    var progress: Float
    var lateral: Float
    var yaw: Float
    var scale: Float
    var radius: Float

    init(
        id: UUID = UUID(),
        kind: PropKind,
        progress: Float,
        lateral: Float = 0,
        yaw: Float = 0,
        scale: Float = 1,
        radius: Float = 1
    ) {
        self.id = id
        self.kind = kind
        self.progress = progress
        self.lateral = lateral
        self.yaw = yaw
        self.scale = scale
        self.radius = radius
    }
}

struct RivalConfig: Identifiable, Codable {
    var id: UUID
    var name: String
    var color: SIMD3<Float>
    var personality: Personality
    var skill: Float
    var startLateral: Float

    init(
        id: UUID = UUID(),
        name: String,
        color: SIMD3<Float>,
        personality: Personality,
        skill: Float,
        startLateral: Float
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.personality = personality
        self.skill = skill
        self.startLateral = startLateral
    }
}

struct CurveKey: Codable {
    var start: Float
    var end: Float
    var yawRadians: Float
}

struct WidthKey: Codable {
    var at: Float
    var width: Float
    var span: Float
}

struct ElevKey: Codable {
    var at: Float
    var height: Float
    var span: Float
}

struct LevelPalette {
    var snow: SIMD3<Float>
    var ice: SIMD3<Float>
    var skyTop: SIMD3<Float>
    var skyBottom: SIMD3<Float>
    var fog: SIMD3<Float>
    var fogStart: Float
    var fogEnd: Float
    var ambient: SIMD3<Float>
    var sunColor: SIMD3<Float>
    var sunIntensity: Float
    var wall: SIMD3<Float>
    var accent: SIMD3<Float>
    var wood: SIMD3<Float>
    var night: Bool
}

struct LevelDefinition: Identifiable {
    var id: LevelID
    var name: String
    var subtitle: String
    var blurb: String
    var theme: LevelTheme
    var palette: LevelPalette
    var length: Float
    var baseWidth: Float
    var slope: Float
    var startHeight: Float
    var curves: [CurveKey]
    var widths: [WidthKey]
    var elevations: [ElevKey]
    var entities: [PlacedEntity]
    var rivals: [RivalConfig]
    var checkpoints: [Float]
    var parTime: TimeInterval
    var crystalTarget: Int
    var crystalStar: Int

    var crystalCount: Int {
        entities.filter { $0.kind == .crystal }.count
    }
}

struct GameSettings: Codable, Equatable {
    var tiltSteering: Bool
    var unlockAll: Bool
    var hapticsEnabled: Bool
    var soundEnabled: Bool

    static let `default` = GameSettings(
        tiltSteering: false,
        unlockAll: false,
        hapticsEnabled: true,
        soundEnabled: true
    )
}

struct LevelRecord: Codable, Equatable {
    var bestPlace: Int
    var bestStars: Int
    var bestTime: TimeInterval
    var bestCrystals: Int
    var timesPlayed: Int

    static let empty = LevelRecord(
        bestPlace: 99,
        bestStars: 0,
        bestTime: 9999,
        bestCrystals: 0,
        timesPlayed: 0
    )
}

struct RaceResult: Identifiable, Equatable {
    var id = UUID()
    var level: LevelID
    var place: Int
    var fieldSize: Int
    var time: TimeInterval
    var crystals: Int
    var crystalTotal: Int
    var stars: Int
    var podium: [PodiumEntry]
}

struct PodiumEntry: Equatable, Identifiable {
    var id: String
    var name: String
    var place: Int
    var time: TimeInterval?
    var isPlayer: Bool
    var color: SIMD3<Float>
}

struct HUDSnapshot: Equatable {
    var place: Int
    var fieldSize: Int
    var progress: Float
    var rivalProgress: [Float]
    var crystals: Int
    var crystalTotal: Int
    var turbo: Float
    var time: TimeInterval
    var countdown: Int?
    var goFlash: Bool
    var magnetActive: Bool
    var ghostActive: Bool
    var rocketActive: Bool
    var bananaArmed: Bool
    var toast: String
    var checkpoints: [Float]
    var speedKph: Int
    var levelName: String
    var rewardedTurboUsed: Bool
    var racing: Bool

    static let empty = HUDSnapshot(
        place: 1,
        fieldSize: 4,
        progress: 0,
        rivalProgress: [],
        crystals: 0,
        crystalTotal: 0,
        turbo: 0,
        time: 0,
        countdown: 3,
        goFlash: false,
        magnetActive: false,
        ghostActive: false,
        rocketActive: false,
        bananaArmed: false,
        toast: "",
        checkpoints: [0.25, 0.5, 0.75],
        speedKph: 0,
        levelName: "",
        rewardedTurboUsed: false,
        racing: false
    )
}

enum GameMath {
    static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * t
    }

    static func lerp(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        a + (b - a) * t
    }

    static func clamp(_ x: Float, _ a: Float, _ b: Float) -> Float {
        min(max(x, a), b)
    }

    static func saturate(_ x: Float) -> Float {
        clamp(x, 0, 1)
    }

    static func damp(_ current: Float, _ target: Float, lambda: Float, dt: Float) -> Float {
        target + (current - target) * exp(-lambda * dt)
    }

    static func damp3(_ current: SIMD3<Float>, _ target: SIMD3<Float>, lambda: Float, dt: Float) -> SIMD3<Float> {
        target + (current - target) * exp(-lambda * dt)
    }

    static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = saturate((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }

    static func wrapAngle(_ a: Float) -> Float {
        var x = a
        while x > Float.pi { x -= 2 * Float.pi }
        while x < -Float.pi { x += 2 * Float.pi }
        return x
    }
}

extension SIMD3 where Scalar == Float {
    var color: Color {
        Color(red: Double(x), green: Double(y), blue: Double(z))
    }
}
