// Shared canvas drawing helpers for the force-graph views.

/** Rounded-rectangle path (used for edge-label pills). */
export function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number
) {
  const rr = Math.min(r, h / 2, w / 2);
  ctx.beginPath();
  ctx.moveTo(x + rr, y);
  ctx.arcTo(x + w, y, x + w, y + h, rr);
  ctx.arcTo(x + w, y + h, x, y + h, rr);
  ctx.arcTo(x, y + h, x, y, rr);
  ctx.arcTo(x, y, x + w, y, rr);
  ctx.closePath();
}

function toRGB(hex: string) {
  const h = (hex || '#8595a6').replace('#', '');
  return {
    r: parseInt(h.slice(0, 2), 16),
    g: parseInt(h.slice(2, 4), 16),
    b: parseInt(h.slice(4, 6), 16),
  };
}

/** #rrggbb + alpha → rgba() string. */
export function hexA(hex: string, alpha: number): string {
  const { r, g, b } = toRGB(hex);
  return `rgba(${r},${g},${b},${alpha})`;
}

/** Blend a hex colour toward white by amt (0..1). */
export function lighten(hex: string, amt: number): string {
  const { r, g, b } = toRGB(hex);
  const f = (c: number) => Math.round(c + (255 - c) * amt);
  return `rgb(${f(r)},${f(g)},${f(b)})`;
}

/** Blend a hex colour toward black by amt (0..1). */
export function darken(hex: string, amt: number): string {
  const { r, g, b } = toRGB(hex);
  const f = (c: number) => Math.round(c * (1 - amt));
  return `rgb(${f(r)},${f(g)},${f(b)})`;
}
