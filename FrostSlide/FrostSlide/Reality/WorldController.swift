import RealityKit
import UIKit
import simd

/// RealityKit renderer for the arcade spline sim. Owns the non-AR ARView scene.
final class WorldController {
    private(set) var view: ARView?
    private var anchor = AnchorEntity(world: .zero)
    private var worldRoot = Entity()
    private var camera = PerspectiveCamera()
    private var racerEntities: [UUID: Entity] = [:]
    private var pickupEntities: [UUID: Entity] = [:]
    private var trail: IceTrail?
    private var snow = SnowField()
    private var peelEntities: [UUID: Entity] = [:]
    private var trailTick: Float = 0
    private var spinTime: Float = 0
    private var built = false
    private var pending: (LevelDefinition, TrackPath, [Racer])?

    func attach(to view: ARView) {
        self.view = view
        view.environment.background = .color(UIColor(red: 0.86, green: 0.92, blue: 0.98, alpha: 1))
        view.environment.lighting.intensityExponent = 0.15
        view.renderOptions.insert(.disableMotionBlur)
        view.renderOptions.insert(.disableDepthOfField)
        if let pending {
            install(level: pending.0, path: pending.1, racers: pending.2)
        }
    }

    func build(level: LevelDefinition, path: TrackPath, racers: [Racer]) {
        pending = (level, path, racers)
        guard view != nil else { return }
        install(level: level, path: path, racers: racers)
    }

    private func install(level: LevelDefinition, path: TrackPath, racers: [Racer]) {
        guard let view else { return }
        for existing in view.scene.anchors {
            view.scene.removeAnchor(existing)
        }
        anchor = AnchorEntity(world: .zero)
        worldRoot = Entity()
        worldRoot.name = "world"
        anchor.addChild(worldRoot)
        view.scene.addAnchor(anchor)

        let fog = RKMat.ui(level.palette.fog)
        view.environment.background = .color(fog)

        WorldFactory.build(level: level, path: path, into: worldRoot)

        pickupEntities = [:]
        collectPickups(from: worldRoot)

        racerEntities = [:]
        for racer in racers {
            let entity = PenguinFactory.make(sledColor: racer.sledColor)
            entity.name = racer.id.uuidString
            worldRoot.addChild(entity)
            racerEntities[racer.id] = entity
        }

        camera = PerspectiveCamera()
        camera.camera.near = 0.2
        camera.camera.far = 420
        camera.camera.fieldOfViewInDegrees = 50
        anchor.addChild(camera)

        peelEntities = [:]
        trail?.clear()
        trail = IceTrail(parent: worldRoot)
        snow = SnowField()
        if !UIAccessibility.isReduceMotionEnabled {
            snow.attach(to: worldRoot, night: level.palette.night)
        }
        built = true
    }

    func apply(engine: GameEngine, dt: Float) {
        guard built, let path = engine.path else { return }
        spinTime += dt

        for racer in engine.racers {
            guard let entity = racerEntities[racer.id] else { continue }
            let pos = path.worldPosition(progress: racer.progress, lateral: racer.lateral, height: racer.height)
            entity.position = pos
            let qYaw = simd_quatf(angle: racer.yaw, axis: [0, 1, 0])
            let qPitch = simd_quatf(angle: racer.pitch, axis: [1, 0, 0])
            let qRoll = simd_quatf(angle: racer.roll, axis: [0, 0, 1])
            entity.orientation = qYaw * qPitch * qRoll
            entity.scale = [1, racer.squash, 1]
            if let shroud = entity.findEntity(named: "ghostShroud") {
                shroud.isEnabled = racer.ghostTime > 0
            }
            if let glow = entity.findEntity(named: "sledGlow") as? PointLight {
                glow.light.intensity = 280 + racer.trailBoost * 700 + racer.rocketTime * 400
            }
        }

        for live in engine.entities {
            guard let entity = pickupEntities[live.definition.id] else { continue }
            if live.collected || live.destroyed {
                entity.isEnabled = false
                continue
            }
            entity.isEnabled = true
            if live.definition.kind == .cart || live.definition.kind == .npc {
                entity.position = path.worldPosition(
                    progress: live.definition.progress,
                    lateral: live.liveLateral,
                    height: 0
                )
            }
            if live.definition.kind == .crystal {
                let pos = path.worldPosition(
                    progress: live.definition.progress,
                    lateral: live.liveLateral,
                    height: 0.15
                )
                entity.position = [pos.x, 0.7 + sin(spinTime * 3 + live.phase) * 0.12, pos.z]
                entity.orientation = simd_quatf(angle: spinTime * 2.2, axis: [0, 1, 0])
            }
            if live.definition.kind == .rocket || live.definition.kind == .magnet
                || live.definition.kind == .ghost || live.definition.kind == .banana {
                let pulse = 1 + sin(spinTime * 5) * 0.08
                entity.scale = SIMD3(repeating: pulse)
            }
        }

        syncPeels(engine: engine, path: path)

        if let player = engine.playerRacer {
            let pos = path.worldPosition(progress: player.progress, lateral: player.lateral, height: 0)
            trailTick += dt
            if trailTick > 0.05 && !player.airborne {
                trailTick = 0
                trail?.push(position: pos, intense: player.trailBoost > 0 || player.rocketTime > 0)
            }
            snow.tick(dt: dt, around: engine.cameraEye)
        }

        camera.look(at: engine.cameraLook, from: engine.cameraEye, relativeTo: nil)
        camera.camera.fieldOfViewInDegrees = engine.cameraFOV
    }

    private func syncPeels(engine: GameEngine, path: TrackPath) {
        let live = Set(engine.droppedBananas.map(\.id))
        for (id, entity) in peelEntities where !live.contains(id) {
            entity.removeFromParent()
            peelEntities.removeValue(forKey: id)
        }
        for peel in engine.droppedBananas {
            if peelEntities[peel.id] == nil {
                let node = WorldFactory.powerOrb(SIMD3(1.0, 0.85, 0.15), "banana")
                node.name = peel.id.uuidString
                worldRoot.addChild(node)
                peelEntities[peel.id] = node
            }
            peelEntities[peel.id]?.position = path.worldPosition(
                progress: peel.progress,
                lateral: peel.lateral,
                height: 0
            )
        }
    }

    private func collectPickups(from root: Entity) {
        if let id = UUID(uuidString: root.name) {
            pickupEntities[id] = root
        }
        for child in root.children {
            collectPickups(from: child)
        }
    }
}
