/**
 * Development course viewer (`/viewer.html`, not part of the app build): races a scripted bot
 * on a course and draws it, for checking the renderer course by course.
 *
 * Query: `course` (id or 1-based number), `bot` (idle, novice, casual, good, expert), `at`
 * (seconds to fast-forward before drawing), `seed`, `pause` (stop after fast-forwarding),
 * `reduce` (Reduce Motion). Sets `window.viewerReady` once the first frame is drawn.
 */
import { LEVEL_IDS, isLevelID, type LevelID } from '../core/models';
import { level } from '../core/levelCatalog';
import { GameEngine } from '../engine/gameEngine';
import { RaceRenderer } from '../render/raceRenderer';
import { BOTS, Bot, isBotName } from './bots';

const params = new URLSearchParams(location.search);
const courseParam = params.get('course') ?? 'villageDash';
const id: LevelID = isLevelID(courseParam) ? courseParam : (LEVEL_IDS[Number(courseParam) - 1] ?? 'villageDash');
const botName = params.get('bot');
const profile = BOTS[isBotName(botName) ? botName : 'expert'];
const at = Number(params.get('at') ?? 0);
const pauseAfter = params.has('pause');
const reduce = params.has('reduce');

const canvas = document.getElementById('view') as HTMLCanvasElement;
const info = document.getElementById('info') as HTMLDivElement;
const engine = new GameEngine();
engine.start(level(id), {
  steerSensitivity: 1,
  tiltSteering: false,
  unlockAll: false,
  hapticsEnabled: false,
  soundEnabled: false,
  showGhost: false,
  selectedSkin: 'cyan',
  shareUsageData: false,
});
const bot = new Bot(profile, Number(params.get('seed') ?? 7));
const renderer = new RaceRenderer(canvas, { reduceMotion: () => reduce });

const step = 1 / 60;
let finished = false;
engine.onFinished = () => {
  finished = true;
};
const fastForward = (seconds: number) => {
  for (let t = 0; t < seconds && !finished; t += step) {
    bot.update(engine, step);
    engine.tick(step);
    // Keep the renderer's effects (trail, spray) in step with a fast-forward.
    renderer.frame(engine, step, true, false);
  }
};

const resize = () => renderer.resize(canvas.clientWidth, canvas.clientHeight, Math.min(devicePixelRatio || 1, 2));
new ResizeObserver(resize).observe(canvas);
resize();
fastForward(at);

let last = 0;
let frames = 0;
const loop = (now: number) => {
  requestAnimationFrame(loop);
  const dt = last === 0 ? step : Math.min(0.05, (now - last) / 1000);
  last = now;
  const advance = !pauseAfter && !finished;
  if (advance) {
    bot.update(engine, dt);
    engine.tick(dt);
  }
  renderer.frame(engine, dt, advance);
  frames += 1;
  if (frames === 2) (window as unknown as { viewerReady: boolean }).viewerReady = true;
  const hud = engine.hud;
  const stats = renderer.stats;
  info.textContent =
    `${level(id).name} · ${hud.speedKph} km/h · ${Math.round(hud.progress * 100)}% · t ${engine.raceTime.toFixed(1)}s` +
    ` · ${stats.calls} calls · ${Math.round(stats.triangles / 1000)}k tris · ${stats.pixelRatio}x`;
  (window as unknown as { viewerStats: typeof stats }).viewerStats = stats;
};
requestAnimationFrame(loop);
