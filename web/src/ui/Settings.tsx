/**
 * Settings. A port of `UI/SettingsView.swift`: steering, switches, sled skins, the Remove Ads
 * purchase, privacy, and resetting progress. Every change goes through `app.updateSettings`,
 * which applies it to sound, haptics, analytics and tilt and saves it.
 */
import { useEffect, useId, useRef, useState } from 'preact/hooks';
import type { AppModel } from '../app/appModel';
import { cssColor } from '../core/math';
import { STEER_SENSITIVITY_RANGE, type GameSettings } from '../core/models';
import { SKIN_INFO, SLED_SKINS } from '../core/progression';
import { PRIVACY_POLICY_URL } from '../platform/config';
import { BackButton, FrostButton, FrostCard } from './components';
import { SFSymbol } from './icons';
import './settings.css';

/** The on/off settings (`WritableKeyPath<GameSettings, Bool>`). */
type Switch = { [K in keyof GameSettings]: GameSettings[K] extends boolean ? K : never }[keyof GameSettings];

export function Settings({ app }: { app: AppModel }) {
  const save = app.save;
  const settings = save.settings;
  const [confirmReset, setConfirmReset] = useState(false);

  const toggle = (title: string, subtitle: string, key: Switch) => (
    <ToggleRow
      title={title}
      subtitle={subtitle}
      on={settings[key]}
      onChange={(value) => app.updateSettings((s) => (s[key] = value))}
    />
  );

  return (
    <div class="screen settings">
      <div class="settings-scroll scroll-area">
        <div class="settings-list">
          <header class="settings-header">
            <BackButton tone="onLight" onClick={() => app.goTo('menu')} />
            <h1 class="settings-title">Settings</h1>
          </header>

          <FrostCard class="settings-row">
            <SFSymbol name="hand.draw.fill" size={24} class="settings-row-icon" />
            <span class="settings-row-text">
              <span class="settings-row-title">Swipe steering</span>
              <span class="settings-row-subtitle">Drag left and right anywhere on the slope.</span>
            </span>
          </FrostCard>
          <SensitivityCard app={app} value={settings.steerSensitivity} />
          {toggle('Tilt steering', 'Lean the phone to steer, on top of swiping.', 'tiltSteering')}
          {toggle(
            'Haptics',
            'Taps for boost, collect, crash, and finish. Off when Reduce Motion is on.',
            'hapticsEnabled',
          )}
          {toggle('Sound', 'Arcade blips. Silent switch and other audio are respected.', 'soundEnabled')}
          {toggle('Best-run ghost', 'Race a translucent copy of your fastest line on this course.', 'showGhost')}
          {toggle(
            'Share anonymous stats',
            'Which courses get played and finished, so we can fix the hard spots. Nothing that identifies you.',
            'shareUsageData',
          )}
          {import.meta.env.DEV &&
            toggle('Unlock all courses', 'DEBUG only — stripped from Release / App Store builds.', 'unlockAll')}

          <div class="settings-skins-head">
            <h2 class="settings-section-title">Sled skins</h2>
            <p class="settings-caption">{`Earn stars to unlock recolors. ${save.totalStars} stars collected.`}</p>
          </div>
          <div class="settings-skins">
            {SLED_SKINS.map((skin) => {
              const info = SKIN_INFO[skin];
              const open = save.isSkinUnlocked(skin);
              const selected = settings.selectedSkin === skin;
              return (
                <button
                  key={skin}
                  type="button"
                  class={open ? 'skin' : 'skin is-locked'}
                  disabled={!open}
                  aria-pressed={selected}
                  aria-label={open ? info.title : `${info.title}, locked, needs ${info.starsRequired} stars`}
                  onClick={() => app.updateSettings((s) => (s.selectedSkin = skin))}
                >
                  <span
                    class={selected ? 'skin-swatch is-selected' : 'skin-swatch'}
                    style={{ background: cssColor(info.color) }}
                  />
                  <span class="skin-title">{open ? info.title : `${info.starsRequired}★`}</span>
                </button>
              );
            })}
          </div>

          <RemoveAdsCard app={app} />

          <a
            class="settings-link"
            href={PRIVACY_POLICY_URL}
            target="_blank"
            rel="noopener noreferrer"
            onClick={(event) => {
              // Inside the iOS app a new window opens in Safari instead of replacing the game.
              event.preventDefault();
              window.open(PRIVACY_POLICY_URL, '_blank', 'noopener,noreferrer');
            }}
          >
            <SFSymbol name="hand.raised.fill" />
            <span class="settings-row-text">
              <span class="settings-link-title">Privacy Policy</span>
              <span class="settings-row-subtitle">How Frost Slide handles your data</span>
            </span>
            <SFSymbol name="arrow.up.right" />
          </a>
          {app.services.ads.privacyOptionsRequired.value && (
            <button type="button" class="settings-link" onClick={() => app.services.ads.showPrivacyOptions()}>
              <SFSymbol name="checkmark.shield" />
              <span class="settings-row-text">
                <span class="settings-link-title">Privacy choices</span>
                <span class="settings-row-subtitle">Review how ads use your data</span>
              </span>
              <SFSymbol name="chevron.right" />
            </button>
          )}

          <div class="settings-reset">
            <FrostButton title="Reset progress" icon="trash" color="berry" onClick={() => setConfirmReset(true)} />
          </div>

          <p class="settings-version">{'Frost Slide 1.0.0  ·  com.frostslide.FrostSlide'}</p>
        </div>
      </div>

      <ResetSheet open={confirmReset} onClose={() => setConfirmReset(false)} onConfirm={() => app.resetProgress()} />
    </div>
  );
}

