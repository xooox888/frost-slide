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
    private var rigs: [UUID: PenguinRig] = [:]
    private var sky: Entity?
    private var spray: SnowSpray?
    private var pickupEntities: [UUID: Entity] = [:]
    private var trail: IceTrail?
    private var snow = SnowField()
    private var peelEntities: [UUID: Entity] = [:]
    private var ghostEntity: Entity?
    private var avalancheWall: Entity?
    private var trailTick: Float = 0
    private var spinTime: Float = 0
    private var lastLanding = false
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
        sky = worldRoot.findEntity(named: "sky")

        pickupEntities = [:]
        collectPickups(from: worldRoot)

        racerEntities = [:]
        rigs = [:]
        for racer in racers {
            let entity = PenguinFactory.make(sledColor: racer.sledColor)
            entity.name = racer.id.uuidString
            worldRoot.addChild(entity)
            racerEntities[racer.id] = entity
            rigs[racer.id] = PenguinRig(entity)
        }

        camera = PerspectiveCamera()
        camera.camera.near = 0.2
        camera.camera.far = 420
        camera.camera.fieldOfViewInDegrees = 50
        anchor.addChild(camera)

        peelEntities = [:]
        ghostEntity?.removeFromParent()
        ghostEntity = nil
        avalancheWall?.removeFromParent()
        avalancheWall = nil
        lastLanding = false
        trail?.clear()
        trail = IceTrail(parent: worldRoot)
        spray = UIAccessibility.isReduceMotionEnabled ? nil : SnowSpray(parent: worldRoot)
        snow = SnowField()
        if !UIAccessibility.isReduceMotionEnabled {
            snow.attach(to: worldRoot, night: level.palette.night)
        }
        if level.events.contains(where: { $0.kind == .avalanche }) {
            let wall = WorldFactory.avalancheCloud()
            wall.name = "avalanche"
            wall.isEnabled = false
            worldRoot.addChild(wall)
            avalancheWall = wall
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
            let bank = path.sample(at: racer.progress).bank
            let qYaw = simd_quatf(angle: racer.yaw, axis: [0, 1, 0])
            let qPitch = simd_quatf(angle: racer.pitch, axis: [1, 0, 0])
            // The sled lies on the banked surface; its own lean is added on top.
            let qRoll = simd_quatf(angle: racer.roll + bank, axis: [0, 0, 1])
            entity.orientation = qYaw * qPitch * qRoll
            entity.scale = [1, racer.squash, 1]
            guard let rig = rigs[racer.id] else { continue }
            rig.shroud?.isEnabled = racer.ghostTime > 0
            rig.glow?.light.intensity = 280 + racer.trailBoost * 700 + racer.rocketTime * 400
            // Flap hard on boost and in the air; idle sway otherwise. Scarf flutters with speed.
            let seed = Float(abs(racer.id.hashValue % 97))
            let flapping = racer.trailBoost > 0 || racer.airborne || racer.rocketTime > 0
            let flap = flapping ? sin(spinTime * 22 + seed) * 0.55 : sin(spinTime * 3 + seed) * 0.06
            rig.flipL?.orientation = simd_quatf(angle: -0.85 - flap, axis: [0, 0, 1])
            rig.flipR?.orientation = simd_quatf(angle: 0.85 + flap, axis: [0, 0, 1])
            let flutter = sin(spinTime * 15 + seed) * min(1, racer.speed / 16) * 0.4
            rig.tail?.orientation = simd_quatf(angle: flutter, axis: [0, 1, 0]) * simd_quatf(angle: 0.25, axis: [1, 0, 0])
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
        syncGhost(engine: engine, path: path)
        syncAvalanche(engine: engine, path: path)

        if let player = engine.playerRacer {
            let pos = path.worldPosition(progress: player.progress, lateral: player.lateral, height: 0)
            trailTick += dt
            if trailTick > 0.035 && !player.airborne {
                let length = max(0.7, player.speed * trailTick * 1.15)
                trailTick = 0
                trail?.push(
                    position: pos,
                    yaw: player.yaw,
                    length: length,
                    intense: player.trailBoost > 0 || player.rocketTime > 0 || engine.combo >= 3
                )
            }
            let sample = path.sample(at: player.progress)
            var sprayRate: Float = 0
            if !player.airborne && engine.phase == .racing {
                sprayRate = max(0, player.speed - 12) * 1.5 + abs(player.lateralVel) * 5
                if player.trailBoost > 0 || player.rocketTime > 0 { sprayRate += 26 }
            }
            spray?.tick(dt: dt, at: pos, forward: sample.tangent, side: sample.binormal, rate: sprayRate)
            snow.tick(dt: dt, around: engine.cameraEye)
            if engine.landingPulse > 0.7 && !lastLanding {
                snow.burst(at: pos)
                lastLanding = true
            }
            if engine.landingPulse < 0.15 { lastLanding = false }
            if let glow = racerEntities[player.id]?.findEntity(named: "sledGlow") as? PointLight {
                glow.light.intensity = 280 + player.trailBoost * 700 + player.rocketTime * 400 + player.flareTime * 80
                glow.light.attenuationRadius = player.flareTime > 0 ? 14 : 5
            }
        }
        if let view {
            let night = engine.level?.palette.night == true
            let flare = (engine.playerRacer?.flareTime ?? 0) > 0
            view.environment.lighting.intensityExponent = night ? (flare ? 0.35 : -0.15) : 0.15
        }

        // Screen shake is motion the player asked us not to add, when Reduce Motion is on.
        let shake = UIAccessibility.isReduceMotionEnabled ? 0 : engine.cameraShake * 0.16 + engine.landingPulse * 0.06
        let jitter = shake > 0.001
            ? SIMD3<Float>(Float.random(in: -1...1), Float.random(in: -1...1), 0) * shake
            : .zero
        camera.look(at: engine.cameraLook + jitter * 0.5, from: engine.cameraEye + jitter, relativeTo: nil)
        camera.camera.fieldOfViewInDegrees = engine.cameraFOV
        // Keep the sky dome centred on the camera so the horizon stays at eye level.
        sky?.position = engine.cameraEye
    }

    private func syncGhost(engine: GameEngine, path: TrackPath) {
        guard let pose = engine.ghostPose else {
            ghostEntity?.isEnabled = false
            return
        }
        if ghostEntity == nil {
            let ghost = PenguinFactory.make(sledColor: SIMD3(0.75, 0.88, 1.0))
            ghost.name = "bestGhost"
            if let shroud = ghost.findEntity(named: "ghostShroud") {
                shroud.isEnabled = true
            }
            worldRoot.addChild(ghost)
            ghostEntity = ghost
        }
        ghostEntity?.isEnabled = true
        ghostEntity?.position = path.worldPosition(progress: pose.progress, lateral: pose.lateral, height: pose.height)
        // Face down the track like every other sled, instead of always along +z.
        let sample = path.sample(at: pose.progress)
        let qYaw = simd_quatf(angle: sample.heading, axis: [0, 1, 0])
        let qPitch = simd_quatf(angle: sample.slope * 0.4, axis: [1, 0, 0])
        let qBank = simd_quatf(angle: sample.bank, axis: [0, 0, 1])
        ghostEntity?.orientation = qYaw * qPitch * qBank
    }

    private func syncAvalanche(engine: GameEngine, path: TrackPath) {
        guard let wall = avalancheWall else { return }
        wall.isEnabled = engine.avalancheThreat
        guard engine.avalancheThreat else { return }
        // Square across the track at the wall's current position, billowing a little.
        let sample = path.sample(at: engine.avalancheFront)
        wall.position = path.worldPosition(progress: engine.avalancheFront, lateral: 0, height: 0)
        wall.orientation = simd_quatf(angle: sample.heading, axis: [0, 1, 0]) * simd_quatf(angle: sample.bank, axis: [0, 0, 1])
        wall.scale = [1, 1 + sin(spinTime * 5) * 0.05, 1]
    }

    private func syncPeels(engine: GameEngine, path: TrackPath) {
        let live = Set(engine.droppedBananas.map(\.id))
        for (id, entity) in peelEntities where !live.contains(id) {
            entity.removeFromParent()
            peelEntities.removeValue(forKey: id)
        }
        for peel in engine.droppedBananas {
            if peelEntities[peel.id] == nil {
                let node = WorldFactory.bananaPeel()
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

/// Cached handles into a penguin entity so per-frame animation skips tree searches.
private struct PenguinRig {
    let flipL: Entity?
    let flipR: Entity?
    let tail: Entity?
    let shroud: Entity?
    let glow: PointLight?

    init(_ entity: Entity) {
        flipL = entity.findEntity(named: "flipL")
        flipR = entity.findEntity(named: "flipR")
        tail = entity.findEntity(named: "scarfTail")
        shroud = entity.findEntity(named: "ghostShroud")
        glow = entity.findEntity(named: "sledGlow") as? PointLight
    }
}
