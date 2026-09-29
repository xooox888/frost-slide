/**
 * A scripted race per course, sampled twice a second, in the same format as the Swift harness's
 * `tools/headless/run.sh trace`. Used to compare the two engines step by step:
 *
 *   npx tsx scripts/trace.ts [first last] [solo] > ts-trace.txt
 *
 * `solo` removes the rivals (see the Swift side for why).
 */
import { LEVEL_IDS } from '../src/core/models';
import { traceCourse } from '../tests/support/trace';

const first = Number(process.argv[2] ?? 0);
const last = Number(process.argv[3] ?? LEVEL_IDS.length - 1);
const solo = process.argv.includes('solo');
const fix = (v: number, d: number): string => v.toFixed(d);

const fps = Number(process.env.TRACE_FPS ?? 60);
const step = Number(process.env.TRACE_STEP ?? 0.5);
const until = Number(process.env.TRACE_UNTIL ?? 40);
for (let index = first; index <= last; index += 1) {
  for (const row of traceCourse(index, { fps, step, until, solo })) {
    console.log(
      [
        'TRACE',
        index,
        fix(row.t, 2),
        fix(row.progress, 6),
        fix(row.lateral, 5),
        fix(row.speed, 5),
        fix(row.turbo, 5),
        row.crystals,
        row.hits,
        fix(row.rivalProgress, 6),
        fix(row.rivalLateral, 5),
        fix(row.rivalSpeed, 5),
      ].join(' '),
    );
  }
}
