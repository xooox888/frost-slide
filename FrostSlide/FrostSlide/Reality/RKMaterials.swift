import RealityKit
import UIKit

enum RKMat {
    static func pbr(
        _ color: SIMD3<Float>,
        roughness: Float = 0.62,
        metallic: Float = 0.04,
        emissive: SIMD3<Float>? = nil,
        alpha: Float = 1,
        doubleSided: Bool = false
    ) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        let ui = UIColor(
            red: CGFloat(color.x),
            green: CGFloat(color.y),
            blue: CGFloat(color.z),
            alpha: CGFloat(alpha)
        )
        m.baseColor = .init(tint: ui)
        m.roughness = .init(floatLiteral: roughness)
        m.metallic = .init(floatLiteral: metallic)
        if let emissive {
            m.emissiveColor = .init(color: UIColor(
                red: CGFloat(emissive.x),
                green: CGFloat(emissive.y),
                blue: CGFloat(emissive.z),
                alpha: 1
            ))
        }
        if alpha < 0.999 {
            m.blending = .transparent(opacity: .init(floatLiteral: alpha))
        }
        if doubleSided {
            m.faceCulling = .none
        }
        return m
    }

    static func unlit(_ color: SIMD3<Float>) -> UnlitMaterial {
        UnlitMaterial(color: UIColor(
            red: CGFloat(color.x),
            green: CGFloat(color.y),
            blue: CGFloat(color.z),
            alpha: 1
        ))
    }

    static func ui(_ color: SIMD3<Float>, alpha: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: alpha)
    }
}

enum RKEntity {
    static func model(_ mesh: MeshResource, _ material: PhysicallyBasedMaterial) -> ModelEntity {
        ModelEntity(mesh: mesh, materials: [material])
    }

    static func box(_ size: SIMD3<Float>, _ color: SIMD3<Float>, roughness: Float = 0.65) -> ModelEntity {
        model(.generateBox(size: size, cornerRadius: 0.02), RKMat.pbr(color, roughness: roughness))
    }

    static func sphere(_ radius: Float, _ color: SIMD3<Float>, roughness: Float = 0.5) -> ModelEntity {
        model(.generateSphere(radius: radius), RKMat.pbr(color, roughness: roughness))
    }
}
