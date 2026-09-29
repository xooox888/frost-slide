/**
 * Procedural textures drawn on canvases, so the 3D scene ships no image files. A port of
 * `RKTexture` in `Reality/RKMaterials.swift` (same drawing, same numbers). The Swift code drew
 * with unseeded randomness; here it is seeded so a course looks the same every time.
 */
import * as THREE from 'three';
import { seededRandom, type RGB } from '../core/math';
import type { LevelPalette } from '../core/models';
import { css, gray, mix, mul } from './surfaces';

function canvas(width: number, height: number): [HTMLCanvasElement | OffscreenCanvas, CanvasRenderingContext2D] {
  const c: HTMLCanvasElement | OffscreenCanvas =
    typeof document !== 'undefined' ? document.createElement('canvas') : new OffscreenCanvas(width, height);
  c.width = width;
  c.height = height;
  const ctx = c.getContext('2d') as CanvasRenderingContext2D | null;
  if (!ctx) throw new Error('2D canvas unavailable');
  return [c, ctx];
}

function gradient(
  ctx: CanvasRenderingContext2D,
  x0: number,
  y0: number,
  x1: number,
  y1: number,
  stops: [number, string][],
) {
  const g = ctx.createLinearGradient(x0, y0, x1, y1);
  for (const [at, color] of stops) g.addColorStop(at, color);
  return g;
}

/**
 * Equirectangular sky: zenith-to-horizon gradient, two periodic mountain ranges, foothills with a
 * pine line just below eye level, stars at night. Used as the scene background.
 */
