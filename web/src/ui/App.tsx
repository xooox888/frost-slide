/**
 * The root view: one screen at a time, cross-fading for 0.28 s (ease in-out) when the screen
 * changes, or switching at once with Reduce Motion. A port of `RootView` in
 * `FrostSlideApp.swift`.
 *
 * On a phone the screens fill the display; in a wider window they sit in a phone-width column.
 */
import '@fontsource/nunito/500.css';
import '@fontsource/nunito/600.css';
import '@fontsource/nunito/700.css';
import '@fontsource/nunito/900.css';
import './theme.css';
import { useEffect, useLayoutEffect, useRef, useState } from 'preact/hooks';
import type { AppModel, Screen } from '../app/appModel';
import { GameScreen } from './GameScreen';
import { LevelSelect } from './LevelSelect';
import { MainMenu } from './MainMenu';
import { Results } from './Results';
import { Settings } from './Settings';

/** `.animation(.easeInOut(duration: 0.28), value: app.screen)`; keep `theme.css` in step. */
const FADE_MS = 280;

interface Layer {
  id: number;
  screen: Screen;
  phase: 'shown' | 'entering' | 'leaving';
}

export function App({ app }: { app: AppModel }) {
  const screen = app.screen.value;
  const reduceMotion = app.services.reduceMotion.value;
  const [layers, setLayers] = useState<Layer[]>(() => [{ id: 0, screen, phase: 'shown' }]);
  const nextId = useRef(1);

  // A new screen fades in over the old one, which fades out and is then removed.
  useLayoutEffect(() => {
    setLayers((current) => {
      if (current.find((layer) => layer.phase !== 'leaving')?.screen === screen) return current;
      const id = nextId.current++;
      if (reduceMotion) return [{ id, screen, phase: 'shown' }];
      return [...current.map((layer): Layer => ({ ...layer, phase: 'leaving' })), { id, screen, phase: 'entering' }];
    });
  }, [screen, reduceMotion]);

  useEffect(() => {
    if (!layers.some((layer) => layer.phase === 'leaving')) return;
    const timer = setTimeout(
      () => setLayers((current) => current.filter((layer) => layer.phase !== 'leaving')),
      FADE_MS,
    );
    return () => clearTimeout(timer);
  }, [layers]);

  return (
    <div class="app">
      <div class="app-stage">
        {layers.map((layer) => (
          <ScreenLayer key={layer.id} app={app} layer={layer} />
        ))}
      </div>
    </div>
  );
}

function ScreenLayer({ app, layer }: { app: AppModel; layer: Layer }) {
  const ref = useRef<HTMLDivElement>(null);

  // Keyboard and screen reader focus moves to the new screen instead of staying on a button
  // that is fading away. The first screen of a launch leaves focus alone.
  useEffect(() => {
    if (layer.id !== 0) ref.current?.focus({ preventScroll: true });
  }, [layer.id]);

  const leaving = layer.phase === 'leaving';
  return (
    <div ref={ref} class="layer" data-phase={layer.phase} tabIndex={-1} inert={leaving}>
      <ScreenView app={app} screen={layer.screen} />
    </div>
  );
}

function ScreenView({ app, screen }: { app: AppModel; screen: Screen }) {
  switch (screen) {
    case 'menu':
      return <MainMenu app={app} />;
    case 'levelSelect':
      return <LevelSelect app={app} />;
    case 'settings':
      return <Settings app={app} />;
    case 'playing':
      return <GameScreen app={app} />;
    case 'results':
      return <Results app={app} />;
  }
}
