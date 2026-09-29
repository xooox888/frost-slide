import Foundation
import simd

struct TrackSample {
    var progress: Float
    var position: SIMD3<Float>
    var tangent: SIMD3<Float>
    var normal: SIMD3<Float>
    var binormal: SIMD3<Float>
    var width: Float
    var heading: Float
    var slope: Float
    /// Roll of the surface about the tangent, radians. Negative leans the surface toward
    /// the player's left (the inside of a left turn); `normal`/`binormal` already include it.
    var bank: Float = 0
    /// Signed turn rate in radians per metre, eased in and out. Positive turns left.
    var curvature: Float = 0
}

struct TrackPath {
    let samples: [TrackSample]
    let length: Float
    let checkpoints: [Float]

    func sample(at progress: Float) -> TrackSample {
        guard samples.count > 1 else { return samples[0] }
        let t = GameMath.saturate(progress)
        let scaled = t * Float(samples.count - 1)
        let i0 = min(Int(scaled), samples.count - 2)
        let frac = scaled - Float(i0)
        let a = samples[i0]
        let b = samples[i0 + 1]
        return TrackSample(
            progress: GameMath.lerp(a.progress, b.progress, frac),
            position: GameMath.lerp(a.position, b.position, frac),
            tangent: simd_normalize(GameMath.lerp(a.tangent, b.tangent, frac)),
            normal: simd_normalize(GameMath.lerp(a.normal, b.normal, frac)),
            binormal: simd_normalize(GameMath.lerp(a.binormal, b.binormal, frac)),
            width: GameMath.lerp(a.width, b.width, frac),
            heading: a.heading + GameMath.wrapAngle(b.heading - a.heading) * frac,
            slope: GameMath.lerp(a.slope, b.slope, frac),
            bank: GameMath.lerp(a.bank, b.bank, frac),
            curvature: GameMath.lerp(a.curvature, b.curvature, frac)
        )
    }

    func worldPosition(progress: Float, lateral: Float, height: Float) -> SIMD3<Float> {
        let s = sample(at: progress)
        return s.position + s.binormal * lateral + s.normal * (height + 0.12)
    }

    func width(at progress: Float) -> Float {
        sample(at: progress).width
    }

    /// Signed turn rate (rad/m) at a progress value; positive turns left.
    func curvature(at progress: Float) -> Float {
        sample(at: progress).curvature
    }

    static func build(from level: LevelDefinition, sampleCount: Int = 380) -> TrackPath {
        let count = sampleCount
        let step = level.length / Float(count - 1)

        // Pass 1: yaw change per sample from the authored curves.
        var yawDeltas = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let t = Float(i) / Float(count - 1)
            var delta: Float = 0
            for curve in level.curves {
                if t >= curve.start && t <= curve.end {
                    let span = max(0.001, curve.end - curve.start)
                    delta += curve.yawRadians / span / Float(count - 1)
                }
            }
            yawDeltas[i] = delta
        }

        // Pass 2: ease the turn rate in and out for banking and the sideways pull. The raw
        // rate jumps at every curve boundary, which used to snap the cross-section by 15-30
        // degrees in a single sample. Running the filter both ways cancels its lag.
        var forward = yawDeltas
        var backward = yawDeltas
        let smoothing: Float = 0.1
        for i in 1..<count {
            forward[i] = forward[i - 1] + (yawDeltas[i] - forward[i - 1]) * smoothing
        }
        for i in stride(from: count - 2, through: 0, by: -1) {
            backward[i] = backward[i + 1] + (yawDeltas[i] - backward[i + 1]) * smoothing
        }

        var samples: [TrackSample] = []
        samples.reserveCapacity(count)
        var position = SIMD3<Float>(0, level.startHeight, 0)
        var yaw: Float = 0

        for i in 0..<count {
            let t = Float(i) / Float(count - 1)
            yaw += yawDeltas[i]

            var extraY: Float = 0
            for bump in level.elevations {
                let d = abs(t - bump.at)
                if d < bump.span {
                    extraY += bump.height * GameMath.smoothstep(bump.span, 0, d)
                }
            }

            var width = level.baseWidth
            for key in level.widths {
                let d = abs(t - key.at)
                if d < key.span {
                    let w = GameMath.smoothstep(key.span, 0, d)
                    width = GameMath.lerp(width, key.width, w)
                }
            }

            let tangent = simd_normalize(SIMD3<Float>(sin(yaw), -level.slope, cos(yaw)))
            let worldUp = SIMD3<Float>(0, 1, 0)
            var binormal = simd_cross(tangent, worldUp)
            if simd_length(binormal) < 0.001 {
                binormal = SIMD3<Float>(1, 0, 0)
            } else {
                binormal = simd_normalize(binormal)
            }
            let normal = simd_normalize(simd_cross(binormal, tangent))
            // Lean the surface toward the inside of the turn (binormal points to the player's
            // right, so a left turn, positive curvature, needs a negative bank).
            let curvature = (forward[i] + backward[i]) * 0.5 / step
            let bank = GameMath.clamp(-curvature * 14, -0.24, 0.24)
            let bankedNormal = simd_normalize(normal * cos(bank) + binormal * sin(bank))
            let bankedBinormal = simd_normalize(simd_cross(tangent, bankedNormal))

            samples.append(
                TrackSample(
                    progress: t,
                    position: position + SIMD3<Float>(0, extraY, 0),
                    tangent: tangent,
                    normal: bankedNormal,
                    binormal: bankedBinormal,
                    width: width,
                    heading: yaw,
                    slope: level.slope,
                    bank: bank,
                    curvature: curvature
                )
            )

            position += tangent * step
        }

        return TrackPath(samples: samples, length: level.length, checkpoints: level.checkpoints)
    }
}
