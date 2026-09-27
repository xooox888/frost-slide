import RealityKit
import simd
import UIKit

enum PenguinFactory {
    static func make(sledColor: SIMD3<Float>) -> Entity {
        let root = Entity()
        root.name = "penguin"

        let sled = RKEntity.model(
            RKMesh.cylinder(radius: 0.62, height: 0.11),
            RKMat.pbr(sledColor, roughness: 0.22, metallic: 0.15, emissive: sledColor * 0.35)
        )
        sled.position = [0, 0.06, 0]
        root.addChild(sled)

        let rim = RKEntity.model(
            RKMesh.cylinder(radius: 0.66, height: 0.05),
            RKMat.pbr(simd_min(sledColor + SIMD3(0.15, 0.15, 0.15), SIMD3(repeating: 1)), roughness: 0.2, emissive: sledColor * 0.2)
        )
        rim.position = [0, 0.09, 0]
        root.addChild(rim)

        let glow = PointLight()
        glow.light.color = RKMat.ui(sledColor)
        glow.light.intensity = 350
        glow.light.attenuationRadius = 5
        glow.name = "sledGlow"
        glow.position = [0, 0.25, 0]
        root.addChild(glow)

        let black = SIMD3<Float>(0.07, 0.07, 0.08)
        let white = SIMD3<Float>(0.96, 0.96, 0.97)
        let body = RKEntity.sphere(0.38, black, roughness: 0.55)
        body.position = [0, 0.42, 0.02]
        body.scale = [0.92, 1.05, 0.88]
        root.addChild(body)

        let belly = RKEntity.sphere(0.28, white, roughness: 0.4)
        belly.position = [0, 0.38, 0.18]
        belly.scale = [0.78, 0.85, 0.42]
        root.addChild(belly)

        let head = RKEntity.sphere(0.24, black, roughness: 0.5)
        head.position = [0, 0.78, 0.08]
        root.addChild(head)

        for sign: Float in [-1, 1] {
            let eye = RKEntity.sphere(0.055, white, roughness: 0.2)
            eye.position = [sign * 0.085, 0.82, 0.26]
            root.addChild(eye)
            let pupil = RKEntity.sphere(0.028, SIMD3(0.05, 0.05, 0.05), roughness: 0.1)
            pupil.position = [sign * 0.09, 0.82, 0.30]
            root.addChild(pupil)
        }

        let beak = RKEntity.model(
            RKMesh.cone(bottomRadius: 0.055, height: 0.12),
            RKMat.pbr(SIMD3(1.0, 0.55, 0.15), roughness: 0.3)
        )
        beak.position = [0, 0.74, 0.30]
        beak.orientation = simd_quatf(angle: Float.pi / 2, axis: [1, 0, 0])
        root.addChild(beak)

        for sign: Float in [-1, 1] {
            let flip = RKEntity.model(
                RKMesh.capsule(radius: 0.055, height: 0.32),
                RKMat.pbr(black, roughness: 0.55)
            )
            flip.position = [sign * 0.36, 0.40, 0.02]
            flip.orientation = simd_quatf(angle: sign * 0.85, axis: [0, 0, 1])
            root.addChild(flip)
        }

        let shroud = RKEntity.sphere(0.85, SIMD3(0.6, 0.85, 1.0), roughness: 0.1)
        shroud.name = "ghostShroud"
        shroud.position = [0, 0.5, 0]
        shroud.isEnabled = false
        if var model = shroud.model {
            model.materials = [RKMat.pbr(SIMD3(0.55, 0.85, 1.0), roughness: 0.15, alpha: 0.28)]
            shroud.model = model
        }
        root.addChild(shroud)

        return root
    }
}
