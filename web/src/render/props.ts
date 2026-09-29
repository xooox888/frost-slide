/**
 * Every course prop, built from primitives. A port of the prop functions in
 * `Reality/WorldFactory.swift`, part for part and number for number.
 *
 * Each builder returns the prop in its own frame (x across the track, y up, z down the track);
 * `world.ts` places it on the course. Every mesh carries its `Surface` in `userData.surface` so
 * static scenery can be baked into merged meshes.
 *
 * One difference from Swift: many builders give their root a height (a crystal floats 0.7 m up,
 * a crate sits on its base). Swift's `makeProp` then overwrote that position with the course
 * position, so those props were drawn centred on the snow (half buried) and crystals were placed
 * at a fixed world height, under the course. Here the root keeps its height above the snow. The
 * hanging icicles and stalactites keep the look the Swift app shipped (point down, planted in
 * the snow), which reads as an obstacle rather than something floating overhead.
 */
import * as THREE from 'three';
import type { RGB } from '../core/math';
import type { LevelPalette } from '../core/models';
import type { GeometryCache } from './geometries';
import type { MaterialCache } from './materials';
import { glow, gray, mix, mul, pbr, rgb, type Surface } from './surfaces';

export interface Kit {
  geo: GeometryCache;
  mat: MaterialCache;
  /** Seeded, for the choices Swift made with `randomElement()`. */
  random: () => number;
}

export const AXIS_X = new THREE.Vector3(1, 0, 0);
export const AXIS_Y = new THREE.Vector3(0, 1, 0);
export const AXIS_Z = new THREE.Vector3(0, 0, 1);
export const quat = (axis: THREE.Vector3, angle: number) => new THREE.Quaternion().setFromAxisAngle(axis, angle);

/** One mesh with its surface recorded for baking. */
export function part(kit: Kit, geometry: THREE.BufferGeometry, surface: Surface): THREE.Mesh {
  const mesh = new THREE.Mesh(geometry, kit.mat.get(surface));
  mesh.userData.surface = surface;
  return mesh;
}

const at = <T extends THREE.Object3D>(object: T, x: number, y: number, z: number): T => {
  object.position.set(x, y, z);
  return object;
};

/** `RKEntity.box` */
const box = (kit: Kit, w: number, h: number, d: number, color: RGB, roughness = 0.65) =>
  part(kit, kit.geo.box(w, h, d), pbr(color, { roughness }));

/** `RKEntity.sphere` */
const sphere = (kit: Kit, radius: number, color: RGB, roughness = 0.5) =>
  part(kit, kit.geo.sphere(radius), pbr(color, { roughness }));

const pick = <T>(kit: Kit, items: readonly T[]): T => items[Math.floor(kit.random() * items.length) % items.length];

const WHITE = gray(1);
const SNOW_CAP = rgb(0.97, 0.98, 1.0);

