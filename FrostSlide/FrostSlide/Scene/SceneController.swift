import SceneKit
import UIKit

final class SceneController {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private let worldRoot = SCNNode()
    private let racerRoot = SCNNode()
    private var racerNodes: [UUID: SCNNode] = [:]
    private var pickupNodes: [UUID: SCNNode] = [:]
    private var trail: IceTrail?
    private var spray: SCNParticleSystem?
    private var streaks: SCNParticleSystem?
    private var snowNode = SCNNode()
    private var builtLevel: LevelID?
    private var trailTick: Float = 0

    func build(level: LevelDefinition, path: TrackPath, racers: [Racer]) {
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        worldRoot.name = "world"
        racerRoot.name = "racers"
        scene.rootNode.addChildNode(worldRoot)
        scene.rootNode.addChildNode(racerRoot)

        scene.fogStartDistance = CGFloat(level.palette.fogStart)
        scene.fogEndDistance = CGFloat(level.palette.fogEnd)
        scene.fogColor = UIColor(simd: level.palette.fog)
        scene.background.contents = UIColor(simd: level.palette.skyBottom)

        WorldFactory.build(level: level, path: path, into: worldRoot)

        pickupNodes = [:]
        worldRoot.enumerateChildNodes { node, _ in
            if let name = node.name, let id = UUID(uuidString: name) {
                pickupNodes[id] = node
            }
        }

        racerNodes = [:]
        racerRoot.childNodes.forEach { $0.removeFromParentNode() }
        for racer in racers {
            let node = PenguinFactory.make(sledColor: UIColor(simd: racer.sledColor))
            node.name = racer.id.uuidString
            racerRoot.addChildNode(node)
            racerNodes[racer.id] = node
        }

        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.2
        cameraNode.camera?.zFar = 420
        cameraNode.camera?.fieldOfView = 50
        cameraNode.camera?.wantsHDR = true
        cameraNode.camera?.bloomIntensity = 0.35
        cameraNode.camera?.bloomBlurRadius = 8
        scene.rootNode.addChildNode(cameraNode)

        snowNode = SCNNode()
        snowNode.addParticleSystem(EffectsFactory.snowfall(night: level.palette.night))
        scene.rootNode.addChildNode(snowNode)

        trail?.clear()
        trail = IceTrail(parent: worldRoot)

        if let playerNode = racers.first(where: { $0.isPlayer }).flatMap({ racerNodes[$0.id] }) {
            let spray = EffectsFactory.spray()
            let streaks = EffectsFactory.boostStreaks()
            playerNode.addParticleSystem(spray)
            playerNode.addParticleSystem(streaks)
            self.spray = spray
            self.streaks = streaks
        }

        builtLevel = level.id
    }

    func apply(engine: GameEngine, dt: Float) {
        guard let path = engine.path else { return }
        for racer in engine.racers {
            guard let node = racerNodes[racer.id] else { continue }
            let pos = path.worldPosition(progress: racer.progress, lateral: racer.lateral, height: racer.height)
            node.simdPosition = pos
            node.simdEulerAngles = SIMD3<Float>(racer.pitch, racer.yaw, racer.roll)
            node.scale = SCNVector3(1, racer.squash, 1)
            node.opacity = racer.ghostTime > 0 ? 0.42 : 1
            if let glow = node.childNode(withName: "sledGlow", recursively: true) {
                glow.light?.intensity = CGFloat(70 + racer.trailBoost * 160 + racer.rocketTime * 80)
            }
        }

        for entity in engine.entities {
            guard let node = pickupNodes[entity.definition.id] else { continue }
            if entity.collected || entity.destroyed {
                if node.opacity > 0.01 {
                    node.runAction(.fadeOut(duration: 0.18))
                }
                node.opacity = 0
                continue
            }
            if entity.definition.kind == .cart || entity.definition.kind == .npc {
                let pos = path.worldPosition(
                    progress: entity.definition.progress,
                    lateral: entity.liveLateral,
                    height: 0
                )
                node.simdPosition = pos
            }
            if entity.definition.kind == .crystal {
                let pos = path.worldPosition(
                    progress: entity.definition.progress,
                    lateral: entity.liveLateral,
                    height: 0.15
                )
                node.simdPosition = SIMD3(pos.x, node.simdPosition.y, pos.z)
            }
        }

        if let player = engine.playerRacer {
            let pos = path.worldPosition(progress: player.progress, lateral: player.lateral, height: 0)
            trailTick += dt
            if trailTick > 0.045 && !player.airborne {
                trailTick = 0
                trail?.push(
                    position: SCNVector3(pos),
                    tangent: path.sample(at: player.progress).tangent,
                    intense: player.trailBoost > 0 || player.rocketTime > 0
                )
            }
            spray?.birthRate = CGFloat(player.airborne ? 0 : 18 + player.speed * 1.4)
            streaks?.birthRate = CGFloat((player.trailBoost > 0 || player.rocketTime > 0) ? 70 : 0)
            snowNode.simdPosition = engine.cameraEye + SIMD3<Float>(0, 8, 10)
        }

        cameraNode.simdPosition = engine.cameraEye
        cameraNode.look(
            at: SCNVector3(engine.cameraLook),
            up: SCNVector3(0, 1, 0),
            localFront: SCNVector3(0, 0, -1)
        )
        cameraNode.camera?.fieldOfView = CGFloat(engine.cameraFOV)
    }

    func configure(_ view: SCNView) {
        view.scene = scene
        view.pointOfView = cameraNode
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.backgroundColor = .white
        view.autoenablesDefaultLighting = false
    }
}
