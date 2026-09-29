/**
 * Colours and number formats shared by every screen. A port of `UI/FrostTheme.swift`. The same
 * colours are CSS variables in `theme.css` (`--ink`, and `--ink-rgb` for see-through variants);
 * this module has them for canvas drawing and for styles set from code.
 */
import type { RGB } from '../core/math';
import type { LevelTheme } from '../core/models';

/** FrostTheme's palette, as the Swift file defines it (sRGB, 0...1). Keep `theme.css` in step. */
export const FROST = {
  ink: [0.1, 0.2, 0.3],
  inkSoft: [0.22, 0.36, 0.48],
  ice: [0.18, 0.62, 1.0],
  iceDeep: [0.08, 0.38, 0.78],
  cream: [0.96, 0.98, 1.0],
  snow: [0.91, 0.95, 0.99],
  ochre: [0.9, 0.7, 0.3],
  berry: [1.0, 0.31, 0.45],
  pine: [0.18, 0.55, 0.42],
  grape: [0.55, 0.38, 0.82],
  night: [0.07, 0.1, 0.22],
} as const satisfies Record<string, RGB>;

export type FrostColor = keyof typeof FROST;

/** SwiftUI's `.cyan`, `.green` and `.red` in light mode, where the Swift screens use them. */
export const SYSTEM_COLOR = { cyan: '#32ade6', green: '#34c759', red: '#ff3b30' } as const;

/** The CSS variable holding a palette colour: `inkSoft` is `--ink-soft` (and `--ink-soft-rgb`). */
export const cssVar = (name: FrostColor): string => `--${name.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}`;

/** `r g b` in 0...255, for `rgb(var(--x-rgb) / alpha)` in CSS. */
export const rgbTriplet = (c: RGB): string => c.map((v) => Math.round(v * 255)).join(' ');

/** `#rrggbb` (canvas-confetti only takes hex colours). */
export function hexColor(c: RGB): string {
  const byte = (v: number) => (256 + Math.round(v * 255)).toString(16).slice(1);
  return `#${c.map(byte).join('')}`;
}

/** Each course family's colour on the course map (`LevelCard.accent`). */
export const LEVEL_ACCENT: Record<LevelTheme, RGB> = {
  village: FROST.ice,
  market: [0.86, 0.38, 0.24],
  cave: [0.3, 0.72, 0.95],
  aurora: [0.4, 0.92, 0.62],
  harbor: [0.22, 0.5, 0.68],
  summit: FROST.ice,
  forest: FROST.pine,
  canyon: [0.45, 0.75, 1.0],
  steam: [0.95, 0.55, 0.28],
  blizzard: [0.7, 0.82, 0.95],
  neon: [1.0, 0.28, 0.72],
  carnival: [1.0, 0.42, 0.38],
};

export function placeWord(place: number): string {
  switch (place) {
    case 1:
      return '1st';
    case 2:
      return '2nd';
    case 3:
      return '3rd';
    default:
      return `${place}th`;
  }
}

/** A race clock such as 0'42.37" (`%d'%05.2f"`); 9000 s and over means "no time". */
export function formatTime(t: number): string {
  if (!(t < 9000)) return `--'--"`;
  const minutes = Math.trunc(t / 60);
  const seconds = t % 60;
  return `${minutes}'${seconds.toFixed(2).padStart(5, '0')}"`;
}

/** Whole-second target such as a par time: 0'42". */
export function formatPar(t: number): string {
  const whole = Math.round(t);
  return `${Math.trunc(whole / 60)}'${String(whole % 60).padStart(2, '0')}"`;
}

/** A signed gap in seconds, always with its sign: +0.42 or -1.30 (`%+.2f`). */
export function formatGap(seconds: number): string {
  const text = seconds.toFixed(2);
  return text.startsWith('-') ? text : `+${text}`;
}