export function building(kit: Kit, palette: LevelPalette, scale: number): THREE.Group {
  const root = new THREE.Group();
  const w = 3.6 + scale * 0.6;
  const h = 4.6 + scale * 1.8;
  const d = 3.6;
  const walls: RGB[] = [
    [0.36, 0.62, 0.74],
    [0.93, 0.88, 0.78],
    [0.52, 0.66, 0.86],
    [0.8, 0.47, 0.38],
    [0.44, 0.7, 0.66],
  ];
  const roofs: RGB[] = [
    [0.16, 0.26, 0.46],
    [0.12, 0.44, 0.52],
    [0.58, 0.2, 0.22],
  ];
  const wall = mix(palette.wall, pick(kit, walls), 0.6);
  root.add(at(box(kit, w, h, d, wall, 0.75), 0, h / 2, 0));
  root.add(at(box(kit, w + 0.12, 0.22, d + 0.12, [0.96, 0.96, 0.98], 0.6), 0, h - 0.1, 0));

  const roofH = 1.8 + scale * 0.3;
  const roof = part(kit, kit.geo.gableRoof(w + 0.8, roofH, d + 0.7), pbr(pick(kit, roofs), { roughness: 0.55 }));
  root.add(at(roof, 0, h, 0));
  // Snow cap: same slope as the roof, shorter, so coloured eaves show below it.
  const cap = part(kit, kit.geo.gableRoof((w + 0.8) * 0.72, roofH * 0.72, d + 0.9), pbr(SNOW_CAP, { roughness: 0.9 }));
  root.add(at(cap, 0, h + roofH * 0.28 + 0.08, 0));

  root.add(at(box(kit, 0.55, 1.4, 0.55, [0.55, 0.3, 0.24], 0.8), w * 0.24, h + roofH * 0.7, -d * 0.2));
  root.add(at(box(kit, 0.68, 0.16, 0.68, SNOW_CAP, 0.9), w * 0.24, h + roofH * 0.7 + 0.76, -d * 0.2));

  // Warm lit windows on every face so they read from the chase camera.
  const lit = glow([1.0, 0.76, 0.4], palette.night ? 2.2 : 1.1);
  const frame = pbr([0.97, 0.97, 0.98], { roughness: 0.6 });
  const pane = kit.geo.box(0.5, 0.66, 0.06);
  const border = kit.geo.box(0.66, 0.82, 0.04);
  const rows = h > 6 ? [0.3, 0.62] : [0.45];
  for (const row of rows) {
    for (const col of [-1, 1]) {
      const faces: [THREE.Vector3, number][] = [
        [new THREE.Vector3(col * w * 0.24, h * row, d * 0.51), 0],
        [new THREE.Vector3(col * w * 0.24, h * row, -d * 0.51), Math.PI],
        [new THREE.Vector3(w * 0.51, h * row, col * d * 0.24), Math.PI / 2],
        [new THREE.Vector3(-w * 0.51, h * row, col * d * 0.24), -Math.PI / 2],
      ];
      for (const [pos, yaw] of faces) {
        const orientation = quat(AXIS_Y, yaw);
        const b = part(kit, border, frame);
        b.position.copy(pos);
        b.quaternion.copy(orientation);
        root.add(b);
        const win = part(kit, pane, lit);
        win.position.copy(pos).add(new THREE.Vector3(0, 0, 0.02).applyQuaternion(orientation));
        win.quaternion.copy(orientation);
        root.add(win);
      }
    }
  }
  root.add(at(box(kit, 0.9, 1.5, 0.08, [0.36, 0.22, 0.14], 0.7), 0, 0.75, -d * 0.52));
  const drift = sphere(kit, 1, [0.95, 0.97, 1.0], 0.92);
  drift.scale.set(w * 0.62, 0.35, d * 0.62);
  root.add(drift);
  return root;
}

/** Ice-crystal arch from the menu art: glassy pillars, a curved crystal span, glowing core. */
export function archway(kit: Kit): THREE.Group {
  const root = new THREE.Group();
  const ice = pbr([0.62, 0.88, 1.0], { roughness: 0.08, metallic: 0.1, emissive: [0.1, 0.36, 0.6], alpha: 0.86 });
  const core = glow([0.3, 0.85, 1.0], 1.4);
  const spike = kit.geo.cone(0.42, 1.5, 6);
  const radius = 4.1;
  const lift = 5.6;
  for (const sign of [-1, 1]) {
    root.add(at(part(kit, kit.geo.box(1.0, lift, 1.1), ice), sign * radius, lift / 2, 0));
    root.add(at(part(kit, kit.geo.box(0.18, lift * 0.92, 1.14), core), sign * radius, lift / 2, 0));
    for (let k = 0; k < 3; k += 1) {
      const c = at(part(kit, spike, ice), sign * (radius + 0.5 + k * 0.25), 0.7 + k * 0.2, (k - 1) * 0.45);
      c.rotation.z = -sign * (0.35 + k * 0.15);
      c.scale.setScalar(0.8 + k * 0.2);
      root.add(c);
    }
  }
  const segments = 9;
  for (let i = 0; i < segments; i += 1) {
    const a = (Math.PI * (i + 0.5)) / segments;
    const block = at(
      part(kit, kit.geo.box(1.55, 0.95, 1.1), ice),
      Math.cos(a) * radius,
      lift + Math.sin(a) * (radius * 0.72),
      0,
    );
    block.rotation.z = a - Math.PI / 2;
    root.add(block);
    const tip = at(
      part(kit, spike, i % 2 === 0 ? ice : core),
      Math.cos(a) * (radius + 0.9),
      lift + Math.sin(a) * (radius * 0.72 + 0.9),
      0,
    );
    tip.rotation.z = a - Math.PI / 2;
    tip.scale.setScalar(i % 2 === 0 ? 1.0 : 0.7);
    root.add(tip);
  }
  return root;
}

