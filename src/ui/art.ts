// Procedural, ordered-dithered cat portraits. Every card and nemesis gets a stable
// portrait from its seed, drawn small and then dithered to the Draft palette.
import { hashString, makeRng, next, pick, type Rng } from '../core/rng';
import type { AbilityId, CardDef, Coat } from '../core/types';

const BAYER = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];

const BASE_PALETTE = ['#0e2119', '#16352a', '#24503c', '#050807', '#f4f1e8', '#e8483b', '#2378f7', '#d3a200', '#47e7fd', '#8a96a8', '#4a5563'];

const FUR: Record<Coat, [string, string, string]> = {
  ember: ['#d0602a', '#f39a4a', '#7a2c12'],
  tide: ['#647a93', '#a7bccf', '#36465a'],
  gilt: ['#d9b56a', '#f3deaa', '#8c6a2c'],
  shadow: ['#1a1d22', '#343a42', '#050807'],
};

const hexToRgb = (h: string): [number, number, number] => [
  parseInt(h.slice(1, 3), 16),
  parseInt(h.slice(3, 5), 16),
  parseInt(h.slice(5, 7), 16),
];

function dither(g: CanvasRenderingContext2D, w: number, h: number, palette: string[], spread = 40) {
  const pal = palette.map(hexToRgb);
  const img = g.getImageData(0, 0, w, h);
  const d = img.data;
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      const i = (y * w + x) * 4;
      const t = (BAYER[y & 3][x & 3] / 16 - 0.5) * spread;
      const r = d[i] + t;
      const gg = d[i + 1] + t;
      const b = d[i + 2] + t;
      let best = 0;
      let bd = Infinity;
      for (let k = 0; k < pal.length; k++) {
        const [pr, pg, pb] = pal[k];
        const dist = (r - pr) * (r - pr) * 0.3 + (gg - pg) * (gg - pg) * 0.59 + (b - pb) * (b - pb) * 0.11;
        if (dist < bd) {
          bd = dist;
          best = k;
        }
      }
      d[i] = pal[best][0];
      d[i + 1] = pal[best][1];
      d[i + 2] = pal[best][2];
      d[i + 3] = 255;
    }
  g.putImageData(img, 0, 0);
}

export interface CatArt {
  seed: number;
  coat: Coat;
  magic: boolean;
  ability: AbilityId;
  legendary: boolean;
  scars?: number;
  crown?: boolean;
  menace?: boolean;
}

function tri(g: CanvasRenderingContext2D, a: number[], color: string) {
  g.fillStyle = color;
  g.beginPath();
  g.moveTo(a[0], a[1]);
  g.lineTo(a[2], a[3]);
  g.lineTo(a[4], a[5]);
  g.closePath();
  g.fill();
}

function ell(g: CanvasRenderingContext2D, x: number, y: number, rx: number, ry: number, color: string, rot = 0) {
  g.fillStyle = color;
  g.beginPath();
  g.ellipse(x, y, Math.max(0.1, rx), Math.max(0.1, ry), rot, 0, Math.PI * 2);
  g.fill();
}

function line(g: CanvasRenderingContext2D, pts: number[], color: string, width = 1) {
  g.strokeStyle = color;
  g.lineWidth = width;
  g.beginPath();
  g.moveTo(pts[0], pts[1]);
  for (let i = 2; i < pts.length; i += 2) g.lineTo(pts[i], pts[i + 1]);
  g.stroke();
}

