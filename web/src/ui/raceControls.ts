/**
 * Race input: the swipe, the BOOST button and the keyboard, fed to the engine the way
 * `GamePlaySurface` in `UI/GameContainerView.swift` does (steering is the drag's width / 60, boost
 * lasts while held, both reset when the race screen goes away). Touches are told apart by pointer
 * id, so one thumb can hold BOOST while the other steers.
 */
import { signal } from '@preact/signals';
import type { AppModel } from '../app/appModel';

/** Sideways drag in CSS px (points on iOS) for full lock at sensitivity 1. */
const DRAG_FOR_FULL_LOCK = 60;

export type HeldKey = 'left' | 'right' | 'boost';

export class RaceControls {
  /** BOOST is held, by a finger, the mouse or the keyboard: the button shows it pressed. */
  readonly boosting = signal(false);

  private steerPointer: number | null = null;
  private steerStartX = 0;
  private dragSteer = 0;
  private readonly boostPointers = new Set<number>();
  private readonly keys = new Set<HeldKey>();

  constructor(private readonly app: AppModel) {}

  get steering(): boolean {
    return this.steerPointer !== null;
  }

  startSteer(pointerId: number, x: number): void {
    this.steerPointer = pointerId;
    this.steerStartX = x;
    this.dragSteer = 0;
    this.applySteer();
  }

  moveSteer(pointerId: number, x: number): void {
    if (pointerId !== this.steerPointer) return;
    this.dragSteer = (x - this.steerStartX) / DRAG_FOR_FULL_LOCK;
    this.applySteer();
  }

  endSteer(pointerId: number): void {
    if (pointerId !== this.steerPointer) return;
    this.steerPointer = null;
    this.dragSteer = 0;
    this.applySteer();
  }

  pressBoost(pointerId: number): void {
    this.boostPointers.add(pointerId);
    this.applyBoost();
  }

  releaseBoost(pointerId: number): void {
    if (this.boostPointers.delete(pointerId)) this.applyBoost();
  }

  keyDown(key: HeldKey): void {
    this.keys.add(key);
    if (key === 'boost') this.applyBoost();
    else this.applySteer();
  }

  keyUp(key: HeldKey): void {
    if (!this.keys.delete(key)) return;
    if (key === 'boost') this.applyBoost();
    else this.applySteer();
  }

  /** Pausing, leaving the window or the race screen: nothing stays held. */
  releaseAll(): void {
    this.steerPointer = null;
    this.dragSteer = 0;
    this.boostPointers.clear();
    this.keys.clear();
    this.applySteer();
    this.applyBoost();
  }

  /** A finger on the slope wins over the arrow keys; the keys give full lock. */
  private applySteer(): void {
    const keySteer = (this.keys.has('right') ? 1 : 0) - (this.keys.has('left') ? 1 : 0);
    this.app.setSteer(this.steerPointer !== null ? this.dragSteer : keySteer);
  }

  private applyBoost(): void {
    const held = this.boostPointers.size > 0 || this.keys.has('boost');
    this.boosting.value = held;
    this.app.setBoost(held);
  }
}