export function boostRamp(kit: Kit): THREE.Group {
  const root = new THREE.Group();
  const slab = at(box(kit, 3.6, 0.55, 4.2, [0.15, 0.82, 0.95], 0.35), 0, 0.55, 0.4);
  slab.rotation.x = -0.28;
  root.add(slab);
  for (let i = 0; i < 3; i += 1) {
    const stripe = at(box(kit, 3.1, 0.04, 0.38, WHITE, 0.25), 0, 0.72 + i * 0.08, -0.4 + i * 0.7);
    stripe.rotation.x = -0.28;
    root.add(stripe);
  }
  return root;
}

export function turboPad(kit: Kit): THREE.Group {
  const root = new THREE.Group();
  const disc = part(
    kit,
    kit.geo.cylinder(1.15, 0.06),
    pbr([0.2, 0.85, 1.0], { roughness: 0.2, emissive: [0.15, 0.55, 0.8] }),
  );
  root.add(at(disc, 0, 0.05, 0));
  const chev = part(kit, kit.geo.cone(0.35, 0.7), pbr(WHITE, { roughness: 0.2 }));
  chev.rotation.x = Math.PI / 2;
  root.add(at(chev, 0, 0.12, 0));
  return root;
}

export const CRYSTAL_SURFACE = glow([0.35, 0.88, 1.0], 1.3, 0.95);

/** The gem: two six-sided cones base to base, as one geometry (crystals are instanced). */
export function crystalGeometry(): THREE.BufferGeometry {
  const top = new THREE.ConeGeometry(0.24, 0.42, 6).translate(0, 0.21, 0);
  const bottom = new THREE.ConeGeometry(0.24, 0.3, 6).rotateX(Math.PI).translate(0, -0.15, 0);
  const merged = mergeSimple([top, bottom]);
  top.dispose();
  bottom.dispose();
  return merged;
}

export const POWER_COLORS = {
  rocket: rgb(1.0, 0.4, 0.2),
  magnet: rgb(0.3, 0.85, 1.0),
  ghost: rgb(0.8, 0.9, 1.0),
  banana: rgb(1.0, 0.85, 0.15),
  flare: rgb(1.0, 0.92, 0.35),
} as const;

export function powerOrb(kit: Kit, color: RGB): THREE.Mesh {
  const node = part(kit, kit.geo.sphere(0.38), glow(color, 1.2));
  const halo = part(kit, kit.geo.sphere(0.55), pbr(color, { roughness: 0.1, emissive: mul(color, 0.5), alpha: 0.25 }));
  node.add(halo);
  node.position.y = 0.85;
  return node;
}

