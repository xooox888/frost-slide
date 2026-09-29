/**
 * Snow and ice effects: the glowing trail the player's sled carves, snow sprayed while carving,
 * falling snow around the camera and puffs where the sled lands. A port of
 * `Reality/EffectsFactory.swift` with the same numbers; each effect is one instanced mesh here
 * instead of dozens of entities. The Swift random calls are seeded.
 */
import * as THREE from 'three';
import { seededRandom, type Vec3 } from '../core/math';
import { AXIS_Y } from './props';
import { toColor } from './surfaces';

const HIDDEN = new THREE.Matrix4().makeScale(0, 0, 0);
const scratch = {
  position: new THREE.Vector3(),
  quaternion: new THREE.Quaternion(),
  scale: new THREE.Vector3(),
  matrix: new THREE.Matrix4(),
};

function instanced(geometry: THREE.BufferGeometry, material: THREE.Material, count: number): THREE.InstancedMesh {
  const mesh = new THREE.InstancedMesh(geometry, material, count);
  mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
  for (let i = 0; i < count; i += 1) mesh.setMatrixAt(i, HIDDEN);
  // Instances move far from the geometry's own bounds; skip culling rather than recompute.
  mesh.frustumCulled = false;
  return mesh;
}

function translucent(color: [number, number, number], opacity: number): THREE.MeshBasicMaterial {
  return new THREE.MeshBasicMaterial({ color: toColor(color), transparent: true, opacity, depthWrite: false });
}

interface Stamp {
  position: THREE.Vector3;
  yaw: number;
  length: number;
  hot: boolean;
}

/** Glowing cyan streak the player's sled carves into the snow. */
export class IceTrail {
  readonly object = new THREE.Group();
  private static readonly MAX = 70;
  private readonly stamps: Stamp[] = [];
  private readonly soft: THREE.InstancedMesh;
  private readonly hot: THREE.InstancedMesh;
  private readonly geometry = new THREE.BoxGeometry(0.5, 0.012, 1);

  constructor() {
    // Swift: soft (0.35, 0.75, 1) at 35% with a blue glow, hot (0.3, 0.85, 1) at 50%. Unlit here,
    // so the stripe keeps its colour on bright snow.
    this.soft = instanced(this.geometry, translucent([0.4, 0.8, 1.0], 0.38), IceTrail.MAX);
    this.hot = instanced(this.geometry, translucent([0.35, 0.88, 1.0], 0.55), IceTrail.MAX);
    this.object.add(this.soft, this.hot);
  }

  /** `length` should cover the distance travelled since the last stamp so the streak stays continuous. */
  push(position: Vec3, yaw: number, length: number, intense: boolean): void {
    this.stamps.push({
      position: new THREE.Vector3(position.x, position.y + 0.03, position.z),
      yaw,
      length,
      hot: intense,
    });
    if (this.stamps.length > IceTrail.MAX) this.stamps.shift();
    let soft = 0;
    let hot = 0;
    this.stamps.forEach((stamp, index) => {
      const fade = (index + 1) / this.stamps.length;
      scratch.quaternion.setFromAxisAngle(AXIS_Y, stamp.yaw);
      scratch.scale.set(fade * (intense ? 1.25 : 1), 1, stamp.length);
      scratch.matrix.compose(stamp.position, scratch.quaternion, scratch.scale);
      if (stamp.hot) this.hot.setMatrixAt(hot++, scratch.matrix);
      else this.soft.setMatrixAt(soft++, scratch.matrix);
    });
    this.soft.count = soft;
    this.hot.count = hot;
    this.soft.instanceMatrix.needsUpdate = true;
    this.hot.instanceMatrix.needsUpdate = true;
  }

  clear(): void {
    this.stamps.length = 0;
    this.soft.count = 0;
    this.hot.count = 0;
  }

  dispose(): void {
    this.geometry.dispose();
    (this.soft.material as THREE.Material).dispose();
    (this.hot.material as THREE.Material).dispose();
  }
}

