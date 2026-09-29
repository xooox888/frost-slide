/**
 * The pause card over a race. A port of `UI/PauseView.swift`: the course and its goals, then
 * resume, restart, the course map and the main menu.
 */
import { useEffect, useId, useRef } from 'preact/hooks';
import type { AppModel } from '../app/appModel';
import { FrostButton, FrostCard } from './components';
import { formatPar } from './theme';

export function PauseMenu({ app }: { app: AppModel }) {
  const hud = app.hud.value;
  const stack = useRef<HTMLDivElement>(null);
  const titleId = useId();

  // Keyboard focus lands on Resume, so Space or Enter carries on racing.
  useEffect(() => {
    stack.current?.querySelector('button')?.focus({ preventScroll: true });
  }, []);

  return (
    <div class="pause" role="dialog" aria-modal="true" aria-labelledby={titleId}>
      <FrostCard class="pause-card">
        <div ref={stack} class="pause-stack">
          <h2 id={titleId} class="pause-title">
            Paused
          </h2>
          <div class="pause-info">
            <p class="pause-course">{`Course ${hud.courseNumber} · ${hud.levelName}`}</p>
            <p class="pause-goals">{`Par ${formatPar(hud.parTime)}  ·  ${hud.crystalGoal} crystals`}</p>
          </div>
          <FrostButton title="Resume" icon="play.fill" color="ice" onClick={() => app.resume()} />
          <FrostButton
            title="Restart"
            icon="arrow.counterclockwise"
            color="ochre"
            foreground="ink"
            onClick={() => app.restart()}
          />
          <FrostButton title="Course Map" icon="map" color="inkSoft" onClick={() => app.backToMap()} />
          <FrostButton title="Main Menu" icon="house.fill" color="berry" onClick={() => app.backToMenu()} />
        </div>
      </FrostCard>
    </div>
  );
}
