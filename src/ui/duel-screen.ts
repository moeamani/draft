import { aiChoose, STYLE_BY_PERSONALITY } from '../core/ai';
import { canPlay, hasAdvantage, mulligan, pass, playCard, rowScore, score, takeEvents, unitPower, type DuelEvent } from '../core/duel';
import { resolveDuel, rankOf, type DuelContext, type DuelOutcome } from '../core/game';
import { portrait } from './art';
import { sfx } from './audio';
import { cardDetailHTML, cardHTML, nemesisPortrait, playerPortrait } from './components';
import { banner, esc, float, stageRect, toast } from './dom';
import { TRAITS, type TraitId } from '../core/traits';
import { ROWS, type Row } from '../core/types';
import type { App } from './app';

const MULLIGANS = 2;

export function showDuel(app: App, ctx: DuelContext, onDone: (out: DuelOutcome) => void) {
  const s = ctx.state;
  const stage = app.stage;
  const save = app.save!;
  let phase: 'mulligan' | 'play' | 'done' = 'mulligan';
  let mulligansLeft = MULLIGANS;
  let busyUntil = 0;
  let aiTimer = 0;
  const style = STYLE_BY_PERSONALITY[ctx.personality] ?? STYLE_BY_PERSONALITY.default;
  const n = ctx.nemesis;
  const enemyPortrait = n
    ? nemesisPortrait(n, rankOf(save, n))
    : portrait({ seed: ctx.node.foe?.seed ?? 1, coat: ctx.node.foe?.coat ?? 'shadow', magic: false, ability: 'none', legendary: false, menace: !!ctx.node.foe?.elite });

  app.render(`<div class="duel" id="duel"></div>`, 'duel-screen', {
    pass: () => {
      if (phase === 'mulligan') return startPlay();
      if (!canPlay(s, 0) || Date.now() < busyUntil) return;
      sfx.pass();
      pass(s, 0);
      after();
    },
    hand: (el) => {
      const uid = el.dataset.huid!;
      if (phase === 'mulligan') {
        if (mulligansLeft <= 0) return;
        if (mulligan(s, 0, uid)) {
          mulligansLeft--;
          sfx.play();
          draw();
          if (mulligansLeft <= 0) setTimeout(startPlay, 350);
        }
        return;
      }
      if (!canPlay(s, 0) || Date.now() < busyUntil) return;
      sfx.play();
      playCard(s, 0, uid);
      after();
    },
  });
  const root = stage.querySelector('#duel') as HTMLElement;

  root.addEventListener('mouseover', (e) => {
    const el = (e.target as HTMLElement).closest('[data-huid],[data-uid]') as HTMLElement | null;
    if (!el) return;
    const slot = root.querySelector('.detail-slot') as HTMLElement;
    if (el.dataset.huid) {
      const c = s.sides[0].hand.find((x) => x.uid === el.dataset.huid);
      if (c) slot.innerHTML = cardDetailHTML(c);
    } else if (el.dataset.uid) {
      for (let side = 0; side < 2; side++)
        for (const row of ROWS) {
          const u = s.sides[side].rows[row].find((x) => x.uid === el.dataset.uid);
          if (u) slot.innerHTML = cardDetailHTML(u.inst, unitPower(s, side, row, u));
        }
    }
  });

  function rowHTML(side: number, row: Row) {
    const sd = s.sides[side];
    const horned = sd.horn[row] || sd.rows[row].some((u) => u.def.ability === 'yowl');
    const cards = sd.rows[row]
      .map((u) =>
        cardHTML(u.inst, {
          size: 'board',
          power: unitPower(s, side, row, u),
          advantage: hasAdvantage(s, side, row, u),
          attrs: `data-uid="${u.uid}"`,
          cls: u.origin !== side ? 'stray-unit' : '',
        }),
      )
      .join('');
    return `<div class="row ${side === 0 ? 'me' : 'foe'} ${row} ${s.weather[row] ? 'weather' : ''}">
      <div class="row-head">
        <div class="row-icon" title="${row === 'vanguard' ? 'Vanguard (Physical)' : 'Arcane (Magic)'}">${row === 'vanguard' ? '⚔' : '◉'}</div>
        <div class="row-score">${rowScore(s, side, row)}</div>
        ${horned ? '<div class="row-horn" title="Doubled by a War Yowl">♬</div>' : ''}
      </div>
      <div class="row-cards">${cards}</div>
      ${s.weather[row] ? `<div class="weather-fx ${row}"></div>` : ''}
    </div>`;
  }

  function gems(side: number) {
    return `<div class="gems">${[0, 1].map((i) => `<span class="gem ${i < s.sides[side].gems ? 'on' : ''}">♦</span>`).join('')}</div>`;
  }

  function enemyTraits() {
    if (!n) {
      const elite = ctx.node.foe?.elite;
      return elite ? `<div class="traits small">${s.revealed[1].map((t) => `<span class="trait strength">${TRAITS[t as TraitId]?.name ?? t}</span>`).join('') || '<span class="trait hidden">elite ???</span>'}</div>` : '';
    }
    const chips = n.traits.map((t) => {
      const known = t.known || s.revealed[1].includes(t.id);
      const info = TRAITS[t.id];
      return known ? `<span class="trait ${info.kind}" title="${esc(info.desc)}">${esc(info.name)}</span>` : `<span class="trait hidden">???</span>`;
    });
    if (n.wins) chips.push(`<span class="trait strength" title="${esc(TRAITS.grudge.desc)}">Grudge ×${n.wins}</span>`);
    return `<div class="traits small">${chips.join('')}</div>`;
  }

  function draw() {
    const me = s.sides[0];
    const foe = s.sides[1];
    const myTurn = phase === 'play' && canPlay(s, 0);
    const turnLabel =
      phase === 'mulligan'
        ? `Redraw up to ${mulligansLeft} card${mulligansLeft === 1 ? '' : 's'}`
        : s.over
          ? 'Duel over'
          : myTurn
            ? 'Your turn'
            : foe.passed && me.passed
              ? '…'
              : `${esc(foe.name)} is thinking…`;
    root.innerHTML = `
      <div class="duel-left">
        <div class="side-panel foe ${foe.passed ? 'passed' : ''} ${s.turn === 1 && phase === 'play' && !s.over ? 'active' : ''}">
          <div class="sp-portrait" style="background-image:url(${enemyPortrait})"></div>
          <div class="sp-name">${esc(foe.name)}</div>
          <div class="sp-sub">${n ? esc(n.epithet) : esc(ctx.node.foe?.name.split(' the ')[1] ?? '')}</div>
          ${gems(1)}
          <div class="sp-counts"><span title="Cards in hand">✋ ${foe.hand.length}</span><span title="Cards in deck">▤ ${foe.deck.length}</span></div>
          ${enemyTraits()}
          <div class="sp-score">${score(s, 1)}</div>
          ${foe.passed ? '<div class="passed-tag">Passed</div>' : ''}
        </div>
        <div class="duel-mid">
          <div class="round-label">Round ${s.round}</div>
          <div class="turn-label ${myTurn ? 'mine' : ''}">${turnLabel}</div>
          <div class="weather-list">${s.weather.vanguard ? '<span>☂ Downpour</span>' : ''}${s.weather.arcane ? '<span>☁ Moonfog</span>' : ''}</div>
        </div>
        <div class="side-panel me ${me.passed ? 'passed' : ''} ${myTurn ? 'active' : ''}">
          <div class="sp-score">${score(s, 0)}</div>
          <div class="sp-portrait" style="background-image:url(${playerPortrait(save.playerName)})"></div>
          <div class="sp-name">${esc(me.name)}</div>
          ${gems(0)}
          <div class="sp-counts"><span title="Cards in hand">✋ ${me.hand.length}</span><span title="Cards in deck">▤ ${me.deck.length}</span></div>
          ${me.passed ? '<div class="passed-tag">Passed</div>' : ''}
          <button class="btn ${phase === 'mulligan' ? 'primary' : 'pass-btn'} ${phase === 'play' && !myTurn ? 'disabled' : ''}" data-act="pass">${phase === 'mulligan' ? 'Keep hand' : 'Pass'}</button>
        </div>
      </div>
      <div class="board">
        <div class="foe-hand">${foe.hand.map(() => '<div class="card-back"></div>').join('')}</div>
        ${rowHTML(1, 'arcane')}
        ${rowHTML(1, 'vanguard')}
        <div class="divider"><span>${score(s, 0)}</span><i></i><span>${score(s, 1)}</span></div>
        ${rowHTML(0, 'vanguard')}
        ${rowHTML(0, 'arcane')}
        <div class="hand ${myTurn || phase === 'mulligan' ? 'live' : ''} ${phase === 'mulligan' ? 'mull' : ''}">
          ${me.hand.map((c) => cardHTML(c, { size: 'hand', attrs: `data-act="hand" data-huid="${c.uid}"`, cls: 'clickable' })).join('')}
        </div>
      </div>
      <div class="duel-right">
        <div class="detail-slot"><div class="muted">Hover any card to inspect it.</div></div>
        <div class="log">${s.log.slice(-14).map((l) => `<div>${esc(l)}</div>`).join('')}</div>
      </div>
      ${phase === 'mulligan' ? `<div class="mull-tip">Click up to ${mulligansLeft} card${mulligansLeft === 1 ? '' : 's'} to swap them, then <b>Keep hand</b>.</div>` : ''}`;
    const log = root.querySelector('.log');
    if (log) log.scrollTop = log.scrollHeight;
  }

  function startPlay() {
    if (phase !== 'mulligan') return;
    phase = 'play';
    takeEvents(s);
    draw();
    if (ctx.spyglass) toast(stage, `Spyglass: ${n?.name} has ${TRAITS[ctx.spyglass].name}`, 'info');
    banner(stage, s.turn === 0 ? 'You lead' : `${s.sides[1].name} leads`, `Round ${s.round}`);
    busyUntil = Date.now() + 900;
    if (s.turn === 1) scheduleAi(1200);
  }

  function handleEvents(events: DuelEvent[]): number {
    let delay = 0;
    const banners = events.filter((e) => e.t === 'banner') as Extract<DuelEvent, { t: 'banner' }>[];
    banners.forEach((b, i) => setTimeout(() => banner(stage, b.text, b.sub), i * 1250));
    delay += banners.length * 1250;
    for (const e of events) {
      if (e.t === 'float') {
        const el = root.querySelector(`[data-uid="${e.uid}"]`);
        if (el) {
          const r = stageRect(el, stage);
          float(stage, r.x + r.w / 2, r.y + 10, e.text, e.good);
        }
      } else if (e.t === 'destroy') {
        sfx.hit();
      } else if (e.t === 'trait') {
        sfx.reveal();
        const name = TRAITS[e.trait as TraitId]?.name ?? e.trait;
        toast(stage, `${e.side === 1 ? s.sides[1].name : 'You'}: ${name} revealed!`, e.side === 1 ? 'info' : 'good');
      } else if (e.t === 'play' && e.side === 1) {
        sfx.enemy();
        const el = root.querySelector(`[data-uid="${e.uid}"]`);
        el?.classList.add('just-played');
      } else if (e.t === 'play' && e.side === 0) {
        const el = root.querySelector(`[data-uid="${e.uid}"]`);
        el?.classList.add('just-played');
      } else if (e.t === 'pass' && e.side === 1) {
        toast(stage, `${s.sides[1].name} passes.`, 'info');
      }
    }
    return delay;
  }

  function after() {
    const events = takeEvents(s);
    draw();
    const delay = handleEvents(events);
    busyUntil = Date.now() + Math.max(250, delay);
    if (s.over) return finish(delay);
    if (s.turn === 1) scheduleAi(delay + 850);
  }

  function scheduleAi(ms: number) {
    clearTimeout(aiTimer);
    aiTimer = window.setTimeout(() => {
      if (s.over || s.turn !== 1 || !root.isConnected) return;
      const a = aiChoose(s, 1, style);
      if (a.type === 'pass') {
        if (s.sides[1].mods.arrogant && score(s, 1) > score(s, 0) && !s.sides[0].passed && !s.revealed[1].includes('arrogant')) {
          s.revealed[1].push('arrogant');
          toast(stage, `${s.sides[1].name} passes smugly: Arrogant revealed!`, 'info');
        }
        pass(s, 1);
        sfx.pass();
      } else playCard(s, 1, a.uid);
      after();
    }, ms);
  }

  function finish(delay: number) {
    phase = 'done';
    setTimeout(() => {
      if (!root.isConnected) return;
      const out = resolveDuel(save, ctx);
      onDone(out);
    }, delay + 1400);
  }

  draw();
}
