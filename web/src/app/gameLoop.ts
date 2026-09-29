/**
 * The race loop: one engine tick and one frame per display refresh. A port of the
 * `CADisplayLink` coordinator in `UI/GameContainerView.swift`. The race screen starts it when its
 * canvas mounts and stops it when the screen goes away.
 */
import { clamp } from '../core/math';
import { RaceRenderer } from '../render/raceRenderer';
import type { AppModel } from './appModel';

export interface GameView {
  stop(): void;
}

/** Longest frame the engine accepts (it clamps the same way); longer gaps are a hiccup. */
const MAX_DT = 1 / 20;

export function startGame(canvas: HTMLCanvasElement, app: AppModel): GameView {
  const renderer = new RaceRenderer(canvas, { reduceMotion: () => app.services.reduceMotion.value });
  let running = true;
  let last = 0;
  let frame = 0;

  const resize = () => {
    const rect = canvas.getBoundingClientRect();
    renderer.resize(Math.max(1, rect.width), Math.max(1, rect.height), Math.min(window.devicePixelRatio || 1, 2));
  };
  const observer = new ResizeObserver(resize);
  observer.observe(canvas);
  resize();

  const step = (now: number) => {
    if (!running) return;
    frame = requestAnimationFrame(step);
    const raw = last === 0 ? 1 / 60 : (now - last) / 1000;
    last = now;
    const engine = app.engine;
    const dt = clamp(raw, 1 / 240, MAX_DT);
    const advanced = engine.phase !== 'idle' && !engine.paused;
    for (let i = 0; i < app.dev.ticksPerFrame; i += 1) {
      app.dev.beforeTick?.(engine, dt);
      engine.tick(raw);
      // Finishing can end the race screen from inside the tick.
      if (!running) return;
    }
    renderer.frame(engine, dt * app.dev.ticksPerFrame, advanced);
  };
  frame = requestAnimationFrame(step);

  return {
    stop() {
      running = false;
      cancelAnimationFrame(frame);
      observer.disconnect();
      renderer.dispose();
    },
  };
}
