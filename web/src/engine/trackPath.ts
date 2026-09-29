/**
 * The course as a sampled spline: position, frame, width, banking and curvature every metre or
 * so. A port of `Engine/TrackPath.swift`.
 */
import {
  addScaled,
  clamp,
  cross,
  length as vlength,
  lerp,
  lerp3,
  normalize,
  smoothstep,
  vec3,
  wrapAngle,
  type Vec3,
} from '../core/math';
import type { LevelDefinition } from '../core/models';

export interface TrackSample {
  progress: number;
  position: Vec3;
  tangent: Vec3;
  normal: Vec3;
  binormal: Vec3;
  width: number;
  heading: number;
  slope: number;
  /**
   * Roll of the surface about the tangent, radians. Negative leans the surface toward the
   * player's left (the inside of a left turn); `normal`/`binormal` already include it.
   */
  bank: number;
  /** Signed turn rate in radians per metre, eased in and out. Positive turns left. */
  curvature: number;
}

export class TrackPath {
  constructor(
    readonly samples: readonly TrackSample[],
    readonly length: number,
    readonly checkpoints: readonly number[],
  ) {}

  sample(progress: number): TrackSample {
    const samples = this.samples;
    if (samples.length < 2) return samples[0];
    const t = clamp(progress, 0, 1);
    const scaled = t * (samples.length - 1);
    const i0 = Math.min(Math.trunc(scaled), samples.length - 2);
    const frac = scaled - i0;
    const a = samples[i0];
    const b = samples[i0 + 1];
    return {
      progress: lerp(a.progress, b.progress, frac),
      position: lerp3(a.position, b.position, frac),
      tangent: normalize(lerp3(a.tangent, b.tangent, frac)),
      normal: normalize(lerp3(a.normal, b.normal, frac)),
      binormal: normalize(lerp3(a.binormal, b.binormal, frac)),
      width: lerp(a.width, b.width, frac),
      heading: a.heading + wrapAngle(b.heading - a.heading) * frac,
      slope: lerp(a.slope, b.slope, frac),
      bank: lerp(a.bank, b.bank, frac),
      curvature: lerp(a.curvature, b.curvature, frac),
    };
  }

  worldPosition(progress: number, lateral: number, height: number): Vec3 {
    const s = this.sample(progress);
    return addScaled(addScaled(s.position, s.binormal, lateral), s.normal, height + 0.12);
  }

  width(progress: number): number {
    return this.sample(progress).width;
  }

  /** Signed turn rate (rad/m) at a progress value; positive turns left. */
  curvature(progress: number): number {
    return this.sample(progress).curvature;
  }

  static build(level: LevelDefinition, sampleCount = 380): TrackPath {
    const count = sampleCount;
    const step = level.length / (count - 1);

    // Pass 1: yaw change per sample from the authored curves.
    const yawDeltas = new Array<number>(count).fill(0);
    for (let i = 0; i < count; i += 1) {
      const t = i / (count - 1);
      let delta = 0;
      for (const curve of level.curves) {
        if (t >= curve.start && t <= curve.end) {
          const span = Math.max(0.001, curve.end - curve.start);
          delta += curve.yawRadians / span / (count - 1);
        }
      }
      yawDeltas[i] = delta;
    }

    // Pass 2: ease the turn rate in and out for banking and the sideways pull. The raw rate jumps
    // at every curve boundary; running the filter both ways cancels its lag.
    const forward = [...yawDeltas];
    const backward = [...yawDeltas];
    const smoothing = 0.1;
    for (let i = 1; i < count; i += 1) {
      forward[i] = forward[i - 1] + (yawDeltas[i] - forward[i - 1]) * smoothing;
    }
    for (let i = count - 2; i >= 0; i -= 1) {
      backward[i] = backward[i + 1] + (yawDeltas[i] - backward[i + 1]) * smoothing;
    }

    const samples: TrackSample[] = [];
    let position = vec3(0, level.startHeight, 0);
    let yaw = 0;
    const worldUp = vec3(0, 1, 0);

    for (let i = 0; i < count; i += 1) {
      const t = i / (count - 1);
      yaw += yawDeltas[i];

      let extraY = 0;
      for (const bump of level.elevations) {
        const d = Math.abs(t - bump.at);
        if (d < bump.span) extraY += bump.height * smoothstep(bump.span, 0, d);
      }

      let width = level.baseWidth;
      for (const key of level.widths) {
        const d = Math.abs(t - key.at);
        if (d < key.span) width = lerp(width, key.width, smoothstep(key.span, 0, d));
      }

      const tangent = normalize(vec3(Math.sin(yaw), -level.slope, Math.cos(yaw)));
      let binormal = cross(tangent, worldUp);
      binormal = vlength(binormal) < 0.001 ? vec3(1, 0, 0) : normalize(binormal);
      const normal = normalize(cross(binormal, tangent));
      // Lean the surface toward the inside of the turn (binormal points to the player's right,
      // so a left turn, positive curvature, needs a negative bank).
      const curvature = ((forward[i] + backward[i]) * 0.5) / step;
      const bank = clamp(-curvature * 14, -0.24, 0.24);
      const bankedNormal = normalize(
        addScaled(
          vec3(normal.x * Math.cos(bank), normal.y * Math.cos(bank), normal.z * Math.cos(bank)),
          binormal,
          Math.sin(bank),
        ),
      );
      const bankedBinormal = normalize(cross(tangent, bankedNormal));

      samples.push({
        progress: t,
        position: vec3(position.x, position.y + extraY, position.z),
        tangent,
        normal: bankedNormal,
        binormal: bankedBinormal,
        width,
        heading: yaw,
        slope: level.slope,
        bank,
        curvature,
      });

      position = addScaled(position, tangent, step);
    }

    return new TrackPath(samples, level.length, level.checkpoints);
  }
}
