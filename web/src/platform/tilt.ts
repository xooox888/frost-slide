/**
 * Tilt steering from the device orientation, in the same unit as the Swift app's CoreMotion
 * reading: the sideways component of gravity in g, positive when the right edge dips.
 *
 * With the W3C angles, gravity in device axes is (cos β sin γ, −sin β, −cos β cos γ), so the
 * sideways lean is cos β · sin γ. That stays smooth however far back the phone is tipped, like
 * CoreMotion's `gravity.x`.
 *
 * iOS asks for permission, and only from a tap: `enable` is called from the Settings switch. If a
 * launch finds tilt already on, the request waits for the first touch.
 */
import type { TiltService } from './services';

interface OrientationPermission {
  requestPermission?: () => Promise<'granted' | 'denied'>;
}

const DEG = Math.PI / 180;

export class OrientationTilt implements TiltService {
  private lean: number | null = null;
  private listening = false;
  private pendingGesture: (() => void) | null = null;

  private readonly onOrientation = (event: DeviceOrientationEvent) => {
    if (event.beta === null || event.gamma === null) return;
    // Portrait only, so the screen and device axes agree.
    this.lean = Math.cos(event.beta * DEG) * Math.sin(event.gamma * DEG);
  };

  async enable(): Promise<boolean> {
    if (typeof window === 'undefined' || !('DeviceOrientationEvent' in window)) return false;
    const request = (DeviceOrientationEvent as unknown as OrientationPermission).requestPermission;
    if (request) {
      try {
        if ((await request()) !== 'granted') return false;
      } catch {
        // Not from a tap (a launch with tilt already on): ask on the first touch instead.
        this.askOnFirstTouch(request);
        return true;
      }
    }
    this.listen();
    return true;
  }

  disable(): void {
    if (this.pendingGesture) {
      window.removeEventListener('pointerup', this.pendingGesture);
      this.pendingGesture = null;
    }
    if (this.listening) window.removeEventListener('deviceorientation', this.onOrientation);
    this.listening = false;
    this.lean = null;
  }

  read(): number | null {
    return this.listening ? this.lean : null;
  }

  private listen(): void {
    if (this.listening) return;
    this.listening = true;
    window.addEventListener('deviceorientation', this.onOrientation);
  }

  private askOnFirstTouch(request: () => Promise<'granted' | 'denied'>): void {
    if (this.pendingGesture) return;
    const handler = () => {
      window.removeEventListener('pointerup', handler);
      this.pendingGesture = null;
      void request()
        .then((state) => {
          if (state === 'granted') this.listen();
        })
        .catch(() => {});
    };
    this.pendingGesture = handler;
    window.addEventListener('pointerup', handler);
  }
}
