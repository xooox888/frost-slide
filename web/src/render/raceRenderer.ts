/**
 * Draws a race with three.js. A port of `Reality/WorldController.swift`: after every engine tick
 * the game loop hands the engine to `frame`, which moves the scene to match it. The engine never
 * knows how it is drawn.
 *
 * Differences from Swift, all fixes: crystals float over the snow (Swift placed them at a fixed
 * world height, under the course), moving bridges move with their collision, and the scene
 * keeps rendering (without animating) while the race is paused, behind the pause menu.
 */
import * as THREE from 'three';
import type { RGB } from '../core/math';
import type { GameEngine } from '../engine/gameEngine';
import type { Racer } from '../engine/racer';
import type { TrackPath } from '../engine/trackPath';
import { IceTrail, SnowField, SnowSpray } from './effects';
import { AXIS_X, AXIS_Y, AXIS_Z, bananaPeel, quat } from './props';
import { RacerModels, type RacerRig } from './racerModel';
import { toColor } from './surfaces';
import {
  AMBIENT_DAY,
  AMBIENT_FLARE,
  AMBIENT_NIGHT,
  MOVING,
  PULSING,
  buildWorld,
  placeOnCourse,
  type World,
} from './world';

export interface RendererOptions {
  /** Reduce Motion: no camera shake, snowfall or spray. */
  reduceMotion: () => boolean;
}

interface LiveRig extends RacerRig {
  seed: number;
}

const GHOST_COLOR: RGB = [0.75, 0.88, 1.0];
const HIDDEN = new THREE.Matrix4().makeScale(0, 0, 0);

/** A small stable number per racer, for animation phase (Swift used the id's hash % 97). */
const seedOf = (id: string): number => {
  let h = 0;
  for (let i = 0; i < id.length; i += 1) h = (h * 31 + id.charCodeAt(i)) >>> 0;
  return h % 97;
};

export class RaceRenderer {
  private readonly renderer: THREE.WebGLRenderer;
  private readonly camera = new THREE.PerspectiveCamera(50, 1, 0.2, 420);
  private readonly idleScene = new THREE.Scene();
  private world: World | null = null;
  private models: RacerModels | null = null;
  private raceId = -1;
  private readonly rigs = new Map<string, LiveRig>();
  private readonly peels = new Map<string, THREE.Object3D>();
  private ghost: RacerRig | null = null;
  private trail: IceTrail | null = null;
  private spray: SnowSpray | null = null;
  private snow: SnowField | null = null;
  private playerLight: THREE.PointLight | null = null;
  private spinTime = 0;
  private trailTick = 0;
  private lastLanding = false;
  private readonly scratch = {
    q: new THREE.Quaternion(),
    m: new THREE.Matrix4(),
    v: new THREE.Vector3(),
    s: new THREE.Vector3(1, 1, 1),
  };

  // Resolution: capped at 2x, and lowered in steps while frames run long.
  private width = 1;
  private height = 1;
  private maxPixelRatio = 2;
  private pixelRatio = 2;
  private lastFrameAt = 0;
  private frameAverage = 1000 / 60;
  private framesSinceChange = 0;
  private raiseAttempts = 0;

