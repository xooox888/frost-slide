import SceneKit
import UIKit

enum PenguinFactory {
    static func make(sledColor: UIColor, ghostly: Bool = false) -> SCNNode {
        let root = SCNNode()
        root.name = "penguin"

        let sled = SCNCylinder(radius: 0.62, height: 0.11)
        sled.radialSegmentCount = 28
        let sledMat = SCNMaterial()
        sledMat.diffuse.contents = sledColor
        sledMat.emission.contents = sledColor.withAlphaComponent(0.35)
        sledMat.specular.contents = UIColor.white
        sledMat.shininess = 0.9
        sled.firstMaterial = sledMat
        let sledNode = SCNNode(geometry: sled)
        sledNode.position = SCNVector3(0, 0.06, 0)
        root.addChildNode(sledNode)

        let rim = SCNTorus(ringRadius: 0.62, pipeRadius: 0.045)
        let rimMat = SCNMaterial()
        rimMat.diffuse.contents = sledColor.lighter(0.18)
        rimMat.emission.contents = sledColor.withAlphaComponent(0.25)
        rim.firstMaterial = rimMat
        let rimNode = SCNNode(geometry: rim)
        rimNode.position = SCNVector3(0, 0.08, 0)
        root.addChildNode(rimNode)

        let glow = SCNLight()
        glow.type = .omni
        glow.intensity = 80
        glow.color = sledColor
        glow.attenuationEndDistance = 4
        let glowNode = SCNNode()
        glowNode.light = glow
        glowNode.position = SCNVector3(0, 0.2, 0)
        glowNode.name = "sledGlow"
        root.addChildNode(glowNode)

        let body = SCNSphere(radius: 0.38)
        body.segmentCount = 24
        body.firstMaterial = mat(UIColor(white: 0.07, alpha: 1), roughness: 0.55)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.42, 0.02)
        bodyNode.scale = SCNVector3(0.92, 1.05, 0.88)
        root.addChildNode(bodyNode)

        let belly = SCNSphere(radius: 0.28)
        belly.firstMaterial = mat(UIColor(white: 0.96, alpha: 1), roughness: 0.4)
        let bellyNode = SCNNode(geometry: belly)
        bellyNode.position = SCNVector3(0, 0.38, 0.18)
        bellyNode.scale = SCNVector3(0.78, 0.85, 0.42)
        root.addChildNode(bellyNode)

        let head = SCNSphere(radius: 0.24)
        head.firstMaterial = mat(UIColor(white: 0.07, alpha: 1), roughness: 0.5)
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, 0.78, 0.08)
        root.addChildNode(headNode)

        for sign in [-1.0, 1.0] {
            let eyeWhite = SCNSphere(radius: 0.055)
            eyeWhite.firstMaterial = mat(.white, roughness: 0.2)
            let eyeNode = SCNNode(geometry: eyeWhite)
            eyeNode.position = SCNVector3(Float(sign) * 0.085, 0.82, 0.26)
            root.addChildNode(eyeNode)

            let pupil = SCNSphere(radius: 0.028)
            pupil.firstMaterial = mat(UIColor(white: 0.05, alpha: 1), roughness: 0.1)
            let pupilNode = SCNNode(geometry: pupil)
            pupilNode.position = SCNVector3(Float(sign) * 0.09, 0.82, 0.30)
            root.addChildNode(pupilNode)
        }

        let beak = SCNCone(topRadius: 0.01, bottomRadius: 0.055, height: 0.12)
        beak.firstMaterial = mat(UIColor(red: 1, green: 0.55, blue: 0.15, alpha: 1), roughness: 0.3)
        let beakNode = SCNNode(geometry: beak)
        beakNode.eulerAngles.x = Float.pi / 2
        beakNode.position = SCNVector3(0, 0.74, 0.30)
        root.addChildNode(beakNode)

        for sign in [-1.0, 1.0] {
            let flipper = SCNCapsule(capRadius: 0.055, height: 0.32)
            flipper.firstMaterial = mat(UIColor(white: 0.07, alpha: 1), roughness: 0.55)
            let flipNode = SCNNode(geometry: flipper)
            flipNode.position = SCNVector3(Float(sign) * 0.36, 0.40, 0.02)
            flipNode.eulerAngles.z = Float(sign) * 0.85
            flipNode.eulerAngles.x = 0.25
            root.addChildNode(flipNode)
        }

        if ghostly {
            root.opacity = 0.45
        }
        return root
    }

    static func mat(_ color: UIColor, roughness: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = 0.05
        m.lightingModel = .physicallyBased
        return m
    }
}

extension UIColor {
    func lighter(_ amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(hue: h, saturation: s, brightness: min(1, b + amount), alpha: a)
        }
        return self
    }

    convenience init(simd: SIMD3<Float>) {
        self.init(red: CGFloat(simd.x), green: CGFloat(simd.y), blue: CGFloat(simd.z), alpha: 1)
    }
}
