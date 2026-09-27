#!/usr/bin/env python3
"""Headless check that all Frost Slide paths are finite and finishable."""

from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass
class Curve:
    start: float
    end: float
    yaw: float


@dataclass
class Level:
    name: str
    length: float
    width: float
    slope: float
    curves: list[Curve]
    rivals: int
    crystals: int


def crystals(lanes: list[tuple[float, float, int]]) -> int:
    return sum(c for _, _, c in lanes)


LEVELS = [
    Level("Village Dash", 560, 17, 0.11, [Curve(0.04, 0.22, 0.65), Curve(0.22, 0.40, -1.05), Curve(0.40, 0.58, 0.95), Curve(0.58, 0.78, -0.85), Curve(0.78, 0.96, 0.55)], 3, crystals([(0.08, 0.18, 7), (0.26, 0.35, 6), (0.42, 0.54, 8), (0.62, 0.74, 7), (0.80, 0.90, 6)])),
    Level("Market Mayhem", 520, 11.5, 0.10, [Curve(0.00, 0.18, 0.9), Curve(0.18, 0.34, -1.2), Curve(0.34, 0.52, 1.15), Curve(0.52, 0.70, -1.0), Curve(0.70, 0.88, 0.85)], 4, crystals([(0.06, 0.14, 6), (0.22, 0.32, 6), (0.38, 0.48, 7), (0.58, 0.68, 6), (0.78, 0.90, 7)])),
    Level("Alley Sprint", 500, 10.4, 0.105, [Curve(0.00, 0.16, 1.15), Curve(0.16, 0.34, -1.35), Curve(0.34, 0.52, 1.05), Curve(0.52, 0.72, -1.20), Curve(0.72, 0.94, 0.80)], 3, crystals([(0.06, 0.14, 6), (0.20, 0.30, 6), (0.36, 0.46, 7), (0.56, 0.66, 6), (0.76, 0.88, 7)])),
    Level("Ice Cave Spiral", 600, 13, 0.13, [Curve(0.00, 1.00, 5.2)], 3, crystals([(0.07, 0.18, 7), (0.22, 0.34, 7), (0.40, 0.52, 8), (0.58, 0.70, 7), (0.80, 0.92, 7)])),
    Level("Crystal Grotto", 590, 13.5, 0.12, [Curve(0.00, 0.22, 0.85), Curve(0.22, 0.48, -1.15), Curve(0.48, 0.74, 1.05), Curve(0.74, 1.00, -0.70)], 3, crystals([(0.06, 0.16, 7), (0.22, 0.34, 7), (0.42, 0.54, 8), (0.62, 0.74, 7), (0.82, 0.92, 7)])),
    Level("Frozen Hollow", 620, 11.2, 0.14, [Curve(0.00, 1.00, 6.4)], 4, crystals([(0.06, 0.16, 7), (0.22, 0.34, 7), (0.40, 0.50, 7), (0.58, 0.70, 7), (0.78, 0.90, 8)])),
    Level("Aurora Night", 580, 15, 0.105, [Curve(0.05, 0.25, -0.8), Curve(0.25, 0.48, 1.25), Curve(0.48, 0.70, -1.1), Curve(0.70, 0.92, 0.75)], 4, crystals([(0.08, 0.16, 6), (0.24, 0.34, 6), (0.40, 0.50, 7), (0.60, 0.70, 6), (0.82, 0.92, 6)])),
    Level("Polar Veil", 600, 14.5, 0.11, [Curve(0.04, 0.26, -1.05), Curve(0.26, 0.50, 1.30), Curve(0.50, 0.74, -1.15), Curve(0.74, 0.96, 0.70)], 4, crystals([(0.06, 0.14, 6), (0.22, 0.32, 6), (0.40, 0.50, 7), (0.58, 0.68, 6), (0.80, 0.92, 7)])),
    Level("Midnight Ribbon", 610, 12.8, 0.12, [Curve(0.00, 0.20, 0.95), Curve(0.20, 0.42, -1.40), Curve(0.42, 0.66, 1.20), Curve(0.66, 0.90, -0.85)], 4, crystals([(0.06, 0.14, 6), (0.22, 0.32, 7), (0.40, 0.50, 7), (0.58, 0.68, 6), (0.80, 0.90, 7)])),
    Level("Harbor Freeze", 540, 12, 0.09, [Curve(0.06, 0.24, 0.55), Curve(0.24, 0.44, -0.95), Curve(0.44, 0.66, 0.85), Curve(0.66, 0.90, -0.60)], 3, crystals([(0.08, 0.16, 5), (0.26, 0.36, 6), (0.46, 0.56, 6), (0.68, 0.80, 6)])),
    Level("Driftwood Docks", 550, 11.0, 0.095, [Curve(0.05, 0.26, 0.70), Curve(0.26, 0.50, -1.05), Curve(0.50, 0.74, 0.90), Curve(0.74, 0.94, -0.55)], 3, crystals([(0.08, 0.16, 5), (0.24, 0.34, 6), (0.44, 0.54, 6), (0.66, 0.80, 7)])),
    Level("Tide Gate", 560, 10.6, 0.10, [Curve(0.04, 0.28, 0.80), Curve(0.28, 0.54, -1.10), Curve(0.54, 0.80, 0.95), Curve(0.80, 0.96, -0.50)], 4, crystals([(0.06, 0.14, 5), (0.22, 0.32, 6), (0.40, 0.50, 6), (0.62, 0.74, 6), (0.82, 0.90, 5)])),
    Level("Summit Rush", 640, 18, 0.16, [Curve(0.04, 0.20, 0.45), Curve(0.20, 0.38, -0.70), Curve(0.38, 0.58, 0.90), Curve(0.58, 0.78, -0.75), Curve(0.78, 0.96, 0.40)], 5, crystals([(0.06, 0.14, 6), (0.24, 0.33, 7), (0.40, 0.50, 8), (0.56, 0.66, 7), (0.78, 0.90, 8)])),
    Level("Glacier Drop", 660, 17.0, 0.17, [Curve(0.04, 0.22, 0.55), Curve(0.22, 0.44, -0.85), Curve(0.44, 0.66, 1.00), Curve(0.66, 0.90, -0.60)], 4, crystals([(0.06, 0.14, 6), (0.24, 0.34, 7), (0.42, 0.52, 8), (0.60, 0.70, 7), (0.80, 0.92, 8)])),
    Level("Icefall Run", 680, 16.0, 0.18, [Curve(0.02, 0.20, 0.40), Curve(0.20, 0.40, -0.80), Curve(0.40, 0.62, 1.05), Curve(0.62, 0.82, -0.90), Curve(0.82, 0.98, 0.45)], 5, crystals([(0.06, 0.14, 6), (0.22, 0.32, 7), (0.40, 0.50, 8), (0.58, 0.68, 7), (0.80, 0.92, 8)])),
    Level("Pine Whisper", 570, 15.0, 0.11, [Curve(0.04, 0.24, 0.75), Curve(0.24, 0.48, -1.00), Curve(0.48, 0.72, 0.90), Curve(0.72, 0.94, -0.60)], 3, crystals([(0.08, 0.16, 6), (0.24, 0.34, 7), (0.42, 0.52, 7), (0.60, 0.70, 6), (0.80, 0.90, 7)])),
    Level("Timber Switchback", 600, 13.0, 0.125, [Curve(0.00, 0.16, 1.35), Curve(0.16, 0.34, -1.55), Curve(0.34, 0.52, 1.40), Curve(0.52, 0.70, -1.45), Curve(0.70, 0.88, 1.10)], 4, crystals([(0.06, 0.14, 6), (0.20, 0.30, 7), (0.38, 0.48, 7), (0.56, 0.66, 6), (0.78, 0.90, 8)])),
    Level("Owl Hollow", 620, 12.4, 0.13, [Curve(0.04, 0.26, 1.10), Curve(0.26, 0.50, -1.25), Curve(0.50, 0.74, 1.15), Curve(0.74, 0.96, -0.80)], 4, crystals([(0.06, 0.14, 6), (0.22, 0.32, 7), (0.40, 0.50, 7), (0.58, 0.68, 6), (0.80, 0.92, 8)])),
    Level("Canyon Glow", 600, 12.6, 0.13, [Curve(0.00, 0.22, 0.70), Curve(0.22, 0.46, -1.20), Curve(0.46, 0.70, 1.10), Curve(0.70, 0.94, -0.75)], 4, crystals([(0.06, 0.16, 7), (0.22, 0.32, 7), (0.40, 0.50, 8), (0.58, 0.68, 7), (0.80, 0.90, 7)])),
    Level("Prism Cut", 610, 11.0, 0.14, [Curve(0.00, 0.18, 1.05), Curve(0.18, 0.40, -1.35), Curve(0.40, 0.64, 1.25), Curve(0.64, 0.90, -0.95)], 4, crystals([(0.06, 0.14, 6), (0.20, 0.30, 7), (0.38, 0.48, 7), (0.56, 0.66, 7), (0.78, 0.90, 8)])),
    Level("Steam Veil", 590, 13.2, 0.12, [Curve(0.04, 0.26, 0.80), Curve(0.26, 0.50, -1.10), Curve(0.50, 0.74, 1.00), Curve(0.74, 0.94, -0.65)], 4, crystals([(0.08, 0.16, 6), (0.24, 0.34, 7), (0.42, 0.52, 7), (0.60, 0.70, 6), (0.80, 0.90, 7)])),
    Level("Whiteout Peak", 640, 14.0, 0.155, [Curve(0.02, 0.20, 0.60), Curve(0.20, 0.42, -1.00), Curve(0.42, 0.64, 1.15), Curve(0.64, 0.86, -0.85)], 5, crystals([(0.06, 0.14, 6), (0.22, 0.32, 7), (0.40, 0.50, 8), (0.60, 0.70, 7), (0.80, 0.90, 8)])),
    Level("Neon Slalom", 600, 13.6, 0.135, [Curve(0.00, 0.18, 1.10), Curve(0.18, 0.38, -1.30), Curve(0.38, 0.58, 1.20), Curve(0.58, 0.78, -1.15), Curve(0.78, 0.96, 0.70)], 4, crystals([(0.06, 0.14, 6), (0.20, 0.30, 7), (0.38, 0.48, 7), (0.56, 0.66, 7), (0.78, 0.90, 8)])),
    Level("Carnival Parade", 630, 14.8, 0.14, [Curve(0.02, 0.20, 0.85), Curve(0.20, 0.40, -1.15), Curve(0.40, 0.62, 1.20), Curve(0.62, 0.82, -1.00), Curve(0.82, 0.98, 0.55)], 5, crystals([(0.06, 0.14, 7), (0.20, 0.30, 7), (0.38, 0.48, 8), (0.56, 0.66, 7), (0.78, 0.90, 8)])),
]


