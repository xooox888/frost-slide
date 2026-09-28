import Metal
import RealityKit
import UIKit
import simd

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

    static func unlit(texture: TextureResource) -> UnlitMaterial {
        var m = UnlitMaterial()
        m.color = .init(tint: .white, texture: .init(texture, sampler: RKTexture.repeating))
        return m
    }

    /// Emissive-only glow material for crystals, rails and lit windows.
    static func glow(_ color: SIMD3<Float>, intensity: Float = 1.6, alpha: Float = 1) -> PhysicallyBasedMaterial {
        var m = pbr(color, roughness: 0.18, emissive: color, alpha: alpha)
        m.emissiveIntensity = intensity
        return m
    }
}

/// Procedural textures drawn with Core Graphics, so the game ships no image assets for 3D.
enum RKTexture {
    static let repeating: MaterialParameters.Texture.Sampler = {
        let d = MTLSamplerDescriptor()
        d.sAddressMode = .repeat
        d.tAddressMode = .repeat
        d.minFilter = .linear
        d.magFilter = .linear
        d.mipFilter = .linear
        d.maxAnisotropy = 8
        return MaterialParameters.Texture.Sampler(d)
    }()

    /// Draws into a context whose origin is the top-left of the image (v = 0 at the top).
    static func make(width: Int, height: Int, draw: (CGContext) -> Void) -> TextureResource? {
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        draw(ctx)
        guard let image = ctx.makeImage() else { return nil }
        return try? TextureResource.generate(
            from: image,
            options: .init(semantic: .color, mipmapsMode: .allocateAndGenerateAll)
        )
    }

    static func cg(_ c: SIMD3<Float>, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(red: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: alpha)
    }

