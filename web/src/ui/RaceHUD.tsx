/**
 * The race HUD. A port of `UI/RaceHUDView.swift`: place, clock, crystals and speed at the top,
 * the progress rail with rivals and the avalanche, the countdown briefing or a toast in the
 * middle, and turbo, power-ups, REFILL, PEEL and BOOST at the bottom.
 *
 * It reads `app.hud` itself, so the engine's 30 snapshots a second re-render only this.
 */
import type { JSX } from 'preact';
import { useId, useRef } from 'preact/hooks';
import type { AppModel } from '../app/appModel';
import { cssColor, saturate } from '../core/math';
import type { HUDSnapshot } from '../core/models';
import { SFSymbol, type SymbolName } from './icons';
import type { RaceControls } from './raceControls';
import { SYSTEM_COLOR, cssVar, formatGap, formatPar, formatTime, placeWord, type FrostColor } from './theme';

interface RaceHUDProps {
  app: AppModel;
  controls: RaceControls;
  /** First races only: spells out the controls. */
  showHints: boolean;
  /** Behind the pause menu. */
  inert: boolean;
}

export function RaceHUD({ app, controls, showHints, inert }: RaceHUDProps) {
  const hud = app.hud.value;
  const rewardedReady = app.services.ads.rewardedReady.value;
  const pause = useGameTap(() => app.pause());
  const refill = useGameTap(() => app.requestRewardedTurbo());
  const peel = useGameTap(() => app.dropPeel());

  // Offered only once the meter is really empty and there is enough race left to use a refill.
  const showRewarded =
    hud.racing &&
    !hud.rewardedTurboUsed &&
    rewardedReady &&
    hud.turbo < 0.06 &&
    hud.progress > 0.12 &&
    hud.progress < 0.85 &&
    hud.countdown === null;
  const avalanche = Math.trunc(hud.avalancheGap);
  const turbo = saturate(hud.turbo);
  // Seconds behind (positive, berry) or ahead of (cyan) the best-run ghost.
  const ghost = hud.ghostGap;

  return (
    <div class="hud" inert={inert}>
      <div class="hud-top">
        <div class="hud-plate hud-place">
          <span class="hud-place-word" aria-hidden="true">
            {placeWord(hud.place)}
          </span>
          <span class="hud-caption" aria-hidden="true">{`of ${hud.fieldSize}`}</span>
          <span class="sr-only">{`Position ${hud.place} of ${hud.fieldSize}`}</span>
        </div>
        <span class="hud-spacer" />
        <div class="hud-plate hud-stats">
          <span class="hud-time">{formatTime(hud.time)}</span>
          {ghost !== null && (
            <span class={ghost > 0 ? 'hud-ghost is-behind' : 'hud-ghost'}>{`Ghost ${formatGap(ghost)}`}</span>
          )}
          <span class="hud-crystals">
            <SFSymbol name="diamond.fill" size={16} />
            <span class="hud-caption">{`${hud.crystals}/${hud.crystalTotal}`}</span>
          </span>
          <span class="hud-speed">{`${hud.speedKph} km/h`}</span>
        </div>
        <button type="button" class="hud-pause" aria-label="Pause" {...pause}>
          <SFSymbol name="pause.fill" size={20} />
        </button>
      </div>

      <div class="hud-rail" aria-hidden="true">
        {/* Ground the avalanche has already swallowed. */}
        {hud.avalancheGap >= 0 && (
          <span class="hud-rail-avalanche" style={{ width: `max(6px, ${saturate(hud.avalancheProgress) * 100}%)` }} />
        )}
        {hud.checkpoints.map((cp, index) => (
          <span key={`cp${index}`} class="hud-rail-checkpoint" style={{ left: `${cp * 100}%` }} />
        ))}
        {hud.rivalProgress.map((p, index) => (
          <span
            key={`rival${index}`}
            class="hud-rail-rival"
            style={{
              left: `${saturate(p) * 100}%`,
              background: index < hud.rivalColors.length ? cssColor(hud.rivalColors[index]) : SYSTEM_COLOR.red,
            }}
          />
        ))}
        <span class="hud-rail-player" style={{ left: `${saturate(hud.progress) * 100}%` }} />
      </div>

      {/* How far behind the player the avalanche is, so the danger is readable without looking back. */}
      {hud.avalancheGap >= 0 && (
        <div class={hud.avalancheGap < 18 ? 'hud-wall is-close' : 'hud-wall'}>
          <SFSymbol name="snowflake" size={18} weight={2.5} />
          <span aria-hidden="true">{`AVALANCHE  ${avalanche} m`}</span>
          <span class="sr-only">{`Avalanche ${avalanche} metres behind`}</span>
        </div>
      )}

      <div class="hud-center">
        {hud.countdown !== null ? (
          <>
            {hud.countdown > 0 && <Briefing hud={hud} showHints={showHints} />}
            <span class="hud-countdown">{hud.countdown === 0 ? 'GO' : String(hud.countdown)}</span>
          </>
        ) : (
          hud.toast !== '' && <span class="hud-toast">{hud.toast}</span>
        )}
      </div>

      {showHints && hud.racing && hud.time < 5 && (
        <div class="hud-hint">
          <SFSymbol name="hand.draw.fill" size={15} />
          <span>{'Drag anywhere to steer  ·  Hold BOOST for speed'}</span>
        </div>
      )}

      <div class="hud-bottom">
        <div class="hud-plate hud-turbo-plate">
          <span class="hud-turbo-label">
            <span>TURBO</span>
            {hud.turbo > 0.98 && <span class="hud-turbo-full">FULL</span>}
          </span>
          <span class="hud-turbo" role="img" aria-label={`Turbo ${Math.trunc(turbo * 100)} percent`}>
            <span
              class={hud.turbo < 0.15 ? 'hud-turbo-fill is-low' : 'hud-turbo-fill'}
              style={{ width: `${turbo * 100}%` }}
            />
          </span>
          {(hud.combo >= 2 || hud.magnetActive || hud.ghostActive || hud.rocketActive || hud.flareActive) && (
            <span class="hud-chips">
              {hud.combo >= 2 && <ComboChip combo={hud.combo} fraction={hud.comboFraction} />}
              {hud.magnetActive && <Chip title="Magnet" color="ice" />}
              {hud.ghostActive && <Chip title="Ghost" color="white" />}
              {hud.rocketActive && <Chip title="Rocket" color="berry" />}
              {hud.flareActive && <Chip title="Flare" color="ochre" />}
            </span>
          )}
        </div>
        <span class="hud-spacer" />
        {/* REFILL sits above PEEL: side by side, with the turbo plate and BOOST, they overflow a phone. */}
        {(showRewarded || hud.bananaArmed) && (
          <div class="hud-extras">
            {showRewarded && (
              <button
                type="button"
                class="hud-round hud-refill"
                aria-label="Watch a short video to refill turbo"
                {...refill}
              >
                <SFSymbol name="play.rectangle.fill" />
                <span>REFILL</span>
              </button>
            )}
            {hud.bananaArmed && (
              <button type="button" class="hud-round hud-peel" aria-label="Drop banana peel" {...peel}>
                <SFSymbol name="leaf.fill" />
                <span>PEEL</span>
              </button>
            )}
          </div>
        )}
        <HoldButton controls={controls} />
      </div>
    </div>
  );
}

