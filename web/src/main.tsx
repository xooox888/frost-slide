/**
 * Boots the game: platform services, the save, the app model, then the UI.
 */
import { render } from 'preact';
import { AppModel } from './app/appModel';
import { GamePersistence, SAVE_KEY } from './core/persistence';
import { createServices } from './platform';
import { App } from './ui/App';

async function boot(): Promise<void> {
  const services = await createServices();
  const persistence = GamePersistence.fromJSON(await services.storage.load(SAVE_KEY), {
    save: (json) => void services.storage.save(SAVE_KEY, json),
    debug: import.meta.env.DEV,
  });
  const app = new AppModel(persistence, services);

  const root = document.getElementById('app');
  if (!root) throw new Error('index.html has no #app element');
  render(<App app={app} />, root);
  services.ready();

  // Browsers keep audio muted until a touch; every touch retries (iOS can suspend it again).
  void services.audio.preload();
  for (const type of ['pointerdown', 'pointerup', 'touchend', 'keydown'] as const) {
    window.addEventListener(type, () => services.audio.unlock(), { capture: true, passive: true });
  }
  void services.store.start();
  void services.ads.start();

  // `?autopilot=expert` lets a scripted bot race (the end-to-end tests use it).
  const params = new URLSearchParams(location.search);
  if (params.has('autopilot')) {
    const { attachAutopilot } = await import('./dev/autopilot');
    attachAutopilot(app, params);
  }
}

void boot();
