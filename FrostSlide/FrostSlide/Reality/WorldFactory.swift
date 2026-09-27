import RealityKit
import simd
import UIKit

enum WorldFactory {
    static func build(level: LevelDefinition, path: TrackPath, into root: Entity) {
        addLights(level: level, root: root)
        addSky(level: level, root: root)
        addGround(path: path, level: level, root: root)
        addBanks(path: path, level: level, root: root)
        for entity in level.entities {
            let node = makeProp(entity, level: level, path: path)
            node.name = entity.id.uuidString
            root.addChild(node)
        }
    }

    static func addLights(level: LevelDefinition, root: Entity) {
        let pal = level.palette
        let sun = DirectionalLight()
        sun.light.color = RKMat.ui(pal.sunColor)
        sun.light.intensity = pal.sunIntensity * 8
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 90, depthBias: 1)
        sun.look(at: [0, 0, 0], from: [24, 48, 18], relativeTo: nil)
        root.addChild(sun)

        if pal.night {
            let fill = DirectionalLight()
            fill.light.color = RKMat.ui(pal.accent)
            fill.light.intensity = 1800
            fill.look(at: [0, 0, 0], from: [-16, 22, 10], relativeTo: nil)
            root.addChild(fill)
        }
    }

    static func addSky(level: LevelDefinition, root: Entity) {
        let sky = ModelEntity(
            mesh: .generateSphere(radius: 380),
            materials: [RKMat.unlit(level.palette.skyBottom)]
        )
        sky.scale = [-1, 1, 1]
        root.addChild(sky)
    }

    static func addGround(path: TrackPath, level: LevelDefinition, root: Entity) {
        let mesh = RKMesh.ribbon(path: path)
        let ground = RKEntity.model(mesh, RKMat.pbr(level.palette.snow, roughness: 0.84, doubleSided: true))
        ground.name = "trackSurface"
        root.addChild(ground)

        if level.theme == .harbor {
            let water = RKEntity.box(
                [80, 0.4, level.length + 40],
                SIMD3(0.12, 0.28, 0.40),
                roughness: 0.12
            )
            let mid = path.sample(at: 0.5).position
            water.position = [mid.x, mid.y - 2.6, mid.z]
            root.addChild(water)
        }
    }

    static func addBanks(path: TrackPath, level: LevelDefinition, root: Entity) {
        let step = max(1, path.samples.count / 64)
        let mesh = MeshResource.generateSphere(radius: 1)
        let mat = RKMat.pbr(level.palette.snow, roughness: 0.9)
        for i in stride(from: 0, to: path.samples.count, by: step) {
            let s = path.samples[i]
            for sign: Float in [-1, 1] {
                let mound = ModelEntity(mesh: mesh, materials: [mat])
                let pos = s.position + s.binormal * sign * (s.width * 0.5 + 1.3) + s.normal * 0.15
                mound.position = pos
                mound.scale = [1.6, 0.45, 1.3]
                root.addChild(mound)
            }
        }
    }

    static func makeProp(_ entity: PlacedEntity, level: LevelDefinition, path: TrackPath) -> Entity {
        let sample = path.sample(at: entity.progress)
        let pos = path.worldPosition(progress: entity.progress, lateral: entity.lateral, height: 0)
        let node: Entity
        switch entity.kind {
        case .building: node = building(palette: level.palette, scale: entity.scale)
        case .arch: node = archway()
        case .stall: node = stall()
        case .crateStack, .crate: node = crate(scale: entity.scale)
        case .pine: node = pine(scale: entity.scale)
        case .dock: node = dockPlank(width: sample.width)
        case .boat: node = boat()
        case .icicle: node = icicle(scale: entity.scale)
        case .auroraRibbon: node = auroraRibbon()
        case .lantern, .lamp: node = lantern(night: level.palette.night)
        case .chimney: node = chimney()
        case .barrel: node = barrel()
        case .snowman: node = snowman()
        case .icePatch: node = icePatch(radius: entity.radius)
        case .cart: node = cart()
        case .bridge: node = lowBridge(width: sample.width)
        case .stalactite: node = stalactite()
        case .water: node = Entity()
        case .wind: node = windWhisp()
        case .npc: node = marketNPC()
        case .crystal: node = crystal()
        case .turboPad: node = turboPad()
        case .ramp: node = boostRamp()
        case .rocket: node = powerOrb(SIMD3(1.0, 0.4, 0.2), "rocket")
        case .magnet: node = powerOrb(SIMD3(0.3, 0.85, 1.0), "magnet")
        case .ghost: node = powerOrb(SIMD3(0.8, 0.9, 1.0), "ghost")
        case .banana: node = powerOrb(SIMD3(1.0, 0.85, 0.15), "banana")
        case .checkpoint: node = checkpointGate(width: sample.width)
        case .finish: node = finishGate(width: sample.width)
        case .startBanner: node = finishGate(width: sample.width)
        }
        node.position = pos
        node.orientation = simd_quatf(angle: sample.heading + entity.yaw, axis: [0, 1, 0])
        if entity.scale != 1, entity.kind != .building, entity.kind != .pine, entity.kind != .crate {
            node.scale = SIMD3(repeating: entity.scale)
        }
        return node
    }

    static func building(palette: LevelPalette, scale: Float) -> Entity {
        let root = Entity()
        let w: Float = 3.4 + scale * 0.6
        let h: Float = 6.5 + scale * 2.4
        let d: Float = 3.2
        let jitter = Float.random(in: -0.06...0.08)
        let wall = simd_clamp(palette.wall + SIMD3(jitter, jitter * 0.5, -jitter * 0.3), SIMD3(repeating: 0), SIMD3(repeating: 1))
        let body = RKEntity.box([w, h, d], wall, roughness: 0.7)
        body.position.y = h / 2
        root.addChild(body)
        let roof = RKEntity.box([w + 0.3, 0.35, d + 0.3], SIMD3(0.97, 0.97, 0.98), roughness: 0.85)
        roof.position.y = h + 0.1
        root.addChild(roof)
        for col: Float in [-1, 1] {
            for row: Float in [0.35, 0.62] {
                let win = RKEntity.box([0.45, 0.62, 0.06], SIMD3(0.35, 0.5, 0.62), roughness: 0.2)
                win.position = [col * w * 0.22, h * row, d * 0.51]
                root.addChild(win)
            }
        }
        return root
    }

    static func archway() -> Entity {
        let root = Entity()
        let stone = SIMD3<Float>(0.93, 0.94, 0.95)
        for sign: Float in [-1, 1] {
            let p = RKEntity.box([1.15, 7.2, 1.4], stone, roughness: 0.7)
            p.position = [sign * 4.1, 3.6, 0]
            root.addChild(p)
        }
        let beam = RKEntity.box([9.6, 1.5, 1.6], stone, roughness: 0.68)
        beam.position.y = 7.4
        root.addChild(beam)
        let facade = RKEntity.box([11, 3.8, 1.8], SIMD3(0.22, 0.62, 0.78), roughness: 0.55)
        facade.position.y = 9.8
        root.addChild(facade)
        return root
    }

    static func boostRamp() -> Entity {
        let root = Entity()
        let slab = RKEntity.box([3.6, 0.55, 4.2], SIMD3(0.15, 0.82, 0.95), roughness: 0.35)
        slab.orientation = simd_quatf(angle: -0.28, axis: [1, 0, 0])
        slab.position = [0, 0.55, 0.4]
        root.addChild(slab)
        for i in 0..<3 {
            let stripe = RKEntity.box([3.1, 0.04, 0.38], SIMD3(1, 1, 1), roughness: 0.25)
            stripe.position = [0, 0.72 + Float(i) * 0.08, -0.4 + Float(i) * 0.7]
            stripe.orientation = simd_quatf(angle: -0.28, axis: [1, 0, 0])
            root.addChild(stripe)
        }
        return root
    }

    static func turboPad() -> Entity {
        let root = Entity()
        let disc = RKEntity.model(
            RKMesh.cylinder(radius: 1.15, height: 0.06),
            RKMat.pbr(SIMD3(0.2, 0.85, 1.0), roughness: 0.2, emissive: SIMD3(0.15, 0.55, 0.8))
        )
        disc.position.y = 0.05
        root.addChild(disc)
        let chev = RKEntity.model(RKMesh.cone(bottomRadius: 0.35, height: 0.7), RKMat.pbr(SIMD3(1, 1, 1), roughness: 0.2))
        chev.orientation = simd_quatf(angle: Float.pi / 2, axis: [1, 0, 0])
        chev.position = [0, 0.12, 0]
        root.addChild(chev)
        return root
    }

    static func crystal() -> Entity {
        let node = RKEntity.box(
            [0.32, 0.55, 0.32],
            SIMD3(0.45, 0.9, 1.0),
            roughness: 0.12
        )
        node.position.y = 0.7
        node.name = "crystalSpin"
        return node
    }

    static func powerOrb(_ color: SIMD3<Float>, _ symbol: String) -> Entity {
        let node = RKEntity.sphere(0.38, color, roughness: 0.15)
        node.position.y = 0.85
        node.name = "power-\(symbol)"
        return node
    }

    static func snowman() -> Entity {
        let root = Entity()
        let white = SIMD3<Float>(0.96, 0.97, 0.98)
        let n1 = RKEntity.sphere(0.55, white, roughness: 0.85); n1.position.y = 0.5
        let n2 = RKEntity.sphere(0.40, white, roughness: 0.85); n2.position.y = 1.2
        let n3 = RKEntity.sphere(0.28, white, roughness: 0.85); n3.position.y = 1.75
        let hat = RKEntity.model(RKMesh.cylinder(radius: 0.22, height: 0.22), RKMat.pbr(SIMD3(0.15, 0.18, 0.28), roughness: 0.6))
        hat.position.y = 2.05
        let nose = RKEntity.model(RKMesh.cone(bottomRadius: 0.05, height: 0.18), RKMat.pbr(SIMD3(1, 0.5, 0.1), roughness: 0.4))
        nose.orientation = simd_quatf(angle: Float.pi / 2, axis: [1, 0, 0])
        nose.position = [0, 1.72, 0.28]
        [n1, n2, n3, hat, nose].forEach { root.addChild($0) }
        return root
    }

    static func crate(scale: Float) -> Entity {
        let node = RKEntity.box([0.95, 0.95, 0.95], SIMD3(0.62, 0.42, 0.22), roughness: 0.75)
        node.position.y = 0.48
        node.scale = SIMD3(repeating: scale)
        return node
    }

    static func cart() -> Entity {
        let root = Entity()
        let bed = RKEntity.box([1.6, 0.45, 1.1], SIMD3(0.55, 0.32, 0.16), roughness: 0.7)
        bed.position.y = 0.55
        root.addChild(bed)
        for sign: Float in [-1, 1] {
            for z: Float in [-0.4, 0.4] {
                let wheel = RKEntity.model(RKMesh.cylinder(radius: 0.22, height: 0.12), RKMat.pbr(SIMD3(0.2, 0.2, 0.22), roughness: 0.5))
                wheel.orientation = simd_quatf(angle: Float.pi / 2, axis: [0, 0, 1])
                wheel.position = [sign * 0.55, 0.22, z]
                root.addChild(wheel)
            }
        }
        return root
    }

    static func marketNPC() -> Entity {
        let root = Entity()
        let body = RKEntity.model(RKMesh.capsule(radius: 0.22, height: 0.9), RKMat.pbr(SIMD3(0.7, 0.25, 0.22), roughness: 0.6))
        body.position.y = 0.7
        let head = RKEntity.sphere(0.18, SIMD3(0.96, 0.80, 0.68), roughness: 0.5)
        head.position.y = 1.28
        root.addChild(body)
        root.addChild(head)
        return root
    }

    static func stall() -> Entity {
        let root = Entity()
        let table = RKEntity.box([2.2, 0.15, 1.1], SIMD3(0.55, 0.35, 0.18), roughness: 0.7)
        table.position.y = 0.85
        let cloth = RKEntity.box([2.25, 0.72, 0.06], SIMD3(0.82, 0.22, 0.25), roughness: 0.6)
        cloth.position = [0, 0.5, 0.55]
        let canopy = RKEntity.box([2.4, 0.08, 1.4], SIMD3(0.15, 0.72, 0.85), roughness: 0.45)
        canopy.position.y = 1.85
        [table, cloth, canopy].forEach { root.addChild($0) }
        return root
    }

    static func pine(scale: Float) -> Entity {
        let root = Entity()
        let trunk = RKEntity.model(RKMesh.cylinder(radius: 0.16, height: 1.1), RKMat.pbr(SIMD3(0.38, 0.24, 0.14), roughness: 0.8))
        trunk.position.y = 0.55
        root.addChild(trunk)
        var y: Float = 1.1
        for i in 0..<3 {
            let cone = RKEntity.model(
                RKMesh.cone(bottomRadius: 1.3 - Float(i) * 0.28, height: 1.35),
                RKMat.pbr(SIMD3(0.16, 0.38, 0.26), roughness: 0.75)
            )
            cone.position.y = y
            root.addChild(cone)
            y += 0.7
        }
        root.scale = SIMD3(repeating: scale)
        return root
    }

    static func dockPlank(width: Float) -> Entity {
        let node = RKEntity.box([width + 1.5, 0.18, 4.2], SIMD3(0.50, 0.34, 0.20), roughness: 0.8)
        node.position.y = 0.04
        return node
    }

    static func boat() -> Entity {
        let hull = RKEntity.model(RKMesh.capsule(radius: 0.7, height: 3.4), RKMat.pbr(SIMD3(0.28, 0.22, 0.18), roughness: 0.55))
        hull.orientation = simd_quatf(angle: Float.pi / 2, axis: [0, 0, 1])
        hull.position.y = 0.4
        return hull
    }

    static func icicle(scale: Float) -> Entity {
        let node = RKEntity.model(
            RKMesh.cone(bottomRadius: 0.22, height: 1.8 * scale),
            RKMat.pbr(SIMD3(0.55, 0.85, 1.0), roughness: 0.15, alpha: 0.65)
        )
        node.position.y = 4.2
        node.orientation = simd_quatf(angle: Float.pi, axis: [1, 0, 0])
        return node
    }

    static func stalactite() -> Entity {
        let node = RKEntity.model(RKMesh.cone(bottomRadius: 0.32, height: 2.4), RKMat.pbr(SIMD3(0.45, 0.72, 0.88), roughness: 0.35))
        node.position.y = 2.6
        node.orientation = simd_quatf(angle: Float.pi, axis: [1, 0, 0])
        return node
    }

    static func auroraRibbon() -> Entity {
        let node = ModelEntity(
            mesh: .generatePlane(width: 18, height: 5),
            materials: [RKMat.pbr(SIMD3(0.35, 0.95, 0.65), roughness: 0.4, emissive: SIMD3(0.2, 0.55, 0.4), alpha: 0.22)]
        )
        node.position.y = 12
        return node
    }

    static func lantern(night: Bool) -> Entity {
        let root = Entity()
        let pole = RKEntity.model(RKMesh.cylinder(radius: 0.07, height: 2.6), RKMat.pbr(SIMD3(0.2, 0.2, 0.22), roughness: 0.5))
        pole.position.y = 1.3
        let bulb = RKEntity.sphere(0.18, SIMD3(1, 0.85, 0.45), roughness: 0.15)
        bulb.position.y = 2.55
        if night {
            let light = PointLight()
            light.light.color = UIColor(red: 1, green: 0.82, blue: 0.5, alpha: 1)
            light.light.intensity = 900
            light.light.attenuationRadius = 12
            bulb.addChild(light)
        }
        root.addChild(pole)
        root.addChild(bulb)
        return root
    }

    static func chimney() -> Entity {
        let node = RKEntity.box([0.7, 2.2, 0.7], SIMD3(0.55, 0.28, 0.22), roughness: 0.8)
        node.position.y = 1.1
        return node
    }

    static func barrel() -> Entity {
        let node = RKEntity.model(RKMesh.cylinder(radius: 0.32, height: 0.55), RKMat.pbr(SIMD3(0.48, 0.30, 0.16), roughness: 0.7))
        node.position.y = 0.28
        return node
    }

    static func icePatch(radius: Float) -> Entity {
        let node = RKEntity.model(
            RKMesh.cylinder(radius: radius, height: 0.04),
            RKMat.pbr(SIMD3(0.55, 0.85, 1.0), roughness: 0.08, metallic: 0.35, alpha: 0.7)
        )
        node.position.y = 0.03
        return node
    }

    static func lowBridge(width: Float) -> Entity {
        let root = Entity()
        let wood = SIMD3<Float>(0.4, 0.26, 0.14)
        for sign: Float in [-1, 1] {
            let post = RKEntity.box([0.35, 1.8, 0.35], wood, roughness: 0.7)
            post.position = [sign * (width * 0.28), 0.9, 0]
            root.addChild(post)
        }
        let beam = RKEntity.box([width * 0.7, 0.22, 0.4], wood, roughness: 0.7)
        beam.position.y = 1.7
        root.addChild(beam)
        return root
    }

    static func windWhisp() -> Entity {
        let node = ModelEntity(
            mesh: .generatePlane(width: 6, height: 1.2),
            materials: [RKMat.pbr(SIMD3(1, 1, 1), roughness: 0.8, alpha: 0.16)]
        )
        node.position.y = 1.4
        return node
    }

    static func checkpointGate(width: Float) -> Entity {
        let root = Entity()
        for sign: Float in [-1, 1] {
            let pole = RKEntity.model(RKMesh.cylinder(radius: 0.09, height: 2.4), RKMat.pbr(SIMD3(0.2, 0.7, 1.0), roughness: 0.3, emissive: SIMD3(0.1, 0.3, 0.5)))
            pole.position = [sign * (width * 0.42), 1.2, 0]
            root.addChild(pole)
        }
        return root
    }

    static func finishGate(width: Float) -> Entity {
        let root = checkpointGate(width: width)
        let banner = RKEntity.box([width * 0.9, 0.55, 0.12], SIMD3(1.0, 0.32, 0.42), roughness: 0.4)
        banner.position.y = 2.6
        root.addChild(banner)
        return root
    }
}
