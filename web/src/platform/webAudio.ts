/**
 * The eight sound effects through Web Audio. Used in the browser and on iOS (the web view plays
 * them; there is no native audio plugin). Browsers keep audio muted until a touch, so `unlock`
 * runs from the first pointer or key event.
 */
import type { GameSettings } from '../core/models';
import type { AudioService, SoundName } from './services';

const SOUNDS: readonly SoundName[] = ['collect', 'boost', 'crash', 'finish', 'tick', 'go', 'whoosh', 'power'];

/** `navigator.audioSession` (Safari 17+): "ambient" mixes with music and follows the silent switch. */
interface AudioSessionNavigator {
  audioSession?: { type: string };
}

export class WebAudioService implements AudioService {
  private context: AudioContext | null = null;
  private master: GainNode | null = null;
  private readonly buffers = new Map<SoundName, AudioBuffer>();
  private loading: Promise<void> | null = null;
  private enabled = true;

  constructor(private readonly baseURL = './sounds/') {
    const nav = navigator as Navigator & AudioSessionNavigator;
    try {
      if (nav.audioSession) nav.audioSession.type = 'ambient';
    } catch {
      // Older WebKit: the default session is fine.
    }
  }

  preload(): Promise<void> {
    this.loading ??= this.load();
    return this.loading;
  }

  unlock(): void {
    const context = this.ensureContext();
    if (context && context.state !== 'running') void context.resume().catch(() => {});
    void this.preload();
  }

  play(name: SoundName, volume = 1): void {
    if (!this.enabled) return;
    const context = this.context;
    const buffer = this.buffers.get(name);
    if (!context || !this.master || !buffer || context.state !== 'running') return;
    const source = context.createBufferSource();
    source.buffer = buffer;
    const gain = context.createGain();
    gain.gain.value = volume;
    source.connect(gain).connect(this.master);
    source.start();
  }

  apply(settings: GameSettings): void {
    this.enabled = settings.soundEnabled;
  }

  private ensureContext(): AudioContext | null {
    if (this.context) return this.context;
    const Ctor =
      window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctor) return null;
    try {
      this.context = new Ctor({ latencyHint: 'interactive' });
      this.master = this.context.createGain();
      this.master.connect(this.context.destination);
    } catch {
      this.context = null;
    }
    return this.context;
  }

  private async load(): Promise<void> {
    const context = this.ensureContext();
    if (!context) return;
    await Promise.all(
      SOUNDS.map(async (name) => {
        try {
          const response = await fetch(`${this.baseURL}${name}.wav`);
          if (!response.ok) return;
          const data = await response.arrayBuffer();
          this.buffers.set(name, await context.decodeAudioData(data));
        } catch {
          // A missing sound is silent, never an error.
        }
      }),
    );
  }
}