/** Pooled snow puffs kicked up behind the player's sled while carving or boosting. */
export class SnowSpray {
  readonly object: THREE.InstancedMesh;
  private static readonly COUNT = 44;
  private static readonly LIFETIME = 0.5;
  private readonly positions = Array.from({ length: SnowSpray.COUNT }, () => new THREE.Vector3());
  private readonly velocities = Array.from({ length: SnowSpray.COUNT }, () => new THREE.Vector3());
  private readonly life = new Float32Array(SnowSpray.COUNT);
  private next = 0;
  private budget = 0;
  private readonly random = seededRandom(0x5b7a);
  private readonly geometry = new THREE.SphereGeometry(0.09, 8, 6);

  constructor() {
    const material = new THREE.MeshStandardMaterial({
      color: toColor([0.95, 0.97, 1.0]),
      roughness: 0.9,
      transparent: true,
      opacity: 0.6,
      depthWrite: false,
    });
    this.object = instanced(this.geometry, material, SnowSpray.COUNT);
  }

  /** `rate` is puffs per second; 0 lets the live puffs finish without spawning more. */
  tick(dt: number, at: Vec3, forward: Vec3, side: Vec3, rate: number): void {
    const r = this.random;
    this.budget += rate * dt;
    while (this.budget >= 1) {
      this.budget -= 1;
      const i = this.next;
      this.next = (this.next + 1) % SnowSpray.COUNT;
      const s = r() < 0.5 ? 1 : -1;
      this.positions[i].set(
        at.x + side.x * s * 0.5 - forward.x * 0.4,
        at.y + side.y * s * 0.5 - forward.y * 0.4 + 0.12,
        at.z + side.z * s * 0.5 - forward.z * 0.4,
      );
      const back = 2 + r() * 2;
      const out = 1 + r() * 1.6;
      const up = 1.4 + r() * 1.6;
      this.velocities[i].set(
        -forward.x * back + side.x * s * out,
        -forward.y * back + side.y * s * out + up,
        -forward.z * back + side.z * s * out,
      );
      this.life[i] = SnowSpray.LIFETIME;
    }
    let changed = false;
    for (let i = 0; i < SnowSpray.COUNT; i += 1) {
      if (this.life[i] <= 0) continue;
      changed = true;
      this.life[i] -= dt;
      this.velocities[i].y -= 9 * dt;
      this.positions[i].addScaledVector(this.velocities[i], dt);
      const k = Math.max(0, this.life[i] / SnowSpray.LIFETIME);
      if (this.life[i] <= 0) {
        this.object.setMatrixAt(i, HIDDEN);
      } else {
        scratch.scale.setScalar((0.5 + (1 - k) * 1.3) * k);
        scratch.matrix.compose(this.positions[i], scratch.quaternion.identity(), scratch.scale);
        this.object.setMatrixAt(i, scratch.matrix);
      }
    }
    if (changed) this.object.instanceMatrix.needsUpdate = true;
  }

  dispose(): void {
    this.geometry.dispose();
    (this.object.material as THREE.Material).dispose();
  }
}

const BURST_LIFE = 0.55;
const BURST_POOL = 30;

/** Falling snow that follows the camera, and the puffs kicked up where the sled lands. */
export class SnowField {
  readonly object = new THREE.Group();
  private readonly flakes: THREE.InstancedMesh | null = null;
  private readonly flakePositions: THREE.Vector3[] = [];
  private readonly flakeSpeeds: number[] = [];
  private readonly bursts: THREE.InstancedMesh;
  private readonly burstPositions = Array.from({ length: BURST_POOL }, () => new THREE.Vector3());
  private readonly burstVelocities = Array.from({ length: BURST_POOL }, () => new THREE.Vector3());
  private readonly burstLife = new Float32Array(BURST_POOL);
  private nextBurst = 0;
  private readonly random = seededRandom(0x5f1a);
  private readonly geometries: THREE.BufferGeometry[] = [];

