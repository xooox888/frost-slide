/**
 * Racer and live-prop state, and the prop collision classes. A port of
 * `Engine/RacerSimulation.swift`.
 */
import type { RGB } from '../core/math';
import type { Personality, PlacedEntity, PropKind, RivalConfig } from '../core/models';
import { SKIN_INFO, type SledSkin } from '../core/progression';

export interface Racer {
  id: string;
  name: string;
  isPlayer: boolean;
  sledColor: RGB;
  personality: Personality | null;
  skill: number;
  progress: number;
  lateral: number;
  height: number;
  verticalVel: number;
  speed: number;
  lateralVel: number;
  turbo: number;
  crystals: number;
  finished: boolean;
  finishTime: number | null;
  airborne: boolean;
  stunned: number;
  ghostTime: number;
  magnetTime: number;
  rocketTime: number;
  invuln: number;
  lastCheckpoint: number;
  bananaArmed: boolean;
  bananaCooldown: number;
  yaw: number;
  roll: number;
  pitch: number;
  squash: number;
  trailBoost: number;
  flareTime: number;
  /**
   * Seconds of powered speed left. Only holding BOOST (while fuel lasts), turbo pads, ramps and
   * rockets grant it; `trailBoost` is the afterglow and only drives visuals.
   */
  boostTime: number;
  /** Seconds left of the speed penalty after grinding along a wall. */
  scrape: number;
  /** Crashes, splashes and avalanche burials so far. */
  hits: number;
}

export interface LiveEntity {
  /** A copy of the course prop: the magnet moves crystals, and the course must not change. */
  definition: PlacedEntity;
  collected: boolean;
  destroyed: boolean;
  liveLateral: number;
  phase: number;
}

export const PLAYER_ID = 'player';

function makeRacer(
  id: string,
  name: string,
  isPlayer: boolean,
  color: RGB,
  personality: Personality | null,
  skill: number,
  lateral: number,
): Racer {
  return {
    id,
    name,
    isPlayer,
    sledColor: color,
    personality,
    skill,
    progress: 0.012,
    lateral,
    height: 0,
    verticalVel: 0,
    speed: 9,
    lateralVel: 0,
    turbo: 0.22,
    crystals: 0,
    finished: false,
    finishTime: null,
    airborne: false,
    stunned: 0,
    ghostTime: 0,
    magnetTime: 0,
    rocketTime: 0,
    invuln: 0,
    lastCheckpoint: 0,
    bananaArmed: false,
    bananaCooldown: 0,
    yaw: 0,
    roll: 0,
    pitch: 0,
    squash: 1,
    trailBoost: 0,
    flareTime: 0,
    boostTime: 0,
    scrape: 0,
    hits: 0,
  };
}

export const RacerFactory = {
  player(startLateral = 0, skin: SledSkin = 'cyan'): Racer {
    return makeRacer(PLAYER_ID, 'You', true, SKIN_INFO[skin].color, null, 1, startLateral);
  },
  rival(config: RivalConfig): Racer {
    return makeRacer(
      config.id,
      config.name,
      false,
      config.color,
      config.personality,
      config.skill,
      config.startLateral,
    );
  },
};

export const CollisionClass = {
  solidHazards: new Set<PropKind>([
    'snowman',
    'crate',
    'cart',
    'npc',
    'stalactite',
    'bridge',
    'barrel',
    'movingBridge',
    'crystalSpire',
    'carnivalFloat',
    'geyser',
  ]),
  pickups: new Set<PropKind>(['crystal', 'rocket', 'magnet', 'ghost', 'banana', 'flare']),
  pads: new Set<PropKind>(['ramp', 'turboPad']),
};
