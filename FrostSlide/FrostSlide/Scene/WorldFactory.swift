import SceneKit
import UIKit

enum WorldFactory {
    static func build(level: LevelDefinition, path: TrackPath, into root: SCNNode) {
        addAtmosphere(level: level, root: root)
        addGround(path: path, level: level, root: root)
        addBanks(path: path, level: level, root: root)
        for entity in level.entities {
            let node = makeProp(entity, level: level, path: path)
            node.name = entity.id.uuidString
            root.addChildNode(node)
        }
    }

    static func addAtmosphere(level: LevelDefinition, root: SCNNode) {
        let pal = level.palette
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(simd: pal.ambient)
        ambient.intensity = pal.night ? 280 : 420
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        root.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.color = UIColor(simd: pal.sunColor)
        sun.intensity = pal.sunIntensity
        sun.castsShadow = true
        sun.shadowMode = .deferred
        sun.shadowSampleCount = 8
        sun.shadowColor = UIColor(white: 0, alpha: 0.22)
        sun.orthographicScale = 40
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-0.85, 0.55, 0)
        root.addChildNode(sunNode)

        if pal.night {
            let fill = SCNLight()
            fill.type = .directional
            fill.color = UIColor(simd: pal.accent)
            fill.intensity = 220
            let fillNode = SCNNode()
            fillNode.light = fill
            fillNode.eulerAngles = SCNVector3(-0.3, -0.9, 0)
            root.addChildNode(fillNode)
        }