function drawCat(g: CanvasRenderingContext2D, W: number, H: number, o: CatArt, rng: Rng) {
  const [fur, furLight, furDark] = FUR[o.coat];
  // background
  const bg = g.createLinearGradient(0, 0, 0, H);
  bg.addColorStop(0, o.menace ? '#050807' : '#24503c');
  bg.addColorStop(1, '#0e2119');
  g.fillStyle = bg;
  g.fillRect(0, 0, W, H);
  const halo = g.createRadialGradient(W / 2, H * 0.45, 2, W / 2, H * 0.45, W * 0.55);
  const haloColor = o.menace ? '#e8483b' : o.legendary ? '#d3a200' : o.coat === 'tide' ? '#2378f7' : o.coat === 'ember' ? '#e8483b' : o.coat === 'gilt' ? '#d3a200' : '#47e7fd';
  halo.addColorStop(0, haloColor + '88');
  halo.addColorStop(1, haloColor + '00');
  g.fillStyle = halo;
  g.fillRect(0, 0, W, H);

  const cx = W / 2 + (next(rng) - 0.5) * 4;
  const cy = H * 0.5 + (next(rng) - 0.5) * 3;
  const rx = 14 + next(rng) * 3;
  const ry = 12 + next(rng) * 2.5;

  // body / garment
  const garment = o.magic
    ? pick(rng, ['#2378f7', '#e8483b', '#16352a', '#d3a200'])
    : o.legendary
      ? '#d3a200'
      : pick(rng, ['#8a96a8', '#4a5563', '#e8483b']);
  ell(g, W / 2, H + 8, 25, 22, garment);
  if (!o.magic) {
    line(g, [W / 2 - 18, H - 6, W / 2 + 18, H - 6], '#f4f1e8', 1);
  } else {
    line(g, [W / 2, H - 14, W / 2, H], '#d3a200', 1.5);
  }

  // hooded black cats get a cowl behind the head
  if (o.ability === 'hex' && !o.legendary && !o.crown) {
    g.fillStyle = '#050807';
    g.beginPath();
    g.ellipse(cx, cy - 1, rx + 5, ry + 8, 0, Math.PI, Math.PI * 2);
    g.lineTo(cx + rx + 7, H);
    g.lineTo(cx - rx - 7, H);
    g.closePath();
    g.fill();
  }

  // ears
  const earSpread = 0.85 + next(rng) * 0.2;
  const L = [cx - rx * earSpread, cy - ry * 0.35, cx - rx * 0.95, cy - ry - 9 - next(rng) * 3, cx - rx * 0.2, cy - ry * 0.85];
  const R = [cx + rx * earSpread, cy - ry * 0.35, cx + rx * 0.95, cy - ry - 9 - next(rng) * 3, cx + rx * 0.2, cy - ry * 0.85];
  tri(g, L, o.coat === 'gilt' ? furDark : fur);
  tri(g, R, o.coat === 'gilt' ? furDark : fur);
  const inner = (a: number[]) => [a[0] * 0.7 + a[2] * 0.15 + a[4] * 0.15, a[1] * 0.7 + a[3] * 0.15 + a[5] * 0.15, a[2], a[3] + 3, a[4] * 0.7 + a[0] * 0.15 + a[2] * 0.15, a[5] * 0.7 + a[1] * 0.15 + a[3] * 0.15];
  tri(g, inner(L), '#e8483b');
  tri(g, inner(R), '#e8483b');

  // head
  ell(g, cx, cy, rx, ry, fur);
  // markings
  if (o.coat === 'ember') {
    for (let i = -1; i <= 1; i++) line(g, [cx + i * 4, cy - ry + 1, cx + i * 3, cy - ry + 6], furDark, 1.6);
  } else if (o.coat === 'tide') {
    ell(g, cx, cy + 5, 8, 5, furLight);
  } else if (o.coat === 'gilt') {
    ell(g, cx, cy + 4, 9, 6, furLight);
  } else {
    ell(g, cx - 4, cy - 4, 5, 3, furLight, -0.4);
  }
  if (o.coat !== 'shadow') ell(g, cx, cy + 5, 6, 4, furLight);

  // eyes
  const eyeColor = o.menace || o.coat === 'shadow' ? '#e8483b' : pick(rng, ['#d3a200', '#47e7fd', '#d3a200']);
  const ey = cy + 0.5;
  const ex = 6 + next(rng) * 1.2;
  const squint = o.menace ? 1.5 : 2.6;
  ell(g, cx - ex, ey, 3.4, squint, eyeColor, o.menace ? 0.35 : 0);
  ell(g, cx + ex, ey, 3.4, squint, eyeColor, o.menace ? -0.35 : 0);
  ell(g, cx - ex, ey, 0.9, squint * 0.85, '#050807');
  ell(g, cx + ex, ey, 0.9, squint * 0.85, '#050807');
  if (o.menace) {
    line(g, [cx - ex - 4, ey - 5, cx - ex + 3, ey - 2.5], '#050807', 1.6);
    line(g, [cx + ex + 4, ey - 5, cx + ex - 3, ey - 2.5], '#050807', 1.6);
  }

  // nose + mouth
  tri(g, [cx - 1.8, cy + 4.5, cx + 1.8, cy + 4.5, cx, cy + 6.5], '#e8483b');
  line(g, [cx - 3, cy + 8.5, cx, cy + 7, cx + 3, cy + 8.5], o.coat === 'shadow' ? '#4a5563' : furDark, 0.8);
  // whiskers
  for (let i = 0; i < 3; i++) {
    const wy = cy + 5 + i * 1.6;
    line(g, [cx - 6, wy, cx - 17, wy - 2 + i * 2], '#f4f1e8', 0.6);
    line(g, [cx + 6, wy, cx + 17, wy - 2 + i * 2], '#f4f1e8', 0.6);
  }

  // headgear
  const top = cy - ry;
  if (o.crown || o.legendary) {
    g.fillStyle = '#d3a200';
    g.beginPath();
    g.moveTo(cx - 9, top + 3);
    g.lineTo(cx - 9, top - 4);
    g.lineTo(cx - 5, top);
    g.lineTo(cx, top - 6);
    g.lineTo(cx + 5, top);
    g.lineTo(cx + 9, top - 4);
    g.lineTo(cx + 9, top + 3);
    g.closePath();
    g.fill();
    ell(g, cx, top - 1, 1.2, 1.2, '#e8483b');
  } else if (o.ability === 'hex') {
    // hood rim
    g.strokeStyle = '#050807';
    g.lineWidth = 3;
    g.beginPath();
    g.ellipse(cx, cy - 1, rx + 2, ry + 3, 0, Math.PI * 1.08, Math.PI * 1.92);
    g.stroke();
  } else if (o.magic && ['inspire', 'groom', 'yowl', 'muster', 'litter', 'none', 'stray', 'purr', 'pounce'].includes(o.ability)) {
    const hat = pick(rng, ['#2378f7', '#e8483b', '#16352a']);
    tri(g, [cx - 12, top + 4, cx + 12, top + 4, cx + 4 + next(rng) * 4, top - 16], hat);
    line(g, [cx - 13, top + 4, cx + 13, top + 4], '#d3a200', 1.6);
    ell(g, cx + 2, top - 5, 1, 1, '#f4f1e8');
  } else if (!o.magic && next(rng) < 0.55) {
    // helm
    g.fillStyle = '#8a96a8';
    g.beginPath();
    g.ellipse(cx, top + 5, rx * 0.95, 8, 0, Math.PI, Math.PI * 2);
    g.fill();
    g.fillRect(cx - 1, top + 4, 2, 7);
    line(g, [cx - rx * 0.9, top + 5, cx + rx * 0.9, top + 5], '#4a5563', 1);
  }

  if (o.ability === 'stray') {
    line(g, [cx - rx, cy - 5, cx + rx, cy - 1], '#050807', 1.2);
    ell(g, cx - ex, ey, 3.8, 3, '#050807');
  }

  // weapon / focus
  if (o.magic) {
    const orb = o.ability === 'hex' ? '#e8483b' : '#47e7fd';
    const og = g.createRadialGradient(W - 12, H - 12, 0, W - 12, H - 12, 9);
    og.addColorStop(0, orb);
    og.addColorStop(1, orb + '00');
    g.fillStyle = og;
    g.fillRect(W - 22, H - 22, 20, 20);
    ell(g, W - 12, H - 12, 3.5, 3.5, orb);
    ell(g, W - 13, H - 13, 1, 1, '#f4f1e8');
  } else {
    line(g, [W - 9, H - 2, W - 9, H - 30], '#f4f1e8', 2);
    line(g, [W - 13, H - 10, W - 5, H - 10], '#d3a200', 2);
    if (o.ability === 'smite') {
      g.fillStyle = '#8a96a8';
      g.fillRect(W - 14, H - 36, 10, 6);
    }
  }

  // scars
  const scars = o.scars ?? 0;
  if (scars > 0) line(g, [cx - ex - 4, ey - 6, cx - ex + 3, ey + 6], '#f4f1e8', 1.2);
  if (scars > 1) line(g, [cx + 4, cy + 3, cx + 12, cy + 8], '#e8483b', 1.2);
  if (scars > 2) tri(g, [R[2] - 3, R[3] + 2, R[2] + 3, R[3] + 2, R[2], R[3] + 7], '#0e2119');
}