  constructor(
    canvas: HTMLCanvasElement,
    private readonly options: RendererOptions,
  ) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    // Neutral tone mapping keeps the palettes' colours (ACES darkened and greyed the snow).
    this.renderer.toneMapping = THREE.NeutralToneMapping;
    this.renderer.toneMappingExposure = 1.0;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFShadowMap;
    this.idleScene.background = new THREE.Color(0.86, 0.92, 0.98);
  }

  /**
   * Moves the scene to the engine's state and draws. `advanced`: the engine ran this frame.
   * `draw` false only updates the scene (for fast-forwarding in the course viewer).
   */
  frame(engine: GameEngine, dt: number, advanced: boolean, draw = true): void {
    if (engine.raceId !== this.raceId) this.install(engine);
    const world = this.world;
    const path = engine.path;
    if (!world || !path) {
      this.renderer.render(this.idleScene, this.camera);
      return;
    }
    if (advanced) this.apply(engine, world, path, dt);
    if (!draw) return;
    this.placeCamera(engine, world, advanced);
    this.renderer.render(world.scene, this.camera);
    this.adaptResolution();
  }

  resize(width: number, height: number, pixelRatio: number): void {
    this.width = width;
    this.height = height;
    this.maxPixelRatio = pixelRatio;
    this.pixelRatio = Math.min(this.pixelRatio, pixelRatio) || pixelRatio;
    this.applySize();
  }

  dispose(): void {
    this.teardown();
    this.renderer.dispose();
    // Free the WebGL context now: every race opens a new one, and Safari caps how many live.
    this.renderer.forceContextLoss();
  }

  /** Draw calls and triangles in the last frame, and the current resolution scale. */
  get stats(): { calls: number; triangles: number; pixelRatio: number } {
    const { calls, triangles } = this.renderer.info.render;
    return { calls, triangles, pixelRatio: this.pixelRatio };
  }

  // MARK: - Building

  private install(engine: GameEngine): void {
    this.teardown();
    this.raceId = engine.raceId;
    const level = engine.level;
    const path = engine.path;
    if (!level || !path) return;
    const world = buildWorld(level, path, this.renderer.capabilities.getMaxAnisotropy());
    this.world = world;
    this.camera.far = world.far;
    this.camera.updateProjectionMatrix();
    const models = new RacerModels(world.kit);
    this.models = models;
    const reduceMotion = this.options.reduceMotion();

    for (const racer of engine.racers) {
      const rig = models.make(racer.sledColor);
      rig.root.name = racer.id;
      world.scene.add(rig.root);
      this.rigs.set(racer.id, { ...rig, seed: seedOf(racer.id) });
      if (racer.isPlayer) {
        // Only the player's sled lights the snow; Swift lit every sled, which a phone's web view
        // can't afford.
        const light = new THREE.PointLight(toColor(racer.sledColor), 6, 5, 2);
        light.position.set(0, 0.25, 0);
        rig.root.add(light);
        this.playerLight = light;
      }
    }

    this.trail = new IceTrail();
    world.scene.add(this.trail.object);
    this.spray = reduceMotion ? null : new SnowSpray();
    if (this.spray) world.scene.add(this.spray.object);
    this.snow = reduceMotion ? null : new SnowField(level.palette.night, true);
    if (this.snow) world.scene.add(this.snow.object, this.snow.burstObject);
    this.spinTime = 0;
    this.trailTick = 0;
    this.lastLanding = false;
    // Place everything once so the first frame (and a paused one) shows the grid, not the origin.
    this.apply(engine, world, path, 0);
  }

  private teardown(): void {
    this.trail?.dispose();
    this.spray?.dispose();
    this.snow?.dispose();
    this.models?.dispose();
    this.world?.dispose();
    this.trail = null;
    this.spray = null;
    this.snow = null;
    this.models = null;
    this.world = null;
    this.ghost = null;
    this.playerLight = null;
    this.rigs.clear();
    this.peels.clear();
  }

  // MARK: - Per frame

  private apply(engine: GameEngine, world: World, path: TrackPath, dt: number): void {
    this.spinTime += dt;
    const spin = this.spinTime;
    const { q, m, s } = this.scratch;

    for (const racer of engine.racers) {
      const rig = this.rigs.get(racer.id);
      if (rig) this.poseRacer(rig, racer, path, spin);
    }

    for (const live of engine.entities) {
      const def = live.definition;
      if (def.kind === 'crystal') {
        const index = world.crystalIndex.get(def.id);
        if (index === undefined || !world.crystals) continue;
        if (live.collected || live.destroyed) {
          world.crystals.setMatrixAt(index, HIDDEN);
          continue;
        }
        const bob = Math.sin(spin * 3 + live.phase) * 0.12;
        const p = path.worldPosition(def.progress, live.liveLateral, 0.58 + bob);
        q.setFromAxisAngle(AXIS_Y, spin * 2.2);
        world.crystals.setMatrixAt(index, m.compose(this.scratch.v.set(p.x, p.y, p.z), q, s.set(1, 1, 1)));
        continue;
      }
      const node = world.dynamic.get(def.id);
      if (!node) continue;
      node.visible = !(live.collected || live.destroyed);
      if (!node.visible) continue;
      if (MOVING.has(def.kind)) placeOnCourse(node, def, path, live.liveLateral);
      if (PULSING.has(def.kind)) node.children[0]?.scale.setScalar(1 + Math.sin(spin * 5) * 0.08);
    }
    if (world.crystals) world.crystals.instanceMatrix.needsUpdate = true;

    this.syncPeels(engine, world, path);
    this.syncGhost(engine, world, path);
    this.syncAvalanche(engine, world, path, spin);

    const player = engine.playerRacer;
    if (player) {
      const pos = path.worldPosition(player.progress, player.lateral, 0);
      this.trailTick += dt;
      if (this.trailTick > 0.035 && !player.airborne) {
        const length = Math.max(0.7, player.speed * this.trailTick * 1.15);
        this.trailTick = 0;
        const intense = player.trailBoost > 0 || player.rocketTime > 0 || engine.combo >= 3;
        this.trail?.push(pos, player.yaw, length, intense);
      }
      const sample = path.sample(player.progress);
      let sprayRate = 0;
      if (!player.airborne && engine.phase === 'racing') {
        sprayRate = Math.max(0, player.speed - 12) * 1.5 + Math.abs(player.lateralVel) * 5;
        if (player.trailBoost > 0 || player.rocketTime > 0) sprayRate += 26;
      }
      this.spray?.tick(dt, pos, sample.tangent, sample.binormal, sprayRate);
      this.snow?.tick(dt, engine.cameraEye);
      if (engine.landingPulse > 0.7 && !this.lastLanding) {
        this.snow?.burst(pos);
        this.lastLanding = true;
      }
      if (engine.landingPulse < 0.15) this.lastLanding = false;
      if (this.playerLight) {
        const lumens = 280 + player.trailBoost * 700 + player.rocketTime * 400 + player.flareTime * 80;
        this.playerLight.intensity = lumens / 70;
        this.playerLight.distance = player.flareTime > 0 ? 14 : 5;
      }
    }

    // Night courses brighten while a flare burns (Swift raised the image-based light).
    const night = engine.level?.palette.night === true;
    const flare = (player?.flareTime ?? 0) > 0;
    world.ambient.intensity = night ? (flare ? AMBIENT_FLARE : AMBIENT_NIGHT) : AMBIENT_DAY;
  }

  private poseRacer(rig: LiveRig, racer: Racer, path: TrackPath, spin: number): void {
    const pos = path.worldPosition(racer.progress, racer.lateral, racer.height);
    rig.root.position.set(pos.x, pos.y, pos.z);
    const bank = path.sample(racer.progress).bank;
    // The sled lies on the banked surface; its own lean is added on top.
    rig.root.quaternion
      .setFromAxisAngle(AXIS_Y, racer.yaw)
      .multiply(quat(AXIS_X, racer.pitch))
      .multiply(quat(AXIS_Z, racer.roll + bank));
    rig.root.scale.set(1, racer.squash, 1);
    rig.shroud.visible = racer.ghostTime > 0;
    // Arms flap hard on boost and in the air, and sway gently otherwise. The scarf flutters with
    // speed, and the big tail wags along (faster while flapping).
    const seed = rig.seed;
    const flapping = racer.trailBoost > 0 || racer.airborne || racer.rocketTime > 0;
    const flap = flapping ? Math.sin(spin * 22 + seed) * 0.55 : Math.sin(spin * 3 + seed) * 0.06;
    rig.flipL.quaternion.setFromAxisAngle(AXIS_Z, -0.85 - flap);
    rig.flipR.quaternion.setFromAxisAngle(AXIS_Z, 0.85 + flap);
    const flutter = Math.sin(spin * 15 + seed) * Math.min(1, racer.speed / 16) * 0.4;
    rig.scarfTail.quaternion.setFromAxisAngle(AXIS_Y, flutter).multiply(quat(AXIS_X, 0.25));
    const wag = flapping ? Math.sin(spin * 9 + seed) * 0.3 : Math.sin(spin * 3.2 + seed) * 0.12;
    rig.fluffTail.quaternion.setFromAxisAngle(AXIS_Y, wag + flutter * 0.4);
  }

  private syncPeels(engine: GameEngine, world: World, path: TrackPath): void {
    const live = new Set(engine.droppedBananas.map((p) => p.id));
    for (const [id, node] of this.peels) {
      if (!live.has(id)) {
        world.scene.remove(node);
        this.peels.delete(id);
      }
    }
    for (const peel of engine.droppedBananas) {
      let node = this.peels.get(peel.id);
      if (!node) {
        node = bananaPeel(world.kit);
        node.name = peel.id;
        world.scene.add(node);
        this.peels.set(peel.id, node);
      }
      const p = path.worldPosition(peel.progress, peel.lateral, 0);
      node.position.set(p.x, p.y, p.z);
    }
  }

  private syncGhost(engine: GameEngine, world: World, path: TrackPath): void {
    const pose = engine.ghostPose;
    if (!pose) {
      if (this.ghost) this.ghost.root.visible = false;
      return;
    }
    if (!this.ghost && this.models) {
      this.ghost = this.models.make(GHOST_COLOR);
      this.ghost.root.name = 'bestGhost';
      this.ghost.shroud.visible = true;
      world.scene.add(this.ghost.root);
    }
    if (!this.ghost) return;
    this.ghost.root.visible = true;
    const p = path.worldPosition(pose.progress, pose.lateral, pose.height);
    this.ghost.root.position.set(p.x, p.y, p.z);
    // Face down the track like every other sled.
    const sample = path.sample(pose.progress);
    this.ghost.root.quaternion
      .setFromAxisAngle(AXIS_Y, sample.heading)
      .multiply(quat(AXIS_X, sample.slope * 0.4))
      .multiply(quat(AXIS_Z, sample.bank));
  }

  private syncAvalanche(engine: GameEngine, world: World, path: TrackPath, spin: number): void {
    const wall = world.avalanche;
    if (!wall) return;
    wall.visible = engine.avalancheThreat;
    if (!engine.avalancheThreat) return;
    // Square across the track at the wall's current position, billowing a little.
    const sample = path.sample(engine.avalancheFront);
    const p = path.worldPosition(engine.avalancheFront, 0, 0);
    wall.position.set(p.x, p.y, p.z);
    wall.quaternion.setFromAxisAngle(AXIS_Y, sample.heading).multiply(quat(AXIS_Z, sample.bank));
    wall.scale.set(1, 1 + Math.sin(spin * 5) * 0.05, 1);
  }

  private placeCamera(engine: GameEngine, world: World, advanced: boolean): void {
    // Screen shake is motion the player asked us not to add, when Reduce Motion is on.
    const shake = advanced && !this.options.reduceMotion() ? engine.cameraShake * 0.16 + engine.landingPulse * 0.06 : 0;
    const jx = shake > 0.001 ? (Math.random() * 2 - 1) * shake : 0;
    const jy = shake > 0.001 ? (Math.random() * 2 - 1) * shake : 0;
    const eye = engine.cameraEye;
    const look = engine.cameraLook;
    this.camera.position.set(eye.x + jx, eye.y + jy, eye.z);
    this.camera.lookAt(look.x + jx * 0.5, look.y + jy * 0.5, look.z);
    if (this.camera.fov !== engine.cameraFOV) {
      this.camera.fov = engine.cameraFOV;
      this.camera.updateProjectionMatrix();
    }
    // The sun follows the view so its shadow map covers what the camera sees.
    world.sun.target.position.set(look.x, look.y, look.z);
    world.sun.position.set(look.x, look.y, look.z).add(world.sunOffset);
  }

  // MARK: - Resolution

  private applySize(): void {
    this.renderer.setPixelRatio(this.pixelRatio);
    this.renderer.setSize(this.width, this.height, false);
    this.camera.aspect = this.width / Math.max(1, this.height);
    this.camera.updateProjectionMatrix();
  }

  /**
   * Drops the resolution a quarter step at a time while frames take longer than a 60 Hz budget
   * allows, down to 1x; tries one step back up after a long smooth stretch.
   */
  private adaptResolution(): void {
    const now = performance.now();
    const interval = this.lastFrameAt === 0 ? 1000 / 60 : now - this.lastFrameAt;
    this.lastFrameAt = now;
    if (interval <= 0 || interval > 250) return;
    this.frameAverage = this.frameAverage * 0.94 + interval * 0.06;
    this.framesSinceChange += 1;
    if (this.framesSinceChange < 90) return;
    if (this.frameAverage > 19.5 && this.pixelRatio > 1) {
      this.pixelRatio = Math.max(1, this.pixelRatio - 0.25);
      this.framesSinceChange = 0;
      this.applySize();
    } else if (
      this.frameAverage < 17.4 &&
      this.pixelRatio < this.maxPixelRatio &&
      this.framesSinceChange > 600 &&
      this.raiseAttempts < 2
    ) {
      this.raiseAttempts += 1;
      this.pixelRatio = Math.min(this.maxPixelRatio, this.pixelRatio + 0.25);
      this.framesSinceChange = 0;
      this.applySize();
    }
  }
}