function SensitivityCard({ app, value }: { app: AppModel; value: number }) {
  const { min, max } = STEER_SENSITIVITY_RANGE;
  const fill = ((value - min) / (max - min)) * 100;
  return (
    <FrostCard class="settings-sensitivity">
      <span class="settings-sensitivity-head">
        <span class="settings-row-title">Steering sensitivity</span>
        <span class="settings-sensitivity-value">{`${value.toFixed(1)}x`}</span>
      </span>
      <input
        class="slider"
        type="range"
        min={min}
        max={max}
        step={0.1}
        value={value}
        style={{ '--fill': `${fill}%` }}
        aria-label="Steering sensitivity"
        aria-valuetext={`${value.toFixed(1)}x`}
        onInput={(event) => {
          // The slider steps by 0.1; rounding keeps 1.2 from arriving as 1.2000000000000002.
          const next = Math.round(Number(event.currentTarget.value) * 10) / 10;
          app.updateSettings((s) => (s.steerSensitivity = next));
        }}
      />
      <span class="settings-row-subtitle">Higher turns the sled with a shorter swipe.</span>
    </FrostCard>
  );
}

function ToggleRow(props: { title: string; subtitle: string; on: boolean; onChange: (value: boolean) => void }) {
  const id = useId();
  return (
    <button
      type="button"
      role="switch"
      class="frost-card settings-toggle"
      aria-checked={props.on}
      aria-labelledby={`${id}-title`}
      aria-describedby={`${id}-subtitle`}
      onClick={() => props.onChange(!props.on)}
    >
      <span class="settings-row-text">
        <span id={`${id}-title`} class="settings-row-title">
          {props.title}
        </span>
        <span id={`${id}-subtitle`} class="settings-row-subtitle">
          {props.subtitle}
        </span>
      </span>
      <span class={props.on ? 'switch is-on' : 'switch'} aria-hidden="true" />
    </button>
  );
}

function RemoveAdsCard({ app }: { app: AppModel }) {
  const store = app.services.store;
  const removed = store.adsRemoved.value;
  const busy = store.busy.value !== 'none';
  const price = store.price.value;
  const message = store.message.value;

  return (
    <FrostCard class="settings-ads">
      <span class="settings-ads-head">
        <SFSymbol name={removed ? 'checkmark.seal.fill' : 'nosign'} size={24} class="settings-row-icon" />
        <span class="settings-row-text">
          <span class="settings-row-title">{removed ? 'Ads removed' : 'Remove ads'}</span>
          <span class="settings-row-subtitle">
            {removed
              ? 'Thank you for supporting Frost Slide.'
              : 'One-time purchase. No more banners or full-screen ads. The optional refill videos stay.'}
          </span>
        </span>
      </span>
      {store.available ? (
        <>
          {!removed && (
            <FrostButton
              title={price ? `Remove ads · ${price}` : 'Remove ads'}
              icon="cart"
              color="ochre"
              foreground="ink"
              disabled={busy}
              onClick={() => void store.purchase()}
            />
          )}
          <button type="button" class="settings-restore" disabled={busy} onClick={() => void store.restore()}>
            Restore purchases
          </button>
          {busy && <span class="spinner" role="progressbar" aria-label="Talking to the App Store" />}
          {message && (
            <p class="settings-ads-message" role="status">
              {message}
            </p>
          )}
        </>
      ) : (
        // A plain browser has no ads and no App Store to buy from.
        <p class="settings-ads-message">Purchases are available in the iPhone app.</p>
      )}
    </FrostCard>
  );
}

/** SwiftUI's `confirmationDialog`: an action sheet with the destructive choice and Cancel. */
function ResetSheet({ open, onClose, onConfirm }: { open: boolean; onClose: () => void; onConfirm: () => void }) {
  const ref = useRef<HTMLDialogElement>(null);
  const id = useId();

  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    else if (!open && dialog.open) dialog.close();
  }, [open]);

  return (
    <dialog
      ref={ref}
      class="sheet"
      aria-labelledby={`${id}-title`}
      aria-describedby={`${id}-message`}
      onClose={onClose}
      onClick={(event) => {
        // A tap outside the buttons dismisses, like an action sheet.
        if (event.target === event.currentTarget) event.currentTarget.close();
      }}
    >
      <div class="sheet-group">
        <div class="sheet-header">
          <p id={`${id}-title`} class="sheet-title">
            Erase all progress?
          </p>
          <p id={`${id}-message`} class="sheet-message">
            Every course goes back to locked except the first. Your settings are kept. This can't be undone.
          </p>
        </div>
        <button
          type="button"
          class="sheet-action sheet-action--destructive"
          onClick={() => {
            onConfirm();
            ref.current?.close();
          }}
        >
          Erase stars, records and ghosts
        </button>
      </div>
      <button type="button" class="sheet-action sheet-cancel" autofocus onClick={() => ref.current?.close()}>
        Cancel
      </button>
    </dialog>
  );
}