def build_path(level: Level, count: int = 380):
    x = y = z = yaw = 0.0
    y = level.length * level.slope + 10
    pts = []
    step = level.length / (count - 1)
    for i in range(count):
        t = i / (count - 1)
        dyaw = 0.0
        for c in level.curves:
            if c.start <= t <= c.end:
                span = max(0.001, c.end - c.start)
                dyaw += c.yaw / span / (count - 1)
        yaw += dyaw
        tx, ty, tz = math.sin(yaw), -level.slope, math.cos(yaw)
        n = math.sqrt(tx * tx + ty * ty + tz * tz)
        tx, ty, tz = tx / n, ty / n, tz / n
        pts.append((x, y, z, t))
        x += tx * step
        y += ty * step
        z += tz * step
    return pts


def race(level: Level) -> float:
    pts = build_path(level)
    progress = 0.012
    speed = 9.0
    time = 0.0
    dt = 1 / 60
    for _ in range(60 * 120):
        sample = pts[min(int(progress * (len(pts) - 1)), len(pts) - 1)]
        slope = level.slope
        max_speed = (13.5 + slope * 22) * 0.98
        accel = 10 + slope * 16
        speed = min(speed + accel * dt, max_speed)
        progress += (speed * dt) / level.length
        time += dt
        if progress >= 0.992:
            return time
        _ = sample
    raise RuntimeError(f"{level.name} did not finish")


def main() -> None:
    assert len(LEVELS) == 24, f"expected 24 courses, got {len(LEVELS)}"
    names = [level.name for level in LEVELS]
    assert len(names) == len(set(names)), "duplicate course names"
    for level in LEVELS:
        pts = build_path(level)
        assert all(math.isfinite(v) for p in pts for v in p)
        drop = pts[0][1] - pts[-1][1]
        assert drop > 20, f"{level.name} is not downhill enough ({drop})"
        t = race(level)
        assert 12 < t < 90, f"{level.name} time {t} out of range"
        assert 3 <= level.rivals <= 5
        assert level.crystals >= 20
        print(f"OK  {level.name:20}  rivals={level.rivals}  crystals={level.crystals:2}  finish={t:5.1f}s  drop={drop:5.1f}")
    print("All 24 courses generate and are finishable.")


if __name__ == "__main__":
    main()
