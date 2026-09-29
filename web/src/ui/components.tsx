/**
 * Building blocks shared by the screens: ports of `FrostButton`, `FrostCard` and
 * `SnowfallOverlay` from `UI/FrostTheme.swift`, plus the round back button of the course map and
 * settings.
 */
import type { ComponentChildren } from 'preact';
import { useEffect, useRef } from 'preact/hooks';
import { SFSymbol, type SymbolName } from './icons';
import { cssVar, type FrostColor } from './theme';

interface FrostButtonProps {
  title: string;
  subtitle?: string;
  icon?: SymbolName;
  color?: FrostColor;
  foreground?: FrostColor | 'white';
  disabled?: boolean;
  onClick: () => void;
}

/** The big capsule button of every menu. */
export function FrostButton({
  title,
  subtitle,
  icon,
  color = 'ice',
  foreground = 'white',
  disabled = false,
  onClick,
}: FrostButtonProps) {
  const style = {
    '--tint-rgb': `var(${cssVar(color)}-rgb)`,
    '--fg': foreground === 'white' ? '#fff' : `var(${cssVar(foreground)})`,
  };
  return (
    <button
      type="button"
      class={subtitle ? 'frost-button frost-button--subtitle' : 'frost-button'}
      style={style}
      disabled={disabled}
      onClick={onClick}
    >
      {icon && <SFSymbol name={icon} />}
      <span class="frost-button-text">
        <span class="frost-button-title">{title}</span>
        {subtitle && <span class="frost-button-subtitle">{subtitle}</span>}
      </span>
    </button>
  );
}

interface FrostCardProps {
  /**
   * The fill laid over the blurred backdrop, as a CSS colour. FrostCard fills with
   * `tint.opacity(0.78)`, so pass the colour with that opacity applied; white by default.
   */
  tint?: string;
  class?: string;
  children: ComponentChildren;
}

/** Frosted panel. */
export function FrostCard({ tint, class: className, children }: FrostCardProps) {
  return (
    <div
      class={className ? `frost-card ${className}` : 'frost-card'}
      style={tint ? { '--card-tint': tint } : undefined}
    >
      {children}
    </div>
  );
}

/** The chevron that returns to the main menu: white on the dark course map, ink on settings. */
export function BackButton({ tone, onClick }: { tone: 'onDark' | 'onLight'; onClick: () => void }) {
  return (
    <button type="button" class={`back-button back-button--${tone}`} aria-label="Back to menu" onClick={onClick}>
      <SFSymbol name="chevron.left" size={24} weight={3} />
    </button>
  );
}

/**
 * Drifting snowflakes behind the menus, with the same maths as `SnowfallOverlay`. Nothing is drawn
 * with Reduce Motion on.
 */
export function Snowfall({ density, reduceMotion }: { density: number; reduceMotion: boolean }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    const context = canvas?.getContext('2d');
    if (!canvas || !context) return;
    let width = 0;
    let height = 0;
    let scale = 1;
    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      scale = Math.min(window.devicePixelRatio || 1, 2);
      width = rect.width;
      height = rect.height;
      canvas.width = Math.round(width * scale);
      canvas.height = Math.round(height * scale);
    };
    const observer = new ResizeObserver(resize);
    observer.observe(canvas);
    resize();

    let frame = 0;
    const draw = (now: number) => {
      frame = requestAnimationFrame(draw);
      // A wall clock, like TimelineView's date, so the flakes don't jump between screens.
      const t = (performance.timeOrigin + now) / 1000;
      context.setTransform(scale, 0, 0, scale, 0, 0);
      context.clearRect(0, 0, width, height);
      context.fillStyle = 'rgba(255, 255, 255, 0.55)';
      context.beginPath();
      for (let i = 0; i < density; i += 1) {
        const seed = i * 97;
        const x = (Math.sin(seed) * 0.5 + 0.5) * width;
        const speed = 18 + (i % 7) * 7;
        const y = ((t * speed + seed * 13) % (height + 40)) - 20;
        // `Path(ellipseIn:)` of an r-by-r square: r is the diameter.
        const r = 1.2 + (i % 4);
        context.moveTo(x + r, y + r / 2);
        context.arc(x + r / 2, y + r / 2, r / 2, 0, Math.PI * 2);
      }
      context.fill();
    };
    frame = requestAnimationFrame(draw);
    return () => {
      cancelAnimationFrame(frame);
      observer.disconnect();
    };
  }, [density, reduceMotion]);

  if (reduceMotion) return null;
  return <canvas ref={ref} class="snowfall" aria-hidden="true" />;
}
