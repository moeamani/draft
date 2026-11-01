import type { Save } from '../core/game';

const KEY = 'draft.save.v1';

export function loadSave(): Save | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const s = JSON.parse(raw) as Save;
    return s.version === 1 ? s : null;
  } catch {
    return null;
  }
}

export function writeSave(s: Save) {
  try {
    localStorage.setItem(KEY, JSON.stringify(s));
  } catch {
    /* storage full or unavailable */
  }
}

export function wipeSave() {
  localStorage.removeItem(KEY);
}
