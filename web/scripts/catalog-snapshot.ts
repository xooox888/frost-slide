/**
 * Rewrites `tests/fixtures/swift-catalog.json` from the TypeScript catalog, in the format the
 * Swift harness dumps. Use it after changing a course on purpose, once the Swift app is no longer
 * the reference, and review the diff before committing.
 *
 *   npm run catalog:snapshot
 */
import { writeFileSync } from 'node:fs';
import { buildLevel } from '../src/core/levelCatalog';
import { LEVEL_IDS } from '../src/core/models';

const levels = LEVEL_IDS.map((id) => {
  const l = buildLevel(id, () => 0);
  return {
    id,
    name: l.name,
    subtitle: l.subtitle,
    blurb: l.blurb,
    theme: l.theme,
    length: l.length,
    baseWidth: l.baseWidth,
    slope: l.slope,
    startHeight: l.startHeight,
    parTime: l.parTime,
    crystalTarget: l.crystalTarget,
    crystalStar: l.crystalStar,
    checkpoints: l.checkpoints,
    palette: l.palette,
    curves: l.curves.map((c) => [c.start, c.end, c.yawRadians]),
    widths: l.widths.map((w) => [w.at, w.width, w.span]),
    elevations: l.elevations.map((e) => [e.at, e.height, e.span]),
    events: l.events.map((e) => [e.kind, e.start, e.end, e.lateral, e.magnitude]),
    rivals: l.rivals.map((r) => [r.id, r.name, r.color, r.personality, r.skill, r.startLateral]),
    firstIds: l.entities.slice(0, 3).map((e) => e.id),
    entities: l.entities.map((e) => [e.kind, e.progress, e.lateral, e.yaw, e.scale, e.radius]),
  };
});
const out = new URL('../tests/fixtures/swift-catalog.json', import.meta.url);
writeFileSync(out, JSON.stringify(levels, null, 1) + '\n');
console.log(`wrote ${levels.length} courses to ${out.pathname}`);
