// Small seedable RNG. State is a plain object so it survives structuredClone / JSON saves.
export interface Rng {
  s: number;
}

export function makeRng(seed: number): Rng {
  return { s: seed >>> 0 };
}

export function next(r: Rng): number {
  r.s = (r.s + 0x6d2b79f5) | 0;
  let t = r.s;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

export function int(r: Rng, n: number): number {
  return Math.floor(next(r) * n);
}

export function range(r: Rng, lo: number, hi: number): number {
  return lo + int(r, hi - lo + 1);
}

export function chance(r: Rng, p: number): boolean {
  return next(r) < p;
}

export function pick<T>(r: Rng, arr: readonly T[]): T {
  return arr[int(r, arr.length)];
}

export function shuffle<T>(r: Rng, arr: T[]): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = int(r, i + 1);
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

export function weighted<T>(r: Rng, items: readonly [T, number][]): T {
  const total = items.reduce((a, [, w]) => a + w, 0);
  let x = next(r) * total;
  for (const [item, w] of items) {
    x -= w;
    if (x <= 0) return item;
  }
  return items[items.length - 1][0];
}

export function hashString(str: string): number {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}
