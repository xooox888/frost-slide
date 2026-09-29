/**
 * Builds a course's scene: lights, sky, fog, the track ribbon, snow banks and every prop. A port
 * of `Reality/WorldFactory.build` and friends.
 *
 * Props that never change are baked into merged meshes, one pair (opaque and see-through) per
 * stretch of about 60 m of course, so a whole course draws in a few dozen calls and stretches
 * outside the view are skipped. Props the race changes (pickups, smashable and moving obstacles)
 * stay separate so they can move or disappear.
 */
import * as THREE from 'three';
import { seededRandom } from '../core/math';
import type { LevelDefinition, PlacedEntity, PropKind } from '../core/models';
import { Tuning } from '../engine/gameEngine';
import type { TrackPath } from '../engine/trackPath';
import { bakeGeometry } from './bake';
import { GeometryCache, ribbon, waterBand } from './geometries';
import { MaterialCache, bakedMaterial } from './materials';
import * as P from './props';
import { mix, mul, pbr, toColor } from './surfaces';
import { auroraTexture, glowSpriteTexture, skyTexture, trackTexture, windTexture } from './textures';

/** Track furniture wide enough that the banking would show if it stayed level. */
const FOLLOWS_BANK = new Set<PropKind>([
  'arch',
  'ramp',
  'turboPad',
  'icePatch',
  'checkpoint',
  'finish',
  'startBanner',
  'shortcut',
  'neonArch',
  'movingBridge',
  'bridge',
  'dock',
]);

/** Props the race changes: picked up, smashed or moving. */
const DYNAMIC = new Set<PropKind>([
  'crystal',
  'rocket',
  'magnet',
  'ghost',
  'banana',
  'flare',
  'crate',
  'snowman',
  'cart',
  'npc',
  'movingBridge',
]);

export const PULSING = new Set<PropKind>(['rocket', 'magnet', 'ghost', 'banana']);
export const MOVING = new Set<PropKind>(['cart', 'npc', 'movingBridge']);

const CHUNK_METRES = 60;

/** Hemisphere light strength, standing in for RealityKit's image-based light. */
export const AMBIENT_DAY = 1.5;
export const AMBIENT_NIGHT = 0.6;
export const AMBIENT_FLARE = 1.2;

export interface World {
  scene: THREE.Scene;
  sun: THREE.DirectionalLight;
  fill: THREE.DirectionalLight | null;
  ambient: THREE.HemisphereLight;
  /** Sun position relative to the point it lights (it follows the player for shadows). */
  sunOffset: THREE.Vector3;
  /** Race-changed props by entity id: the anchor on the course (position and heading). */
  dynamic: Map<string, THREE.Object3D>;
  /** One instance per crystal, by entity id. */
  crystals: THREE.InstancedMesh | null;
  crystalIndex: Map<string, number>;
  avalanche: THREE.Object3D | null;
  kit: P.Kit;
  /** Visible depth: the camera's far plane. */
  far: number;
  dispose(): void;
}

