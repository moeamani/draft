export const STAGE_W = 1600;
export const STAGE_H = 900;

export const esc = (s: string) =>
  s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

let scale = 1;

export function fitStage(stage: HTMLElement) {
  const apply = () => {
    scale = Math.min(window.innerWidth / STAGE_W, window.innerHeight / STAGE_H);
    stage.style.transform = `translate(-50%, -50%) scale(${scale})`;
  };
  window.addEventListener('resize', apply);
  apply();
}

export const stageScale = () => scale;

export function stageRect(el: Element, stage: HTMLElement) {
  const r = el.getBoundingClientRect();
  const s = stage.getBoundingClientRect();
  return {
    x: (r.left - s.left) / scale,
    y: (r.top - s.top) / scale,
    w: r.width / scale,
    h: r.height / scale,
  };
}

export function modal(stage: HTMLElement, html: string, opts: { onClose?: () => void; wide?: boolean } = {}) {
  const wrap = document.createElement('div');
  wrap.className = 'modal-back';
  wrap.innerHTML = `<div class="modal ${opts.wide ? 'wide' : ''}"><button class="modal-x" data-close>✕</button>${html}</div>`;
  const close = () => {
    wrap.remove();
    opts.onClose?.();
  };
  wrap.addEventListener('click', (e) => {
    const t = e.target as HTMLElement;
    if (t === wrap || t.closest('[data-close]')) close();
  });
  stage.appendChild(wrap);
  return { el: wrap.querySelector('.modal') as HTMLElement, close };
}

export function toast(stage: HTMLElement, text: string, kind: 'good' | 'bad' | 'info' = 'info') {
  const t = document.createElement('div');
  t.className = `toast ${kind}`;
  t.textContent = text;
  stage.appendChild(t);
  setTimeout(() => t.classList.add('out'), 2200);
  setTimeout(() => t.remove(), 2800);
}

export function float(stage: HTMLElement, x: number, y: number, text: string, good: boolean) {
  const f = document.createElement('div');
  f.className = `float ${good ? 'good' : 'bad'}`;
  f.style.left = `${x}px`;
  f.style.top = `${y}px`;
  f.textContent = text;
  stage.appendChild(f);
  setTimeout(() => f.remove(), 1400);
}

export function banner(stage: HTMLElement, text: string, sub?: string) {
  stage.querySelectorAll('.banner').forEach((b) => b.remove());
  const b = document.createElement('div');
  b.className = 'banner';
  b.innerHTML = `<div class="banner-text">${esc(text)}</div>${sub ? `<div class="banner-sub">${esc(sub)}</div>` : ''}`;
  stage.appendChild(b);
  setTimeout(() => b.remove(), 1700);
}

export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export const roman = (n: number) => ['', 'I', 'II', 'III', 'IV', 'V'][n] ?? String(n);
