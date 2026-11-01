import { ABILITIES, CHARMS_INFO, COATS, getDef, LEVEL_TITLES, levelBonus, RARITY_COLOR, XP_FOR_LEVEL } from './catalog';
import { cardArt, portrait } from './art';
import { esc, roman } from './dom';
import { fullName, RANK_TITLES, type Nemesis } from '../core/nemesis';
import { TRAITS } from '../core/traits';
import type { CardDef, CardInst } from '../core/types';
import type { CharmId } from '../core/charms';
import type { RunState } from '../core/game';
import { START_LIVES, STEPS_PER_RING } from '../core/game';

export type CardSize = 'hand' | 'board' | 'large' | 'pick' | 'mini';

export interface CardOpts {
  size: CardSize;
  power?: number;
  boosted?: boolean;
  weakened?: boolean;
  advantage?: boolean;
  attrs?: string;
  cls?: string;
  price?: number;
}

export function typeIcon(d: CardDef) {
  if (d.kind === 'special') return '✧';
  return d.type === 'magic' ? '◉' : '⚔';
}

export function cardHTML(c: CardInst | CardDef, o: CardOpts): string {
  const inst = 'uid' in c ? (c as CardInst) : null;
  const def = inst ? getDef(inst) : (c as CardDef);
  const level = inst?.level ?? 1;
  const base = def.power + (def.kind === 'unit' ? levelBonus(level) : 0);
  const power = o.power ?? base;
  const ab = ABILITIES[def.ability];
  const coat = def.coat !== 'none' ? COATS[def.coat] : null;
  const pcls = o.power === undefined ? '' : power > base ? 'up' : power < base ? 'down' : '';
  const stars = level > 1 ? `<div class="stars">${'★'.repeat(level - 1)}</div>` : '';
  const showText = o.size !== 'board' && o.size !== 'mini';
  return `<div class="card sz-${o.size} ${def.kind} r-${def.rarity} ${o.cls ?? ''}" style="--rar:${RARITY_COLOR[def.rarity]};--coat:${coat?.color ?? '#9aa'}" ${o.attrs ?? ''}>
    <div class="art" style="background-image:url(${cardArt(def)})"></div>
    ${def.kind === 'unit' ? `<div class="power ${pcls} ${def.rarity === 'legendary' ? 'legend' : ''}">${power}</div>` : `<div class="power special-icon">${ab.icon}</div>`}
    ${def.kind === 'unit' ? `<div class="type-icon">${typeIcon(def)}</div>` : ''}
    ${coat ? `<div class="coat-pip" title="${coat.name}"></div>` : ''}
    ${o.advantage ? '<div class="adv" title="Coat advantage +2">▲</div>' : ''}
    ${stars}
    ${def.ability !== 'none' && def.kind === 'unit' ? `<div class="ab-icon" title="${esc(ab.name)}">${ab.icon}</div>` : ''}
    ${showText ? `<div class="name">${esc(def.name)}</div>` : ''}
    ${showText && (o.size === 'large' || o.size === 'pick') ? `<div class="ab-text"><b>${esc(ab.name)}</b>${def.ability === 'none' ? '' : ' — ' + esc(ab.desc.replace(/^[A-Za-z ]+: /, ''))}</div>` : ''}
    ${o.size === 'large' || o.size === 'pick' ? `<div class="meta">${def.kind === 'unit' ? (def.type === 'magic' ? 'Magic · Arcane row' : 'Physical · Vanguard row') : 'Special'} · <span class="rar-${def.rarity}">${def.rarity}</span></div>` : ''}
    ${o.price !== undefined ? `<div class="price">${o.price} ⋔</div>` : ''}
  </div>`;
}

export function cardDetailHTML(c: CardInst | CardDef, power?: number): string {
  const inst = 'uid' in c ? (c as CardInst) : null;
  const def = inst ? getDef(inst) : (c as CardDef);
  const coat = def.coat !== 'none' ? COATS[def.coat] : null;
  const xp =
    inst && def.kind === 'unit'
      ? inst.level >= 3
        ? `<div class="xp">Level 3 · ${LEVEL_TITLES[3]} (max)</div>`
        : `<div class="xp">Level ${inst.level}${LEVEL_TITLES[inst.level] ? ' · ' + LEVEL_TITLES[inst.level] : ''} · XP ${inst.xp}/${XP_FOR_LEVEL[inst.level + 1]}</div>`
      : '';
  return `<div class="detail">
    ${cardHTML(c, { size: 'large', power })}
    <div class="detail-body">
      <div class="detail-ab"><b>${esc(ABILITIES[def.ability].name)}</b><br>${esc(ABILITIES[def.ability].desc)}</div>
      ${coat ? `<div class="detail-coat"><span class="dot" style="background:${coat.color}"></span><b>${coat.name}</b> — ${esc(coat.desc)}</div>` : ''}
      ${xp}
      <div class="flavor">“${esc(def.flavor)}”</div>
    </div>
  </div>`;
}

