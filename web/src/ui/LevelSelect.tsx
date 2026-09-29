/**
 * The course map. A port of `UI/LevelSelectView.swift`: today's daily, then the eight worlds with
 * a card per course, each with a top-down sketch of its track.
 */
import { useId } from 'preact/hooks';
import type { AppModel } from '../app/appModel';
import { level } from '../core/levelCatalog';
import { LEVEL_IDS, levelOrder, type LevelDefinition, type LevelID, type LevelRecord } from '../core/models';
import { GOAL_INFO, WORLDS, goalDetail, type WorldInfo } from '../core/progression';
import { BackButton, Snowfall } from './components';
import { GOAL_SYMBOL, SFSymbol, WORLD_SYMBOL } from './icons';
import { LEVEL_ACCENT, SYSTEM_COLOR, formatPar, formatTime, placeWord, rgbTriplet } from './theme';
import './levelSelect.css';

export function LevelSelect({ app }: { app: AppModel }) {
  const save = app.save;
  const reduceMotion = app.services.reduceMotion.value;
  const hintId = useId();

  return (
    <div class="screen map" style={{ '--banner-h': `${app.services.ads.bannerHeight.value}px` }}>
      <div class="map-backdrop" aria-hidden="true" />
      <Snowfall density={18} reduceMotion={reduceMotion} />

      <div class="map-layout">
        <header class="map-header">
          <BackButton tone="onDark" onClick={() => app.goTo('menu')} />
          <div class="map-heading">
            <h1 class="map-title">Course Map</h1>
            <p class="map-summary">
              {`${save.totalStars} of ${LEVEL_IDS.length * 3} stars  ·  ${LEVEL_IDS.length} courses`}
            </p>
          </div>
        </header>

        <div class="map-scroll scroll-area">
          <div class="map-list">
            <DailyCard app={app} />
            {WORLDS.map((world) => (
              <WorldSection key={world.id} app={app} world={world} hintId={hintId} />
            ))}
          </div>
        </div>
      </div>

      <span id={`${hintId}-open`} hidden>
        Starts the race
      </span>
      <span id={`${hintId}-locked`} hidden>
        Finish the previous course to unlock
      </span>
    </div>
  );
}

function DailyCard({ app }: { app: AppModel }) {
  const save = app.save;
  const pick = app.dailyPick.value;
  const course = level(pick.level);
  const goal = GOAL_INFO[pick.goal];
  const done = save.dailyDoneToday;
  const streak = save.activeDailyStreak;

  return (
    <button type="button" class="map-daily" onClick={() => app.playDaily()}>
      <span class={done ? 'map-daily-badge is-done' : 'map-daily-badge'}>
        <SFSymbol name={done ? 'checkmark' : GOAL_SYMBOL[goal.icon]} size={26} />
      </span>
      <span class="map-daily-text">
        <span class="map-daily-title">{done ? 'Daily complete' : `Daily · ${goal.title}`}</span>
        <span class="map-daily-detail">
          {`${course.name}  ·  ${goalDetail(pick.goal, course.parTime, course.crystalStar)}`}
        </span>
      </span>
      {streak > 0 && (
        <span class="map-daily-streak">
          <SFSymbol name="flame.fill" size={20} />
          <span aria-hidden="true">{streak}</span>
          <span class="sr-only">{`${streak}-day streak`}</span>
        </span>
      )}
      <SFSymbol name="play.fill" size={20} class="map-daily-play" />
    </button>
  );
}

function WorldSection({ app, world, hintId }: { app: AppModel; world: WorldInfo; hintId: string }) {
  const save = app.save;
  const stars = world.courses.reduce((sum, id) => sum + (save.records.get(id)?.bestStars ?? 0), 0);
  return (
    <section class="map-world">
      <div class="map-world-head">
        <SFSymbol name={WORLD_SYMBOL[world.icon]} />
        <h2 class="map-world-title">{world.title}</h2>
        <span class="map-world-stars">{`${stars}/${world.courses.length * 3}`}</span>
      </div>
      <p class="map-world-blurb">{world.blurb}</p>
      {world.courses.map((id) => (
        <LevelCard
          key={id}
          course={level(id)}
          unlocked={save.isUnlocked(id)}
          record={save.records.get(id) ?? null}
          hintId={hintId}
          onPlay={() => app.play(id)}
        />
      ))}
    </section>
  );
}

/** Best result so far, or the par time to aim for on a course that has not been finished. */
function cardFooter(course: LevelDefinition, unlocked: boolean, record: LevelRecord | null): string {
  if (!unlocked) return 'Finish previous';
  if (record && record.bestTime < 9000) return `Best ${placeWord(record.bestPlace)} · ${formatTime(record.bestTime)}`;
  return `Par ${formatPar(course.parTime)}`;
}

const THUMBNAILS: Partial<Record<LevelID, string>> = {
  villageDash: './art/thumb-village.jpg',
  iceCaveSpiral: './art/thumb-cave.jpg',
  auroraNight: './art/thumb-aurora.jpg',
};

interface LevelCardProps {
  course: LevelDefinition;
  unlocked: boolean;
  record: LevelRecord | null;
  hintId: string;
  onPlay: () => void;
}

