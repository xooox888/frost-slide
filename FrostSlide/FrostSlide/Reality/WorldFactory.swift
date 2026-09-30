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
        let material: RealityKit.Material
        if let texture = RKTexture.sky(level.palette) {
            material = RKMat.unlit(texture: texture)
        } else {
            material = RKMat.unlit(level.palette.skyBottom)
        }
        let sky = ModelEntity(mesh: .generateSphere(radius: 360), materials: [material])
        sky.name = "sky"
        sky.scale = [-1, 1, 1]
        root.addChild(sky)
    }

    static func addGround(path: TrackPath, level: LevelDefinition, root: Entity) {
        let mesh = RKMesh.ribbon(path: path)
        var mat = RKMat.pbr(level.palette.snow, roughness: 0.78, doubleSided: true)
        // Base colour only: an emissive texture here lit the whole ribbon white
        // and washed out the grooves and rails, which already read in the albedo.
        if let color = RKTexture.track(level.palette) {
            mat.baseColor = .init(tint: .white, texture: .init(color, sampler: RKTexture.repeating))
        }
        let ground = RKEntity.model(mesh, mat)
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
        // Soft drifts with a cool shadow tint so the white track keeps a readable edge.
        let step = max(1, path.samples.count / 110)
        let mesh = MeshResource.generateSphere(radius: 1)
        let drift = RKMat.pbr(simd_mix(level.palette.snow, level.palette.ice, SIMD3(repeating: 0.18)), roughness: 0.92)
        let deep = RKMat.pbr(simd_mix(level.palette.snow, level.palette.ice, SIMD3(repeating: 0.38)), roughness: 0.92)
        var flip = false
        for i in stride(from: 0, to: path.samples.count, by: step) {
            let s = path.samples[i]
            flip.toggle()
            for sign: Float in [-1, 1] {
                let mound = ModelEntity(mesh: mesh, materials: [flip ? drift : deep])
                // Sit outside the track edge so the glowing rails stay visible.
                let pos = s.position + s.binormal * sign * (s.width * 0.5 + 2.9) + s.normal * 0.1
                mound.position = pos
                let wobble = Float((i * 7919) % 13) / 13
                mound.scale = [2.2 + wobble * 0.8, 0.75 + wobble * 0.45, 2.4]
                mound.orientation = simd_quatf(angle: s.heading, axis: [0, 1, 0])
                root.addChild(mound)
            }
        }
    }

    /// Track furniture wide enough that the banking would show if it stayed level.
    private static let followsBank: Set<PropKind> = [
        .arch, .ramp, .turboPad, .icePatch, .checkpoint, .finish, .startBanner,
        .shortcut, .neonArch, .movingBridge, .bridge, .dock
    ]

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
        case .flare: node = powerOrb(SIMD3(1.0, 0.92, 0.35), "flare")
        case .avalanche: node = avalancheMarker()
        case .shortcut: node = shortcutGate(width: sample.width)
        case .movingBridge: node = movingBridge(width: sample.width)
        case .geyser: node = geyser()
        case .carnivalFloat: node = carnivalFloat()
        case .neonArch: node = neonArchway(width: sample.width)
        case .crystalSpire: node = crystalSpire(scale: entity.scale)
        }
        node.position = pos
        let heading = simd_quatf(angle: sample.heading + entity.yaw, axis: [0, 1, 0])
        // Wide props sit on the tilted surface instead of floating over one side of it.
        node.orientation = followsBank.contains(entity.kind)
            ? heading * simd_quatf(angle: sample.bank, axis: [0, 0, 1])
            : heading
        if entity.scale != 1, entity.kind != .building, entity.kind != .pine, entity.kind != .crate {
            node.scale = SIMD3(repeating: entity.scale)
        }
        return node
    }

    static func building(palette: LevelPalette, scale: Float) -> Entity {
        let root = Entity()
        let w: Float = 3.6 + scale * 0.6
        let h: Float = 4.6 + scale * 1.8
        let d: Float = 3.6
        let walls: [SIMD3<Float>] = [
            SIMD3(0.36, 0.62, 0.74), SIMD3(0.93, 0.88, 0.78), SIMD3(0.52, 0.66, 0.86),
            SIMD3(0.80, 0.47, 0.38), SIMD3(0.44, 0.70, 0.66)
        ]
        let roofs: [SIMD3<Float>] = [SIMD3(0.16, 0.26, 0.46), SIMD3(0.12, 0.44, 0.52), SIMD3(0.58, 0.20, 0.22)]
        let wall = simd_mix(palette.wall, walls.randomElement()!, SIMD3(repeating: 0.6))
        let body = RKEntity.box([w, h, d], wall, roughness: 0.75)
        body.position.y = h / 2
        root.addChild(body)

        let trim = RKEntity.box([w + 0.12, 0.22, d + 0.12], SIMD3(0.96, 0.96, 0.98), roughness: 0.6)
        trim.position.y = h - 0.1
        root.addChild(trim)

        let roofH: Float = 1.8 + scale * 0.3
        let roof = RKEntity.model(
            RKMesh.gableRoof(width: w + 0.8, height: roofH, depth: d + 0.7),
            RKMat.pbr(roofs.randomElement()!, roughness: 0.55)
        )
        roof.position.y = h
        root.addChild(roof)
        // Snow cap: same slope as the roof, shorter, so coloured eaves show below it.
        let cap = RKEntity.model(
            RKMesh.gableRoof(width: (w + 0.8) * 0.72, height: roofH * 0.72, depth: d + 0.9),
            RKMat.pbr(SIMD3(0.97, 0.98, 1.0), roughness: 0.9)
        )
        cap.position.y = h + roofH * 0.28 + 0.08
        root.addChild(cap)

        let chimney = RKEntity.box([0.55, 1.4, 0.55], SIMD3(0.55, 0.30, 0.24), roughness: 0.8)
        chimney.position = [w * 0.24, h + roofH * 0.7, -d * 0.2]
        root.addChild(chimney)
        let chimneySnow = RKEntity.box([0.68, 0.16, 0.68], SIMD3(0.97, 0.98, 1.0), roughness: 0.9)
        chimneySnow.position = [w * 0.24, h + roofH * 0.7 + 0.76, -d * 0.2]
        root.addChild(chimneySnow)

        // Warm lit windows on every face so they read from the chase camera.
        let lit = RKMat.glow(SIMD3(1.0, 0.76, 0.40), intensity: palette.night ? 2.2 : 1.1)
        let frame = RKMat.pbr(SIMD3(0.97, 0.97, 0.98), roughness: 0.6)
        let pane = MeshResource.generateBox(size: [0.5, 0.66, 0.06])
        let border = MeshResource.generateBox(size: [0.66, 0.82, 0.04])
        let rows: [Float] = h > 6 ? [0.3, 0.62] : [0.45]
        for row in rows {
            for col: Float in [-1, 1] {
                for (pos, yaw) in [
                    (SIMD3<Float>(col * w * 0.24, h * row, d * 0.51), Float(0)),
                    (SIMD3<Float>(col * w * 0.24, h * row, -d * 0.51), Float.pi),
                    (SIMD3<Float>(w * 0.51, h * row, col * d * 0.24), Float.pi / 2),
                    (SIMD3<Float>(-w * 0.51, h * row, col * d * 0.24), -Float.pi / 2)
                ] {
                    let b = ModelEntity(mesh: border, materials: [frame])
                    b.position = pos
                    b.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                    root.addChild(b)
                    let win = ModelEntity(mesh: pane, materials: [lit])
                    win.position = pos + simd_quatf(angle: yaw, axis: [0, 1, 0]).act([0, 0, 0.02])
                    win.orientation = b.orientation
                    root.addChild(win)
                }
            }
        }
        let door = RKEntity.box([0.9, 1.5, 0.08], SIMD3(0.36, 0.22, 0.14), roughness: 0.7)
        door.position = [0, 0.75, -d * 0.52]
        root.addChild(door)
        let drift = RKEntity.sphere(1, SIMD3(0.95, 0.97, 1.0), roughness: 0.92)
        drift.scale = [w * 0.62, 0.35, d * 0.62]
        root.addChild(drift)
        return root
    }

    static func archway() -> Entity {
        // Ice-crystal arch from the menu art: glassy pillars, a curved crystal span, glowing core.
        let root = Entity()
        let ice = RKMat.pbr(SIMD3(0.62, 0.88, 1.0), roughness: 0.08, metallic: 0.1, emissive: SIMD3(0.10, 0.36, 0.60), alpha: 0.86)
        let core = RKMat.glow(SIMD3(0.30, 0.85, 1.0), intensity: 1.4)
        let spike = RKMesh.cone(bottomRadius: 0.42, height: 1.5, segments: 6)
        let radius: Float = 4.1
        let lift: Float = 5.6
        for sign: Float in [-1, 1] {
            let pillar = RKEntity.model(.generateBox(size: [1.0, lift, 1.1], cornerRadius: 0.12), ice)
            pillar.position = [sign * radius, lift / 2, 0]
            root.addChild(pillar)
            let seam = RKEntity.model(.generateBox(size: [0.18, lift * 0.92, 1.14]), core)
            seam.position = [sign * radius, lift / 2, 0]
            root.addChild(seam)
            for k in 0..<3 {
                let c = RKEntity.model(spike, ice)
                let fk = Float(k)
                c.position = [sign * (radius + 0.5 + fk * 0.25), 0.7 + fk * 0.2, (fk - 1) * 0.45]
                c.orientation = simd_quatf(angle: -sign * (0.35 + fk * 0.15), axis: [0, 0, 1])
                c.scale = SIMD3(repeating: 0.8 + fk * 0.2)
                root.addChild(c)
            }
        }
        let segments = 9
        for i in 0..<segments {
            let a = Float.pi * (Float(i) + 0.5) / Float(segments)
            let block = RKEntity.model(.generateBox(size: [1.55, 0.95, 1.1], cornerRadius: 0.1), ice)
            block.position = [cos(a) * radius, lift + sin(a) * (radius * 0.72), 0]
            block.orientation = simd_quatf(angle: a - Float.pi / 2, axis: [0, 0, 1])
            root.addChild(block)
            let tip = RKEntity.model(spike, i % 2 == 0 ? ice : core)
            tip.position = [cos(a) * (radius + 0.9), lift + sin(a) * (radius * 0.72 + 0.9), 0]
            tip.orientation = simd_quatf(angle: a - Float.pi / 2, axis: [0, 0, 1])
            tip.scale = SIMD3(repeating: i % 2 == 0 ? 1.0 : 0.7)
            root.addChild(tip)
        }
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
            RKMat.pbr(SIMD3(0.15, 0.92, 1.0), roughness: 0.16, emissive: SIMD3(0.22, 0.72, 1.0))
        )
        disc.position.y = 0.05
        disc.name = "turboGlow"
        root.addChild(disc)
        let ring = RKEntity.model(
            RKMesh.cylinder(radius: 1.38, height: 0.03),
            RKMat.pbr(SIMD3(1.0, 0.95, 0.55), roughness: 0.18, emissive: SIMD3(0.55, 0.42, 0.08))
        )
        ring.position.y = 0.04
        root.addChild(ring)
        let chev = RKEntity.model(RKMesh.cone(bottomRadius: 0.32, height: 0.62), RKMat.pbr(SIMD3(1, 1, 1), roughness: 0.15, emissive: SIMD3(0.35, 0.35, 0.35)))
        chev.orientation = simd_quatf(angle: Float.pi / 2, axis: [1, 0, 0])
        chev.position = [0, 0.14, -0.12]
        root.addChild(chev)
        let chev2 = RKEntity.model(RKMesh.cone(bottomRadius: 0.26, height: 0.5), RKMat.pbr(SIMD3(1, 1, 1), roughness: 0.15, emissive: SIMD3(0.25, 0.25, 0.25)))
        chev2.orientation = simd_quatf(angle: Float.pi / 2, axis: [1, 0, 0])
        chev2.position = [0, 0.14, 0.38]
        root.addChild(chev2)
        return root
    }

    static func crystal() -> Entity {
        let node = Entity()
        let gem = RKMat.glow(SIMD3(0.35, 0.88, 1.0), intensity: 1.3, alpha: 0.95)
        let top = RKEntity.model(RKMesh.cone(bottomRadius: 0.24, height: 0.42, segments: 6), gem)
        top.position.y = 0.21
        let bottom = RKEntity.model(RKMesh.cone(bottomRadius: 0.24, height: 0.3, segments: 6), gem)
        bottom.position.y = -0.15
        bottom.orientation = simd_quatf(angle: Float.pi, axis: [1, 0, 0])
        node.addChild(top)
        node.addChild(bottom)
        node.position.y = 0.7
        node.name = "crystalSpin"
        return node
    }

    static func powerOrb(_ color: SIMD3<Float>, _ symbol: String) -> Entity {
        let node = RKEntity.model(.generateSphere(radius: 0.38), RKMat.glow(color, intensity: 1.2))
        let halo = RKEntity.model(.generateSphere(radius: 0.55), RKMat.pbr(color, roughness: 0.1, emissive: color * 0.5, alpha: 0.25))
        node.addChild(halo)
        node.position.y = 0.85
        node.name = "power-\(symbol)"
        return node
    }

    static func snowman() -> Entity {
        let root = Entity()
        let white = SIMD3<Float>(0.96, 0.97, 0.98)
        let coal = SIMD3<Float>(0.08, 0.08, 0.10)
        let n1 = RKEntity.sphere(0.55, white, roughness: 0.85); n1.position.y = 0.5
        let n2 = RKEntity.sphere(0.40, white, roughness: 0.85); n2.position.y = 1.2
        let n3 = RKEntity.sphere(0.28, white, roughness: 0.85); n3.position.y = 1.75
        let hat = RKEntity.model(RKMesh.cylinder(radius: 0.22, height: 0.26), RKMat.pbr(SIMD3(0.15, 0.18, 0.28), roughness: 0.6))
        hat.position.y = 2.07
        let brim = RKEntity.model(RKMesh.cylinder(radius: 0.32, height: 0.04), RKMat.pbr(SIMD3(0.15, 0.18, 0.28), roughness: 0.6))
        brim.position.y = 1.95
        let nose = RKEntity.model(RKMesh.cone(bottomRadius: 0.05, height: 0.2), RKMat.pbr(SIMD3(1, 0.5, 0.1), roughness: 0.4))
        nose.orientation = simd_quatf(angle: Float.pi / 2, axis: [1, 0, 0])
        nose.position = [0, 1.72, 0.3]
        let scarf = RKEntity.model(RKMesh.cylinder(radius: 0.33, height: 0.12), RKMat.pbr(SIMD3(0.92, 0.26, 0.34), roughness: 0.6))
        scarf.position.y = 1.5
        let tail = RKEntity.box([0.14, 0.42, 0.05], SIMD3(0.92, 0.26, 0.34), roughness: 0.6)
        tail.position = [0.16, 1.32, 0.3]
        [n1, n2, n3, hat, brim, nose, scarf, tail].forEach { root.addChild($0) }
        for sign: Float in [-1, 1] {
            let eye = RKEntity.sphere(0.04, coal, roughness: 0.3)
            eye.position = [sign * 0.1, 1.82, 0.25]
            root.addChild(eye)
            let arm = RKEntity.model(RKMesh.cylinder(radius: 0.025, height: 0.8), RKMat.pbr(SIMD3(0.36, 0.22, 0.12), roughness: 0.8))
            arm.position = [sign * 0.62, 1.32, 0]
            arm.orientation = simd_quatf(angle: sign * 1.0, axis: [0, 0, 1])
            root.addChild(arm)
        }
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
        [table, cloth].forEach { root.addChild($0) }
        for i in 0..<6 {
            let stripe = RKEntity.box([0.4, 0.1, 1.45], i % 2 == 0 ? SIMD3(0.96, 0.96, 0.98) : SIMD3(0.15, 0.62, 0.85), roughness: 0.5)
            stripe.position = [-1.0 + Float(i) * 0.4, 1.85, 0]
            root.addChild(stripe)
        }
        for sign: Float in [-1, 1] {
            let post = RKEntity.box([0.08, 1.8, 0.08], SIMD3(0.45, 0.30, 0.16), roughness: 0.7)
            post.position = [sign * 1.05, 0.9, -0.6]
            root.addChild(post)
        }
        return root
    }

    static func pine(scale: Float) -> Entity {
        let root = Entity()
        let trunk = RKEntity.model(RKMesh.cylinder(radius: 0.18, height: 1.1), RKMat.pbr(SIMD3(0.38, 0.24, 0.14), roughness: 0.8))
        trunk.position.y = 0.55
        root.addChild(trunk)
        let needles = RKMat.pbr(SIMD3(0.10, 0.34, 0.27), roughness: 0.8)
        let snow = RKMat.pbr(SIMD3(0.95, 0.97, 1.0), roughness: 0.9)
        var y: Float = 1.25
        for i in 0..<4 {
            let r = 1.45 - Float(i) * 0.3
            let cone = RKEntity.model(RKMesh.cone(bottomRadius: r, height: 1.3, segments: 12), needles)
            cone.position.y = y
            root.addChild(cone)
            let cap = RKEntity.model(RKMesh.cone(bottomRadius: r * 0.62, height: 0.8, segments: 12), snow)
            cap.position.y = y + 0.28
            root.addChild(cap)
            y += 0.72
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
        let bulb = RKEntity.model(.generateSphere(radius: 0.2), RKMat.glow(SIMD3(1, 0.82, 0.45), intensity: night ? 2.4 : 1.2))
        bulb.position.y = 2.6
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
        // The slippery zone is an ellipse stretched along the track (see Tuning.icePatchStretch);
        // draw exactly that, so the patch you see is the patch you slide on.
        node.scale = [1, 1, Tuning.icePatchStretch]
        return node
    }

    /// A dropped peel: yellow petals splayed on the snow inside a warning ring, so it can't be
    /// mistaken for the glowing orb that gives you one.
    static func bananaPeel() -> Entity {
        let root = Entity()
        let yellow = RKMat.pbr(SIMD3(1.0, 0.86, 0.18), roughness: 0.35, emissive: SIMD3(0.30, 0.24, 0.02))
        let brown = RKMat.pbr(SIMD3(0.35, 0.22, 0.08), roughness: 0.6)
        for k in 0..<3 {
            let angle = Float(k) * 2 * Float.pi / 3
            let petal = RKEntity.model(.generateSphere(radius: 0.32), yellow)
            petal.scale = [1.5, 0.22, 0.6]
            petal.position = [cos(angle) * 0.34, 0.12, sin(angle) * 0.34]
            petal.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
            root.addChild(petal)
        }
        let stalk = RKEntity.model(RKMesh.cylinder(radius: 0.06, height: 0.3), brown)
        stalk.position = [0, 0.2, 0]
        root.addChild(stalk)
        let ring = RKEntity.model(
            RKMesh.cylinder(radius: 0.85, height: 0.03),
            RKMat.pbr(SIMD3(1.0, 0.35, 0.2), roughness: 0.3, emissive: SIMD3(0.5, 0.12, 0.05), alpha: 0.45)
        )
        ring.position.y = 0.03
        root.addChild(ring)
        return root
    }

    /// The avalanche: overlapping translucent puffs across the track, so it reads as a wave of
    /// powder and never hard-blocks the view when it rolls over the camera.
    static func avalancheCloud() -> Entity {
        let root = Entity()
        let soft = RKMat.pbr(SIMD3(0.94, 0.97, 1.0), roughness: 0.95, alpha: 0.78)
        let dense = RKMat.pbr(SIMD3(0.85, 0.92, 1.0), roughness: 0.95, alpha: 0.9)
        let puffs = 11
        for i in 0..<puffs {
            let t = Float(i) / Float(puffs - 1)
            let radius = 1.7 + Float((i * 5) % 4) * 0.45
            let puff = RKEntity.model(.generateSphere(radius: radius), i % 3 == 0 ? dense : soft)
            puff.position = [
                (t - 0.5) * 15,
                radius * 0.9 + Float((i * 7) % 3) * 0.5,
                Float((i * 3) % 3) * 0.6 - 0.6
            ]
            root.addChild(puff)
        }
        return root
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

    static func avalancheMarker() -> Entity {
        Entity()
    }

    static func shortcutGate(width: Float) -> Entity {
        let root = Entity()
        for sign: Float in [-1, 1] {
            let pole = RKEntity.model(
                RKMesh.cylinder(radius: 0.1, height: 2.8),
                RKMat.pbr(SIMD3(0.15, 0.95, 0.72), roughness: 0.25, emissive: SIMD3(0.1, 0.45, 0.32))
            )
            pole.position = [sign * 1.4, 1.4, 0]
            root.addChild(pole)
        }
        let beam = RKEntity.box([3.1, 0.22, 0.18], SIMD3(0.2, 1.0, 0.75), roughness: 0.25)
        beam.position.y = 2.7
        root.addChild(beam)
        _ = width
        return root
    }

    static func movingBridge(width: Float) -> Entity {
        let plank = RKEntity.box([width * 0.55, 0.22, 2.8], SIMD3(0.42, 0.28, 0.16), roughness: 0.7)
        plank.position.y = 0.2
        return plank
    }

    static func geyser() -> Entity {
        let root = Entity()
        let mound = RKEntity.model(RKMesh.cylinder(radius: 0.55, height: 0.28), RKMat.pbr(SIMD3(0.55, 0.48, 0.38), roughness: 0.8))
        mound.position.y = 0.12
        let steam = RKEntity.model(
            RKMesh.cone(bottomRadius: 0.32, height: 1.6),
            RKMat.pbr(SIMD3(0.92, 0.94, 0.96), roughness: 0.4, alpha: 0.28)
        )
        steam.position.y = 1.0
        root.addChild(mound)
        root.addChild(steam)
        return root
    }

    static func carnivalFloat() -> Entity {
        let root = Entity()
        let body = RKEntity.box([2.4, 1.4, 1.6], SIMD3(0.95, 0.28, 0.48), roughness: 0.45)
        body.position.y = 1.0
        let dome = RKEntity.sphere(0.7, SIMD3(1.0, 0.82, 0.25), roughness: 0.25)
        dome.position.y = 2.0
        root.addChild(body)
        root.addChild(dome)
        return root
    }

    static func neonArchway(width: Float) -> Entity {
        let root = Entity()
        for sign: Float in [-1, 1] {
            let pole = RKEntity.model(
                RKMesh.cylinder(radius: 0.08, height: 3.4),
                RKMat.pbr(SIMD3(1.0, 0.2, 0.72), roughness: 0.2, emissive: SIMD3(0.6, 0.1, 0.4))
            )
            pole.position = [sign * (width * 0.38), 1.7, 0]
            root.addChild(pole)
        }
        let beam = RKEntity.box([width * 0.82, 0.16, 0.16], SIMD3(0.2, 0.95, 1.0), roughness: 0.15)
        beam.position.y = 3.4
        root.addChild(beam)
        return root
    }

    static func crystalSpire(scale: Float) -> Entity {
        let node = RKEntity.model(
            RKMesh.cone(bottomRadius: 0.38 * scale, height: 2.6 * scale),
            RKMat.pbr(SIMD3(0.45, 0.85, 1.0), roughness: 0.12, emissive: SIMD3(0.12, 0.35, 0.55))
        )
        node.position.y = 1.3 * scale
        return node
    }

    static func finishGate(width: Float) -> Entity {
        let root = checkpointGate(width: width)
        let span = width * 0.86
        let cols = 14
        let cell = span / Float(cols)
        let black = RKMat.pbr(SIMD3(0.08, 0.09, 0.12), roughness: 0.5)
        let white = RKMat.pbr(SIMD3(0.97, 0.97, 0.98), roughness: 0.5)
        let box = MeshResource.generateBox(size: [cell, cell, 0.1])
        let top = 2.45 + cell * 2
        for sign: Float in [-1, 1] {
            let post = RKEntity.model(
                RKMesh.cylinder(radius: 0.12, height: top + 0.2),
                RKMat.glow(SIMD3(1.0, 0.32, 0.45), intensity: 0.9)
            )
            post.position = [sign * (span / 2 + 0.12), (top + 0.2) / 2, 0]
            root.addChild(post)
        }
        for row in 0..<2 {
            for col in 0..<cols {
                let tile = ModelEntity(mesh: box, materials: [(row + col) % 2 == 0 ? black : white])
                tile.position = [-span / 2 + cell * (Float(col) + 0.5), 2.45 + Float(row) * cell, 0]
                root.addChild(tile)
            }
        }
        return root
    }
}
