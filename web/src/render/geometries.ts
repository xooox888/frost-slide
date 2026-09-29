/**
 * Shared geometries (a port of `Reality/RKMesh.swift` plus the RealityKit primitives it used).
 * Every mesh of the same shape and size shares one geometry.
 */
import * as THREE from 'three';
import type { TrackPath } from '../engine/trackPath';

export class GeometryCache {
  private readonly geometries = new Map<string, THREE.BufferGeometry>();

  private cached(key: string, make: () => THREE.BufferGeometry): THREE.BufferGeometry {
    let geometry = this.geometries.get(key);
    if (!geometry) {
      geometry = make();
      this.geometries.set(key, geometry);
    }
    return geometry;
  }

  /** `generateBox(size:)`; the Swift boxes' 2 cm rounded corners are too small to see. */
  box(w: number, h: number, d: number): THREE.BufferGeometry {
    return this.cached(`box:${w}:${h}:${d}`, () => new THREE.BoxGeometry(w, h, d));
  }

  /** `generateSphere(radius:)`. Small spheres get fewer segments. */
  sphere(radius: number): THREE.BufferGeometry {
    const detail = radius >= 0.6 ? [24, 16] : radius >= 0.2 ? [16, 12] : [10, 8];
    return this.cached(`sphere:${radius}`, () => new THREE.SphereGeometry(radius, detail[0], detail[1]));
  }

  /** A sphere with explicit tessellation, for shapes drawn hundreds of times. */
  sphereDetail(radius: number, widthSegments: number, heightSegments: number): THREE.BufferGeometry {
    return this.cached(
      `sphere:${radius}:${widthSegments}:${heightSegments}`,
      () => new THREE.SphereGeometry(radius, widthSegments, heightSegments),
    );
  }

  /** `RKMesh.cylinder`: centred, along y. */
  cylinder(radius: number, height: number, segments = 18): THREE.BufferGeometry {
    return this.cached(
      `cyl:${radius}:${height}:${segments}`,
      () => new THREE.CylinderGeometry(radius, radius, height, segments),
    );
  }

  /** `RKMesh.cone`: centred, apex up. */
  cone(radius: number, height: number, segments = 16): THREE.BufferGeometry {
    return this.cached(`cone:${radius}:${height}:${segments}`, () => new THREE.ConeGeometry(radius, height, segments));
  }

  /** `RKMesh.capsule`, which was a cylinder shortened by the caps it never drew. */
  capsule(radius: number, height: number): THREE.BufferGeometry {
    return this.cylinder(radius, Math.max(0.08, height - radius * 2), 14);
  }

  /** `generatePlane(width:height:)`: upright in the xy plane, facing +z. */
  plane(width: number, height: number): THREE.BufferGeometry {
    return this.cached(`plane:${width}:${height}`, () => new THREE.PlaneGeometry(width, height));
  }

  /** `RKMesh.gableRoof`: ridge along z, eaves at y = 0, apex at y = height, flat-shaded. */
  gableRoof(width: number, height: number, depth: number): THREE.BufferGeometry {
    return this.cached(`roof:${width}:${height}:${depth}`, () => gableRoof(width, height, depth));
  }

  dispose(): void {
    for (const geometry of this.geometries.values()) geometry.dispose();
    this.geometries.clear();
  }
}

function gableRoof(width: number, height: number, depth: number): THREE.BufferGeometry {
  const hw = width * 0.5;
  const hd = depth * 0.5;
  const v = (x: number, y: number, z: number) => new THREE.Vector3(x, y, z);
  const l0 = v(-hw, 0, -hd);
  const l1 = v(-hw, 0, hd);
  const r0 = v(hw, 0, -hd);
  const r1 = v(hw, 0, hd);
  const t0 = v(0, height, -hd);
  const t1 = v(0, height, hd);
  const positions: number[] = [];
  const normals: number[] = [];
  const indices: number[] = [];
  // Counter-clockwise seen from outside, flat-shaded per face.
  const face = (corners: THREE.Vector3[]) => {
    const n = new THREE.Vector3()
      .subVectors(corners[1], corners[0])
      .cross(new THREE.Vector3().subVectors(corners[2], corners[0]))
      .normalize();
    const base = positions.length / 3;
    for (const c of corners) {
      positions.push(c.x, c.y, c.z);
      normals.push(n.x, n.y, n.z);
    }
    for (let k = 1; k < corners.length - 1; k += 1) indices.push(base, base + k, base + k + 1);
  };
  face([l0, l1, t1, t0]);
  face([r1, r0, t0, t1]);
  face([l1, r1, t1]);
  face([r0, l0, t0]);
  face([l0, r0, r1, l1]);
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
  geometry.setIndex(indices);
  return geometry;
}

/**
 * `RKMesh.ribbon`: the track surface. u runs across the track (0 = left edge), v down it, tiling
 * every `tile` metres so the snow texture keeps a constant scale.
 */
export function ribbon(path: TrackPath, tile = 7): THREE.BufferGeometry {
  const samples = path.samples;
  const positions = new Float32Array(samples.length * 6);
  const normals = new Float32Array(samples.length * 6);
  const uvs = new Float32Array(samples.length * 4);
  let travelled = 0;
  let previous = samples[0].position;
  samples.forEach((s, i) => {
    const p = s.position;
    travelled += Math.hypot(p.x - previous.x, p.y - previous.y, p.z - previous.z);
    previous = p;
    const half = s.width * 0.5;
    const b = s.binormal;
    positions.set([p.x - b.x * half, p.y - b.y * half, p.z - b.z * half], i * 6);
    positions.set([p.x + b.x * half, p.y + b.y * half, p.z + b.z * half], i * 6 + 3);
    normals.set([s.normal.x, s.normal.y, s.normal.z, s.normal.x, s.normal.y, s.normal.z], i * 6);
    const v = travelled / tile;
    uvs.set([0, v, 1, v], i * 4);
  });
  const indices: number[] = [];
  for (let i = 0; i < samples.length - 1; i += 1) {
    const a = i * 2;
    indices.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geometry.setAttribute('normal', new THREE.BufferAttribute(normals, 3));
  geometry.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  geometry.computeBoundingSphere();
  return geometry;
}

/**
 * The harbour water: a wide flat band that follows the course `drop` metres below the snow. (The
 * Swift app used one level box at the course's mid height, which the lower half of the course
 * ran underneath.) The band narrows in tight turns so its inside edge never folds over itself.
 */
export function waterBand(path: TrackPath, drop: number, maxHalfWidth: number): THREE.BufferGeometry {
  const samples = path.samples;
  const positions = new Float32Array(samples.length * 6);
  const normals = new Float32Array(samples.length * 6);
  samples.forEach((s, i) => {
    const p = s.position;
    const turn = Math.abs(s.curvature);
    const half = Math.max(12, Math.min(maxHalfWidth, turn > 1e-5 ? 0.8 / turn : maxHalfWidth));
    // Level across (the track's banking doesn't tilt the sea).
    const side = new THREE.Vector3(s.binormal.x, 0, s.binormal.z).normalize();
    positions.set([p.x - side.x * half, p.y - drop, p.z - side.z * half], i * 6);
    positions.set([p.x + side.x * half, p.y - drop, p.z + side.z * half], i * 6 + 3);
    normals.set([0, 1, 0, 0, 1, 0], i * 6);
  });
  const indices: number[] = [];
  for (let i = 0; i < samples.length - 1; i += 1) {
    const a = i * 2;
    indices.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geometry.setAttribute('normal', new THREE.BufferAttribute(normals, 3));
  geometry.setIndex(indices);
  geometry.computeBoundingSphere();
  return geometry;
}
