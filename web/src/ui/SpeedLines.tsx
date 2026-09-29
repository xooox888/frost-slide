/**
 * Edge streaks that fade in above cruising speed so boosts feel fast. A port of
 * `SpeedLinesOverlay` in `UI/GameContainerView.swift`, with the same maths, drawn on a 2D canvas
 * over the 3D view. Off with Reduce Motion.
 *
 * It follows the HUD snapshot (speed and race clock) from an animation frame instead of
 * subscribing to it, so it never re-renders anything.
 */
import { useEffect, useRef } from 'preact/hooks';
import type { AppModel } from '../app/appModel';
import type { HUDSnapshot } from '../core/models';

const COUNT = 36;

export function SpeedLines({ app }: { app: AppModel }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    const context = canvas?.getContext('2d');
    if (!canvas || !context) return;
    let width = 0;
    let height = 0;
    let scale = 1;
    let drawn: HUDSnapshot | null = null;
    let drawnReduceMotion = false;
    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      scale = Math.min(window.devicePixelRatio || 1, 2);
      width = rect.width;
      height = rect.height;
      canvas.width = Math.round(width * scale);
      canvas.height = Math.round(height * scale);
      drawn = null;
    };
    const observer = new ResizeObserver(resize);
    observer.observe(canvas);
    resize();

    let frame = 0;
    const draw = () => {
      frame = requestAnimationFrame(draw);
      const hud = app.hud.peek();
      const reduceMotion = app.services.reduceMotion.peek();
      // The picture only changes with a new HUD snapshot (about 30 a second), like the Swift Canvas.
      if (hud === drawn && reduceMotion === drawnReduceMotion) return;
      drawn = hud;
      drawnReduceMotion = reduceMotion;

      context.setTransform(scale, 0, 0, scale, 0, 0);
      context.clearRect(0, 0, width, height);
      const intensity = Math.min(1, Math.max(0, (hud.speedKph - 64) / 26));
      if (intensity <= 0 || reduceMotion) return;
      const centerX = width / 2;
      const centerY = height * 0.46;
      const reach = Math.max(width, height) * 0.75;
      for (let i = 0; i < COUNT; i += 1) {
        const seed = i * 12.9898;
        const jitter = seed - Math.floor(seed);
        const angle = (i / COUNT) * 2 * Math.PI + Math.sin(seed) * 0.12;
        const speed = 2.2 + jitter * 1.6;
        const phase = (hud.time * speed + jitter * 3.1) % 1;
        const inner = reach * (0.42 + phase * 0.5);
        const length = reach * (0.08 + intensity * 0.16);
        const dx = Math.cos(angle);
        const dy = Math.sin(angle);
        context.beginPath();
        context.moveTo(centerX + dx * inner, centerY + dy * inner);
        context.lineTo(centerX + dx * (inner + length), centerY + dy * (inner + length));
        context.strokeStyle = `rgba(158, 219, 255, ${0.5 * intensity * (1 - phase * 0.5)})`;
        context.lineWidth = 1.5 + jitter * 2;
        context.stroke();
      }
    };
    frame = requestAnimationFrame(draw);
    return () => {
      cancelAnimationFrame(frame);
      observer.disconnect();
    };
  }, [app]);

  return <canvas ref={ref} class="race-speedlines" aria-hidden="true" />;
}