export function snowman(kit: Kit): THREE.Group {
  const root = new THREE.Group();
  const white = rgb(0.96, 0.97, 0.98);
  const coal = rgb(0.08, 0.08, 0.1);
  const felt = pbr([0.15, 0.18, 0.28], { roughness: 0.6 });
  const red = rgb(0.92, 0.26, 0.34);
  root.add(at(sphere(kit, 0.55, white, 0.85), 0, 0.5, 0));
  root.add(at(sphere(kit, 0.4, white, 0.85), 0, 1.2, 0));
  root.add(at(sphere(kit, 0.28, white, 0.85), 0, 1.75, 0));
  root.add(at(part(kit, kit.geo.cylinder(0.22, 0.26), felt), 0, 2.07, 0));
  root.add(at(part(kit, kit.geo.cylinder(0.32, 0.04), felt), 0, 1.95, 0));
  const nose = at(part(kit, kit.geo.cone(0.05, 0.2), pbr([1, 0.5, 0.1], { roughness: 0.4 })), 0, 1.72, 0.3);
  nose.rotation.x = Math.PI / 2;
  root.add(nose);
  root.add(at(part(kit, kit.geo.cylinder(0.33, 0.12), pbr(red, { roughness: 0.6 })), 0, 1.5, 0));
  root.add(at(box(kit, 0.14, 0.42, 0.05, red, 0.6), 0.16, 1.32, 0.3));
  for (const sign of [-1, 1]) {
    root.add(at(sphere(kit, 0.04, coal, 0.3), sign * 0.1, 1.82, 0.25));
    const arm = at(
      part(kit, kit.geo.cylinder(0.025, 0.8), pbr([0.36, 0.22, 0.12], { roughness: 0.8 })),
      sign * 0.62,
      1.32,
      0,
    );
    arm.rotation.z = sign * 1.0;
    root.add(arm);
  }
  return root;
}

export function crate(kit: Kit, scale: number): THREE.Mesh {
  const node = box(kit, 0.95, 0.95, 0.95, [0.62, 0.42, 0.22], 0.75);
  node.position.y = 0.48;
  node.scale.setScalar(scale);
  return node;
}

export function cart(kit: Kit): THREE.Group {
  const root = new THREE.Group();
  root.add(at(box(kit, 1.6, 0.45, 1.1, [0.55, 0.32, 0.16], 0.7), 0, 0.55, 0));
  for (const sign of [-1, 1]) {
    for (const z of [-0.4, 0.4]) {
      const wheel = at(
        part(kit, kit.geo.cylinder(0.22, 0.12), pbr([0.2, 0.2, 0.22], { roughness: 0.5 })),
        sign * 0.55,
        0.22,
        z,
      );
      wheel.rotation.z = Math.PI / 2;
      root.add(wheel);
    }
  }
  return root;
}

export function marketNPC(kit: Kit): THREE.Group {
  const root = new THREE.Group();
  root.add(at(part(kit, kit.geo.capsule(0.22, 0.9), pbr([0.7, 0.25, 0.22], { roughness: 0.6 })), 0, 0.7, 0));
  root.add(at(sphere(kit, 0.18, [0.96, 0.8, 0.68], 0.5), 0, 1.28, 0));
  return root;
}

export function stall(kit: Kit): THREE.Group {
  const root = new THREE.Group();
  root.add(at(box(kit, 2.2, 0.15, 1.1, [0.55, 0.35, 0.18], 0.7), 0, 0.85, 0));
  root.add(at(box(kit, 2.25, 0.72, 0.06, [0.82, 0.22, 0.25], 0.6), 0, 0.5, 0.55));
  for (let i = 0; i < 6; i += 1) {
    const color: RGB = i % 2 === 0 ? [0.96, 0.96, 0.98] : [0.15, 0.62, 0.85];
    root.add(at(box(kit, 0.4, 0.1, 1.45, color, 0.5), -1.0 + i * 0.4, 1.85, 0));
  }
  for (const sign of [-1, 1]) root.add(at(box(kit, 0.08, 1.8, 0.08, [0.45, 0.3, 0.16], 0.7), sign * 1.05, 0.9, -0.6));
  return root;
}

export function pine(kit: Kit, scale: number): THREE.Group {
  const root = new THREE.Group();
  root.add(at(part(kit, kit.geo.cylinder(0.18, 1.1), pbr([0.38, 0.24, 0.14], { roughness: 0.8 })), 0, 0.55, 0));
  const needles = pbr([0.1, 0.34, 0.27], { roughness: 0.8 });
  const snow = pbr([0.95, 0.97, 1.0], { roughness: 0.9 });
  let y = 1.25;
  for (let i = 0; i < 4; i += 1) {
    const r = 1.45 - i * 0.3;
    root.add(at(part(kit, kit.geo.cone(r, 1.3, 12), needles), 0, y, 0));
    root.add(at(part(kit, kit.geo.cone(r * 0.62, 0.8, 12), snow), 0, y + 0.28, 0));
    y += 0.72;
  }
  root.scale.setScalar(scale);
  return root;
}

