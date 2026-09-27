import SceneKit
import UIKit

enum EffectsFactory {
    static func snowfall(night: Bool) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = night ? 40 : 70
        p.particleLifeSpan = 4.5
        p.particleLifeSpanVariation = 1.2
        p.emitterShape = SCNBox(width: 40, height: 1, length: 50, chamferRadius: 0)
        p.particleSize = 0.07
        p.particleSizeVariation = 0.04
        p.particleColor = UIColor.white.withAlphaComponent(night ? 0.55 : 0.8)
        p.particleVelocity = SCNVector3(0, -2.8, 0)
        p.particleVelocityVariation = SCNVector3(0.6, 0.5, 0.6)
        p.spreadingAngle = 8
        p.blendMode = .alpha
        p.isAffectedByGravity = false
        p.orientationMode = .billboard
        p.loops = true
        return p
    }

    static func spray() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 0
        p.particleLifeSpan = 0.35
        p.particleSize = 0.05
        p.particleSizeVariation = 0.03
        p.particleColor = UIColor(red: 0.75, green: 0.9, blue: 1, alpha: 0.8)
        p.particleVelocity = SCNVector3(0, 1.4, -3)
        p.particleVelocityVariation = SCNVector3(1.4, 0.6, 1.2)
        p.spreadingAngle = 30
        p.blendMode = .additive
        p.loops = true
        return p
    }

    static func boostStreaks() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 0
        p.particleLifeSpan = 0.28
        p.particleSize = 0.04
        p.particleColor = UIColor(red: 0.35, green: 0.8, blue: 1, alpha: 0.9)
        p.particleVelocity = SCNVector3(0, 0.2, -8)
        p.particleVelocityVariation = SCNVector3(0.4, 0.3, 1)
        p.blendMode = .additive
        p.loops = true
        return p
    }

    static func sparkle() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 8
        p.particleLifeSpan = 0.7
        p.particleSize = 0.06
        p.particleColor = UIColor(red: 0.55, green: 0.9, blue: 1, alpha: 1)
        p.particleVelocity = SCNVector3(0, 0.6, 0)
        p.spreadingAngle = 180
        p.blendMode = .additive
        p.loops = true
        return p
    }

    static func landingPuff() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 0
        p.emissionDuration = 0.12
        p.particleLifeSpan = 0.45
        p.particleSize = 0.12
        p.particleColor = UIColor.white
        p.particleVelocity = SCNVector3(0, 1.2, 0)
        p.particleVelocityVariation = SCNVector3(1.8, 0.4, 1.8)
        p.spreadingAngle = 160
        p.blendMode = .alpha
        p.loops = false
        return p
    }
}

final class IceTrail {
    private let node = SCNNode()
    private var stamps: [SCNNode] = []
    private let maxStamps = 48

    init(parent: SCNNode) {
        node.name = "iceTrail"
        parent.addChildNode(node)
    }

    func push(position: SCNVector3, tangent: SIMD3<Float>, intense: Bool) {
        let disc = SCNCylinder(radius: intense ? 0.34 : 0.26, height: 0.02)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.35, green: 0.55, blue: 0.75, alpha: intense ? 0.38 : 0.22)
        mat.emission.contents = UIColor(red: 0.2, green: 0.45, blue: 0.7, alpha: 0.12)
        mat.transparency = intense ? 0.55 : 0.35
        disc.firstMaterial = mat
        let stamp = SCNNode(geometry: disc)
        stamp.position = SCNVector3(position.x, position.y + 0.02, position.z)
        stamp.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(SIMD3(0, 1, 0)))
        node.addChildNode(stamp)
        stamps.append(stamp)
        if stamps.count > maxStamps {
            stamps.removeFirst().removeFromParentNode()
        }
        for (idx, s) in stamps.enumerated() {
            let fade = CGFloat(idx + 1) / CGFloat(stamps.count)
            s.opacity = fade * 0.7
        }
        _ = tangent
    }

    func clear() {
        stamps.forEach { $0.removeFromParentNode() }
        stamps.removeAll()
    }
}
