/**
 * The finish screen. A port of `UI/ResultsView.swift`: place and stars (revealed one by one, with
 * confetti for three), where each star came from, the daily, the next sled, the podium, and the
 * way on. Leaving (next course, map, menu) goes through `app.leaveResults`, which may show a
 * full-screen ad first; a rematch never does.
 */
import confetti from 'canvas-confetti';
import { useEffect, useRef, useState } from 'preact/hooks';
import type { AppModel } from '../app/appModel';
import { cssColor } from '../core/math';
import {
  beatPar,
  hitCrystalGoal,
  isPerfect,
  nextLevel,
  resultPoints,
  type PodiumEntry,
  type RaceResult,
} from '../core/models';
import { GOAL_INFO, SKIN_INFO, type DailyGoal, type SledSkin } from '../core/progression';
import { FrostButton, FrostCard, Snowfall } from './components';
import { GOAL_SYMBOL, SFSymbol } from './icons';
import { FROST, formatGap, formatPar, formatTime, hexColor, placeWord } from './theme';
import './results.css';

/** Seconds from appearing to the first star, and between stars (`revealStars`). */
const REVEAL_DELAY = 0.3;
const REVEAL_STEP = 0.4;

export function Results({ app }: { app: AppModel }) {
  const result = app.lastResult.value;
  const save = app.save;
  const reduceMotion = app.services.reduceMotion.value;
  const hasNext = nextLevel(app.selectedLevel.value) !== null;
  const [shownStars, setShownStars] = useState(() => (app.services.reduceMotion.peek() ? (result?.stars ?? 0) : 0));
  const confettiCanvas = useRef<HTMLCanvasElement>(null);

  // Stars pop in one after another; three stars earn a burst once the last one has landed.
  useEffect(() => {
    if (!result) return;
    const stars = result.stars;
    if (app.services.reduceMotion.peek()) {
      setShownStars(stars);
      return;
    }
    setShownStars(0);
    const timers: number[] = [];
    const after = (seconds: number, action: () => void) => timers.push(window.setTimeout(action, seconds * 1000));
    for (let i = 1; i <= Math.max(1, stars); i += 1) {
      after(REVEAL_DELAY + REVEAL_STEP * i, () => {
        setShownStars(i);
        app.fx.tap('light');
      });
    }
    let cannon: confetti.CreateTypes | null = null;
    if (stars === 3 && confettiCanvas.current) {
      const canvas = confettiCanvas.current;
      after(REVEAL_DELAY + REVEAL_STEP * 3 + 0.25, () => {
        cannon = confetti.create(canvas, { resize: true, disableForReducedMotion: true });
        fireConfetti(cannon, isPerfect(result), after);
        app.fx.comboHit();
      });
    }
    return () => {
      for (const timer of timers) clearTimeout(timer);
      cannon?.reset();
    };
  }, [app, result]);

  return (
    <div class="screen results">
      <div class="results-backdrop" aria-hidden="true" />
      <Snowfall density={22} reduceMotion={reduceMotion} />

      <div class="results-scroll scroll-area">
        <div class="results-content">
          {result && (
            <>
              <Summary result={result} shownStars={shownStars} />
              <Breakdown result={result} />
              {result.dailyGoal && (
                <DailyCard goal={result.dailyGoal} result={result} doneToday={save.dailyDoneToday} />
              )}
              {result.unlockedSkin ? (
                <p class="results-skin">{`New sled unlocked: ${SKIN_INFO[result.unlockedSkin].title}`}</p>
              ) : (
                save.nextSkinGoal && <p class="results-next-skin">{nextSkinLine(save.nextSkinGoal)}</p>
              )}
              <Standings result={result} />
            </>
          )}
        </div>

        {/* Pinned below the scrolling content so the next step is always in reach. */}
        <div class="results-actions">
          {hasNext && (
            <FrostButton
              title="Next Course"
              icon="forward.fill"
              color="ice"
              onClick={() => app.leaveResults(() => app.nextLevel())}
            />
          )}
          <div class="results-actions-row">
            <FrostButton
              title="Race Again"
              icon="arrow.counterclockwise"
              color="ochre"
              foreground="ink"
              onClick={() => app.restart()}
            />
            <FrostButton
              title="Course Map"
              icon="map.fill"
              color="inkSoft"
              onClick={() => app.leaveResults(() => app.backToMap())}
            />
          </div>
          <button type="button" class="results-menu" onClick={() => app.leaveResults(() => app.backToMenu())}>
            Main Menu
          </button>
        </div>
      </div>

      <canvas ref={confettiCanvas} class="results-confetti" aria-hidden="true" />
    </div>
  );
}