        let sky = SCNSphere(radius: 420)
        let skyMat = SCNMaterial()
        skyMat.diffuse.contents = skyGradient(top: pal.skyTop, bottom: pal.skyBottom)
        skyMat.isDoubleSided = true
        skyMat.lightingModel = .constant
        sky.firstMaterial = skyMat
        let skyNode = SCNNode(geometry: sky)
        skyNode.scale = SCNVector3(-1, 1, 1)
        root.addChildNode(skyNode)
    }

    static func addGround(path: TrackPath, level: LevelDefinition, root: SCNNode) {
        var verts: [SCNVector3] = []
        var norms: [SCNVector3] = []
        var indices: [Int32] = []
        verts.reserveCapacity(path.samples.count * 2)

        for sample in path.samples {
            let half = sample.width * 0.5
            let left = sample.position - sample.binormal * half
            let right = sample.position + sample.binormal * half
            verts.append(SCNVector3(left))
            verts.append(SCNVector3(right))
            norms.append(SCNVector3(sample.normal))
            norms.append(SCNVector3(sample.normal))
        }
        for i in 0..<(path.samples.count - 1) {
            let a = Int32(i * 2)
            indices.append(contentsOf: [a, a + 1, a + 2, a + 1, a + 3, a + 2])
        }

        let src = SCNGeometrySource(vertices: verts)
        let nrm = SCNGeometrySource(normals: norms)
        let elem = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [src, nrm], elements: [elem])
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(simd: level.palette.snow)
        mat.roughness.contents = 0.82
        mat.metalness.contents = 0.02
        mat.lightingModel = .physicallyBased
        mat.isDoubleSided = true
        geo.firstMaterial = mat
        let node = SCNNode(geometry: geo)
        node.name = "trackSurface"
        root.addChildNode(node)

        if level.theme == .harbor {
            let water = SCNBox(width: 80, height: 0.4, length: CGFloat(level.length + 40), chamferRadius: 0)
            let wmat = SCNMaterial()
            wmat.diffuse.contents = UIColor(red: 0.12, green: 0.28, blue: 0.40, alpha: 0.92)
            wmat.emission.contents = UIColor(red: 0.05, green: 0.15, blue: 0.25, alpha: 0.4)
            wmat.roughness.contents = 0.15
            wmat.metalness.contents = 0.4
            water.firstMaterial = wmat
            let waterNode = SCNNode(geometry: water)
            let mid = path.sample(at: 0.5).position
            waterNode.position = SCNVector3(mid.x, mid.y - 2.6, mid.z)
            root.addChildNode(waterNode)
        }
    }

    static func addBanks(path: TrackPath, level: LevelDefinition, root: SCNNode) {
        let step = max(1, path.samples.count / 70)
        for i in stride(from: 0, to: path.samples.count, by: step) {
            let s = path.samples[i]
            for sign: Float in [-1, 1] {
                let mound = SCNSphere(radius: CGFloat(0.9 + s.width * 0.04))
                mound.segmentCount = 10
                let mat = SCNMaterial()
                mat.diffuse.contents = UIColor(simd: level.palette.snow)
                mat.roughness.contents = 0.9
                mound.firstMaterial = mat
                let node = SCNNode(geometry: mound)
                let pos = s.position + s.binormal * sign * (s.width * 0.5 + 1.3) + s.normal * 0.15
                node.position = SCNVector3(pos)
                node.scale = SCNVector3(1.6, 0.45, 1.3)
                root.addChildNode(node)
            }
        }
    }

    static func makeProp(_ entity: PlacedEntity, level: LevelDefinition, path: TrackPath) -> SCNNode {
        let sample = path.sample(at: entity.progress)
        let pos = path.worldPosition(progress: entity.progress, lateral: entity.lateral, height: 0)
        let node: SCNNode
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
        case .water: node = SCNNode()
        case .wind: node = windWhisp()
        case .npc: node = marketNPC()
        case .crystal: node = crystal()
        case .turboPad: node = turboPad()
        case .ramp: node = boostRamp()
        case .rocket: node = powerOrb(color: UIColor(red: 1, green: 0.4, blue: 0.2, alpha: 1), symbol: "rocket")
        case .magnet: node = powerOrb(color: UIColor(red: 0.3, green: 0.85, blue: 1, alpha: 1), symbol: "magnet")
        case .ghost: node = powerOrb(color: UIColor(red: 0.8, green: 0.9, blue: 1, alpha: 1), symbol: "ghost")
        case .banana: node = powerOrb(color: UIColor(red: 1, green: 0.85, blue: 0.15, alpha: 1), symbol: "banana")
        case .checkpoint: node = checkpointGate(width: sample.width)
        case .finish: node = finishGate(width: sample.width)
        case .startBanner: node = startBanner(width: sample.width)
        }
        node.position = SCNVector3(pos.x, pos.y, pos.z)
        node.eulerAngles.y = sample.heading + entity.yaw
        node.scale = SCNVector3(entity.scale, entity.scale, entity.scale)
        return node
    }

    static func building(palette: LevelPalette, scale: Float) -> SCNNode {
        let root = SCNNode()
        let w = CGFloat(3.4 + Double(scale) * 0.6)
        let h = CGFloat(6.5 + Double(scale) * 2.4)
        let d = CGFloat(3.2)
        let box = SCNBox(width: w, height: h, length: d, chamferRadius: 0.04)
        let wall = SCNMaterial()
        let jitter = Float.random(in: -0.06...0.08)
        wall.diffuse.contents = UIColor(simd: palette.wall + SIMD3(jitter, jitter * 0.5, -jitter * 0.3))
        wall.roughness.contents = 0.7
        let trim = SCNMaterial()
        trim.diffuse.contents = UIColor(white: 0.94, alpha: 1)
        box.materials = [wall, wall, wall, wall, trim, wall]
        let body = SCNNode(geometry: box)
        body.position.y = Float(h / 2)
        root.addChildNode(body)

        let roof = SCNBox(width: w + 0.3, height: 0.35, length: d + 0.3, chamferRadius: 0)
        roof.firstMaterial = PenguinFactory.mat(UIColor(white: 0.97, alpha: 1), roughness: 0.85)
        let roofNode = SCNNode(geometry: roof)
        roofNode.position.y = Float(h) + 0.1
        root.addChildNode(roofNode)

        for col in [-1.0, 1.0] {
            for row in [0.35, 0.62] {
                let win = SCNBox(width: 0.45, height: 0.62, length: 0.06, chamferRadius: 0)
                win.firstMaterial = PenguinFactory.mat(UIColor(red: 0.35, green: 0.5, blue: 0.62, alpha: 1), roughness: 0.2)
                let wn = SCNNode(geometry: win)
                wn.position = SCNVector3(Float(col) * Float(w) * 0.22, Float(h) * Float(row), Float(d) * 0.51)
                root.addChildNode(wn)
            }
        }
        return root
    }

    static func archway() -> SCNNode {
        let root = SCNNode()
        let pillarGeo = SCNBox(width: 1.15, height: 7.2, length: 1.4, chamferRadius: 0.08)
        pillarGeo.firstMaterial = PenguinFactory.mat(UIColor(white: 0.93, alpha: 1), roughness: 0.7)
        for sign in [-1.0, 1.0] {
            let p = SCNNode(geometry: pillarGeo)
            p.position = SCNVector3(Float(sign) * 4.1, 3.6, 0)
            root.addChildNode(p)
        }
        let beam = SCNBox(width: 9.6, height: 1.5, length: 1.6, chamferRadius: 0.08)
        beam.firstMaterial = PenguinFactory.mat(UIColor(white: 0.94, alpha: 1), roughness: 0.68)
        let beamNode = SCNNode(geometry: beam)
        beamNode.position.y = 7.4
        root.addChildNode(beamNode)

        let ochre = SCNBox(width: 11, height: 3.8, length: 1.8, chamferRadius: 0.05)
        ochre.firstMaterial = PenguinFactory.mat(UIColor(red: 0.90, green: 0.72, blue: 0.34, alpha: 1), roughness: 0.65)
        let facade = SCNNode(geometry: ochre)
        facade.position = SCNVector3(0, 9.8, 0)
        root.addChildNode(facade)
        return root
    }

    static func boostRamp() -> SCNNode {
        let root = SCNNode()
        let slab = SCNBox(width: 3.6, height: 0.55, length: 4.2, chamferRadius: 0.04)
        slab.firstMaterial = PenguinFactory.mat(UIColor(red: 0.98, green: 0.78, blue: 0.16, alpha: 1), roughness: 0.4)
        let slabNode = SCNNode(geometry: slab)
        slabNode.eulerAngles.x = -0.28
        slabNode.position = SCNVector3(0, 0.55, 0.4)
        root.addChildNode(slabNode)
        for i in 0..<3 {
            let stripe = SCNBox(width: 3.1, height: 0.04, length: 0.38, chamferRadius: 0)
            stripe.firstMaterial = PenguinFactory.mat(UIColor.white, roughness: 0.3)
            let sn = SCNNode(geometry: stripe)
            sn.position = SCNVector3(0, 0.72 + Float(i) * 0.08, -0.4 + Float(i) * 0.7)
            sn.eulerAngles.x = -0.28
            root.addChildNode(sn)
        }
        return root
    }

    static func turboPad() -> SCNNode {
        let disc = SCNCylinder(radius: 1.15, height: 0.06)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        mat.emission.contents = UIColor(red: 1, green: 0.75, blue: 0.1, alpha: 0.55)
        disc.firstMaterial = mat
        let node = SCNNode(geometry: disc)
        node.position.y = 0.05
        let chev = SCNCone(topRadius: 0.02, bottomRadius: 0.35, height: 0.7)
        chev.firstMaterial = PenguinFactory.mat(.white, roughness: 0.2)
        let c = SCNNode(geometry: chev)
        c.eulerAngles.x = Float.pi / 2
        c.position = SCNVector3(0, 0.12, 0)
        node.addChildNode(c)
        return node
    }

    static func crystal() -> SCNNode {
        let geo = SCNBox(width: 0.32, height: 0.55, length: 0.32, chamferRadius: 0.04)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.45, green: 0.9, blue: 1, alpha: 0.95)
        mat.emission.contents = UIColor(red: 0.25, green: 0.7, blue: 1, alpha: 0.7)
        mat.transparency = 0.35
        geo.firstMaterial = mat
        let node = SCNNode(geometry: geo)
        node.position.y = 0.7
        node.eulerAngles.y = 0.5
        node.addParticleSystem(EffectsFactory.sparkle())
        let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2.4, z: 0, duration: 1.6))
        let bob = SCNAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 0.16, z: 0, duration: 0.7),
            .moveBy(x: 0, y: -0.16, z: 0, duration: 0.7)
        ]))
        node.runAction(.group([spin, bob]))
        return node
    }

    static func powerOrb(color: UIColor, symbol: String) -> SCNNode {
        let sphere = SCNSphere(radius: 0.38)
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color.withAlphaComponent(0.55)
        sphere.firstMaterial = mat
        let node = SCNNode(geometry: sphere)
        node.position.y = 0.85
        node.name = "power-\(symbol)"
        node.runAction(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.45),
            .scale(to: 0.92, duration: 0.45)
        ])))
        return node
    }

    static func snowman() -> SCNNode {
        let root = SCNNode()
        let c1 = SCNSphere(radius: 0.55)
        let c2 = SCNSphere(radius: 0.40)
        let c3 = SCNSphere(radius: 0.28)
        for g in [c1, c2, c3] {
            g.firstMaterial = PenguinFactory.mat(UIColor(white: 0.96, alpha: 1), roughness: 0.85)
        }
        let n1 = SCNNode(geometry: c1); n1.position.y = 0.5
        let n2 = SCNNode(geometry: c2); n2.position.y = 1.2
        let n3 = SCNNode(geometry: c3); n3.position.y = 1.75
        let hat = SCNCylinder(radius: 0.22, height: 0.22)
        hat.firstMaterial = PenguinFactory.mat(UIColor(red: 0.15, green: 0.18, blue: 0.28, alpha: 1), roughness: 0.6)
        let hatNode = SCNNode(geometry: hat)
        hatNode.position.y = 2.05
        let nose = SCNCone(topRadius: 0.01, bottomRadius: 0.05, height: 0.18)
        nose.firstMaterial = PenguinFactory.mat(UIColor(red: 1, green: 0.5, blue: 0.1, alpha: 1), roughness: 0.4)
        let noseNode = SCNNode(geometry: nose)
        noseNode.eulerAngles.x = Float.pi / 2
        noseNode.position = SCNVector3(0, 1.72, 0.28)
        [n1, n2, n3, hatNode, noseNode].forEach { root.addChildNode($0) }
        return root
    }

    static func crate(scale: Float) -> SCNNode {
        let box = SCNBox(width: 0.95, height: 0.95, length: 0.95, chamferRadius: 0.03)
        box.firstMaterial = PenguinFactory.mat(UIColor(red: 0.62, green: 0.42, blue: 0.22, alpha: 1), roughness: 0.75)
        let node = SCNNode(geometry: box)
        node.position.y = 0.48
        node.scale = SCNVector3(scale, scale, scale)
        return node
    }

    static func cart() -> SCNNode {
        let root = SCNNode()
        let bed = SCNBox(width: 1.6, height: 0.45, length: 1.1, chamferRadius: 0.04)
        bed.firstMaterial = PenguinFactory.mat(UIColor(red: 0.55, green: 0.32, blue: 0.16, alpha: 1), roughness: 0.7)
        let bedNode = SCNNode(geometry: bed)
        bedNode.position.y = 0.55
        root.addChildNode(bedNode)
        for sign in [-1.0, 1.0] {
            let wheel = SCNCylinder(radius: 0.22, height: 0.12)
            wheel.firstMaterial = PenguinFactory.mat(UIColor.darkGray, roughness: 0.5)
            let w = SCNNode(geometry: wheel)
            w.eulerAngles.z = Float.pi / 2
            w.position = SCNVector3(Float(sign) * 0.55, 0.22, 0.4)
            root.addChildNode(w)
            let w2 = w.clone()
            w2.position.z = -0.4
            root.addChildNode(w2)
        }
        return root
    }

    static func marketNPC() -> SCNNode {
        let root = SCNNode()
        let body = SCNCapsule(capRadius: 0.22, height: 0.9)
        body.firstMaterial = PenguinFactory.mat(UIColor(red: 0.7, green: 0.25, blue: 0.22, alpha: 1), roughness: 0.6)
        let b = SCNNode(geometry: body)
        b.position.y = 0.7
        let head = SCNSphere(radius: 0.18)
        head.firstMaterial = PenguinFactory.mat(UIColor(red: 0.96, green: 0.80, blue: 0.68, alpha: 1), roughness: 0.5)
        let h = SCNNode(geometry: head)
        h.position.y = 1.28
        root.addChildNode(b)
        root.addChildNode(h)
        return root
    }

    static func stall() -> SCNNode {
        let root = SCNNode()
        let table = SCNBox(width: 2.2, height: 0.15, length: 1.1, chamferRadius: 0)
        table.firstMaterial = PenguinFactory.mat(UIColor(red: 0.55, green: 0.35, blue: 0.18, alpha: 1), roughness: 0.7)
        let t = SCNNode(geometry: table)
        t.position.y = 0.85
        let cloth = SCNBox(width: 2.25, height: 0.72, length: 0.06, chamferRadius: 0)
        cloth.firstMaterial = PenguinFactory.mat(UIColor(red: 0.82, green: 0.22, blue: 0.25, alpha: 1), roughness: 0.6)
        let c = SCNNode(geometry: cloth)
        c.position = SCNVector3(0, 0.5, 0.55)
        let canopy = SCNBox(width: 2.4, height: 0.08, length: 1.4, chamferRadius: 0)
        canopy.firstMaterial = PenguinFactory.mat(UIColor(red: 0.95, green: 0.78, blue: 0.25, alpha: 1), roughness: 0.5)
        let can = SCNNode(geometry: canopy)
        can.position.y = 1.85
        root.addChildNode(t)
        root.addChildNode(c)
        root.addChildNode(can)
        return root
    }

    static func pine(scale: Float) -> SCNNode {
        let root = SCNNode()
        let trunk = SCNCylinder(radius: 0.16, height: 1.1)
        trunk.firstMaterial = PenguinFactory.mat(UIColor(red: 0.38, green: 0.24, blue: 0.14, alpha: 1), roughness: 0.8)
        let t = SCNNode(geometry: trunk)
        t.position.y = 0.55
        root.addChildNode(t)
        var y: Float = 1.1
        for i in 0..<3 {
            let cone = SCNCone(topRadius: 0.05, bottomRadius: CGFloat(1.3 - Double(i) * 0.28), height: 1.35)
            cone.firstMaterial = PenguinFactory.mat(UIColor(red: 0.16, green: 0.38, blue: 0.26, alpha: 1), roughness: 0.75)
            let c = SCNNode(geometry: cone)
            c.position.y = y
            root.addChildNode(c)
            y += 0.7
        }
        root.scale = SCNVector3(scale, scale, scale)
        return root
    }

    static func dockPlank(width: Float) -> SCNNode {
        let board = SCNBox(width: CGFloat(width + 1.5), height: 0.18, length: 4.2, chamferRadius: 0)
        board.firstMaterial = PenguinFactory.mat(UIColor(red: 0.50, green: 0.34, blue: 0.20, alpha: 1), roughness: 0.8)
        let node = SCNNode(geometry: board)
        node.position.y = 0.04
        return node
    }

    static func boat() -> SCNNode {
        let hull = SCNCapsule(capRadius: 0.7, height: 3.4)
        hull.firstMaterial = PenguinFactory.mat(UIColor(red: 0.28, green: 0.22, blue: 0.18, alpha: 1), roughness: 0.55)
        let node = SCNNode(geometry: hull)
        node.eulerAngles.z = Float.pi / 2
        node.position.y = 0.4
        return node
    }

    static func icicle(scale: Float) -> SCNNode {
        let cone = SCNCone(topRadius: 0.02, bottomRadius: 0.22, height: CGFloat(1.8 * scale))
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 0.7)
        mat.emission.contents = UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 0.25)
        mat.transparency = 0.35
        cone.firstMaterial = mat
        let node = SCNNode(geometry: cone)
        node.position.y = 4.2
        node.eulerAngles.x = Float.pi
        return node
    }

    static func stalactite() -> SCNNode {
        let cone = SCNCone(topRadius: 0.04, bottomRadius: 0.32, height: 2.4)
        cone.firstMaterial = PenguinFactory.mat(UIColor(red: 0.45, green: 0.72, blue: 0.88, alpha: 1), roughness: 0.35)
        let node = SCNNode(geometry: cone)
        node.position.y = 2.6
        node.eulerAngles.x = Float.pi
        return node
    }

    static func auroraRibbon() -> SCNNode {
        let plane = SCNPlane(width: 18, height: 5)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.35, green: 0.95, blue: 0.65, alpha: 0.18)
        mat.emission.contents = UIColor(red: 0.35, green: 0.9, blue: 0.7, alpha: 0.35)
        mat.transparency = 0.7
        mat.isDoubleSided = true
        plane.firstMaterial = mat
        let node = SCNNode(geometry: plane)
        node.position.y = 12
        node.eulerAngles.y = 0.4
        return node
    }

    static func lantern(night: Bool) -> SCNNode {
        let root = SCNNode()
        let pole = SCNCylinder(radius: 0.07, height: 2.6)
        pole.firstMaterial = PenguinFactory.mat(UIColor.darkGray, roughness: 0.5)
        let p = SCNNode(geometry: pole)
        p.position.y = 1.3
        let bulb = SCNSphere(radius: 0.18)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 1, green: 0.85, blue: 0.45, alpha: 1)
        mat.emission.contents = UIColor(red: 1, green: 0.8, blue: 0.4, alpha: night ? 0.9 : 0.25)
        bulb.firstMaterial = mat
        let b = SCNNode(geometry: bulb)
        b.position.y = 2.55
        if night {
            let light = SCNLight()
            light.type = .omni
            light.intensity = 180
            light.color = UIColor(red: 1, green: 0.82, blue: 0.5, alpha: 1)
            light.attenuationEndDistance = 12
            b.light = light
        }
        root.addChildNode(p)
        root.addChildNode(b)
        return root
    }

    static func chimney() -> SCNNode {
        let box = SCNBox(width: 0.7, height: 2.2, length: 0.7, chamferRadius: 0.04)
        box.firstMaterial = PenguinFactory.mat(UIColor(red: 0.55, green: 0.28, blue: 0.22, alpha: 1), roughness: 0.8)
        let node = SCNNode(geometry: box)
        node.position.y = 1.1
        return node
    }

    static func barrel() -> SCNNode {
        let c = SCNCylinder(radius: 0.32, height: 0.55)
        c.firstMaterial = PenguinFactory.mat(UIColor(red: 0.48, green: 0.30, blue: 0.16, alpha: 1), roughness: 0.7)
        let node = SCNNode(geometry: c)
        node.position.y = 0.28
        return node
    }

    static func icePatch(radius: Float) -> SCNNode {
        let disc = SCNCylinder(radius: CGFloat(radius), height: 0.04)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 0.7)
        mat.roughness.contents = 0.08
        mat.metalness.contents = 0.35
        mat.emission.contents = UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.15)
        disc.firstMaterial = mat
        let node = SCNNode(geometry: disc)
        node.position.y = 0.03
        return node
    }

    static func lowBridge(width: Float) -> SCNNode {
        let root = SCNNode()
        for sign in [-1.0, 1.0] {
            let post = SCNBox(width: 0.35, height: 1.8, length: 0.35, chamferRadius: 0)
            post.firstMaterial = PenguinFactory.mat(UIColor(red: 0.4, green: 0.26, blue: 0.14, alpha: 1), roughness: 0.7)
            let p = SCNNode(geometry: post)
            p.position = SCNVector3(Float(sign) * (width * 0.28), 0.9, 0)
            root.addChildNode(p)
        }
        let beam = SCNBox(width: CGFloat(width * 0.7), height: 0.22, length: 0.4, chamferRadius: 0)
        beam.firstMaterial = PenguinFactory.mat(UIColor(red: 0.42, green: 0.28, blue: 0.16, alpha: 1), roughness: 0.7)
        let b = SCNNode(geometry: beam)
        b.position.y = 1.7
        root.addChildNode(b)
        return root
    }

    static func windWhisp() -> SCNNode {
        let plane = SCNPlane(width: 6, height: 1.2)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(white: 1, alpha: 0.12)
        mat.emission.contents = UIColor(white: 1, alpha: 0.08)
        mat.isDoubleSided = true
        plane.firstMaterial = mat
        let node = SCNNode(geometry: plane)
        node.position.y = 1.4
        node.runAction(.repeatForever(.sequence([
            .fadeOpacity(to: 0.15, duration: 0.6),
            .fadeOpacity(to: 0.55, duration: 0.6)
        ])))
        return node
    }

    static func checkpointGate(width: Float) -> SCNNode {
        let root = SCNNode()
        for sign in [-1.0, 1.0] {
            let pole = SCNCylinder(radius: 0.09, height: 2.4)
            pole.firstMaterial = PenguinFactory.mat(UIColor(red: 0.2, green: 0.7, blue: 1, alpha: 1), roughness: 0.3)
            let p = SCNNode(geometry: pole)
            p.position = SCNVector3(Float(sign) * (width * 0.42), 1.2, 0)
            root.addChildNode(p)
        }
        return root
    }

    static func finishGate(width: Float) -> SCNNode {
        let root = checkpointGate(width: width)
        let banner = SCNBox(width: CGFloat(width * 0.9), height: 0.55, length: 0.12, chamferRadius: 0)
        banner.firstMaterial = PenguinFactory.mat(UIColor(red: 1, green: 0.32, blue: 0.42, alpha: 1), roughness: 0.4)
        let b = SCNNode(geometry: banner)
        b.position.y = 2.6
        root.addChildNode(b)
        return root
    }

    static func startBanner(width: Float) -> SCNNode {
        finishGate(width: width)
    }

    static func skyGradient(top: SIMD3<Float>, bottom: SIMD3<Float>) -> UIImage {
        let size = CGSize(width: 8, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            for y in 0..<Int(size.height) {
                let t = CGFloat(y) / size.height
                let c = top + (bottom - top) * Float(t)
                UIColor(simd: c).setFill()
                ctx.fill(CGRect(x: 0, y: y, width: Int(size.width), height: 1))
            }
        }
    }
}

extension SCNVector3 {
    init(_ v: SIMD3<Float>) {
        self.init(v.x, v.y, v.z)
    }
}
