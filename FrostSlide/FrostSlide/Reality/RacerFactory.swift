import RealityKit
import simd
import UIKit

/// Builds one racer: a red panda cub in a knitted beanie and scarf, riding a glowing disc sled.
///
/// The chase camera mostly sees the racer from behind and above, so the identity colour lives
/// on the beanie, the scarf and the sled, and the fur, ears and striped tail give the silhouette.
///
/// The node names below are the contract with `WorldController`'s animation rig: `flipL` and
/// `flipR` (arm pivots), `scarfTail`, `fluffTail`, `ghostShroud` and `sledGlow`.
enum RacerFactory {
    // Fur palette.
    private static let rust = SIMD3<Float>(0.86, 0.34, 0.10)
    private static let deepRust = SIMD3<Float>(0.58, 0.18, 0.07)
    private static let dark = SIMD3<Float>(0.17, 0.09, 0.07)
    private static let cream = SIMD3<Float>(0.97, 0.92, 0.84)
    private static let tip = SIMD3<Float>(0.30, 0.11, 0.06)
    private static let ink = SIMD3<Float>(0.05, 0.04, 0.04)

    /// An ellipsoid, so face parts can sit on the surface of the head or body they belong to.
    private struct Ellipsoid {
        var center: SIMD3<Float>
        var radii: SIMD3<Float>

        /// The point on the front of the surface above (x, y), pushed out along z by `lift`.
        func front(x: Float, y: Float, lift: Float = 0) -> SIMD3<Float> {
            let nx = (x - center.x) / radii.x
            let ny = (y - center.y) / radii.y
            let depth = max(0, 1 - nx * nx - ny * ny).squareRoot()
            return SIMD3(x, y, center.z + radii.z * depth + lift)
        }
    }

    private static let bodyShape = Ellipsoid(center: [0, 0.42, 0], radii: [0.34, 0.34, 0.33])
    private static let headShape = Ellipsoid(center: [0, 0.80, 0.07], radii: [0.29, 0.225, 0.25])

    static func make(sledColor: SIMD3<Float>) -> Entity {
        let root = Entity()
        root.name = "racer"
        addSled(to: root, color: sledColor)
        addBody(to: root)
        addHead(to: root)
        addEars(to: root)
        addBeanieAndScarf(to: root, color: sledColor)
        addArms(to: root)
        addTail(to: root)
        addShroud(to: root)
        return root
    }

    /// Every rounded part is this one mesh, scaled: a racer is about forty parts and a race
    /// builds up to seven racers, so they share it instead of generating hundreds of spheres.
    private static let unitSphere = MeshResource.generateSphere(radius: 1)

    private static func ellipsoid(_ shape: Ellipsoid, _ color: SIMD3<Float>, roughness: Float = 0.5) -> ModelEntity {
        let part = RKEntity.model(unitSphere, RKMat.pbr(color, roughness: roughness))
        part.position = shape.center
        part.scale = shape.radii
        return part
    }

    private static func blob(
        _ radii: SIMD3<Float>,
        at position: SIMD3<Float>,
        _ color: SIMD3<Float>,
        roughness: Float = 0.5
    ) -> ModelEntity {
        ellipsoid(Ellipsoid(center: position, radii: radii), color, roughness: roughness)
    }

    // MARK: - Sled

    private static func addSled(to root: Entity, color: SIMD3<Float>) {
        let sled = RKEntity.model(
            RKMesh.cylinder(radius: 0.62, height: 0.11),
            RKMat.pbr(color, roughness: 0.22, metallic: 0.15, emissive: color * 0.35)
        )
        sled.position = [0, 0.06, 0]
        root.addChild(sled)

        let rim = RKEntity.model(
            RKMesh.cylinder(radius: 0.66, height: 0.05),
            RKMat.pbr(simd_min(color + SIMD3(0.15, 0.15, 0.15), SIMD3(repeating: 1)), roughness: 0.2, emissive: color * 0.2)
        )
        rim.position = [0, 0.09, 0]
        root.addChild(rim)

        let glow = PointLight()
        glow.light.color = RKMat.ui(color)
        glow.light.intensity = 350
        glow.light.attenuationRadius = 5
        glow.name = "sledGlow"
        glow.position = [0, 0.25, 0]
        root.addChild(glow)
    }