    /// Equirect-style sky: zenith to horizon gradient, periodic mountain silhouettes, stars at night.
    static func sky(_ pal: LevelPalette) -> TextureResource? {
        let w = 1024, h = 512
        return make(width: w, height: h) { ctx in
            let horizon = CGFloat(h) * 0.5
            let space = CGColorSpaceCreateDeviceRGB()
            let top = pal.skyTop
            let glowBand = simd_mix(pal.skyBottom, SIMD3(repeating: 1), SIMD3(repeating: pal.night ? 0.05 : 0.35))
            if let grad = CGGradient(
                colorsSpace: space,
                colors: [cg(top * (pal.night ? 0.75 : 0.92)), cg(top), cg(pal.skyBottom), cg(glowBand)] as CFArray,
                locations: [0, 0.35, 0.85, 1]
            ) {
                ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: horizon), options: [])
            }
            if let below = CGGradient(
                colorsSpace: space,
                colors: [cg(glowBand), cg(pal.fog)] as CFArray,
                locations: [0, 1]
            ) {
                ctx.drawLinearGradient(below, start: CGPoint(x: 0, y: horizon), end: CGPoint(x: 0, y: CGFloat(h)), options: [])
            }
            if pal.night {
                var rng = SystemRandomNumberGenerator()
                for _ in 0..<420 {
                    let x = CGFloat.random(in: 0..<CGFloat(w), using: &rng)
                    let y = CGFloat.random(in: 0..<(horizon * 0.8), using: &rng)
                    let r = CGFloat.random(in: 0.6...1.8, using: &rng)
                    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: CGFloat.random(in: 0.35...0.95, using: &rng)))
                    ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
                }
            }
            // Two mountain ranges; sin terms are periodic in u so the seam wraps cleanly.
            let far = simd_mix(pal.skyBottom, pal.ice * 0.8, SIMD3(repeating: pal.night ? 0.55 : 0.45)) * (pal.night ? 0.55 : 1)
            let near = simd_mix(far, pal.ice * 0.55, SIMD3(repeating: 0.4)) * (pal.night ? 0.8 : 0.92)
            for (layer, color) in [(0, far), (1, near)] {
                let amp: CGFloat = layer == 0 ? 70 : 44
                let lift: CGFloat = layer == 0 ? 18 : 4
                ctx.setFillColor(cg(color))
                ctx.move(to: CGPoint(x: 0, y: horizon + 2))
                for i in 0...w {
                    let u = Double(i) / Double(w) * 2 * .pi
                    let k = Double(layer) * 1.7
                    let n = sin(u * 3 + k) * 0.5 + sin(u * 7 + 1.3 + k) * 0.3 + abs(sin(u * 13 + k)) * 0.35
                    let y = horizon - lift - CGFloat(max(0, n + 0.25)) * amp
                    ctx.addLine(to: CGPoint(x: CGFloat(i), y: y))
                }
                ctx.addLine(to: CGPoint(x: CGFloat(w), y: horizon + 2))
                ctx.closePath()
                ctx.fillPath()
            }
            // Foothills just below eye level, where the camera looks past the track's end,
            // with a pine tree line so the haze reads as distant terrain.
            let hills = simd_mix(pal.fog, pal.snow, SIMD3(repeating: 0.5)) * (pal.night ? 0.45 : 0.93)
            let pines = simd_mix(SIMD3<Float>(0.10, 0.30, 0.26), pal.fog, SIMD3(repeating: pal.night ? 0.6 : 0.35))
            ctx.setFillColor(cg(hills))
            ctx.move(to: CGPoint(x: 0, y: CGFloat(h)))
            for i in 0...w {
                let u = Double(i) / Double(w) * 2 * .pi
                let y = horizon + 10 - CGFloat(sin(u * 5 + 0.7) * 0.5 + sin(u * 11) * 0.25 + 0.75) * 16
                ctx.addLine(to: CGPoint(x: CGFloat(i), y: y))
            }
            ctx.addLine(to: CGPoint(x: CGFloat(w), y: CGFloat(h)))
            ctx.closePath()
            ctx.fillPath()
            ctx.setFillColor(cg(pines))
            for i in stride(from: 0, to: w, by: 5) {
                let u = Double(i) / Double(w) * 2 * .pi
                guard sin(u * 9 + 2) > -0.2 else { continue }
                let base = horizon + 10 - CGFloat(sin(u * 5 + 0.7) * 0.5 + sin(u * 11) * 0.25 + 0.75) * 16 + 3
                let tall = CGFloat(6 + (i * 37 % 7))
                ctx.move(to: CGPoint(x: CGFloat(i) - 2.5, y: base))
                ctx.addLine(to: CGPoint(x: CGFloat(i), y: base - tall))
                ctx.addLine(to: CGPoint(x: CGFloat(i) + 2.5, y: base))
                ctx.closePath()
            }
            ctx.fillPath()
            // Snow caps on the far range.
            ctx.setFillColor(cg(simd_mix(far, SIMD3(repeating: 1), SIMD3(repeating: pal.night ? 0.25 : 0.7)), 0.9))
            for i in stride(from: 0, to: w, by: 2) {
                let u = Double(i) / Double(w) * 2 * .pi
                let n = sin(u * 3) * 0.5 + sin(u * 7 + 1.3) * 0.3 + abs(sin(u * 13)) * 0.35
                guard n > 0.55 else { continue }
                let y = horizon - 18 - CGFloat(n + 0.25) * 70
                ctx.fill(CGRect(x: CGFloat(i), y: y, width: 2, height: CGFloat(n - 0.5) * 30))
            }
        }
    }

    /// Track surface tile (u across the track, v down it): snow with ice-tinted edges,
    /// carve grooves, cyan edge rails and sparkles.
    static func track(_ pal: LevelPalette) -> TextureResource? {
        let w = 256, h = 512
        return make(width: w, height: h) { ctx in
            let W = CGFloat(w), H = CGFloat(h)
            do {
                let space = CGColorSpaceCreateDeviceRGB()
                // Albedo below 1 so the sun doesn't clip the snow to flat white.
                let edge = simd_mix(pal.snow, pal.ice, SIMD3(repeating: 0.55)) * 0.84
                let mid = pal.snow * 0.86
                if let grad = CGGradient(
                    colorsSpace: space,
                    colors: [cg(edge), cg(mid), cg(mid), cg(edge)] as CFArray,
                    locations: [0, 0.22, 0.78, 1]
                ) {
                    ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: W, y: 0), options: [])
                }
                ctx.setStrokeColor(cg(pal.ice * 0.6, 0.3))
                ctx.setLineWidth(3)
                for u: CGFloat in [0.31, 0.43, 0.57, 0.69] {
                    ctx.move(to: CGPoint(x: u * W, y: 0))
                    ctx.addLine(to: CGPoint(x: u * W, y: H))
                }
                ctx.strokePath()
            }
            let rail = pal.night ? pal.accent : SIMD3<Float>(0.25, 0.85, 1.0)
            ctx.setFillColor(cg(rail, 0.9))
            ctx.fill(CGRect(x: W * 0.03, y: 0, width: W * 0.045, height: H))
            ctx.fill(CGRect(x: W * 0.925, y: 0, width: W * 0.045, height: H))
            var rng = SystemRandomNumberGenerator()
            for _ in 0..<160 {
                let x = CGFloat.random(in: 0.08...0.92, using: &rng) * W
                let y = CGFloat.random(in: 0..<H, using: &rng)
                let r = CGFloat.random(in: 1...2.6, using: &rng)
                ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
        }
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
