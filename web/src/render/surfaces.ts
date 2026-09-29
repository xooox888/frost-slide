/**
 * Surface descriptions: what `RKMat.pbr` and `RKMat.glow` took in the Swift app (colour,
 * roughness, metalness, emission, opacity), kept as plain data. Moving props get a cached
 * three.js material for each; static scenery is baked into merged meshes that carry these values
 * per vertex (see `bake.ts`), so one material draws all of it.
 */
import * as THREE from 'three';
import type { RGB } from '../core/math';

export interface Surface {
  color: RGB;
  roughness: number;
  metalness: number;
  /** Emitted colour (sRGB, like `color`) and a linear multiplier on it, as RealityKit had. */
  emissive: RGB | null;
  emissiveIntensity: number;
  alpha: number;
  doubleSided: boolean;
}

export interface PbrOptions {
  roughness?: number;
  metallic?: number;
  emissive?: RGB | null;
  alpha?: number;
  doubleSided?: boolean;
}

/** `RKMat.pbr`, with the same defaults. */
export function pbr(color: RGB, options: PbrOptions = {}): Surface {
  return {
    color,
    roughness: options.roughness ?? 0.62,
    metalness: options.metallic ?? 0.04,
    emissive: options.emissive ?? null,
    emissiveIntensity: 1,
    alpha: options.alpha ?? 1,
    doubleSided: options.doubleSided ?? false,
  };
}

/** `RKMat.glow`: emissive in its own colour, for crystals, rails and lit windows. */
export function glow(color: RGB, intensity = 1.6, alpha = 1): Surface {
  return { ...pbr(color, { roughness: 0.18, emissive: color, alpha }), emissiveIntensity: intensity };
}

// MARK: - Colour maths on sRGB triples (the Swift code's SIMD3<Float> colours)

export const rgb = (r: number, g: number, b: number): RGB => [r, g, b];
export const gray = (v: number): RGB => [v, v, v];
export const mix = (a: RGB, b: RGB, t: number): RGB => [
  a[0] + (b[0] - a[0]) * t,
  a[1] + (b[1] - a[1]) * t,
  a[2] + (b[2] - a[2]) * t,
];
export const mul = (a: RGB, s: number): RGB => [a[0] * s, a[1] * s, a[2] * s];
export const plus = (a: RGB, b: RGB): RGB => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
export const clamp01 = (a: RGB): RGB => [Math.min(1, a[0]), Math.min(1, a[1]), Math.min(1, a[2])];

/** A three.js colour (linear, as three.js works) from an sRGB triple, as UIColor read them. */
export function toColor(c: RGB, target = new THREE.Color()): THREE.Color {
  return target.setRGB(c[0], c[1], c[2], THREE.SRGBColorSpace);
}

/** The linear emitted light of a surface (black if it doesn't glow). */
export function emittedColor(s: Surface, target = new THREE.Color()): THREE.Color {
  if (!s.emissive) return target.setRGB(0, 0, 0);
  return toColor(s.emissive, target).multiplyScalar(s.emissiveIntensity);
}

/** A canvas colour string. Canvas colours are sRGB, like the Core Graphics ones they replace. */
export function css(c: RGB, alpha = 1): string {
  const ch = (v: number) => Math.round(Math.min(1, Math.max(0, v)) * 255);
  return `rgba(${ch(c[0])}, ${ch(c[1])}, ${ch(c[2])}, ${alpha})`;
}

export const surfaceKey = (s: Surface): string =>
  [
    ...s.color,
    s.roughness,
    s.metalness,
    ...(s.emissive ?? [-1, -1, -1]),
    s.emissiveIntensity,
    s.alpha,
    s.doubleSided ? 1 : 0,
  ]
    .map((v) => (typeof v === 'number' ? v.toFixed(3) : v))
    .join(',');
