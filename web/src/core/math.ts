/**
 * Maths shared by the game logic and the renderer. A port of `GameMath` and the bits of `simd`
 * the Swift engine used. Vectors are plain objects so the engine runs in Node without three.js.
 */

export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

/** An sRGB colour with channels in 0...1, as the Swift code stored them. */
export type RGB = readonly [number, number, number];

export const vec3 = (x: number, y: number, z: number): Vec3 => ({ x, y, z });

export const add = (a: Vec3, b: Vec3): Vec3 => ({ x: a.x + b.x, y: a.y + b.y, z: a.z + b.z });
export const sub = (a: Vec3, b: Vec3): Vec3 => ({ x: a.x - b.x, y: a.y - b.y, z: a.z - b.z });
export const scale = (a: Vec3, s: number): Vec3 => ({ x: a.x * s, y: a.y * s, z: a.z * s });
export const dot = (a: Vec3, b: Vec3): number => a.x * b.x + a.y * b.y + a.z * b.z;
export const cross = (a: Vec3, b: Vec3): Vec3 => ({
  x: a.y * b.z - a.z * b.y,
  y: a.z * b.x - a.x * b.z,
  z: a.x * b.y - a.y * b.x,
});
export const length = (a: Vec3): number => Math.sqrt(dot(a, a));
export const normalize = (a: Vec3): Vec3 => {
  const l = length(a);
  return l > 0 ? scale(a, 1 / l) : { x: 0, y: 0, z: 0 };
};
/** `a + b * s`, the most common combination in track maths. */
export const addScaled = (a: Vec3, b: Vec3, s: number): Vec3 => ({
  x: a.x + b.x * s,
  y: a.y + b.y * s,
  z: a.z + b.z * s,
});

export const lerp = (a: number, b: number, t: number): number => a + (b - a) * t;
export const lerp3 = (a: Vec3, b: Vec3, t: number): Vec3 => ({
  x: a.x + (b.x - a.x) * t,
  y: a.y + (b.y - a.y) * t,
  z: a.z + (b.z - a.z) * t,
});
export const clamp = (x: number, a: number, b: number): number => Math.min(Math.max(x, a), b);
export const saturate = (x: number): number => clamp(x, 0, 1);

/** Frame-rate independent exponential approach of `current` toward `target`. */
export const damp = (current: number, target: number, lambda: number, dt: number): number =>
  target + (current - target) * Math.exp(-lambda * dt);

export const damp3 = (current: Vec3, target: Vec3, lambda: number, dt: number): Vec3 => {
  const k = Math.exp(-lambda * dt);
  return {
    x: target.x + (current.x - target.x) * k,
    y: target.y + (current.y - target.y) * k,
    z: target.z + (current.z - target.z) * k,
  };
};

export const smoothstep = (edge0: number, edge1: number, x: number): number => {
  const t = saturate((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
};

export const wrapAngle = (a: number): number => {
  let x = a;
  while (x > Math.PI) x -= 2 * Math.PI;
  while (x < -Math.PI) x += 2 * Math.PI;
  return x;
};

/** CSS colour for an RGB triple. */
export const cssColor = (c: RGB, alpha = 1): string =>
  alpha >= 1
    ? `rgb(${Math.round(c[0] * 255)}, ${Math.round(c[1] * 255)}, ${Math.round(c[2] * 255)})`
    : `rgba(${Math.round(c[0] * 255)}, ${Math.round(c[1] * 255)}, ${Math.round(c[2] * 255)}, ${alpha})`;

/**
 * Small deterministic random generator (mulberry32). Used for scenery that the Swift app placed
 * with the system generator, so a course now looks the same on every launch.
 */
export function seededRandom(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
