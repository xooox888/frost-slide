import Foundation
import simd

struct Racer {
    var id: UUID
    var name: String
    var isPlayer: Bool
    var sledColor: SIMD3<Float>
    var personality: Personality?
    var skill: Float
    var progress: Float
    var lateral: Float
    var height: Float
    var verticalVel: Float
    var speed: Float
    var lateralVel: Float
    var turbo: Float
    var crystals: Int
    var finished: Bool
    var finishTime: TimeInterval?
    var airborne: Bool
    var stunned: Float
    var ghostTime: Float
    var magnetTime: Float
    var rocketTime: Float
    var invuln: Float
    var lastCheckpoint: Float
    var bananaArmed: Bool
    var bananaCooldown: Float
    var yaw: Float
    var roll: Float
    var pitch: Float
    var squash: Float
    var trailBoost: Float
    var flareTime: Float
}

struct LiveEntity {
    var definition: PlacedEntity
    var collected: Bool
    var destroyed: Bool
    var liveLateral: Float
    var phase: Float
}

enum RacerFactory {
    static func player(startLateral: Float = 0, skin: SledSkin = .cyan) -> Racer {
        make(
            id: UUID(),
            name: "You",
            isPlayer: true,
            color: skin.color,
            personality: nil,
            skill: 1,
            lateral: startLateral
        )
    }

    static func rival(_ config: RivalConfig) -> Racer {
        make(
            id: config.id,
            name: config.name,
            isPlayer: false,
            color: config.color,
            personality: config.personality,
            skill: config.skill,
            lateral: config.startLateral
        )
    }

    private static func make(
        id: UUID,
        name: String,
        isPlayer: Bool,
        color: SIMD3<Float>,
        personality: Personality?,
        skill: Float,
        lateral: Float
    ) -> Racer {
        Racer(
            id: id,
            name: name,
            isPlayer: isPlayer,
            sledColor: color,
            personality: personality,
            skill: skill,
            progress: 0.012,
            lateral: lateral,
            height: 0,
            verticalVel: 0,
            speed: 9,
            lateralVel: 0,
            turbo: 0.22,
            crystals: 0,
            finished: false,
            finishTime: nil,
            airborne: false,
            stunned: 0,
            ghostTime: 0,
            magnetTime: 0,
            rocketTime: 0,
            invuln: 0,
            lastCheckpoint: 0,
            bananaArmed: false,
            bananaCooldown: 0,
            yaw: 0,
            roll: 0,
            pitch: 0,
            squash: 1,
            trailBoost: 0,
            flareTime: 0
        )
    }
}

enum CollisionClass {
    static let solidHazards: Set<PropKind> = [
        .snowman, .crate, .cart, .npc, .stalactite, .bridge, .barrel,
        .movingBridge, .crystalSpire, .carnivalFloat, .geyser
    ]
    static let pickups: Set<PropKind> = [.crystal, .rocket, .magnet, .ghost, .banana, .flare]
    static let pads: Set<PropKind> = [.ramp, .turboPad]
}