/**
 * HUD buttons act as the finger lands: on iOS a second finger's tap never becomes a click while
 * the first one is steering, and a dropped peel should not wait for the lift. The mouse, the
 * keyboard and assistive tech still click.
 */
function useGameTap(action: () => void) {
  const touchedAt = useRef(-Infinity);
  return {
    onPointerDown: (event: JSX.TargetedPointerEvent<HTMLButtonElement>) => {
      if (event.pointerType === 'mouse') return;
      touchedAt.current = event.timeStamp;
      action();
    },
    onClick: (event: JSX.TargetedMouseEvent<HTMLButtonElement>) => {
      // The click that follows a touch already handled on the way down.
      if (event.timeStamp - touchedAt.current < 1000) return;
      action();
    },
  };
}

/** BOOST burns turbo for as long as it is held (`HoldButton`). */
function HoldButton({ controls }: { controls: RaceControls }) {
  const hintId = useId();
  const release = (event: JSX.TargetedPointerEvent<HTMLButtonElement>) => controls.releaseBoost(event.pointerId);
  return (
    <button
      type="button"
      class={controls.boosting.value ? 'hud-boost is-pressed' : 'hud-boost'}
      aria-label="Boost"
      aria-describedby={hintId}
      onPointerDown={(event) => {
        if (event.pointerType === 'mouse' && event.button !== 0) return;
        // Held even if the thumb slides off the button, like SwiftUI's drag gesture.
        event.currentTarget.setPointerCapture(event.pointerId);
        controls.pressBoost(event.pointerId);
      }}
      onPointerUp={release}
      onPointerCancel={release}
      onPointerLeave={release}
      onLostPointerCapture={release}
    >
      BOOST
      <span id={hintId} hidden>
        Hold to burn turbo for extra speed
      </span>
    </button>
  );
}

function Chip({ title, color }: { title: string; color: FrostColor | 'white' }) {
  const rgb = color === 'white' ? '255 255 255' : `var(${cssVar(color)}-rgb)`;
  return (
    <span class="hud-chip" style={{ '--chip-rgb': rgb }}>
      {title}
    </span>
  );
}

/** The chain multiplier, filling back from full as the window to keep it alive closes. */
function ComboChip({ combo, fraction }: { combo: number; fraction: number }) {
  return (
    <span class="hud-combo">
      <span class="hud-combo-fill" style={{ width: `${saturate(fraction) * 100}%` }} />
      <span class="hud-combo-text" aria-hidden="true">{`x${combo}`}</span>
      <span class="sr-only">{`Combo times ${combo}`}</span>
    </span>
  );
}

/**
 * Goals for this course, shown while the lights count down so the player knows what the stars
 * are asking for before the race starts.
 */
function Briefing({ hud, showHints }: { hud: HUDSnapshot; showHints: boolean }) {
  return (
    <div class="hud-briefing">
      <span class="sr-only">
        {`Course ${hud.courseNumber}, ${hud.levelName}. Par ${formatPar(hud.parTime)}, ${hud.crystalGoal} crystals.`}
      </span>
      <span class="hud-briefing-course" aria-hidden="true">{`COURSE ${hud.courseNumber}`}</span>
      <span class="hud-briefing-name" aria-hidden="true">
        {hud.levelName}
      </span>
      <span class="hud-briefing-goals" aria-hidden="true">
        <GoalChip icon="timer" text={`Par ${formatPar(hud.parTime)}`} />
        <GoalChip icon="diamond.fill" text={`${hud.crystalGoal} crystals`} />
        <GoalChip icon="flag.checkered" text="Win" />
      </span>
      {showHints && (
        <span class="hud-briefing-hint" aria-hidden="true">
          Tap BOOST as the light turns green for a launch
        </span>
      )}
    </div>
  );
}

function GoalChip({ icon, text }: { icon: SymbolName; text: string }) {
  return (
    <span class="hud-goal">
      <SFSymbol name={icon} size={14} weight={2.5} />
      {text}
    </span>
  );
}
