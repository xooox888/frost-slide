/**
 * Sounds and haptics for race events. A port of `Core/AudioHaptics.swift`: the same sound, volume
 * and haptic for each event. The engine calls these through its `EngineFx` interface; the results
 * screen uses `tap` and `comboHit` for the star reveal.
 */
import type { EngineFx, HapticStyle } from '../engine/gameEngine';
import type { Services, SoundName } from '../platform/services';

export function engineFx(services: Services): EngineFx {
  const play = (name: SoundName, volume: number) => services.audio.play(name, volume);
  // Impacts follow Reduce Motion, like the Swift app; the finish notification does not.
  const tap = (style: HapticStyle) => {
    if (!services.reduceMotion.value) services.haptics.impact(style);
  };
  return {
    collect() {
      play('collect', 0.7);
      tap('light');
    },
    boost() {
      play('boost', 0.85);
      tap('medium');
    },
    crash() {
      play('crash', 0.9);
      tap('heavy');
    },
    finish() {
      play('finish', 1);
      services.haptics.success();
    },
    countdown() {
      play('tick', 0.55);
      tap('light');
    },
    go() {
      play('go', 0.8);
      tap('medium');
    },
    whoosh() {
      play('whoosh', 0.6);
      tap('medium');
    },
    comboHit() {
      play('collect', 0.45);
      tap('light');
    },
    power() {
      play('power', 0.75);
      tap('medium');
    },
    tap,
  };
}
