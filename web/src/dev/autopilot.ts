/**
 * `?autopilot=<bot>` for the end-to-end tests and demos: one of the scripted bots from the parity
 * sweeps drives the player's sled. `&speed=4` runs four engine ticks per frame so a race finishes
 * quickly. The app is also exposed as `window.frostSlide` so tests can drive the menus.
 */
import type { AppModel } from '../app/appModel';
import { BOTS, Bot, isBotName } from './bots';

export function attachAutopilot(app: AppModel, params: URLSearchParams): void {
  const name = params.get('autopilot');
  const profile = BOTS[isBotName(name) ? name : 'expert'];
  const speed = Math.max(1, Math.min(8, Number(params.get('speed')) || 1));
  let bot = new Bot(profile, 1);
  let raceId = -1;
  app.dev.ticksPerFrame = speed;
  app.dev.beforeTick = (engine, dt) => {
    if (engine.raceId !== raceId) {
      raceId = engine.raceId;
      bot = new Bot(profile, 1000 + raceId);
    }
    bot.update(engine, dt);
  };
  (window as unknown as { frostSlide: AppModel }).frostSlide = app;
}