    // MARK: - Body and head

    private static func addBody(to root: Entity) {
        root.addChild(ellipsoid(bodyShape, rust, roughness: 0.55))

        // Dark belly, like the real thing.
        let belly = bodyShape.front(x: 0, y: 0.33)
        root.addChild(blob([0.21, 0.22, 0.12], at: [0, 0.34, belly.z - 0.09], dark, roughness: 0.6))

        // Hind feet stick out in front of the sled seat.
        for sign: Float in [-1, 1] {
            root.addChild(blob([0.11, 0.055, 0.17], at: [sign * 0.16, 0.14, 0.29], dark, roughness: 0.55))
        }
    }

    private static func addHead(to root: Entity) {
        root.addChild(ellipsoid(headShape, rust, roughness: 0.55))

        // White cheek fluff and muzzle.
        for sign: Float in [-1, 1] {
            let cheek = headShape.front(x: sign * 0.17, y: 0.745, lift: -0.06)
            root.addChild(blob([0.125, 0.10, 0.09], at: cheek, cream, roughness: 0.75))

            // The dark tear line below the eye.
            let tear = headShape.front(x: sign * 0.12, y: 0.765, lift: -0.005)
            let tearLine = blob([0.011, 0.045, 0.01], at: tear, deepRust, roughness: 0.7)
            tearLine.orientation = simd_quatf(angle: sign * 0.35, axis: [0, 0, 1])
            root.addChild(tearLine)

            let eye = headShape.front(x: sign * 0.105, y: 0.82, lift: 0.005)
            root.addChild(blob([0.042, 0.048, 0.03], at: eye, ink, roughness: 0.15))
        }
        let muzzle = headShape.front(x: 0, y: 0.735, lift: -0.03)
        root.addChild(blob([0.10, 0.075, 0.085], at: muzzle, cream, roughness: 0.7))
        root.addChild(blob([0.042, 0.03, 0.03], at: [0, 0.752, muzzle.z + 0.075], ink, roughness: 0.2))
    }

    /// Round ears that poke out through the sides of the beanie.
    private static func addEars(to root: Entity) {
        for sign: Float in [-1, 1] {
            let ear = Entity()
            ear.position = [sign * 0.245, 0.985, 0.0]
            ear.orientation = simd_quatf(angle: sign * -0.4, axis: [0, 0, 1]) * simd_quatf(angle: sign * 0.35, axis: [0, 1, 0])
            let outer = blob([0.105, 0.115, 0.07], at: [0, 0, 0], dark, roughness: 0.6)
            let inner = blob([0.068, 0.078, 0.04], at: [0, 0, 0.038], cream, roughness: 0.8)
            ear.addChild(outer)
            ear.addChild(inner)
            root.addChild(ear)
        }
    }

    // MARK: - Beanie and scarf