export function buildWorld(level: LevelDefinition, path: TrackPath, maxAnisotropy: number): World {
  const pal = level.palette;
  const geo = new GeometryCache();
  const mat = new MaterialCache();
  const kit: P.Kit = { geo, mat, random: seededRandom(0xb1d + level.entities.length * 31 + Math.round(level.length)) };
  const scene = new THREE.Scene();
  const disposables: { dispose(): void }[] = [geo, mat];

  // Sky and fog. RealityKit had no fog; the palettes carry the range the original SceneKit
  // version used, stretched a little so the next turns stay readable at full speed.
  const sky = skyTexture(pal);
  disposables.push(sky);
  scene.background = sky;
  const fogStart = pal.fogStart * 1.2;
  const fogEnd = pal.fogEnd * 1.3;
  scene.fog = new THREE.Fog(toColor(pal.fog), fogStart, fogEnd);

  // Lights. Swift: sun at sunIntensity × 8 lux from (24, 48, 18), a coloured fill at night, and
  // RealityKit's image-based light, which a hemisphere light stands in for here.
  const sun = new THREE.DirectionalLight(toColor(pal.sunColor), pal.sunIntensity / 260);
  const sunOffset = new THREE.Vector3(24, 48, 18);
  sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024);
  const shadow = sun.shadow.camera;
  shadow.left = -22;
  shadow.right = 22;
  shadow.top = 22;
  shadow.bottom = -22;
  shadow.near = 1;
  shadow.far = 140;
  sun.shadow.bias = -0.0008;
  sun.shadow.normalBias = 0.04;
  scene.add(sun, sun.target);
  let fill: THREE.DirectionalLight | null = null;
  if (pal.night) {
    fill = new THREE.DirectionalLight(toColor(pal.accent), 0.7);
    fill.position.set(-16, 22, 10);
    scene.add(fill, fill.target);
  }
  const ambient = new THREE.HemisphereLight(
    toColor(mix(pal.ambient, pal.skyTop, 0.3)),
    toColor(mul(mix(pal.snow, pal.ice, 0.3), 0.7)),
    pal.night ? AMBIENT_NIGHT : AMBIENT_DAY,
  );
  scene.add(ambient);

  // The track.
  const track = trackTexture(pal, maxAnisotropy);
  disposables.push(track);
  const groundMaterial = new THREE.MeshStandardMaterial({
    map: track,
    roughness: 0.78,
    metalness: 0.04,
    side: THREE.DoubleSide,
  });
  const groundGeometry = ribbon(path);
  disposables.push(groundMaterial, groundGeometry);
  const ground = new THREE.Mesh(groundGeometry, groundMaterial);
  ground.name = 'trackSurface';
  ground.receiveShadow = true;
  scene.add(ground);

  if (level.theme === 'harbor') {
    const waterGeometry = waterBand(path, 2.6, 40);
    const water = new THREE.Mesh(waterGeometry, mat.get(pbr([0.12, 0.28, 0.4], { roughness: 0.12 })));
    disposables.push(waterGeometry);
    scene.add(water);
  }

  addBanks(scene, level, path, geo, mat);

  // Props: static ones collected per stretch for baking, the rest kept live.
  const opaqueMaterial = bakedMaterial(false);
  const transparentMaterial = bakedMaterial(true);
  disposables.push(opaqueMaterial, transparentMaterial);
  const dynamic = new Map<string, THREE.Object3D>();
  const chunkCount = Math.max(1, Math.ceil(level.length / CHUNK_METRES));
  const chunks = Array.from({ length: chunkCount }, () => new THREE.Group());
  const lanternSpots: THREE.Vector3[] = [];
  const crystalDefs: PlacedEntity[] = [];
  const veils: Record<'auroraRibbon' | 'wind', THREE.Matrix4[]> = { auroraRibbon: [], wind: [] };
  for (const entity of level.entities) {
    if (entity.kind === 'crystal') {
      crystalDefs.push(entity);
      continue;
    }
    const node = makeProp(kit, entity, level, path);
    if (!node) continue;
    if (entity.kind === 'auroraRibbon' || entity.kind === 'wind') {
      // Textured, so drawn apart from the baked scenery (see addVeils).
      node.updateMatrixWorld(true);
      veils[entity.kind].push(node.children[0].matrixWorld.clone());
      continue;
    }
    if (DYNAMIC.has(entity.kind)) {
      // One mesh per prop (two if part of it is see-through) instead of one per part.
      const prop = node.children[0];
      const baked = bakeProp(prop, opaqueMaterial, transparentMaterial, disposables);
      node.remove(prop);
      node.add(baked);
      node.name = entity.id;
      scene.add(node);
      dynamic.set(entity.id, node);
    } else {
      const chunk = Math.min(chunkCount - 1, Math.floor(entity.progress * chunkCount));
      chunks[chunk].add(node);
    }
  }

  for (const chunk of chunks) {
    chunk.updateMatrixWorld(true);
    chunk.traverse((node) => {
      if (node.userData.lanternGlow) lanternSpots.push(node.getWorldPosition(new THREE.Vector3()));
    });
    const baked = bakeGeometry(chunk);
    if (baked.opaque) {
      const mesh = new THREE.Mesh(baked.opaque, opaqueMaterial);
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      scene.add(mesh);
      disposables.push(baked.opaque);
    }
    if (baked.transparent) {
      scene.add(new THREE.Mesh(baked.transparent, transparentMaterial));
      disposables.push(baked.transparent);
    }
  }

  if (lanternSpots.length > 0) addLanternGlow(scene, lanternSpots, path, disposables);
  addVeils(scene, veils, disposables);

  // Crystals: one instanced mesh, placed every frame by the renderer.
  let crystals: THREE.InstancedMesh | null = null;
  const crystalIndex = new Map<string, number>();
  if (crystalDefs.length > 0) {
    const gem = P.crystalGeometry();
    disposables.push(gem);
    crystals = new THREE.InstancedMesh(gem, mat.get(P.CRYSTAL_SURFACE), crystalDefs.length);
    crystals.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    crystals.frustumCulled = false;
    crystalDefs.forEach((entity, i) => crystalIndex.set(entity.id, i));
    scene.add(crystals);
  }

  let avalanche: THREE.Object3D | null = null;
  if (level.events.some((e) => e.kind === 'avalanche')) {
    avalanche = P.avalancheCloud(kit);
    avalanche.name = 'avalanche';
    avalanche.visible = false;
    scene.add(avalanche);
  }

  return {
    scene,
    sun,
    fill,
    ambient,
    sunOffset,
    dynamic,
    crystals,
    crystalIndex,
    avalanche,
    kit,
    far: Math.max(140, fogEnd + 40),
    dispose() {
      for (const d of disposables) d.dispose();
    },
  };
}

