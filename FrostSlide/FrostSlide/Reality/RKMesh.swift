import RealityKit
import simd

enum RKMesh {
    static func cylinder(radius: Float, height: Float, segments: Int = 18) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let half = height * 0.5
        for i in 0...segments {
            let a = Float(i) / Float(segments) * 2 * Float.pi
            let x = cos(a) * radius
            let z = sin(a) * radius
            let n = simd_normalize(SIMD3<Float>(x, 0, z))
            positions.append(SIMD3(x, -half, z))
            positions.append(SIMD3(x, half, z))
            normals.append(n)
            normals.append(n)
        }
        for i in 0..<segments {
            let a = UInt32(i * 2)
            indices += [a, a + 1, a + 2, a + 1, a + 3, a + 2]
        }
        let topCenter = UInt32(positions.count)
        positions.append(SIMD3(0, half, 0))
        normals.append(SIMD3(0, 1, 0))
        let bottomCenter = UInt32(positions.count)
        positions.append(SIMD3(0, -half, 0))
        normals.append(SIMD3(0, -1, 0))
        for i in 0..<segments {
            let t0 = UInt32(i * 2 + 1)
            let t1 = UInt32((i + 1) * 2 + 1)
            indices += [topCenter, t1, t0]
            let b0 = UInt32(i * 2)
            let b1 = UInt32((i + 1) * 2)
            indices += [bottomCenter, b0, b1]
        }
        return generate(positions, normals, indices)
    }

    static func cone(bottomRadius: Float, height: Float, segments: Int = 16) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let half = height * 0.5
        let apex = SIMD3<Float>(0, half, 0)
        positions.append(apex)
        normals.append(SIMD3(0, 1, 0))
        for i in 0...segments {
            let a = Float(i) / Float(segments) * 2 * Float.pi
            let x = cos(a) * bottomRadius
            let z = sin(a) * bottomRadius
            positions.append(SIMD3(x, -half, z))
            let side = SIMD3<Float>(x, height * 0.15, z)
            normals.append(simd_normalize(side))
        }
        for i in 0..<segments {
            indices += [0, UInt32(i + 1), UInt32(i + 2)]
        }
        let baseCenter = UInt32(positions.count)
        positions.append(SIMD3(0, -half, 0))
        normals.append(SIMD3(0, -1, 0))
        for i in 0..<segments {
            indices += [baseCenter, UInt32(i + 2), UInt32(i + 1)]
        }
        return generate(positions, normals, indices)
    }

    static func capsule(radius: Float, height: Float) -> MeshResource {
        cylinder(radius: radius, height: max(0.08, height - radius * 2), segments: 14)
    }

    static func ribbon(path: TrackPath) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        positions.reserveCapacity(path.samples.count * 2)
        for sample in path.samples {
            let half = sample.width * 0.5
            let left = sample.position - sample.binormal * half
            let right = sample.position + sample.binormal * half
            positions.append(left)
            positions.append(right)
            normals.append(sample.normal)
            normals.append(sample.normal)
        }
        for i in 0..<(path.samples.count - 1) {
            let a = UInt32(i * 2)
            indices += [a, a + 1, a + 2, a + 1, a + 3, a + 2]
            // Reverse winding so the ribbon is visible from below on jumps.
            indices += [a, a + 2, a + 1, a + 1, a + 2, a + 3]
        }
        return generate(positions, normals, indices)
    }

    private static func generate(
        _ positions: [SIMD3<Float>],
        _ normals: [SIMD3<Float>],
        _ indices: [UInt32]
    ) -> MeshResource {
        var desc = MeshDescriptor(name: "proc")
        desc.positions = MeshBuffers.Positions(positions)
        desc.normals = MeshBuffers.Normals(normals)
        desc.primitives = .triangles(indices)
        return try! MeshResource.generate(from: [desc])
    }
}