function drawSpecial(g: CanvasRenderingContext2D, W: number, H: number, ability: AbilityId) {
  const bg = g.createLinearGradient(0, 0, 0, H);
  bg.addColorStop(0, '#24503c');
  bg.addColorStop(1, '#0e2119');
  g.fillStyle = bg;
  g.fillRect(0, 0, W, H);
  const cx = W / 2;
  const cy = H / 2;
  switch (ability) {
    case 'downpour':
      ell(g, cx - 10, cy - 10, 12, 8, '#8a96a8');
      ell(g, cx + 6, cy - 12, 14, 10, '#a7bccf');
      ell(g, cx + 14, cy - 6, 9, 6, '#8a96a8');
      for (let i = 0; i < 9; i++) line(g, [cx - 20 + i * 5, cy + 2 + (i % 3) * 3, cx - 24 + i * 5, cy + 14 + (i % 3) * 3], '#2378f7', 1.4);
      break;
    case 'moonfog':
      ell(g, cx + 8, cy - 10, 10, 10, '#f3deaa');
      ell(g, cx + 13, cy - 13, 9, 9, '#16352a');
      for (let i = 0; i < 4; i++) {
        g.fillStyle = `rgba(200,210,220,${0.35 + i * 0.1})`;
        g.fillRect(4 + i * 3, cy + i * 6, W - 8 - i * 6, 3);
      }
      break;
    case 'sunbeam': {
      const sg = g.createRadialGradient(cx, cy, 2, cx, cy, W * 0.6);
      sg.addColorStop(0, '#f3deaa');
      sg.addColorStop(0.3, '#d3a200');
      sg.addColorStop(1, '#d3a20000');
      g.fillStyle = sg;
      g.fillRect(0, 0, W, H);
      for (let i = 0; i < 12; i++) {
        const a = (i / 12) * Math.PI * 2;
        line(g, [cx + Math.cos(a) * 12, cy + Math.sin(a) * 12, cx + Math.cos(a) * 26, cy + Math.sin(a) * 26], '#d3a200', 1.5);
      }
      ell(g, cx, cy, 9, 9, '#f4f1e8');
      break;
    }
    case 'warhorn':
      g.fillStyle = '#d3a200';
      g.beginPath();
      g.moveTo(cx - 18, cy + 4);
      g.quadraticCurveTo(cx - 6, cy + 14, cx + 10, cy - 2);
      g.lineTo(cx + 14, cy - 14);
      g.lineTo(cx + 20, cy + 4);
      g.lineTo(cx + 12, cy + 4);
      g.quadraticCurveTo(cx - 4, cy + 20, cx - 18, cy + 8);
      g.closePath();
      g.fill();
      for (let i = 1; i <= 3; i++) {
        g.strokeStyle = '#f4f1e8';
        g.lineWidth = 1;
        g.beginPath();
        g.arc(cx + 16, cy - 6, 4 + i * 4, -1.2, 0.6);
        g.stroke();
      }
      break;
    case 'box':
      g.fillStyle = '#b07a3a';
      g.fillRect(cx - 18, cy - 4, 36, 22);
      g.fillStyle = '#8c5a2a';
      g.fillRect(cx - 18, cy - 4, 36, 4);
      tri(g, [cx - 12, cy - 4, cx - 8, cy - 14, cx - 4, cy - 4], '#1a1d22');
      tri(g, [cx + 4, cy - 4, cx + 8, cy - 14, cx + 12, cy - 4], '#1a1d22');
      ell(g, cx - 4, cy + 1, 1.6, 1.6, '#d3a200');
      ell(g, cx + 4, cy + 1, 1.6, 1.6, '#d3a200');
      break;
    case 'hairball':
      for (let i = 0; i < 40; i++) {
        const a = (i / 40) * Math.PI * 2;
        const r = 10 + (i % 4) * 2;
        line(g, [cx, cy, cx + Math.cos(a) * r, cy + Math.sin(a) * r], i % 2 ? '#7a2c12' : '#d0602a', 1.4);
      }
      ell(g, cx, cy, 8, 8, '#8c6a2c');
      break;
    default:
      break;
  }
}