/** A prop's parts merged into one or two meshes, keeping the prop root's own transform. */
function bakeProp(
  prop: THREE.Object3D,
  opaqueMaterial: THREE.Material,
  transparentMaterial: THREE.Material,
  disposables: { dispose(): void }[],
): THREE.Object3D {
  const group = new THREE.Group();
  group.position.copy(prop.position);
  group.quaternion.copy(prop.quaternion);
  group.scale.copy(prop.scale);
  const saved = { position: prop.position.clone(), quaternion: prop.quaternion.clone(), scale: prop.scale.clone() };
  // Bake in the prop's own frame: its transform moves to the group.
  prop.position.set(0, 0, 0);
  prop.quaternion.identity();
  prop.scale.set(1, 1, 1);
  const parent = prop.parent;
  parent?.remove(prop);
  const baked = bakeGeometry(prop);
  prop.position.copy(saved.position);
  prop.quaternion.copy(saved.quaternion);
  prop.scale.copy(saved.scale);
  if (baked.opaque) {
    const mesh = new THREE.Mesh(baked.opaque, opaqueMaterial);
    mesh.castShadow = true;
    group.add(mesh);
    disposables.push(baked.opaque);
  }
  if (baked.transparent) {
    group.add(new THREE.Mesh(baked.transparent, transparentMaterial));
    disposables.push(baked.transparent);
  }
  return group;
}

/** Soft drifts with a cool shadow tint so the white track keeps a readable edge. */
function addBanks(scene: THREE.Scene, level: LevelDefinition, path: TrackPath, geo: GeometryCache, mat: MaterialCache) {
  const samples = path.samples;
  const step = Math.max(1, Math.floor(samples.length / 110));
  const drift = mat.get(pbr(mix(level.palette.snow, level.palette.ice, 0.18), { roughness: 0.92 }));
  const deep = mat.get(pbr(mix(level.palette.snow, level.palette.ice, 0.38), { roughness: 0.92 }));
  const matrices: [THREE.Matrix4[], THREE.Matrix4[]] = [[], []];
  const q = new THREE.Quaternion();
  const position = new THREE.Vector3();
  const scale = new THREE.Vector3();
  let flip = false;
  for (let i = 0; i < samples.length; i += step) {
    const s = samples[i];
    flip = !flip;
    for (const sign of [-1, 1]) {
      // Sit outside the track edge so the glowing rails stay visible.
      const out = sign * (s.width * 0.5 + 2.9);
      position.set(
        s.position.x + s.binormal.x * out + s.normal.x * 0.1,
        s.position.y + s.binormal.y * out + s.normal.y * 0.1,
        s.position.z + s.binormal.z * out + s.normal.z * 0.1,
      );
      const wobble = ((i * 7919) % 13) / 13;
      scale.set(2.2 + wobble * 0.8, 0.75 + wobble * 0.45, 2.4);
      q.setFromAxisAngle(P.AXIS_Y, s.heading);
      matrices[flip ? 0 : 1].push(new THREE.Matrix4().compose(position, q, scale));
    }
  }
  // Two hundred drifts: a coarse sphere is plenty for a soft mound.
  const sphere = geo.sphereDetail(1, 14, 9);
  [drift, deep].forEach((material, k) => {
    const list = matrices[k];
    if (list.length === 0) return;
    const mesh = new THREE.InstancedMesh(sphere, material, list.length);
    list.forEach((m, i) => mesh.setMatrixAt(i, m));
    mesh.receiveShadow = true;
    mesh.computeBoundingSphere();
    scene.add(mesh);
  });
}

