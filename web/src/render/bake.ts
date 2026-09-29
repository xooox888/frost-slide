/**
 * Bakes a tree of meshes into one or two merged geometries: positions and normals in the tree
 * root's frame, plus per-vertex colour, opacity, roughness, metalness and glow read by
 * `bakedMaterial`. A whole stretch of scenery (or a racer's body) then draws in one call instead
 * of hundreds.
 */
import * as THREE from 'three';
import { emittedColor, toColor, type Surface } from './surfaces';

export interface BakedGeometry {
  opaque: THREE.BufferGeometry | null;
  transparent: THREE.BufferGeometry | null;
}

class Buffers {
  private readonly positions: number[] = [];
  private readonly normals: number[] = [];
  private readonly colors: number[] = [];
  private readonly surfaces: number[] = [];
  private readonly glows: number[] = [];
  private readonly indices: number[] = [];
  private readonly v = new THREE.Vector3();
  private readonly n = new THREE.Vector3();
  private readonly color = new THREE.Color();
  private readonly glow = new THREE.Color();

  constructor(private readonly withAlpha: boolean) {}

  add(geometry: THREE.BufferGeometry, matrix: THREE.Matrix4, surface: Surface): void {
    const normalMatrix = new THREE.Matrix3().getNormalMatrix(matrix);
    const mirrored = matrix.determinant() < 0;
    toColor(surface.color, this.color);
    emittedColor(surface, this.glow);
    const sides = surface.doubleSided ? [false, true] : [false];
    for (const back of sides) this.append(geometry, matrix, normalMatrix, surface, mirrored !== back, back);
  }

  private append(
    geometry: THREE.BufferGeometry,
    matrix: THREE.Matrix4,
    normalMatrix: THREE.Matrix3,
    surface: Surface,
    flipWinding: boolean,
    flipNormals: boolean,
  ): void {
    const position = geometry.getAttribute('position');
    const normal = geometry.getAttribute('normal');
    const base = this.positions.length / 3;
    for (let i = 0; i < position.count; i += 1) {
      this.v.fromBufferAttribute(position, i).applyMatrix4(matrix);
      this.n.fromBufferAttribute(normal, i).applyMatrix3(normalMatrix).normalize();
      if (flipNormals) this.n.negate();
      this.positions.push(this.v.x, this.v.y, this.v.z);
      this.normals.push(this.n.x, this.n.y, this.n.z);
      this.colors.push(this.color.r, this.color.g, this.color.b);
      if (this.withAlpha) this.colors.push(surface.alpha);
      this.surfaces.push(surface.roughness, surface.metalness);
      this.glows.push(this.glow.r, this.glow.g, this.glow.b);
    }
    const index = geometry.getIndex();
    const count = index ? index.count : position.count;
    for (let i = 0; i < count; i += 3) {
      const a = index ? index.getX(i) : i;
      const b = index ? index.getX(i + 1) : i + 1;
      const c = index ? index.getX(i + 2) : i + 2;
      if (flipWinding) this.indices.push(base + a, base + c, base + b);
      else this.indices.push(base + a, base + b, base + c);
    }
  }

  build(): THREE.BufferGeometry | null {
    if (this.positions.length === 0) return null;
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(this.positions, 3));
    geometry.setAttribute('normal', new THREE.Float32BufferAttribute(this.normals, 3));
    geometry.setAttribute('color', new THREE.Float32BufferAttribute(this.colors, this.withAlpha ? 4 : 3));
    geometry.setAttribute('surface', new THREE.Float32BufferAttribute(this.surfaces, 2));
    geometry.setAttribute('glow', new THREE.Float32BufferAttribute(this.glows, 3));
    geometry.setIndex(this.indices);
    geometry.computeBoundingSphere();
    geometry.computeBoundingBox();
    return geometry;
  }
}

/** Merges every mesh under `root` that has a surface, in `root`'s own frame. */
export function bakeGeometry(root: THREE.Object3D): BakedGeometry {
  root.updateMatrixWorld(true);
  const toRoot = root.matrixWorld.clone().invert();
  const opaque = new Buffers(false);
  const transparent = new Buffers(true);
  const matrix = new THREE.Matrix4();
  root.traverse((node) => {
    if (!(node instanceof THREE.Mesh)) return;
    const surface = node.userData.surface as Surface | undefined;
    if (!surface) return;
    matrix.multiplyMatrices(toRoot, node.matrixWorld);
    (surface.alpha < 0.999 ? transparent : opaque).add(node.geometry, matrix, surface);
  });
  return { opaque: opaque.build(), transparent: transparent.build() };
}