export function nemesisPortrait(n: Nemesis, rank = 0) {
  return portrait({
    seed: n.seed,
    coat: n.coat,
    magic: ['hex', 'inspire', 'groom'].includes(n.style),
    ability: n.style,
    legendary: false,
    crown: rank === 1,
    scars: n.scars,
    menace: true,
  });
}

export function playerPortrait(name: string) {
  let h = 0;
  for (const ch of name) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return portrait({ seed: h, coat: 'gilt', magic: false, ability: 'smite', legendary: false, crown: false });
}

export function traitChips(n: Nemesis, showHidden = true) {
  const chips = n.traits.map((t) => {
    if (!t.known)
      return showHidden ? `<span class="trait hidden" title="Unknown trait. Gather intel to reveal it.">???</span>` : '';
    const info = TRAITS[t.id];
    return `<span class="trait ${info.kind}" title="${esc(info.desc)}">${esc(info.name)}</span>`;
  });
  if (n.wins > 0)
    chips.push(`<span class="trait strength" title="${esc(TRAITS.grudge.desc)}">Grudge ×${n.wins}</span>`);
  return chips.join('');
}

export function nemesisCardHTML(n: Nemesis, rank: number, opts: { attrs?: string; compact?: boolean } = {}) {
  const last = n.history.slice(-3).reverse();
  return `<div class="nem-card ${opts.compact ? 'compact' : ''} coat-${n.coat}" ${opts.attrs ?? ''}>
    <div class="nem-rank">${rank ? RANK_TITLES[rank] : n.status}</div>
    <div class="nem-portrait" style="background-image:url(${nemesisPortrait(n, rank)})"></div>
    <div class="nem-name">${esc(n.name)}</div>
    <div class="nem-epithet">${esc(n.epithet)}</div>
    <div class="nem-stats">
      <span>Lv ${n.level}</span>
      <span style="color:${COATS[n.coat].color}">${COATS[n.coat].name}</span>
      <span title="Times they beat you">☠ ${n.wins}</span>
      <span title="Times you beat them">⚔ ${n.losses}</span>
    </div>
    <div class="traits">${traitChips(n)}</div>
    ${opts.compact ? '' : `<div class="nem-history">${last.map((h) => `<div>${esc(h.text)}</div>`).join('')}</div>`}
  </div>`;
}

export function charmHTML(id: CharmId, opts: { price?: number; attrs?: string; cls?: string } = {}) {
  const c = CHARMS_INFO[id];
  return `<div class="charm ${opts.cls ?? ''}" ${opts.attrs ?? ''} title="${esc(c.name)}: ${esc(c.desc)}">
    <div class="charm-icon">${c.icon}</div>
    <div class="charm-body"><b>${esc(c.name)}</b><span>${esc(c.desc)}</span></div>
    ${opts.price !== undefined ? `<div class="price">${opts.price} ⋔</div>` : ''}
  </div>`;
}

export const RING_NAMES = ['', 'The Gutter Ring', 'The Yard', 'The Rooftops', 'The Moon Court'];

export function hudHTML(run: RunState) {
  const lives = Array.from({ length: START_LIVES }, (_, i) => `<span class="life ${i < run.lives ? 'on' : ''}">♥</span>`).join('');
  const steps = Array.from({ length: STEPS_PER_RING }, (_, i) =>
    `<span class="step ${i < run.step ? 'done' : i === run.step ? 'now' : ''} ${i === STEPS_PER_RING - 1 ? 'boss' : ''}"></span>`,
  ).join('');
  return `<div class="hud">
    <div class="hud-ring"><span class="label">Ring ${roman(run.ring)}</span> ${esc(RING_NAMES[run.ring] ?? '')} <span class="steps">${steps}</span></div>
    <div class="hud-lives" title="Nine lives. Losing a duel costs lives.">${lives}</div>
    <div class="hud-fish" title="Fish (currency)">${run.fish} ⋔</div>
    <div class="hud-charms">${run.charms.map((c) => `<span class="hud-charm" title="${esc(CHARMS_INFO[c].name)}: ${esc(CHARMS_INFO[c].desc)}">${CHARMS_INFO[c].icon}</span>`).join('')}</div>
    <button class="btn small ghost" data-act="deck">Deck (${run.deck.length})</button>
    <button class="btn small ghost" data-act="hands">The Four Hands</button>
    <button class="btn small ghost" data-act="menu">☰</button>
  </div>`;
}

export function deckGridHTML(deck: CardInst[], attr?: (c: CardInst) => string) {
  const sorted = [...deck].sort((a, b) => {
    const da = getDef(a);
    const db = getDef(b);
    return (da.kind === db.kind ? 0 : da.kind === 'unit' ? -1 : 1) || (db.type ?? '').localeCompare(da.type ?? '') || db.power - da.power;
  });
  return `<div class="deck-grid">${sorted.map((c) => cardHTML(c, { size: 'hand', attrs: `data-uid="${c.uid}" ${attr ? attr(c) : ''}` })).join('')}</div>`;
}

export const nemesisTitle = (n: Nemesis) => fullName(n);
