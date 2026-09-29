/**
 * Anonymous usage stats through TelemetryDeck. A port of `Analytics/Analytics.swift`: the same
 * event names and parameters, off until an App ID is configured, and switched off entirely (not
 * just muted) when the player turns "Share anonymous stats" off.
 *
 * Nothing typed by the player, no names and no advertising id is sent. The SDK hashes a random
 * per-install id before it leaves the device.
 */
import type TelemetryDeck from '@telemetrydeck/sdk';
import type { GameSettings } from '../core/models';
import { ANALYTICS_CONFIG, analyticsConfigured } from './config';
import type { AnalyticsEvent, AnalyticsService, StorageService } from './services';

const INSTALL_ID_KEY = 'frostslide.installId';

/** Parameters as strings, like the Swift app sends them, plus the finish time as the float value. */
export function signalPayload(event: AnalyticsEvent): Record<string, string | number> {
  const yesNo = (value: boolean) => (value ? 'yes' : 'no');
  switch (event.name) {
    case 'Race.started':
      return { course: `${event.course}`, daily: yesNo(event.daily) };
    case 'Race.finished':
      return {
        course: `${event.course}`,
        place: `${event.place}`,
        stars: `${event.stars}`,
        perfect: yesNo(event.perfect),
        crashes: `${event.crashes}`,
        floatValue: event.seconds,
      };
    case 'Race.abandoned':
      return { course: `${event.course}`, progress: `${event.progress}` };
    case 'Daily.completed':
      return { streak: `${event.streak}` };
    case 'Store.adsRemoved':
      return {};
  }
}

export class TelemetryDeckAnalytics implements AnalyticsService {
  private client: TelemetryDeck | null = null;
  private enabled = false;
  private starting: Promise<void> | null = null;

  constructor(
    private readonly storage: StorageService,
    private readonly testMode: boolean,
  ) {}

  apply(settings: GameSettings): void {
    if (!analyticsConfigured()) return;
    this.enabled = settings.shareUsageData;
    if (this.enabled) {
      this.starting ??= this.start();
    } else {
      this.client = null;
      this.starting = null;
    }
  }

  track(event: AnalyticsEvent): void {
    if (!this.enabled) return;
    void (this.starting ?? Promise.resolve()).then(() => {
      if (!this.enabled || !this.client) return;
      this.client.signal(event.name, signalPayload(event)).catch(() => {
        // Offline or blocked: stats are best effort.
      });
    });
  }

  private async start(): Promise<void> {
    try {
      const { default: Client } = await import('@telemetrydeck/sdk');
      if (!this.enabled) return;
      this.client = new Client({
        appID: ANALYTICS_CONFIG.appID,
        clientUser: await this.installId(),
        testMode: this.testMode,
      });
    } catch {
      this.client = null;
    }
  }

  private async installId(): Promise<string> {
    const saved = await this.storage.load(INSTALL_ID_KEY);
    if (saved) return saved;
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    const id = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
    await this.storage.save(INSTALL_ID_KEY, id);
    return id;
  }
}
