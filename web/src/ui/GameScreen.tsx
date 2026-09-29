/**
 * The race screen. A port of `GamePlaySurface` in `UI/GameContainerView.swift`: the 3D view (a
 * full-screen canvas the game loop draws into), the speed lines, the HUD and, while paused, the
 * pause menu. A drag that starts anywhere but on a button steers; desktop players also get keys.
 *
 * Only the HUD reads `app.hud`, so this component renders once per race, not 30 times a second.
 */
import { useSignalEffect } from '@preact/signals';
import type { JSX } from 'preact';
import { useEffect, useMemo, useRef } from 'preact/hooks';
import type { AppModel } from '../app/appModel';
import { startGame, type GameView } from '../app/gameLoop';
import { cssColor } from '../core/math';
import { PauseMenu } from './PauseMenu';
import { RaceHUD } from './RaceHUD';
import { RaceControls, type HeldKey } from './raceControls';
import { SpeedLines } from './SpeedLines';
import './race.css';

/** Held keys (by physical position, so A/D sit under the left hand on any layout). */
const HELD_KEYS: Partial<Record<string, HeldKey>> = {
  ArrowLeft: 'left',
  KeyA: 'left',
  ArrowRight: 'right',
  KeyD: 'right',
  Space: 'boost',
  ArrowUp: 'boost',
};

/**
 * The race screen currently driving the engine. When a race screen mounts while the previous one
 * is still fading out, the old one stops, so the engine never ticks twice a frame.
 */
let activeView: GameView | null = null;

export function GameScreen({ app }: { app: AppModel }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const controls = useMemo(() => new RaceControls(app), [app]);
  const paused = app.paused.value;
  const showHints = app.save.totalRaces < 2;
  // The renderer clears to the course's fog colour; the page shows it too until the first frame.
  const fog = app.engine.level?.palette.fog;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    activeView?.stop();
    const view = stopOnce(startGame(canvas, app));
    activeView = view;
    const active = () => activeView === view && app.screen.peek() === 'playing';

    const onKeyDown = (event: KeyboardEvent) => {
      if (!active() || event.metaKey || event.ctrlKey || event.altKey) return;
      if (event.code === 'Escape' || event.code === 'KeyP') {
        event.preventDefault();
        if (event.repeat) return;
        if (app.paused.peek()) app.resume();
        else app.pause();
        return;
      }
      // While paused, Space and Enter belong to the pause menu's buttons.
      if (app.paused.peek()) return;
      const key = HELD_KEYS[event.code];
      if (key) {
        event.preventDefault();
        controls.keyDown(key);
      } else if (event.code === 'KeyB') {
        event.preventDefault();
        if (!event.repeat) app.dropPeel();
      }
    };
    const onKeyUp = (event: KeyboardEvent) => {
      const key = HELD_KEYS[event.code];
      if (!key) return;
      controls.keyUp(key);
      if (active() && !app.paused.peek()) event.preventDefault();
    };
    // Key-ups are lost while another window has focus.
    const onBlur = () => controls.releaseAll();
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    window.addEventListener('blur', onBlur);

    return () => {
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
      window.removeEventListener('blur', onBlur);
      view.stop();
      if (activeView !== view) return;
      activeView = null;
      // `.onDisappear`: no boost or steering is left on once the race screen is gone.
      controls.releaseAll();
    };
  }, [app, controls]);

  // Pausing lets go of every finger and key; the player presses again after resuming.
  useSignalEffect(() => {
    if (app.paused.value) controls.releaseAll();
  });

  const onPointerDown = (event: JSX.TargetedPointerEvent<HTMLDivElement>) => {
    // A second finger on the slope doesn't steal the steering; a fresh (primary) touch always
    // takes it, so a lost pointer-up can never leave the sled turning.
    if (app.paused.peek() || (controls.steering && !event.isPrimary)) return;
    if (event.pointerType === 'mouse' && event.button !== 0) return;
    // Buttons (pause, peel, refill, boost) keep their touches; everything else is the slope.
    if (event.target instanceof Element && event.target.closest('button')) return;
    controls.startSteer(event.pointerId, event.clientX);
    event.currentTarget.setPointerCapture(event.pointerId);
  };
  const onPointerMove = (event: JSX.TargetedPointerEvent<HTMLDivElement>) => {
    controls.moveSteer(event.pointerId, event.clientX);
  };
  const onPointerEnd = (event: JSX.TargetedPointerEvent<HTMLDivElement>) => {
    controls.endSteer(event.pointerId);
  };

  return (
    <div
      class="screen race"
      style={fog ? { background: cssColor(fog) } : undefined}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerEnd}
      onPointerCancel={onPointerEnd}
      onLostPointerCapture={onPointerEnd}
      onContextMenu={(event) => event.preventDefault()}
    >
      <canvas ref={canvasRef} class="race-canvas" aria-hidden="true" />
      <SpeedLines app={app} />
      <RaceHUD app={app} controls={controls} showHints={showHints} inert={paused} />
      {paused && <PauseMenu app={app} />}
    </div>
  );
}

/** `stop()` may come from the next race screen and again from this one's unmount. */
function stopOnce(view: GameView): GameView {
  let stopped = false;
  return {
    stop() {
      if (stopped) return;
      stopped = true;
      view.stop();
    },
  };
}