export function dockPlank(kit: Kit, width: number): THREE.Mesh {
  return at(box(kit, width + 1.5, 0.18, 4.2, [0.5, 0.34, 0.2], 0.8), 0, 0.04, 0);
}

export function boat(kit: Kit): THREE.Mesh {
  const hull = part(kit, kit.geo.capsule(0.7, 3.4), pbr([0.28, 0.22, 0.18], { roughness: 0.55 }));
  hull.rotation.z = Math.PI / 2;
  hull.position.y = 0.4;
  return hull;
}

/** Point down, planted in the snow, as the Swift app drew it (its 4.2 m hang was overwritten). */
export function icicle(kit: Kit, scale: number): THREE.Mesh {
  const node = part(kit, kit.geo.cone(0.22, 1.8 * scale), pbr([0.55, 0.85, 1.0], { roughness: 0.15, alpha: 0.65 }));
  node.rotation.x = Math.PI;
  return node;
}

/** Point down, planted in the snow, as the Swift app drew it: an obstacle on the line. */
export function stalactite(kit: Kit): THREE.Mesh {
  const node = part(kit, kit.geo.cone(0.32, 2.4), pbr([0.45, 0.72, 0.88], { roughness: 0.35 }));
  node.rotation.x = Math.PI;
  return node;
}

/** A translucent green curtain high over the course. Two-sided, so the chase camera sees it. */
export function auroraRibbon(kit: Kit): THREE.Mesh {
  const node = part(
    kit,
    kit.geo.plane(18, 5),
    pbr([0.35, 0.95, 0.65], { roughness: 0.4, emissive: [0.2, 0.55, 0.4], alpha: 0.22, doubleSided: true }),
  );
  node.position.y = 12;
  return node;
}

export function lantern(kit: Kit, night: boolean): THREE.Group {
  const root = new THREE.Group();
  root.add(at(part(kit, kit.geo.cylinder(0.07, 2.6), pbr([0.2, 0.2, 0.22], { roughness: 0.5 })), 0, 1.3, 0));
  const bulb = at(part(kit, kit.geo.sphere(0.2), glow([1, 0.82, 0.45], night ? 2.4 : 1.2)), 0, 2.6, 0);
  // At night Swift hung a point light in every lantern; here a glow sprite does that job (see
  // world.ts), because dozens of real lights are too slow in a phone's web view.
  bulb.userData.lanternGlow = night;
  root.add(bulb);
  return root;
}

export function chimney(kit: Kit): THREE.Mesh {
  return at(box(kit, 0.7, 2.2, 0.7, [0.55, 0.28, 0.22], 0.8), 0, 1.1, 0);
}

export function barrel(kit: Kit): THREE.Mesh {
  return at(part(kit, kit.geo.cylinder(0.32, 0.55), pbr([0.48, 0.3, 0.16], { roughness: 0.7 })), 0, 0.28, 0);
}

/**
 * The slippery zone is an ellipse stretched along the track (`Tuning.icePatchStretch`); draw
 * exactly that, so the patch you see is the patch you slide on.
 */
export function icePatch(kit: Kit, radius: number, stretch: number): THREE.Mesh {
  const node = part(
    kit,
    kit.geo.cylinder(radius, 0.04),
    pbr([0.55, 0.85, 1.0], { roughness: 0.08, metallic: 0.35, alpha: 0.7 }),
  );
  node.position.y = 0.03;
  node.scale.set(1, 1, stretch);
  return node;
}

/**
 * A dropped peel: yellow petals splayed on the snow inside a warning ring, so it can't be
 * mistaken for the glowing orb that gives you one.
 */
