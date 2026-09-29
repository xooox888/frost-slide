/**
 * One bot race, sampled every half second, in the format of the Swift harness's `bottrace`.
 *
 *   npx tsx scripts/bottrace.ts <course index 0-23> <bot> <seed>
 */
import { level } from '../src/core/levelCatalog';
import { DEFAULT_SETTINGS, LEVEL_IDS } from '../src/core/models';
import { BOTS, Bot, isBotName } from '../src/dev/bots';
import { GameEngine } from '../src/engine/gameEngine';

const [indexArg = '0', botArg = 'good', seedArg = '1'] = process.argv.slice(2);
if (!isBotName(botArg)) throw new Error(`unknown bot ${botArg}`);
const engine = new GameEngine();
engine.start(level(LEVEL_IDS[Number(indexArg)]), { ...DEFAULT_SETTINGS });
const bot = new Bot(BOTS[botArg], BigInt(seedArg));
const dt = Math.fround(1 / 60);
const step = Number(process.env.TRACE_STEP ?? 0.5);
let next = 0;
let clock = 0;
for (let n = 0; n < 60 * 60; n += 1) {
  bot.update(engine, dt);
  engine.tick(dt);
  clock += dt;
  if (engine.phase === 'finished') break;
  const me = engine.playerRacer;
  if (clock >= next && me) {
    next += step;
    console.log(
      `BOT ${clock.toFixed(2)} ${me.progress.toFixed(6)} ${me.lateral.toFixed(5)} ${me.speed.toFixed(5)} ${me.turbo.toFixed(5)} ${me.crystals} ${me.hits}`,
    );
  }
}
