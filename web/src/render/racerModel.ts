/**
 * One racer: a red panda cub in a knitted beanie and scarf, riding a glowing disc sled. A port of
 * `Reality/RacerFactory.swift`, part for part.
 *
 * The chase camera mostly sees the racer from behind and above, so the identity colour lives on
 * the beanie, the scarf and the sled, and the fur, ears and striped tail give the silhouette.
 *
 * About forty parts are built as in Swift, then baked into five meshes: the body and the four
 * pieces `RaceRenderer` animates (both arms, the scarf tail and the fluffy tail). Seven racers
 * then cost about forty draw calls instead of three hundred.
 */
import * as THREE from 'three';
import type { RGB } from '../core/math';
import { bakeGeometry } from './bake';
import { bakedMaterial } from './materials';
import { AXIS_X, AXIS_Y, AXIS_Z, part, quat, type Kit } from './props';
import { clamp01, mul, pbr, plus, type Surface } from './surfaces';

// Fur palette.
const RUST: RGB = [0.86, 0.34, 0.1];
const DEEP_RUST: RGB = [0.58, 0.18, 0.07];
const DARK: RGB = [0.17, 0.09, 0.07];
const CREAM: RGB = [0.97, 0.92, 0.84];
const TIP: RGB = [0.3, 0.11, 0.06];
const INK: RGB = [0.05, 0.04, 0.04];

/** An ellipsoid, so face parts can sit on the surface of the head or body they belong to. */
class Ellipsoid {
  constructor(
    readonly center: THREE.Vector3,
    readonly radii: THREE.Vector3,
  ) {}

  /** The point on the front of the surface above (x, y), pushed out along z by `lift`. */
  front(x: number, y: number, lift = 0): THREE.Vector3 {
    const nx = (x - this.center.x) / this.radii.x;
    const ny = (y - this.center.y) / this.radii.y;
    const depth = Math.sqrt(Math.max(0, 1 - nx * nx - ny * ny));
    return new THREE.Vector3(x, y, this.center.z + this.radii.z * depth + lift);
  }
}

const v3 = (x: number, y: number, z: number) => new THREE.Vector3(x, y, z);
const BODY = new Ellipsoid(v3(0, 0.42, 0), v3(0.34, 0.34, 0.33));
const HEAD = new Ellipsoid(v3(0, 0.8, 0.07), v3(0.29, 0.225, 0.25));

export interface RacerRig {
  root: THREE.Group;
  flipL: THREE.Object3D;
  flipR: THREE.Object3D;
  scarfTail: THREE.Object3D;
  fluffTail: THREE.Object3D;
  shroud: THREE.Mesh;
}

export class RacerModels {
  private readonly material = bakedMaterial(false);
  private readonly unitSphere: THREE.BufferGeometry;
  private readonly geometries: THREE.BufferGeometry[] = [];

  constructor(private readonly kit: Kit) {
    // Every rounded part is this one sphere, scaled, as in Swift. The parts are small on screen,
    // so it is coarser than the scenery's spheres.
    this.unitSphere = kit.geo.sphereDetail(1, 14, 10);
  }