  /** `falling`: false with Reduce Motion (Swift skipped the snowfall then). */
  constructor(night: boolean, falling: boolean) {
    const r = this.random;
    if (falling) {
      const count = night ? 36 : 52;
      const geometry = new THREE.BoxGeometry(0.07, 0.07, 0.07);
      this.geometries.push(geometry);
      const material = new THREE.MeshStandardMaterial({
        color: 0xffffff,
        roughness: 0.9,
        transparent: true,
        opacity: night ? 0.55 : 0.8,
      });
      const flakes = instanced(geometry, material, count);
      for (let i = 0; i < count; i += 1) {
        this.flakePositions.push(new THREE.Vector3(-18 + r() * 36, 2 + r() * 14, -10 + r() * 34));
        this.flakeSpeeds.push(2.2 + r() * 3.3);
      }
      this.flakes = flakes;
      this.object.add(flakes);
    }
    const burstGeometry = new THREE.SphereGeometry(0.09, 8, 6);
    this.geometries.push(burstGeometry);
    const burstMaterial = new THREE.MeshStandardMaterial({
      color: toColor([0.92, 0.96, 1.0]),
      roughness: 0.7,
      transparent: true,
      opacity: 0.7,
      depthWrite: false,
    });
    this.bursts = instanced(burstGeometry, burstMaterial, BURST_POOL);
  }

  /** The bursts live in world space; add this to the scene next to `object`. */
  get burstObject(): THREE.InstancedMesh {
    return this.bursts;
  }

  /** A ring of puffs kicked up where the sled lands. */
  burst(at: Vec3): void {
    for (let i = 0; i < 10; i += 1) {
      const a = (i / 10) * 2 * Math.PI;
      const k = this.nextBurst;
      this.nextBurst = (this.nextBurst + 1) % BURST_POOL;
      this.burstPositions[k].set(at.x + Math.cos(a) * 0.55, at.y + 0.12, at.z + Math.sin(a) * 0.55);
      this.burstVelocities[k].set(Math.cos(a) * 2.6, 2.4, Math.sin(a) * 2.6);
      this.burstLife[k] = BURST_LIFE;
    }
  }

  tick(dt: number, camera: Vec3): void {
    const r = this.random;
    this.object.position.set(camera.x, camera.y, camera.z);
    if (this.flakes) {
      for (let i = 0; i < this.flakePositions.length; i += 1) {
        const p = this.flakePositions[i];
        p.y -= this.flakeSpeeds[i] * dt;
        if (p.y < -4) p.set(-18 + r() * 36, 8 + r() * 8, -8 + r() * 30);
        scratch.matrix.makeTranslation(p.x, p.y, p.z);
        this.flakes.setMatrixAt(i, scratch.matrix);
      }
      this.flakes.instanceMatrix.needsUpdate = true;
    }
    let changed = false;
    for (let i = 0; i < BURST_POOL; i += 1) {
      if (this.burstLife[i] <= 0) continue;
      changed = true;
      this.burstLife[i] -= dt;
      if (this.burstLife[i] <= 0) {
        this.bursts.setMatrixAt(i, HIDDEN);
        continue;
      }
      this.burstVelocities[i].y -= 9 * dt;
      this.burstPositions[i].addScaledVector(this.burstVelocities[i], dt);
      const k = this.burstLife[i] / BURST_LIFE;
      scratch.scale.setScalar((0.6 + (1 - k) * 1.2) * Math.max(0.2, k));
      scratch.matrix.compose(this.burstPositions[i], scratch.quaternion.identity(), scratch.scale);
      this.bursts.setMatrixAt(i, scratch.matrix);
    }
    if (changed) this.bursts.instanceMatrix.needsUpdate = true;
  }

  dispose(): void {
    for (const geometry of this.geometries) geometry.dispose();
    if (this.flakes) (this.flakes.material as THREE.Material).dispose();
    (this.bursts.material as THREE.Material).dispose();
  }
}
