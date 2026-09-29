/**
 * The scripted race used to compare the TypeScript engine with the Swift one (see
 * `tools/headless/Sources/Dump.swift`, `dumpTrace`): a slow weave, boost in one-second bursts
 * every three seconds, sampled every `step` seconds.
 */
import { level } from '../../src/core/levelCatalog';
import { DEFAULT_SETTINGS, LEVEL_IDS } from '../../src/core/models';
import { GameEngine } from '../../src/engine/gameEngine';

export interface TraceRow {
  t: number;
  progress: number;
  lateral: number;
  speed: number;
  turbo: number;
  crystals: number;
  hits: number;
  rivalProgress: number;
  rivalLateral: number;
  rivalSpeed: number;
}

export function traceCourse(
  index: number,
  {
    fps = 60,
    step = 0.5,
    until = 40,
    solo = false,
  }: { fps?: number; step?: number; until?: number; solo?: boolean } = {},
): TraceRow[] {
  const engine = new GameEngine();
  const def = level(LEVEL_IDS[index]);
  engine.start(solo ? { ...def, rivals: [] } : def, { ...DEFAULT_SETTINGS });
  const dt = 1 / fps;
  const rows: TraceRow[] = [];
  let clock = 0;
  let nextSample = 0;
  while (clock < until && !(engine.phase === 'finished' && clock > 36)) {
    engine.steerInput = Math.fround(Math.sin(clock * 1.3) * 0.8);
    engine.boostHeld = clock % 3 < 1;
    engine.tick(dt);
    clock += dt;
    if (clock >= nextSample) {
      nextSample += step;
      const me = engine.playerRacer;
      if (!me) continue;
      const rival = engine.racers.find((r) => !r.isPlayer) ?? me;
      rows.push({
        t: clock,
        progress: me.progress,
        lateral: me.lateral,
        speed: me.speed,
        turbo: me.turbo,
        crystals: me.crystals,
        hits: me.hits,
        rivalProgress: rival.progress,
        rivalLateral: rival.lateral,
        rivalSpeed: rival.speed,
      });
    }
  }
  return rows;
}
