/**
 * The title screen. A port of `UI/MainMenuView.swift`: painted hero, snowfall, the brand badge
 * and four buttons (race the next course, the daily, the course map, settings).
 */
import type { AppModel } from '../app/appModel';
import { level } from '../core/levelCatalog';
import { levelOrder } from '../core/models';
import { GOAL_INFO } from '../core/progression';
import { FrostButton, Snowfall } from './components';
import './menu.css';

export function MainMenu({ app }: { app: AppModel }) {
  const save = app.save;
  const reduceMotion = app.services.reduceMotion.value;
  const next = app.nextCourse.value;
  const pick = app.dailyPick.value;

  let dailySubtitle: string;
  if (save.dailyDoneToday) {
    const streak = save.activeDailyStreak;
    dailySubtitle = streak > 1 ? `Done today · ${streak}-day streak` : 'Done today · come back tomorrow';
  } else {
    dailySubtitle = `${level(pick.level).name} · ${GOAL_INFO[pick.goal].title}`;
  }

  return (
    <div class="screen menu" style={{ '--banner-h': `${app.services.ads.bannerHeight.value}px` }}>
      <img class="menu-hero" src="./art/menu-hero.jpg" alt="" aria-hidden="true" decoding="async" />
      <div class="menu-shade" aria-hidden="true" />
      <Snowfall density={36} reduceMotion={reduceMotion} />

      <div class="menu-content">
        <div class={reduceMotion ? 'menu-badge menu-badge--still' : 'menu-badge'}>
          <img src="./art/brand-badge.jpg" alt="" decoding="async" />
        </div>
        <h1 class="menu-title">
          <span class="menu-title-frost">FROST</span> <span class="menu-title-slide">SLIDE</span>
        </h1>
        <p class="menu-tagline">Ice-crystal downhill racing</p>

        <div class="menu-buttons">
          <FrostButton
            title="Race"
            subtitle={`Course ${levelOrder(next) + 1} · ${level(next).name}`}
            icon="flag.checkered"
            color="berry"
            onClick={() => app.quickRace()}
          />
          <FrostButton
            title="Daily Challenge"
            subtitle={dailySubtitle}
            icon="calendar"
            color="ochre"
            foreground="ink"
            onClick={() => app.playDaily()}
          />
          <FrostButton title="Course Map" icon="map.fill" color="ice" onClick={() => app.goTo('levelSelect')} />
          <FrostButton
            title="Settings"
            icon="slider.horizontal.3"
            color="inkSoft"
            onClick={() => app.goTo('settings')}
          />
        </div>

        <p class="menu-hint">{'Swipe to steer  ·  Hold turbo to boost'}</p>
      </div>
    </div>
  );
}