/**
 * Night lanterns: a halo round each bulb and a warm pool of light on the snow below it, standing
 * in for the point light Swift hung in every lantern.
 */
function addLanternGlow(
  scene: THREE.Scene,
  spots: THREE.Vector3[],
  path: TrackPath,
  disposables: { dispose(): void }[],
): void {
  const texture = glowSpriteTexture();
  const warm = toColor([1, 0.82, 0.5]);
  const halo = new THREE.PointsMaterial({
    map: texture,
    color: warm,
    size: 2.6,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
  });
  const haloGeometry = new THREE.BufferGeometry().setFromPoints(spots);
  scene.add(new THREE.Points(haloGeometry, halo));

  const pool = new THREE.MeshBasicMaterial({
    map: texture,
    color: warm.clone().multiplyScalar(0.55),
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    polygonOffset: true,
    polygonOffsetFactor: -2,
  });
  const quad = new THREE.PlaneGeometry(9, 9).rotateX(-Math.PI / 2);
  const pools = new THREE.InstancedMesh(quad, pool, spots.length);
  const matrix = new THREE.Matrix4();
  spots.forEach((spot, i) => {
    // Drop the pool onto the snow: find the nearest course sample's height.
    const ground = nearestSurfaceY(path, spot);
    matrix.makeTranslation(spot.x, ground + 0.16, spot.z);
    pools.setMatrixAt(i, matrix);
  });
  pools.computeBoundingSphere();
  scene.add(pools);
  disposables.push(texture, halo, haloGeometry, pool, quad);
}

/** Aurora curtains and wind gusts: soft textured planes, one instanced mesh per kind. */
function addVeils(
  scene: THREE.Scene,
  veils: Record<'auroraRibbon' | 'wind', THREE.Matrix4[]>,
  disposables: { dispose(): void }[],
): void {
  const kinds = [
    {
      matrices: veils.auroraRibbon,
      geometry: new THREE.PlaneGeometry(18, 5),
      // Additive light in the sky; fog would turn distant curtains into grey panels.
      material: new THREE.MeshBasicMaterial({
        map: auroraTexture(),
        transparent: true,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
        side: THREE.DoubleSide,
        fog: false,
      }),
    },
    {
      matrices: veils.wind,
      geometry: new THREE.PlaneGeometry(6, 1.2),
      material: new THREE.MeshBasicMaterial({
        map: windTexture(),
        transparent: true,
        opacity: 0.8,
        depthWrite: false,
        side: THREE.DoubleSide,
      }),
    },
  ];
  for (const { matrices, geometry, material } of kinds) {
    disposables.push(geometry, material, material.map!);
    if (matrices.length === 0) continue;
    const mesh = new THREE.InstancedMesh(geometry, material, matrices.length);
    matrices.forEach((m, i) => mesh.setMatrixAt(i, m));
    mesh.computeBoundingSphere();
    scene.add(mesh);
  }
}