function LevelCard({ course, unlocked, record, hintId, onPlay }: LevelCardProps) {
  const number = levelOrder(course.id) + 1;
  const stars = record?.bestStars ?? 0;
  const perfect = record?.perfect === true;

  const footer = cardFooter(course, unlocked, record);
  let label = `Course ${number}, ${course.name}. ${course.subtitle}.`;
  if (!unlocked) label += ' Locked.';
  else label += ` ${stars} of 3 stars.${perfect ? ' Perfect run.' : ''} ${footer}.`;

  const thumbnail = THUMBNAILS[course.id];
  return (
    <button
      type="button"
      class={unlocked ? 'level-card' : 'level-card is-locked'}
      style={{ '--accent-rgb': rgbTriplet(LEVEL_ACCENT[course.theme]) }}
      disabled={!unlocked}
      aria-label={label}
      aria-describedby={`${hintId}-${unlocked ? 'open' : 'locked'}`}
      onClick={onPlay}
    >
      <span class="level-thumb" aria-hidden="true">
        {thumbnail && <img src={thumbnail} alt="" loading="lazy" decoding="async" />}
        <TrackPreview course={course} />
      </span>
      <span class="level-body">
        <span class="level-head">
          <span class="level-number">{String(number).padStart(2, '0')}</span>
          <span class="level-names">
            <span class="level-name">{course.name}</span>
            <span class="level-subtitle">{course.subtitle}</span>
          </span>
          {unlocked ? (
            <span class="level-stars">
              {[1, 2, 3].map((i) => (
                <SFSymbol
                  key={i}
                  name={i <= stars ? 'star.fill' : 'star'}
                  size={18}
                  class={i <= stars ? 'is-earned' : undefined}
                />
              ))}
              {perfect && <SFSymbol name="seal.fill" size={18} class="level-perfect" />}
            </span>
          ) : (
            <SFSymbol name="lock.fill" size={18} class="level-lock" />
          )}
        </span>
        <span class="level-blurb">{course.blurb}</span>
        <span class="level-foot">
          <span class="level-racers">
            <SFSymbol name="person.3.fill" size={16} />
            {`${course.rivals.length + 1} racers`}
          </span>
          <span>{footer}</span>
        </span>
      </span>
    </button>
  );
}

// MARK: - Track sketch

const SKETCH_WIDTH = 72;
const SKETCH_HEIGHT = 96;
const outlines = new Map<LevelID, string>();

/**
 * The course's centre line seen from above, start at the top, drawn from the same curve data the
 * track is built from, so a hairpin course looks like a hairpin course.
 */
function TrackPreview({ course }: { course: LevelDefinition }) {
  let points = outlines.get(course.id);
  if (points === undefined) {
    points = fitOutline(trackOutline(course), SKETCH_WIDTH, SKETCH_HEIGHT);
    outlines.set(course.id, points);
  }
  const coords = points.split(' ');
  const [startX, startY] = coords[0].split(',');
  const [endX, endY] = coords[coords.length - 1].split(',');
  return (
    <svg class="level-track" viewBox={`0 0 ${SKETCH_WIDTH} ${SKETCH_HEIGHT}`} aria-hidden="true" focusable="false">
      <polyline points={points} stroke="rgba(0, 0, 0, 0.28)" stroke-width="6.5" />
      <polyline points={points} stroke="#fff" stroke-width="4" />
      <circle cx={startX} cy={startY} r="4" fill={SYSTEM_COLOR.green} />
      <circle cx={endX} cy={endY} r="4" fill={SYSTEM_COLOR.red} />
    </svg>
  );
}

/**
 * Centre line in map space: x to the right, y down the screen (`TrackPreview.outline`). The track
 * heads along +z with yaw measured toward +x, which on a top-down map with the start at the top
 * puts +z down the screen and +x to the right.
 */
function trackOutline(course: LevelDefinition, samples = 90): { x: number; y: number }[] {
  const points: { x: number; y: number }[] = [];
  let x = 0;
  let y = 0;
  let yaw = 0;
  const step = course.length / (samples - 1);
  for (let i = 0; i < samples; i += 1) {
    const t = i / (samples - 1);
    let delta = 0;
    for (const curve of course.curves) {
      if (t >= curve.start && t <= curve.end) {
        delta += curve.yawRadians / Math.max(0.001, curve.end - curve.start) / (samples - 1);
      }
    }
    yaw += delta;
    points.push({ x, y });
    x += step * Math.sin(yaw);
    y += step * Math.cos(yaw);
  }
  return points;
}

/** Scales the outline into the thumbnail with a 14 pt inset, centred, as the Swift Canvas does. */
function fitOutline(points: { x: number; y: number }[], width: number, height: number): string {
  let minX = points[0].x;
  let maxX = minX;
  let minY = points[0].y;
  let maxY = minY;
  for (const p of points) {
    minX = Math.min(minX, p.x);
    maxX = Math.max(maxX, p.x);
    minY = Math.min(minY, p.y);
    maxY = Math.max(maxY, p.y);
  }
  const inset = 14;
  const spanX = Math.max(maxX - minX, 1);
  const spanY = Math.max(maxY - minY, 1);
  const scale = Math.min((width - inset * 2) / spanX, (height - inset * 2) / spanY);
  const originX = (width - spanX * scale) / 2 - minX * scale;
  const originY = (height - spanY * scale) / 2 - minY * scale;
  return points.map((p) => `${(p.x * scale + originX).toFixed(2)},${(p.y * scale + originY).toFixed(2)}`).join(' ');
}
