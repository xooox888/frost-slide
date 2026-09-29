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

    /// Track surface. u runs across the track (0 = left edge), v runs down it,
    /// tiling every `tile` metres so the snow texture keeps a constant scale.
    static func ribbon(path: TrackPath, tile: Float = 7) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        positions.reserveCapacity(path.samples.count * 2)
        var travelled: Float = 0
        var previous = path.samples.first?.position ?? .zero
        for sample in path.samples {
            travelled += simd_distance(sample.position, previous)
            previous = sample.position
            let half = sample.width * 0.5
            let left = sample.position - sample.binormal * half
            let right = sample.position + sample.binormal * half
            positions.append(left)
            positions.append(right)
            normals.append(sample.normal)
            normals.append(sample.normal)
            let v = travelled / tile
            uvs.append(SIMD2(0, v))
            uvs.append(SIMD2(1, v))
        }
        for i in 0..<(path.samples.count - 1) {
            let a = UInt32(i * 2)
            // Single winding: the track material is double-sided, and a coincident
            // reversed copy z-fights with flipped normals and turns white snow grey.
            indices += [a, a + 1, a + 2, a + 1, a + 3, a + 2]
        }
        var desc = MeshDescriptor(name: "ribbon")
        desc.positions = MeshBuffers.Positions(positions)
        desc.normals = MeshBuffers.Normals(normals)
        desc.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        desc.primitives = .triangles(indices)
        // A mesh built from our own valid buffers cannot fail; a crash here means a programming error.
        // swiftlint:disable:next force_try
        return try! MeshResource.generate(from: [desc])
    }

    /// Triangular prism roof: ridge along z, eaves at y = 0, apex at y = height.
    static func gableRoof(width: Float, height: Float, depth: Float) -> MeshResource {
        let hw = width * 0.5
        let hd = depth * 0.5
        let l0 = SIMD3<Float>(-hw, 0, -hd), l1 = SIMD3<Float>(-hw, 0, hd)
        let r0 = SIMD3<Float>(hw, 0, -hd), r1 = SIMD3<Float>(hw, 0, hd)
        let t0 = SIMD3<Float>(0, height, -hd), t1 = SIMD3<Float>(0, height, hd)
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        // Counter-clockwise seen from outside, flat-shaded per face.
        func face(_ corners: [SIMD3<Float>]) {
            let n = simd_normalize(simd_cross(corners[1] - corners[0], corners[2] - corners[0]))
            let base = UInt32(positions.count)
            positions += corners
            normals += Array(repeating: n, count: corners.count)
            for k in 1..<(corners.count - 1) {
                indices += [base, base + UInt32(k), base + UInt32(k + 1)]
            }
        }
        face([l0, l1, t1, t0])   // left slope, normal (-x, +y)
        face([r1, r0, t0, t1])   // right slope, normal (+x, +y)
        face([l1, r1, t1])       // front gable, normal +z
        face([r0, l0, t0])       // back gable, normal -z
        face([l0, r0, r1, l1])   // underside, normal -y
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
        // A mesh built from our own valid buffers cannot fail; a crash here means a programming error.
        // swiftlint:disable:next force_try
        return try! MeshResource.generate(from: [desc])
    }
}