const cache = new Map<string, string>();

function render(key: string, W: number, H: number, paint: (g: CanvasRenderingContext2D) => void): string {
  const hit = cache.get(key);
  if (hit) return hit;
  const c = document.createElement('canvas');
  c.width = W;
  c.height = H;
  const g = c.getContext('2d', { willReadFrequently: true })!;
  g.imageSmoothingEnabled = false;
  paint(g);
  const url = c.toDataURL();
  cache.set(key, url);
  return url;
}

export function cardArt(def: CardDef): string {
  const key = `card:${def.id}:${def.scars ?? 0}`;
  return render(key, 64, 52, (g) => {
    if (def.kind === 'special') drawSpecial(g, 64, 52, def.ability);
    else {
      const seed = def.artSeed ?? hashString(def.id);
      drawCat(g, 64, 52, {
        seed,
        coat: def.coat === 'none' ? 'shadow' : def.coat,
        magic: def.type === 'magic',
        ability: def.ability,
        legendary: def.rarity === 'legendary',
        scars: def.scars,
      }, makeRng(seed));
    }
    dither(g, 64, 52, [...BASE_PALETTE, ...Object.values(FUR).flat()]);
  });
}

export function portrait(o: CatArt): string {
  const size = 64;
  const key = `p:${o.seed}:${o.coat}:${o.magic}:${o.ability}:${o.legendary}:${o.scars ?? 0}:${o.crown}:${o.menace}`;
  return render(key, size, size, (g) => {
    drawCat(g, size, size, o, makeRng(o.seed));
    dither(g, size, size, [...BASE_PALETTE, ...Object.values(FUR).flat()]);
  });
}
