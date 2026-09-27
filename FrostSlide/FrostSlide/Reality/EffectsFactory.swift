import RealityKit
import simd

final class IceTrail {
    private let root = Entity()
    private var stamps: [ModelEntity] = []
    private let maxStamps = 64
    private let disc = RKMesh.cylinder(radius: 0.32, height: 0.02)

    init(parent: Entity) {
        root.name = "iceTrail"
        parent.addChild(root)
    }

    func push(position: SIMD3<Float>, intense: Bool) {
        let color = intense ? SIMD3<Float>(0.25, 0.55, 0.85) : SIMD3<Float>(0.40, 0.58, 0.75)
        let stamp = RKEntity.model(disc, RKMat.pbr(color, roughness: 0.12, metallic: 0.2, emissive: color * 0.2, alpha: intense ? 0.5 : 0.28))
        stamp.position = position + SIMD3(0, 0.03, 0)
        stamp.scale = intense ? [1.25, 1, 1.25] : [1, 1, 1]
        root.addChild(stamp)
        stamps.append(stamp)
        if stamps.count > maxStamps {
            let old = stamps.removeFirst()
            old.removeFromParent()
        }
        for (idx, s) in stamps.enumerated() {
            let fade = Float(idx + 1) / Float(stamps.count)
            s.scale = [fade * (intense ? 1.2 : 1), 1, fade]
        }
    }

    func clear() {
        stamps.forEach { $0.removeFromParent() }
        stamps.removeAll()
    }
}

final class SnowField {
    private let root = Entity()
    private var flakes: [Entity] = []
    private var velocities: [Float] = []

    func attach(to parent: Entity, night: Bool) {
        root.name = "snow"
        parent.addChild(root)
        let count = night ? 36 : 52
        let mesh = MeshResource.generateBox(size: [0.07, 0.07, 0.07])
        let mat = RKMat.pbr(SIMD3(1, 1, 1), roughness: 0.9, alpha: night ? 0.55 : 0.8)
        for _ in 0..<count {
            let flake = ModelEntity(mesh: mesh, materials: [mat])
            flake.position = SIMD3(
                Float.random(in: -18...18),
                Float.random(in: 2...16),
                Float.random(in: -10...24)
            )
            root.addChild(flake)
            flakes.append(flake)
            velocities.append(Float.random(in: 2.2...5.5))
        }
    }

    func burst(at position: SIMD3<Float>) {
        let mesh = MeshResource.generateSphere(radius: 0.09)
        let mat = RKMat.pbr(SIMD3(0.92, 0.96, 1.0), roughness: 0.7, alpha: 0.7)
        for i in 0..<10 {
            let puff = ModelEntity(mesh: mesh, materials: [mat])
            let a = Float(i) / 10 * 2 * Float.pi
            puff.position = position + SIMD3(cos(a) * 0.55, 0.12, sin(a) * 0.55)
            root.addChild(puff)
            flakes.append(puff)
            velocities.append(3.2)
        }
    }

    func tick(dt: Float, around camera: SIMD3<Float>) {
        root.position = camera
        for i in flakes.indices {
            flakes[i].position.y -= velocities[i] * dt
            if flakes[i].position.y < -4 {
                flakes[i].position = SIMD3(
                    Float.random(in: -18...18),
                    Float.random(in: 8...16),
                    Float.random(in: -8...22)
                )
            }
        }
    }
}