export function bananaPeel(kit: Kit): THREE.Group {
  const root = new THREE.Group();
  const yellow = pbr([1.0, 0.86, 0.18], { roughness: 0.35, emissive: [0.3, 0.24, 0.02] });
  for (let k = 0; k < 3; k += 1) {
    const angle = (k * 2 * Math.PI) / 3;
    const petal = at(part(kit, kit.geo.sphere(0.32), yellow), Math.cos(angle) * 0.34, 0.12, Math.sin(angle) * 0.34);
    petal.scale.set(1.5, 0.22, 0.6);
    petal.rotation.y = -angle;
    root.add(petal);
  }
  root.add(at(part(kit, kit.geo.cylinder(0.06, 0.3), pbr([0.35, 0.22, 0.08], { roughness: 0.6 })), 0, 0.2, 0));
  const ring = part(
    kit,
    kit.geo.cylinder(0.85, 0.03),
    pbr([1.0, 0.35, 0.2], { roughness: 0.3, emissive: [0.5, 0.12, 0.05], alpha: 0.45 }),
  );
  root.add(at(ring, 0, 0.03, 0));
  return root;
}

/**
 * The avalanche: overlapping translucent puffs across the track, so it reads as a wave of powder
 * and never hard-blocks the view when it rolls over the camera.
 */
export function avalancheCloud(kit: Kit): THREE.Group {
  const root = new THREE.Group();
  const soft = pbr([0.94, 0.97, 1.0], { roughness: 0.95, alpha: 0.78 });
  const dense = pbr([0.85, 0.92, 1.0], { roughness: 0.95, alpha: 0.9 });
  const puffs = 11;
  for (let i = 0; i < puffs; i += 1) {
    const t = i / (puffs - 1);
    const radius = 1.7 + ((i * 5) % 4) * 0.45;
    const puff = part(kit, kit.geo.sphere(radius), i % 3 === 0 ? dense : soft);
    root.add(at(puff, (t - 0.5) * 15, radius * 0.9 + ((i * 7) % 3) * 0.5, ((i * 3) % 3) * 0.6 - 0.6));
  }
  return root;
}

export function lowBridge(kit: Kit, width: number): THREE.Group {
  const root = new THREE.Group();
  const wood = rgb(0.4, 0.26, 0.14);
  for (const sign of [-1, 1]) root.add(at(box(kit, 0.35, 1.8, 0.35, wood, 0.7), sign * (width * 0.28), 0.9, 0));
  root.add(at(box(kit, width * 0.7, 0.22, 0.4, wood, 0.7), 0, 1.7, 0));
  return root;
}

/** A pale streak where the wind blows. Two-sided, so the chase camera sees it coming. */
export function windWhisp(kit: Kit): THREE.Mesh {
  const node = part(kit, kit.geo.plane(6, 1.2), pbr(WHITE, { roughness: 0.8, alpha: 0.16, doubleSided: true }));
  node.position.y = 1.4;
  return node;
}

export function checkpointGate(kit: Kit, width: number): THREE.Group {
  const root = new THREE.Group();
  const pole = pbr([0.2, 0.7, 1.0], { roughness: 0.3, emissive: [0.1, 0.3, 0.5] });
  for (const sign of [-1, 1]) root.add(at(part(kit, kit.geo.cylinder(0.09, 2.4), pole), sign * (width * 0.42), 1.2, 0));
  return root;
}

export function shortcutGate(kit: Kit): THREE.Group {
  const root = new THREE.Group();
  const pole = pbr([0.15, 0.95, 0.72], { roughness: 0.25, emissive: [0.1, 0.45, 0.32] });
  for (const sign of [-1, 1]) root.add(at(part(kit, kit.geo.cylinder(0.1, 2.8), pole), sign * 1.4, 1.4, 0));
  root.add(at(box(kit, 3.1, 0.22, 0.18, [0.2, 1.0, 0.75], 0.25), 0, 2.7, 0));
  return root;
}

export function movingBridge(kit: Kit, width: number): THREE.Mesh {
  return at(box(kit, width * 0.55, 0.22, 2.8, [0.42, 0.28, 0.16], 0.7), 0, 0.2, 0);
}