  make(sledColor: RGB): RacerRig {
    const kit = this.kit;
    const root = new THREE.Group();
    root.name = 'racer';
    const body = new THREE.Group();

    const blob = (radii: THREE.Vector3, position: THREE.Vector3, color: RGB, roughness = 0.5) => {
      const mesh = part(kit, this.unitSphere, pbr(color, { roughness }));
      mesh.position.copy(position);
      mesh.scale.copy(radii);
      return mesh;
    };

    // Sled. (Swift also hung a point light on every sled; only the player's gets one here.)
    const sled = part(
      kit,
      kit.geo.cylinder(0.62, 0.11),
      pbr(sledColor, { roughness: 0.22, metallic: 0.15, emissive: mul(sledColor, 0.35) }),
    );
    sled.position.set(0, 0.06, 0);
    body.add(sled);
    const rim = part(
      kit,
      kit.geo.cylinder(0.66, 0.05),
      pbr(clamp01(plus(sledColor, [0.15, 0.15, 0.15])), { roughness: 0.2, emissive: mul(sledColor, 0.2) }),
    );
    rim.position.set(0, 0.09, 0);
    body.add(rim);

    // Body, with a dark belly like the real thing, and hind feet in front of the seat.
    body.add(blob(BODY.radii, BODY.center, RUST, 0.55));
    const belly = BODY.front(0, 0.33);
    body.add(blob(v3(0.21, 0.22, 0.12), v3(0, 0.34, belly.z - 0.09), DARK, 0.6));
    for (const sign of [-1, 1]) body.add(blob(v3(0.11, 0.055, 0.17), v3(sign * 0.16, 0.14, 0.29), DARK, 0.55));

    // Head: white cheek fluff and muzzle, the dark tear line below each eye.
    body.add(blob(HEAD.radii, HEAD.center, RUST, 0.55));
    for (const sign of [-1, 1]) {
      body.add(blob(v3(0.125, 0.1, 0.09), HEAD.front(sign * 0.17, 0.745, -0.06), CREAM, 0.75));
      const tearLine = blob(v3(0.011, 0.045, 0.01), HEAD.front(sign * 0.12, 0.765, -0.005), DEEP_RUST, 0.7);
      tearLine.rotation.z = sign * 0.35;
      body.add(tearLine);
      body.add(blob(v3(0.042, 0.048, 0.03), HEAD.front(sign * 0.105, 0.82, 0.005), INK, 0.15));
    }
    const muzzle = HEAD.front(0, 0.735, -0.03);
    body.add(blob(v3(0.1, 0.075, 0.085), muzzle, CREAM, 0.7));
    body.add(blob(v3(0.042, 0.03, 0.03), v3(0, 0.752, muzzle.z + 0.075), INK, 0.2));

    // Round ears that poke out through the sides of the beanie.
    for (const sign of [-1, 1]) {
      const ear = new THREE.Group();
      ear.position.set(sign * 0.245, 0.985, 0);
      ear.quaternion.copy(quat(AXIS_Z, sign * -0.4).multiply(quat(AXIS_Y, sign * 0.35)));
      ear.add(blob(v3(0.105, 0.115, 0.07), v3(0, 0, 0), DARK, 0.6));
      ear.add(blob(v3(0.068, 0.078, 0.04), v3(0, 0, 0.038), CREAM, 0.8));
      body.add(ear);
    }

    // Beanie and a chunky knitted scarf: overlapping lumps laid round the neck.
    const wool = pbr(sledColor, { roughness: 0.75 });
    const beanie = part(kit, kit.geo.sphere(0.28), wool);
    beanie.position.set(0, 0.945, 0.05);
    beanie.scale.set(1.0, 0.68, 0.98);
    body.add(beanie);
    const band = part(kit, kit.geo.cylinder(0.285, 0.075), pbr(CREAM, { roughness: 0.8 }));
    band.position.set(0, 0.905, 0.05);
    body.add(band);
    const pom = part(kit, kit.geo.sphere(0.08), pbr(CREAM, { roughness: 0.9 }));
    pom.position.set(0, 1.135, 0.045);
    body.add(pom);
    const lumps = 10;
    for (let i = 0; i < lumps; i += 1) {
      const a = (i / lumps) * 2 * Math.PI;
      const lump = part(kit, this.unitSphere, wool);
      lump.position.set(Math.cos(a) * 0.255, 0.63, 0.03 + Math.sin(a) * 0.235);
      lump.scale.set(0.092, 0.06, 0.064);
      lump.rotation.y = -a - Math.PI / 2;
      body.add(lump);
    }
    root.add(this.baked(body));

    const scarfTail = new THREE.Group();
    scarfTail.name = 'scarfTail';
    scarfTail.position.set(0.1, 0.63, -0.2);
    const scarfEnd = part(kit, kit.geo.box(0.13, 0.05, 0.42), pbr(sledColor, { roughness: 0.75 }));
    scarfEnd.position.set(0, 0, -0.2);
    scarfTail.add(this.bakedParts([scarfEnd]));
    root.add(scarfTail);

    // Arms hang from shoulder pivots; the renderer swings them, out and flapping on boost.
    const arms: THREE.Object3D[] = [];
    for (const sign of [-1, 1]) {
      const pivot = new THREE.Group();
      pivot.name = sign < 0 ? 'flipL' : 'flipR';
      pivot.position.set(sign * 0.3, 0.52, 0.05);
      pivot.rotation.z = sign * 0.85;
      const arm = part(kit, kit.geo.cylinder(0.07, 0.22), pbr(DARK, { roughness: 0.55 }));
      arm.position.set(0, -0.13, 0);
      pivot.add(this.bakedParts([arm, blob(v3(0.085, 0.085, 0.085), v3(0, -0.25, 0.01), DARK, 0.5)]));
      root.add(pivot);
      arms.push(pivot);
    }

    // The long ringed tail: a chain of fluffy segments that curls up behind the racer's right
    // side, so the chase camera sees the rings as stripes instead of looking down its length.
    const fluffTail = new THREE.Group();
    fluffTail.name = 'fluffTail';
    fluffTail.position.set(-0.06, 0.24, -0.22);
    const rings: RGB[] = [RUST, DEEP_RUST, RUST, DEEP_RUST, RUST, DEEP_RUST, TIP];
    const widths = [0.095, 0.118, 0.13, 0.135, 0.13, 0.112, 0.08];
    const segments: THREE.Object3D[] = [];
    rings.forEach((ring, i) => {
      const t = i / (rings.length - 1);
      const position = v3(-0.04 - 0.22 * t * t, 0.02 + 0.36 * t, -0.08 - 0.2 * Math.sin(Math.PI * t));
      // Lay each segment along the curve (its long axis is z).
      const along = v3(-0.44 * t, 0.36, -0.2 * Math.PI * Math.cos(Math.PI * t)).normalize();
      if (along.z < 0) along.negate();
      const yaw = Math.atan2(along.x, along.z);
      const pitch = -Math.atan2(along.y, Math.hypot(along.x, along.z));
      const segment = blob(v3(widths[i], widths[i], widths[i] * 1.35), position, ring, 0.65);
      segment.quaternion.copy(quat(AXIS_Y, yaw).multiply(quat(AXIS_X, pitch)));
      segments.push(segment);
    });
    fluffTail.add(this.bakedParts(segments));
    root.add(fluffTail);

    // The ghost power-up's shroud.
    const shroudSurface: Surface = pbr([0.55, 0.85, 1.0], { roughness: 0.15, alpha: 0.28 });
    const shroud = new THREE.Mesh(kit.geo.sphere(0.85), kit.mat.get(shroudSurface));
    shroud.name = 'ghostShroud';
    shroud.position.set(0, 0.5, 0);
    shroud.visible = false;
    root.add(shroud);

    root.traverse((node) => {
      if (node instanceof THREE.Mesh && node !== shroud) node.castShadow = true;
    });
    return { root, flipL: arms[0], flipR: arms[1], scarfTail, fluffTail, shroud };
  }

  dispose(): void {
    for (const geometry of this.geometries) geometry.dispose();
    this.geometries.length = 0;
    this.material.dispose();
  }

  /** One mesh for everything under `group`, in the group's frame. */
  private baked(group: THREE.Object3D): THREE.Mesh {
    const { opaque } = bakeGeometry(group);
    const geometry = opaque ?? new THREE.BufferGeometry();
    this.geometries.push(geometry);
    const mesh = new THREE.Mesh(geometry, this.material);
    mesh.position.copy(group.position);
    mesh.quaternion.copy(group.quaternion);
    mesh.scale.copy(group.scale);
    return mesh;
  }

  private bakedParts(parts: THREE.Object3D[]): THREE.Mesh {
    const group = new THREE.Group();
    for (const p of parts) group.add(p);
    return this.baked(group);
  }
}
