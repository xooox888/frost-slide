/**
 * The app's bridges to the platform: engine events to sounds and haptics (as
 * `Core/AudioHaptics.swift`), and analytics events to TelemetryDeck payloads (as
 * `Analytics/Analytics.swift`).
 */
import { signal } from '@preact/signals';
import { describe, expect, it } from 'vitest';
import { engineFx } from '../src/app/engineFx';
import { signalPayload } from '../src/platform/analytics';
import type { HapticStyle, Services, SoundName } from '../src/platform/services';

function fakeServices(reduceMotion = false) {
  const log: string[] = [];
  const services = {
    audio: { play: (name: SoundName, volume?: number) => log.push(`sound ${name} ${volume}`) },
    haptics: {
      impact: (style: HapticStyle) => log.push(`impact ${style}`),
      success: () => log.push('success'),
    },
    reduceMotion: signal(reduceMotion),
  } as unknown as Services;
  return { services, log };
}

describe('engine sounds and haptics', () => {
  it('match AudioHaptics.swift event for event', () => {
    const { services, log } = fakeServices();
    const fx = engineFx(services);
    fx.collect();
    fx.boost();
    fx.crash();
    fx.finish();
    fx.countdown();
    fx.go();
    fx.whoosh();
    fx.comboHit();
    fx.power();
    expect(log).toEqual([
      'sound collect 0.7',
      'impact light',
      'sound boost 0.85',
      'impact medium',
      'sound crash 0.9',
      'impact heavy',
      'sound finish 1',
      'success',
      'sound tick 0.55',
      'impact light',
      'sound go 0.8',
      'impact medium',
      'sound whoosh 0.6',
      'impact medium',
      'sound collect 0.45',
      'impact light',
      'sound power 0.75',
      'impact medium',
    ]);
  });

  it('skip impacts with Reduce Motion, but keep sounds and the finish notification', () => {
    const { services, log } = fakeServices(true);
    const fx = engineFx(services);
    fx.crash();
    fx.tap('heavy');
    fx.finish();
    expect(log).toEqual(['sound crash 0.9', 'sound finish 1', 'success']);
  });
});

describe('analytics payloads', () => {
  it('send the Swift parameter names and string values', () => {
    expect(signalPayload({ name: 'Race.started', course: 3, daily: true })).toEqual({ course: '3', daily: 'yes' });
    expect(
      signalPayload({
        name: 'Race.finished',
        course: 12,
        place: 2,
        stars: 3,
        perfect: false,
        seconds: 41.5,
        crashes: 1,
      }),
    ).toEqual({ course: '12', place: '2', stars: '3', perfect: 'no', crashes: '1', floatValue: 41.5 });
    expect(signalPayload({ name: 'Race.abandoned', course: 5, progress: 62 })).toEqual({ course: '5', progress: '62' });
    expect(signalPayload({ name: 'Daily.completed', streak: 4 })).toEqual({ streak: '4' });
    expect(signalPayload({ name: 'Store.adsRemoved' })).toEqual({});
  });
});
