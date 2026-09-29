// Minimal Linux stand-in for Apple's `simd` overlay: only what the headless build needs.
import Foundation

@inlinable public func simd_dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float { (a * b).sum() }
@inlinable public func simd_length(_ v: SIMD3<Float>) -> Float { simd_dot(v, v).squareRoot() }
@inlinable public func simd_normalize(_ v: SIMD3<Float>) -> SIMD3<Float> { v / simd_length(v) }
@inlinable public func simd_distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float { simd_length(a - b) }
@inlinable public func simd_cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3<Float>(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}
@inlinable public func simd_min(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> { a.replacing(with: b, where: b .< a) }
@inlinable public func simd_max(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> { a.replacing(with: b, where: b .> a) }
@inlinable public func simd_mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: SIMD3<Float>) -> SIMD3<Float> { a + (b - a) * t }