/**
 * ConfettiCannon(num: 44, or 70 for a perfect run, repeated 0.7 s later): pieces burst up from the
 * middle of the screen in a 40...140° fan, about 380 pt out, then rain down.
 */
function fireConfetti(
  cannon: confetti.CreateTypes,
  perfect: boolean,
  after: (seconds: number, action: () => void) => void,
): void {
  const burst = () =>
    void cannon({
      particleCount: perfect ? 70 : 44,
      angle: 90,
      spread: 100,
      startVelocity: 36,
      decay: 0.9,
      gravity: 1.1,
      ticks: 240,
      origin: { x: 0.5, y: 0.5 },
      colors: [hexColor(FROST.ice), hexColor(FROST.ochre), hexColor(FROST.berry), hexColor(FROST.grape), '#ffffff'],
      scalar: 1.1,
      disableForReducedMotion: true,
    });
  burst();
  if (perfect) after(0.7, burst);
}

// MARK: - Sections

function Summary({ result, shownStars }: { result: RaceResult; shownStars: number }) {
  const newBest = result.newBest && result.previousBest !== null;
  const perfect = isPerfect(result);
  const delta = timeDelta(result);
  return (
    <div class="results-summary">
      <h1 class={newBest ? 'results-headline is-best' : 'results-headline'}>{newBest ? 'New best!' : 'Finish'}</h1>
      <p class={result.place === 1 ? 'results-place is-winner' : 'results-place'}>{placeWord(result.place)}</p>
      <div class="results-stars" role="img" aria-label={`${result.stars} of 3 stars${perfect ? ', perfect run' : ''}`}>
        {[1, 2, 3].map((i) => (
          <span
            key={i}
            class={`results-star${i <= shownStars ? ' is-shown' : ''}${i === shownStars ? ' is-latest' : ''}`}
          >
            <SFSymbol name={i <= shownStars ? 'star.fill' : 'star'} size={40} />
          </span>
        ))}
        {perfect && <SFSymbol name="seal.fill" size={36} class="results-seal" />}
      </div>
      {perfect && <p class="results-perfect">PERFECT RUN</p>}
      {delta && <p class="results-delta">{delta}</p>}
    </div>
  );
}

function nextSkinLine({ skin, starsToGo }: { skin: SledSkin; starsToGo: number }): string {
  return `${starsToGo} more ${starsToGo === 1 ? 'star' : 'stars'} to unlock the ${SKIN_INFO[skin].title} sled`;
}

/** How this run compares with the previous best on the same course. */
function timeDelta(result: RaceResult): string | null {
  if (result.previousBest === null) return null;
  const diff = result.time - result.previousBest;
  return result.newBest ? `${formatGap(diff)} s vs your old best` : `${formatGap(diff)} s off your best`;
}

/** Where each star came from, and what is still on the table. */
function Breakdown({ result }: { result: RaceResult }) {
  const place = result.place;
  return (
    <FrostCard class="results-breakdown">
      <div class="results-breakdown-head">
        <span class="results-breakdown-title">STARS</span>
        <span class="results-breakdown-points">{`Bonus points ${resultPoints(result)}  ·  two earn 3 stars`}</span>
      </div>
      <Row title="Crossed the line" detail={`${result.fieldSize} racers`} earned points={null} />
      <Row
        title={place === 1 ? 'Won the race' : `Finished ${placeWord(place)}`}
        detail="Win = 2, second = 1"
        earned={place <= 2}
        points={place === 1 ? '+2' : place === 2 ? '+1' : '0'}
      />
      <Row
        title={`Crystals ${result.crystals}/${result.crystalTotal}`}
        detail={`Goal ${result.crystalGoal}`}
        earned={hitCrystalGoal(result)}
        points={hitCrystalGoal(result) ? '+1' : '0'}
      />
      <Row
        title={`Time ${formatTime(result.time)}`}
        detail={`Par ${formatPar(result.parTime)}`}
        earned={beatPar(result)}
        points={beatPar(result) ? '+1' : '0'}
      />
    </FrostCard>
  );
}

