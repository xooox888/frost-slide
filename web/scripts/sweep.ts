/**
 * Balance sweep: races the scripted bots on every course and prints win, podium, par and
 * crystal-goal rates in the same format as the Swift harness (`tools/headless/run.sh sweep`),
 * so `tools/headless/summary.py` can read either.
 *
 *   npm run sweep -- [bot|all] [runs] [first last]
 *
 * With no course range it splits the 24 courses over four processes.
 */
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { level } from '../src/core/levelCatalog';
import { LEVEL_IDS, crystalCount } from '../src/core/models';
import { BOTS, BOT_ORDER, isBotName, runRace, type BotProfile } from '../src/dev/bots';

const [which = 'all', runsArg = '12', firstArg, lastArg] = process.argv.slice(2);
const runs = Number(runsArg);

const pct = (n: number, d: number): string => ((n / Math.max(1, d)) * 100).toFixed(0).padStart(3);

function sweep(profiles: BotProfile[], first: number, last: number): void {
  for (const profile of profiles) {
    for (let index = first; index <= last; index += 1) {
      const id = LEVEL_IDS[index];
      const def = level(id);
      let wins = 0;
      let podium = 0;
      let par = 0;
      let goal = 0;
      let unfinished = 0;
      let finished = 0;
      let place = 0;
      let time = 0;
      let crystals = 0;
      let crashes = 0;
      let stars = 0;
      let combo = 0;
      for (let k = 0; k < runs; k += 1) {
        const { stat } = runRace(id, profile, 1000 + index * 131 + k * 7919);
        if (!stat.finished) {
          unfinished += 1;
          continue;
        }
        finished += 1;
        if (stat.place === 1) wins += 1;
        if (stat.place <= 3) podium += 1;
        if (stat.time <= def.parTime) par += 1;
        if (stat.crystals >= def.crystalStar) goal += 1;
        place += stat.place;
        time += stat.time;
        crystals += stat.crystals;
        crashes += stat.crashes;
        stars += stat.stars;
        combo += stat.comboMax;
      }
      const n = Math.max(1, finished);
      console.log(
        `${profile.name.padEnd(6)} ${String(index + 1).padStart(2, '0')} ${def.name.padEnd(17)} ` +
          `win ${pct(wins, n)}% top3 ${pct(podium, n)}% place ${(place / n).toFixed(2)} ` +
          `time ${(time / n).toFixed(1).padStart(5)} (par ${def.parTime.toFixed(0).padStart(2)}, made ${pct(par, n)}%) ` +
          `crys ${(crystals / n).toFixed(1).padStart(4)}/${crystalCount(def)} (star ${String(def.crystalStar).padStart(2)}: ${pct(goal, n)}%) ` +
          `crashes ${(crashes / n).toFixed(1)} stars ${(stars / n).toFixed(2)} combo ${(combo / n).toFixed(1)} dnf ${unfinished}`,
      );
    }
  }
}

const profiles = which === 'all' ? BOT_ORDER.map((b) => BOTS[b]) : isBotName(which) ? [BOTS[which]] : [];
if (profiles.length === 0) {
  console.error(`unknown bot "${which}" (use ${BOT_ORDER.join(', ')} or all)`);
  process.exit(1);
}

if (firstArg !== undefined) {
  sweep(profiles, Number(firstArg), Number(lastArg ?? firstArg));
} else {
  // Four processes, six courses each.
  const self = fileURLToPath(import.meta.url);
  const slices = [
    [0, 5],
    [6, 11],
    [12, 17],
    [18, 23],
  ];
  const outputs = await Promise.all(
    slices.map(
      ([a, b]) =>
        new Promise<string>((resolve, reject) => {
          const child = spawn(process.execPath, [...process.execArgv, self, which, runsArg, String(a), String(b)], {
            stdio: ['ignore', 'pipe', 'inherit'],
          });
          let out = '';
          child.stdout.on('data', (d: Buffer) => (out += d.toString()));
          child.on('close', (code) => (code === 0 ? resolve(out) : reject(new Error(`slice ${a}-${b} failed`))));
        }),
    ),
  );
  const lines = outputs.join('').split('\n').filter(Boolean);
  const order = new Map(BOT_ORDER.map((b, i) => [b, i]));
  lines.sort((x, y) => (order.get(x.split(' ')[0] as never) ?? 0) - (order.get(y.split(' ')[0] as never) ?? 0));
  console.log(lines.join('\n'));
}