export function skyTexture(pal: LevelPalette): THREE.CanvasTexture {
  const w = 1024;
  const h = 512;
  const [c, ctx] = canvas(w, h);
  const horizon = h * 0.5;
  const random = seededRandom(0x5c1e5);
  const top = pal.skyTop;
  const glowBand = mix(pal.skyBottom, gray(1), pal.night ? 0.05 : 0.35);
  ctx.fillStyle = gradient(ctx, 0, 0, 0, horizon, [
    [0, css(mul(top, pal.night ? 0.75 : 0.92))],
    [0.35, css(top)],
    [0.85, css(pal.skyBottom)],
    [1, css(glowBand)],
  ]);
  ctx.fillRect(0, 0, w, horizon);
  ctx.fillStyle = gradient(ctx, 0, horizon, 0, h, [
    [0, css(glowBand)],
    [1, css(pal.fog)],
  ]);
  ctx.fillRect(0, horizon, w, h - horizon);

  if (pal.night) {
    for (let i = 0; i < 420; i += 1) {
      const x = random() * w;
      const y = random() * horizon * 0.8;
      const r = 0.6 + random() * 1.2;
      ctx.fillStyle = `rgba(255, 255, 255, ${0.35 + random() * 0.6})`;
      ctx.beginPath();
      ctx.ellipse(x + r / 2, y + r / 2, r / 2, r / 2, 0, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // Two mountain ranges; the sine terms are periodic in u so the seam wraps cleanly.
  const far = mul(mix(pal.skyBottom, mul(pal.ice, 0.8), pal.night ? 0.55 : 0.45), pal.night ? 0.55 : 1);
  const near = mul(mix(far, mul(pal.ice, 0.55), 0.4), pal.night ? 0.8 : 0.92);
  const ranges: [number, RGB][] = [
    [0, far],
    [1, near],
  ];
  for (const [layer, color] of ranges) {
    const amp = layer === 0 ? 70 : 44;
    const lift = layer === 0 ? 18 : 4;
    ctx.fillStyle = css(color);
    ctx.beginPath();
    ctx.moveTo(0, horizon + 2);
    for (let i = 0; i <= w; i += 1) {
      const u = (i / w) * 2 * Math.PI;
      const k = layer * 1.7;
      const n = Math.sin(u * 3 + k) * 0.5 + Math.sin(u * 7 + 1.3 + k) * 0.3 + Math.abs(Math.sin(u * 13 + k)) * 0.35;
      ctx.lineTo(i, horizon - lift - Math.max(0, n + 0.25) * amp);
    }
    ctx.lineTo(w, horizon + 2);
    ctx.closePath();
    ctx.fill();
  }

  // Foothills just below eye level, where the camera looks past the course's end, with a pine
  // tree line so the haze reads as distant terrain.
  const hills = mul(mix(pal.fog, pal.snow, 0.5), pal.night ? 0.45 : 0.93);
  const pines = mix([0.1, 0.3, 0.26], pal.fog, pal.night ? 0.6 : 0.35);
  const hillY = (i: number) => {
    const u = (i / w) * 2 * Math.PI;
    return horizon + 10 - (Math.sin(u * 5 + 0.7) * 0.5 + Math.sin(u * 11) * 0.25 + 0.75) * 16;
  };
  ctx.fillStyle = css(hills);
  ctx.beginPath();
  ctx.moveTo(0, h);
  for (let i = 0; i <= w; i += 1) ctx.lineTo(i, hillY(i));
  ctx.lineTo(w, h);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = css(pines);
  ctx.beginPath();
  for (let i = 0; i < w; i += 5) {
    const u = (i / w) * 2 * Math.PI;
    if (Math.sin(u * 9 + 2) <= -0.2) continue;
    const base = hillY(i) + 3;
    const tall = 6 + ((i * 37) % 7);
    ctx.moveTo(i - 2.5, base);
    ctx.lineTo(i, base - tall);
    ctx.lineTo(i + 2.5, base);
    ctx.closePath();
  }
  ctx.fill();

  // Snow caps on the far range.
  ctx.fillStyle = css(mix(far, gray(1), pal.night ? 0.25 : 0.7), 0.9);
  for (let i = 0; i < w; i += 2) {
    const u = (i / w) * 2 * Math.PI;
    const n = Math.sin(u * 3) * 0.5 + Math.sin(u * 7 + 1.3) * 0.3 + Math.abs(Math.sin(u * 13)) * 0.35;
    if (n <= 0.55) continue;
    const y = horizon - 18 - (n + 0.25) * 70;
    ctx.fillRect(i, y, 2, (n - 0.5) * 30);
  }

  const texture = new THREE.CanvasTexture(c as HTMLCanvasElement);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.mapping = THREE.EquirectangularReflectionMapping;
  return texture;
}

/**
 * Track surface tile (u across the track, v down it): snow with ice-tinted edges, carve grooves,
 * cyan edge rails and sparkles.
 */
export function trackTexture(pal: LevelPalette, anisotropy: number): THREE.CanvasTexture {
  const w = 256;
  const h = 512;
  const [c, ctx] = canvas(w, h);
  const random = seededRandom(0x7ac4);
  // Albedo below 1 so the sun doesn't clip the snow to flat white.
  const edge = mul(mix(pal.snow, pal.ice, 0.55), 0.84);
  const mid = mul(pal.snow, 0.86);
  ctx.fillStyle = gradient(ctx, 0, 0, w, 0, [
    [0, css(edge)],
    [0.22, css(mid)],
    [0.78, css(mid)],
    [1, css(edge)],
  ]);
  ctx.fillRect(0, 0, w, h);
  ctx.strokeStyle = css(mul(pal.ice, 0.6), 0.3);
  ctx.lineWidth = 3;
  ctx.beginPath();
  for (const u of [0.31, 0.43, 0.57, 0.69]) {
    ctx.moveTo(u * w, 0);
    ctx.lineTo(u * w, h);
  }
  ctx.stroke();

  const rail: RGB = pal.night ? pal.accent : [0.25, 0.85, 1.0];
  ctx.fillStyle = css(rail, 0.9);
  ctx.fillRect(w * 0.03, 0, w * 0.045, h);
  ctx.fillRect(w * 0.925, 0, w * 0.045, h);
  ctx.fillStyle = 'rgba(255, 255, 255, 0.9)';
  for (let i = 0; i < 160; i += 1) {
    const x = (0.08 + random() * 0.84) * w;
    const y = random() * h;
    const r = 1 + random() * 1.6;
    ctx.beginPath();
    ctx.ellipse(x + r / 2, y + r / 2, r / 2, r / 2, 0, 0, Math.PI * 2);
    ctx.fill();
  }

  const texture = new THREE.CanvasTexture(c as HTMLCanvasElement);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.anisotropy = anisotropy;
  return texture;
}

/** A soft round glow for lantern halos (sprites), white so a sprite colour tints it. */
export function glowSpriteTexture(): THREE.CanvasTexture {
  const size = 64;
  const [c, ctx] = canvas(size, size);
  const g = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  g.addColorStop(0, 'rgba(255, 255, 255, 1)');
  g.addColorStop(0.35, 'rgba(255, 255, 255, 0.45)');
  g.addColorStop(1, 'rgba(255, 255, 255, 0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, size, size);
  const texture = new THREE.CanvasTexture(c as HTMLCanvasElement);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

/**
 * An aurora curtain: soft vertical rays, brightest low down, fading out at the top and the ends.
 * (Swift drew a flat translucent rectangle, which its chase camera never saw: it faced away.)
 */
export function auroraTexture(): THREE.CanvasTexture {
  const w = 256;
  const h = 128;
  const [c, ctx] = canvas(w, h);
  const random = seededRandom(0xa0a0);
  for (let x = 0; x < w; x += 1) {
    const u = x / (w - 1);
    const ends = Math.min(1, u / 0.18, (1 - u) / 0.18);
    const ray = 0.55 + 0.45 * Math.sin(u * 37 + Math.sin(u * 11) * 2) * Math.sin(u * 13 + 1.7);
    const flicker = 0.75 + random() * 0.25;
    const strength = Math.max(0, ends) * ray * flicker;
    const g = ctx.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, 'rgba(150, 110, 255, 0)');
    g.addColorStop(0.35, `rgba(120, 200, 255, ${0.25 * strength})`);
    g.addColorStop(0.72, `rgba(90, 255, 170, ${0.9 * strength})`);
    g.addColorStop(0.86, `rgba(90, 255, 170, ${0.35 * strength})`);
    g.addColorStop(1, 'rgba(90, 255, 170, 0)');
    ctx.fillStyle = g;
    ctx.fillRect(x, 0, 1, h);
  }
  const texture = new THREE.CanvasTexture(c as HTMLCanvasElement);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

/** A gust: a few pale streaks with soft ends, so wind reads as moving air, not a pane of glass. */
export function windTexture(): THREE.CanvasTexture {
  const w = 256;
  const h = 64;
  const [c, ctx] = canvas(w, h);
  const random = seededRandom(0x3d17);
  for (let i = 0; i < 9; i += 1) {
    const y = 6 + random() * (h - 12);
    const x0 = random() * w * 0.35;
    const x1 = w * 0.65 + random() * w * 0.35;
    const g = ctx.createLinearGradient(x0, 0, x1, 0);
    g.addColorStop(0, 'rgba(255, 255, 255, 0)');
    g.addColorStop(0.5, `rgba(255, 255, 255, ${0.35 + random() * 0.4})`);
    g.addColorStop(1, 'rgba(255, 255, 255, 0)');
    ctx.strokeStyle = g;
    ctx.lineWidth = 1.5 + random() * 2.5;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(x0, y);
    ctx.bezierCurveTo(x0 + (x1 - x0) * 0.3, y - 5, x0 + (x1 - x0) * 0.6, y + 5, x1, y);
    ctx.stroke();
  }
  const texture = new THREE.CanvasTexture(c as HTMLCanvasElement);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}