interface RowProps {
  title: string;
  detail: string;
  earned: boolean;
  /** "+2", "+1" or "0"; finishing itself has none. */
  points: string | null;
}

function Row({ title, detail, earned, points }: RowProps) {
  return (
    <div class={earned ? 'results-row is-earned' : 'results-row'}>
      <SFSymbol name={earned ? 'checkmark.circle.fill' : 'circle'} class="results-row-icon" />
      <span class="results-row-text">
        <span class="results-row-title">{title}</span>
        <span class="results-row-detail">{detail}</span>
      </span>
      {points !== null && <span class="results-row-points">{points}</span>}
    </div>
  );
}

function DailyCard({ goal, result, doneToday }: { goal: DailyGoal; result: RaceResult; doneToday: boolean }) {
  const info = GOAL_INFO[goal];
  let line: string;
  if (result.dailyMet) {
    line =
      result.dailyStreak > 1
        ? `Complete! ${result.dailyStreak}-day streak`
        : 'Complete! Come back tomorrow to start a streak';
  } else if (doneToday) {
    line = 'Already complete today';
  } else {
    line = 'Goal missed. Race again to have another go.';
  }
  // FrostCard(tint: pine.opacity(0.12)), which FrostCard fills at 0.78.
  const tint = result.dailyMet ? `rgb(var(--pine-rgb) / ${0.12 * 0.78})` : undefined;
  return (
    <FrostCard class={result.dailyMet ? 'results-daily is-met' : 'results-daily'} tint={tint}>
      <SFSymbol
        name={result.dailyMet ? 'checkmark.seal.fill' : GOAL_SYMBOL[info.icon]}
        size={26}
        class="results-daily-icon"
      />
      <span class="results-daily-text">
        <span class="results-daily-title">{`Daily · ${info.title}`}</span>
        <span class="results-daily-line">{line}</span>
      </span>
    </FrostCard>
  );
}

function Standings({ result }: { result: RaceResult }) {
  const you = result.standings.find((entry) => entry.isPlayer);
  const winner = result.standings[0]?.time ?? null;
  return (
    <div class="results-standings">
      <Podium entries={result.podium} />
      {you && you.place > 3 && (
        <p class="results-you">
          <span>{`You finished ${placeWord(you.place)}`}</span>
          {winner !== null && you.time !== null && (
            <span class="results-you-gap">{`${formatGap(you.time - winner)} s`}</span>
          )}
        </p>
      )}
    </div>
  );
}

function Podium({ entries }: { entries: PodiumEntry[] }) {
  const winnerTime = entries.find((entry) => entry.place === 1)?.time ?? null;
  // In place order for screen readers; the styles stand the winner in the middle (second, first, third).
  const ranked = [1, 2, 3]
    .map((place) => entries.find((entry) => entry.place === place))
    .filter((entry): entry is PodiumEntry => entry !== undefined);
  return (
    <ol class="results-podium">
      {ranked.map((entry) => (
        <li key={entry.id} class={`results-podium-entry place-${entry.place}`}>
          <span class="results-podium-sled" style={{ background: cssColor(entry.color) }} />
          <span class="results-podium-name">{entry.isPlayer ? 'You' : entry.name}</span>
          <span class="results-podium-block">{entry.place}</span>
          <span class="results-podium-time">{podiumTime(entry, winnerTime)}</span>
        </li>
      ))}
    </ol>
  );
}

/** The winner's time, then everyone else's gap to it. */
function podiumTime(entry: PodiumEntry, winnerTime: number | null): string {
  if (entry.time === null) return '';
  if (entry.place === 1 || winnerTime === null) return formatTime(entry.time);
  return formatGap(entry.time - winnerTime);
}
