// Tiny WebAudio blips so the game has some feedback without shipping sound files.
let ctx: AudioContext | null = null;
let muted = localStorage.getItem('draft.muted') === '1';

export const isMuted = () => muted;
export function toggleMute() {
  muted = !muted;
  localStorage.setItem('draft.muted', muted ? '1' : '0');
  return muted;
}

function tone(freq: number, dur: number, type: OscillatorType = 'triangle', vol = 0.06, slide = 0) {
  if (muted) return;
  try {
    ctx ??= new AudioContext();
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.type = type;
    o.frequency.value = freq;
    if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(40, freq + slide), ctx.currentTime + dur);
    g.gain.value = vol;
    g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + dur);
    o.connect(g).connect(ctx.destination);
    o.start();
    o.stop(ctx.currentTime + dur);
  } catch {
    /* audio unavailable */
  }
}

export const sfx = {
  play: () => tone(420, 0.12, 'triangle', 0.05, 180),
  enemy: () => tone(260, 0.14, 'triangle', 0.05, -60),
  pass: () => tone(200, 0.2, 'sine', 0.05, -80),
  hit: () => tone(140, 0.18, 'square', 0.03, -60),
  win: () => [523, 659, 784].forEach((f, i) => setTimeout(() => tone(f, 0.25, 'triangle', 0.05), i * 110)),
  lose: () => [392, 330, 262].forEach((f, i) => setTimeout(() => tone(f, 0.3, 'sine', 0.05), i * 140)),
  click: () => tone(660, 0.05, 'sine', 0.03),
  reveal: () => tone(880, 0.2, 'sine', 0.04, 300),
};
