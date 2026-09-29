/**
 * The SF Symbols the Swift screens use, each drawn with the closest Lucide icon, so the ports can
 * keep the Swift symbol names. Also maps the world and daily-goal icon names from
 * `core/progression.ts` to their symbols.
 */
import {
  ArrowUpRight,
  Badge,
  BadgeCheck,
  Ban,
  Calendar,
  Check,
  ChevronLeft,
  ChevronRight,
  Circle,
  CircleCheck,
  Diamond,
  FastForward,
  Flag,
  Flame,
  Hand,
  House,
  Leaf,
  Lock,
  Map as MapIcon,
  Medal,
  Mountain,
  PartyPopper,
  Pause,
  Play,
  Pointer,
  RotateCcw,
  Sailboat,
  ShieldCheck,
  ShoppingCart,
  SlidersHorizontal,
  Snowflake,
  Sparkles,
  SquarePlay,
  Star,
  Timer,
  Trash,
  TreeDeciduous,
  Triangle,
  Users,
  type LucideIcon,
} from 'lucide-preact';
import type { GoalIcon, WorldIcon } from '../core/progression';

/**
 * `outline`: Lucide's own stroked drawing. `filled`: the shape filled with the colour, for the
 * `.fill` symbols whose Lucide drawing is one closed shape. `knockout`: filled, with the inner
 * mark in `--knockout` (white unless the parent sets it), like `checkmark.seal.fill`.
 */
type Style = 'outline' | 'filled' | 'knockout';

const SYMBOLS = {
  'arrow.counterclockwise': [RotateCcw, 'outline'],
  'arrow.up.right': [ArrowUpRight, 'outline'],
  calendar: [Calendar, 'outline'],
  cart: [ShoppingCart, 'outline'],
  checkmark: [Check, 'outline'],
  'checkmark.circle.fill': [CircleCheck, 'knockout'],
  'checkmark.seal.fill': [BadgeCheck, 'knockout'],
  'checkmark.shield': [ShieldCheck, 'outline'],
  'chevron.left': [ChevronLeft, 'outline'],
  'chevron.right': [ChevronRight, 'outline'],
  circle: [Circle, 'outline'],
  'diamond.fill': [Diamond, 'filled'],
  'flag.checkered': [Flag, 'outline'],
  'flame.fill': [Flame, 'filled'],
  'forward.fill': [FastForward, 'filled'],
  'hand.draw.fill': [Pointer, 'outline'],
  'hand.raised.fill': [Hand, 'outline'],
  'house.fill': [House, 'outline'],
  'house.lodge.fill': [House, 'outline'],
  'leaf.fill': [Leaf, 'filled'],
  'lock.fill': [Lock, 'outline'],
  map: [MapIcon, 'outline'],
  'map.fill': [MapIcon, 'outline'],
  'medal.fill': [Medal, 'outline'],
  'mountain.2.fill': [Mountain, 'filled'],
  nosign: [Ban, 'outline'],
  'party.popper.fill': [PartyPopper, 'outline'],
  'pause.fill': [Pause, 'filled'],
  'person.3.fill': [Users, 'outline'],
  'play.fill': [Play, 'filled'],
  'play.rectangle.fill': [SquarePlay, 'knockout'],
  'sailboat.fill': [Sailboat, 'outline'],
  'seal.fill': [Badge, 'filled'],
  'slider.horizontal.3': [SlidersHorizontal, 'outline'],
  snowflake: [Snowflake, 'outline'],
  sparkles: [Sparkles, 'filled'],
  star: [Star, 'outline'],
  'star.fill': [Star, 'filled'],
  timer: [Timer, 'outline'],
  trash: [Trash, 'outline'],
  'tree.fill': [TreeDeciduous, 'filled'],
  'triangle.fill': [Triangle, 'filled'],
} as const satisfies Record<string, readonly [LucideIcon, Style]>;

export type SymbolName = keyof typeof SYMBOLS;

interface SFSymbolProps {
  name: SymbolName;
  /** Box size in CSS px. Lucide draws inside a 24-unit box with a margin, so a symbol set in a
   * SwiftUI font of size N matches a box of about 1.2 N. */
  size?: number;
  /** Stroke width in Lucide units (2 is Lucide's regular; bold SF weights look like 3). */
  weight?: number;
  class?: string;
}

/** An SF Symbol from the Swift UI; decorative (hidden from assistive tech) like SwiftUI's. */
export function SFSymbol({ name, size = 20, weight = 2, class: className }: SFSymbolProps) {
  const [Icon, style] = SYMBOLS[name];
  const classes = ['sf-symbol', style === 'outline' ? '' : `sf-symbol--${style}`, className ?? ''];
  return (
    <Icon
      size={size}
      strokeWidth={weight}
      class={classes.filter(Boolean).join(' ')}
      aria-hidden="true"
      focusable="false"
    />
  );
}

/** `CourseWorld.symbol`. */
export const WORLD_SYMBOL: Record<WorldIcon, SymbolName> = {
  lodge: 'house.lodge.fill',
  triangle: 'triangle.fill',
  sparkles: 'sparkles',
  sailboat: 'sailboat.fill',
  mountain: 'mountain.2.fill',
  tree: 'tree.fill',
  diamond: 'diamond.fill',
  party: 'party.popper.fill',
};

/** `DailyChallenge.Goal.symbol`. */
export const GOAL_SYMBOL: Record<GoalIcon, SymbolName> = {
  timer: 'timer',
  medal: 'medal.fill',
  diamond: 'diamond.fill',
  seal: 'checkmark.seal.fill',
};