    private static func addBeanieAndScarf(to root: Entity, color: SIMD3<Float>) {
        let wool = RKMat.pbr(color, roughness: 0.75)
        let beanie = RKEntity.model(.generateSphere(radius: 0.28), wool)
        beanie.position = [0, 0.945, 0.05]
        beanie.scale = [1.0, 0.68, 0.98]
        root.addChild(beanie)
        let band = RKEntity.model(RKMesh.cylinder(radius: 0.285, height: 0.075), RKMat.pbr(cream, roughness: 0.8))
        band.position = [0, 0.905, 0.05]
        root.addChild(band)
        let pom = RKEntity.sphere(0.08, cream, roughness: 0.9)
        pom.position = [0, 1.135, 0.045]
        root.addChild(pom)

        // A chunky knitted rope: overlapping lumps laid round the neck.
        let lumps = 10
        for i in 0..<lumps {
            let a = Float(i) / Float(lumps) * 2 * Float.pi
            let lump = RKEntity.model(unitSphere, wool)
            lump.position = [cos(a) * 0.255, 0.63, 0.03 + sin(a) * 0.235]
            lump.scale = [0.092, 0.06, 0.064]
            lump.orientation = simd_quatf(angle: -a - Float.pi / 2, axis: [0, 1, 0])
            root.addChild(lump)
        }
        let tailPivot = Entity()
        tailPivot.name = "scarfTail"
        tailPivot.position = [0.1, 0.63, -0.2]
        let tail = RKEntity.box([0.13, 0.05, 0.42], color, roughness: 0.75)
        tail.position = [0, 0, -0.2]
        tailPivot.addChild(tail)
        root.addChild(tailPivot)
    }

    // MARK: - Arms and tail

    /// Arms hang from shoulder pivots. `WorldController` swings them: out and flapping on boost.
    private static func addArms(to root: Entity) {
        for sign: Float in [-1, 1] {
            let pivot = Entity()
            pivot.name = sign < 0 ? "flipL" : "flipR"
            pivot.position = [sign * 0.3, 0.52, 0.05]
            pivot.orientation = simd_quatf(angle: sign * 0.85, axis: [0, 0, 1])
            let arm = RKEntity.model(RKMesh.cylinder(radius: 0.07, height: 0.22), RKMat.pbr(dark, roughness: 0.55))
            arm.position = [0, -0.13, 0]
            pivot.addChild(arm)
            pivot.addChild(blob([0.085, 0.085, 0.085], at: [0, -0.25, 0.01], dark, roughness: 0.5))
            root.addChild(pivot)
        }
    }

    /// The long ringed tail: a chain of fluffy segments that curls up behind the racer's right
    /// side, so the chase camera sees the rings as stripes instead of looking down its length.
    private static func addTail(to root: Entity) {
        let pivot = Entity()
        pivot.name = "fluffTail"
        pivot.position = [-0.06, 0.24, -0.22]
        let rings = [rust, deepRust, rust, deepRust, rust, deepRust, tip]
        let widths: [Float] = [0.095, 0.118, 0.13, 0.135, 0.13, 0.112, 0.08]
        for i in 0..<rings.count {
            let t = Float(i) / Float(rings.count - 1)
            let position = SIMD3<Float>(-0.04 - 0.22 * t * t, 0.02 + 0.36 * t, -0.08 - 0.2 * sin(Float.pi * t))
            let slope = SIMD3<Float>(-0.44 * t, 0.36, -0.2 * Float.pi * cos(Float.pi * t))
            // Lay each segment along the curve (its long axis is z).
            var along = simd_normalize(slope)
            if along.z < 0 { along = -along }
            let yaw = atan2(along.x, along.z)
            let pitch = -atan2(along.y, (along.x * along.x + along.z * along.z).squareRoot())
            let segment = blob([widths[i], widths[i], widths[i] * 1.35], at: position, rings[i], roughness: 0.65)
            segment.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0]) * simd_quatf(angle: pitch, axis: [1, 0, 0])
            pivot.addChild(segment)
        }
        root.addChild(pivot)
    }

    // MARK: - Power-up shroud

    private static func addShroud(to root: Entity) {
        let shroud = RKEntity.sphere(0.85, SIMD3(0.6, 0.85, 1.0), roughness: 0.1)
        shroud.name = "ghostShroud"
        shroud.position = [0, 0.5, 0]
        shroud.isEnabled = false
        if var model = shroud.model {
            model.materials = [RKMat.pbr(SIMD3(0.55, 0.85, 1.0), roughness: 0.15, alpha: 0.28)]
            shroud.model = model
        }
        root.addChild(shroud)
    }
}
