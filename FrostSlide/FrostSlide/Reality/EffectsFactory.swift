import RealityKit
import simd

/// Glowing cyan streak the player's sled carves into the snow.
final class IceTrail {
    private let root = Entity()
    private var stamps: [ModelEntity] = []
    private let maxStamps = 70
    private let streak = MeshResource.generateBox(size: [0.5, 0.012, 1], cornerRadius: 0.006)
    private let soft = RKMat.pbr(SIMD3(0.35, 0.75, 1.0), roughness: 0.1, emissive: SIMD3(0.05, 0.30, 0.60), alpha: 0.35)
    private let hot = RKMat.pbr(SIMD3(0.30, 0.85, 1.0), roughness: 0.1, emissive: SIMD3(0.10, 0.50, 0.90), alpha: 0.5)

    init(parent: Entity) {
        root.name = "iceTrail"
        parent.addChild(root)
    }

    /// `length` should cover the distance travelled since the last stamp so the streak stays continuous.
    func push(position: SIMD3<Float>, yaw: Float, length: Float, intense: Bool) {
        let stamp = ModelEntity(mesh: streak, materials: [intense ? hot : soft])
        stamp.position = position + SIMD3(0, 0.03, 0)
        stamp.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        stamp.scale = [1, 1, length]
        root.addChild(stamp)
        stamps.append(stamp)
        if stamps.count > maxStamps {
            let old = stamps.removeFirst()
            old.removeFromParent()
        }
        for (idx, s) in stamps.enumerated() {
            let fade = Float(idx + 1) / Float(stamps.count)
            s.scale = [fade * (intense ? 1.25 : 1), 1, s.scale.z]
        }
    }

    func clear() {
        stamps.forEach { $0.removeFromParent() }
        stamps.removeAll()
    }
}

/// Pooled snow puffs kicked up behind the player's sled while carving or boosting.
/// (RealityKit particle emitters need iOS 18; the game targets 17.)
final class SnowSpray {
    private let root = Entity()
    private var puffs: [ModelEntity] = []
    private var velocity: [SIMD3<Float>] = []
    private var life: [Float] = []
    private var next = 0
    private var budget: Float = 0
    private let lifetime: Float = 0.5

    init(parent: Entity) {
        root.name = "spray"
        parent.addChild(root)
        let mesh = MeshResource.generateSphere(radius: 0.09)
        let mat = RKMat.pbr(SIMD3(0.95, 0.97, 1.0), roughness: 0.9, alpha: 0.6)
        for _ in 0..<44 {
            let puff = ModelEntity(mesh: mesh, materials: [mat])
            puff.isEnabled = false
            root.addChild(puff)
            puffs.append(puff)
            velocity.append(.zero)
            life.append(0)
        }
    }

    /// `rate` is puffs per second; 0 lets the live puffs finish without spawning more.
    func tick(dt: Float, at position: SIMD3<Float>, forward: SIMD3<Float>, side: SIMD3<Float>, rate: Float) {
        budget += rate * dt
        while budget >= 1 {
            budget -= 1
            let i = next
            next = (next + 1) % puffs.count
            let s: Float = Bool.random() ? 1 : -1
            puffs[i].position = position + side * s * 0.5 - forward * 0.4 + SIMD3(0, 0.12, 0)
            velocity[i] = -forward * Float.random(in: 2...4)
                + side * s * Float.random(in: 1...2.6)
                + SIMD3(0, Float.random(in: 1.4...3.0), 0)
            life[i] = lifetime
            puffs[i].isEnabled = true
        }
        for i in puffs.indices where life[i] > 0 {
            life[i] -= dt
            velocity[i].y -= 9 * dt
            puffs[i].position += velocity[i] * dt
            let k = max(0, life[i] / lifetime)
            puffs[i].scale = SIMD3(repeating: (0.5 + (1 - k) * 1.3) * k)
            if life[i] <= 0 { puffs[i].isEnabled = false }
        }
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