export function geyser(kit: Kit): THREE.Group {
  const root = new THREE.Group();
  root.add(at(part(kit, kit.geo.cylinder(0.55, 0.28), pbr([0.55, 0.48, 0.38], { roughness: 0.8 })), 0, 0.12, 0));
  const steam = part(kit, kit.geo.cone(0.32, 1.6), pbr([0.92, 0.94, 0.96], { roughness: 0.4, alpha: 0.28 }));
  root.add(at(steam, 0, 1.0, 0));
  return root;
}

export function carnivalFloat(kit: Kit): THREE.Group {
  const root = new THREE.Group();
  root.add(at(box(kit, 2.4, 1.4, 1.6, [0.95, 0.28, 0.48], 0.45), 0, 1.0, 0));
  root.add(at(sphere(kit, 0.7, [1.0, 0.82, 0.25], 0.25), 0, 2.0, 0));
  return root;
}

export function neonArchway(kit: Kit, width: number): THREE.Group {
  const root = new THREE.Group();
  const pole = pbr([1.0, 0.2, 0.72], { roughness: 0.2, emissive: [0.6, 0.1, 0.4] });
  for (const sign of [-1, 1]) root.add(at(part(kit, kit.geo.cylinder(0.08, 3.4), pole), sign * (width * 0.38), 1.7, 0));
  root.add(at(box(kit, width * 0.82, 0.16, 0.16, [0.2, 0.95, 1.0], 0.15), 0, 3.4, 0));
  return root;
}

export function crystalSpire(kit: Kit, scale: number): THREE.Mesh {
  const node = part(
    kit,
    kit.geo.cone(0.38 * scale, 2.6 * scale),
    pbr([0.45, 0.85, 1.0], { roughness: 0.12, emissive: [0.12, 0.35, 0.55] }),
  );
  node.position.y = 1.3 * scale;
  return node;
}

export function finishGate(kit: Kit, width: number): THREE.Group {
  const root = checkpointGate(kit, width);
  const span = width * 0.86;
  const cols = 14;
  const cell = span / cols;
  const black = pbr([0.08, 0.09, 0.12], { roughness: 0.5 });
  const white = pbr([0.97, 0.97, 0.98], { roughness: 0.5 });
  const tileGeometry = kit.geo.box(cell, cell, 0.1);
  const top = 2.45 + cell * 2;
  for (const sign of [-1, 1]) {
    const post = part(kit, kit.geo.cylinder(0.12, top + 0.2), glow([1.0, 0.32, 0.45], 0.9));
    root.add(at(post, sign * (span / 2 + 0.12), (top + 0.2) / 2, 0));
  }
  for (let row = 0; row < 2; row += 1) {
    for (let col = 0; col < cols; col += 1) {
      const tile = part(kit, tileGeometry, (row + col) % 2 === 0 ? black : white);
      root.add(at(tile, -span / 2 + cell * (col + 0.5), 2.45 + row * cell, 0));
    }
  }
  return root;
}

/** Joins indexed geometries with position and normal only (no uv), for small fixed shapes. */
export function mergeSimple(geometries: THREE.BufferGeometry[]): THREE.BufferGeometry {
  const positions: number[] = [];
  const normals: number[] = [];
  const indices: number[] = [];
  for (const g of geometries) {
    const base = positions.length / 3;
    const pos = g.getAttribute('position');
    const nor = g.getAttribute('normal');
    for (let i = 0; i < pos.count; i += 1) {
      positions.push(pos.getX(i), pos.getY(i), pos.getZ(i));
      normals.push(nor.getX(i), nor.getY(i), nor.getZ(i));
    }
    const index = g.getIndex();
    if (index) for (let i = 0; i < index.count; i += 1) indices.push(base + index.getX(i));
    else for (let i = 0; i < pos.count; i += 1) indices.push(base + i);
  }
  const merged = new THREE.BufferGeometry();
  merged.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  merged.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
  merged.setIndex(indices);
  merged.computeBoundingSphere();
  return merged;
}