function nearestSurfaceY(path: TrackPath, point: THREE.Vector3): number {
  let best = Infinity;
  let y = point.y - 2.6;
  for (const s of path.samples) {
    const d = (s.position.x - point.x) ** 2 + (s.position.z - point.z) ** 2;
    if (d < best) {
      best = d;
      y = s.position.y;
    }
  }
  return y;
}

/** `WorldFactory.makeProp`: builds a prop and sets its anchor on the course. */
function makeProp(kit: P.Kit, entity: PlacedEntity, level: LevelDefinition, path: TrackPath): THREE.Object3D | null {
  const sample = path.sample(entity.progress);
  const width = sample.width;
  let node: THREE.Object3D;
  switch (entity.kind) {
    case 'building':
      node = P.building(kit, level.palette, entity.scale);
      break;
    case 'arch':
      node = P.archway(kit);
      break;
    case 'stall':
      node = P.stall(kit);
      break;
    case 'crateStack':
    case 'crate':
      node = P.crate(kit, entity.scale);
      break;
    case 'pine':
      node = P.pine(kit, entity.scale);
      break;
    case 'dock':
      node = P.dockPlank(kit, width);
      break;
    case 'boat':
      node = P.boat(kit);
      break;
    case 'icicle':
      node = P.icicle(kit, entity.scale);
      break;
    case 'auroraRibbon':
      node = P.auroraRibbon(kit);
      break;
    case 'lantern':
    case 'lamp':
      node = P.lantern(kit, level.palette.night);
      break;
    case 'chimney':
      node = P.chimney(kit);
      break;
    case 'barrel':
      node = P.barrel(kit);
      break;
    case 'snowman':
      node = P.snowman(kit);
      break;
    case 'icePatch':
      node = P.icePatch(kit, entity.radius, Tuning.icePatchStretch);
      break;
    case 'cart':
      node = P.cart(kit);
      break;
    case 'bridge':
      node = P.lowBridge(kit, width);
      break;
    case 'stalactite':
      node = P.stalactite(kit);
      break;
    case 'wind':
      node = P.windWhisp(kit);
      break;
    case 'npc':
      node = P.marketNPC(kit);
      break;
    case 'turboPad':
      node = P.turboPad(kit);
      break;
    case 'ramp':
      node = P.boostRamp(kit);
      break;
    case 'rocket':
    case 'magnet':
    case 'ghost':
    case 'banana':
    case 'flare':
      node = P.powerOrb(kit, P.POWER_COLORS[entity.kind]);
      break;
    case 'checkpoint':
      node = P.checkpointGate(kit, width);
      break;
    case 'finish':
    case 'startBanner':
      node = P.finishGate(kit, width);
      break;
    case 'shortcut':
      node = P.shortcutGate(kit);
      break;
    case 'movingBridge':
      node = P.movingBridge(kit, width);
      break;
    case 'geyser':
      node = P.geyser(kit);
      break;
    case 'carnivalFloat':
      node = P.carnivalFloat(kit);
      break;
    case 'neonArch':
      node = P.neonArchway(kit, width);
      break;
    case 'crystalSpire':
      node = P.crystalSpire(kit, entity.scale);
      break;
    case 'water':
    case 'avalanche':
    case 'crystal':
      return null;
  }
  const anchor = new THREE.Group();
  anchor.add(node);
  placeOnCourse(anchor, entity, path);
  if (entity.scale !== 1 && entity.kind !== 'building' && entity.kind !== 'pine' && entity.kind !== 'crate') {
    anchor.scale.setScalar(entity.scale);
  }
  return anchor;
}

/** Position and heading on the course; wide props also lean with the banking. */
export function placeOnCourse(anchor: THREE.Object3D, entity: PlacedEntity, path: TrackPath, lateral = entity.lateral) {
  const sample = path.sample(entity.progress);
  const pos = path.worldPosition(entity.progress, lateral, 0);
  anchor.position.set(pos.x, pos.y, pos.z);
  anchor.quaternion.setFromAxisAngle(P.AXIS_Y, sample.heading + entity.yaw);
  if (FOLLOWS_BANK.has(entity.kind)) anchor.quaternion.multiply(P.quat(P.AXIS_Z, sample.bank));
}
