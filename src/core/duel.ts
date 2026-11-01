import { CARDS, COATS, COAT_ADVANTAGE, getDef, isLegend, levelBonus } from './cards';
import { makeRng, shuffle, type Rng } from './rng';
import { baseMods, type SideMods } from './traits';
import { ROWS, rowOf, type CardDef, type CardInst, type Row } from './types';

export interface Unit {
  uid: string;
  inst: CardInst;
  def: CardDef;
  level: number;
  /** Permanent modifier: damage (negative) or buffs (positive). */
  mod: number;
  ninelivesUsed: boolean;
  /** Side index that owns the card (strays sit on the other side). */
  origin: number;
}

export interface Side {
  name: string;
  deck: CardInst[];
  hand: CardInst[];
  discard: CardInst[];
  rows: Record<Row, Unit[]>;
  horn: Record<Row, boolean>;
  passed: boolean;
  gems: number;
  mods: SideMods;
  unitsThisRound: number;
  /** uids of card instances played from hand this duel (for XP). */
  played: string[];
}

export type DuelEvent =
  | { t: 'play'; side: number; name: string; uid: string }
  | { t: 'float'; uid: string; text: string; good: boolean }
  | { t: 'destroy'; side: number; name: string }
  | { t: 'banner'; text: string; sub?: string }
  | { t: 'trait'; side: number; trait: string }
  | { t: 'pass'; side: number }
  | { t: 'draw'; side: number; n: number }
  | { t: 'log'; text: string };

export interface RoundRecord {
  scores: [number, number];
  winner: -1 | 0 | 1 | 2; // 2 = tie
}

export interface DuelState {
  sides: [Side, Side];
  weather: Record<Row, boolean>;
  round: number;
  turn: 0 | 1;
  rng: Rng;
  over: boolean;
  result: 'win' | 'loss' | 'draw' | null;
  rounds: RoundRecord[];
  events: DuelEvent[];
  log: string[];
  /** Trait ids revealed during this duel, per side. */
  revealed: [string[], string[]];
  uidc: number;
  sim: boolean;
}

export interface DuelSetup {
  name: string;
  deck: CardInst[];
  mods?: SideMods;
}

const HAND_SIZE = 8;
const MAX_HAND = 10;

function emptySide(setup: DuelSetup): Side {
  return {
    name: setup.name,
    deck: setup.deck.map((c) => ({ ...c })),
    hand: [],
    discard: [],
    rows: { vanguard: [], arcane: [] },
    horn: { vanguard: false, arcane: false },
    passed: false,
    gems: 2,
    mods: setup.mods ?? baseMods(),
    unitsThisRound: 0,
    played: [],
  };
}

export function createDuel(a: DuelSetup, b: DuelSetup, seed: number, first: 0 | 1 = 0): DuelState {
  const s: DuelState = {
    sides: [emptySide(a), emptySide(b)],
    weather: { vanguard: false, arcane: false },
    round: 1,
    turn: first,
    rng: makeRng(seed),
    over: false,
    result: null,
    rounds: [],
    events: [],
    log: [],
    revealed: [[], []],
    uidc: 0,
    sim: false,
  };
  for (let i = 0; i < 2; i++) {
    const side = s.sides[i];
    shuffle(s.rng, side.deck);
    const n = Math.max(5, Math.min(MAX_HAND, HAND_SIZE + side.mods.extraDraw));
    if (side.mods.extraDraw !== 0) reveal(s, i, side.mods.source.extraDraw);
    draw(s, i, n, true);
  }
  startRound(s);
  return s;
}

export function cloneDuel(s: DuelState): DuelState {
  const c = structuredClone(s);
  c.events = [];
  c.log = [];
  c.sim = true;
  return c;
}

// ---------------------------------------------------------------- helpers

function emit(s: DuelState, e: DuelEvent) {
  if (s.sim) return;
  s.events.push(e);
  if (e.t === 'log') s.log.push(e.text);
}

function log(s: DuelState, text: string) {
  emit(s, { t: 'log', text });
}

export function reveal(s: DuelState, side: number, trait: string | undefined) {
  if (!trait || s.sim) return;
  if (s.revealed[side].includes(trait)) return;
  s.revealed[side].push(trait);
  emit(s, { t: 'trait', side, trait });
}

function draw(s: DuelState, side: number, n: number, silent = false) {
  const sd = s.sides[side];
  let drawn = 0;
  for (let i = 0; i < n && sd.deck.length && sd.hand.length < MAX_HAND; i++) {
    sd.hand.push(sd.deck.pop()!);
    drawn++;
  }
  if (drawn && !silent) emit(s, { t: 'draw', side, n: drawn });
}

function uid(s: DuelState) {
  return 'u' + s.uidc++;
}

export function allUnits(s: DuelState, side: number): { unit: Unit; row: Row }[] {
  const out: { unit: Unit; row: Row }[] = [];
  for (const row of ROWS) for (const unit of s.sides[side].rows[row]) out.push({ unit, row });
  return out;
}

const rawPower = (u: Unit) => u.def.power + levelBonus(u.level) + u.mod;

export function unitPower(s: DuelState, side: number, row: Row, u: Unit): number {
  const me = s.sides[side];
  const opp = s.sides[1 - side];
  const legendary = isLegend(u.def);
  let p = rawPower(u);
  if (!legendary) {
    if (s.weather[row] && !me.mods.weatherImmune) {
      p = me.mods.weatherZero ? 0 : Math.min(p, me.mods.weatherFloor);
    }
    if (u.def.ability === 'litter') {
      p *= me.rows[row].filter((x) => x.def.id === u.def.id).length;
    }
    p += me.rows[row].filter((x) => x !== u && x.def.ability === 'inspire').length;
    const horned = me.horn[row] || me.rows[row].some((x) => x !== u && x.def.ability === 'yowl');
    if (horned) p *= 2;
  } else {
    p += me.mods.legendBonus;
  }
  p += row === 'vanguard' ? me.mods.vanguardBonus : me.mods.arcaneBonus;
  if (u.def.coat !== 'none') {
    p += me.mods.coatBonus[u.def.coat] ?? 0;
    if (hasAdvantage(s, side, row, u)) p += COAT_ADVANTAGE;
    if (opp.mods.dread && opp.mods.dread === u.def.coat) p += 2;
  }
  return Math.max(0, p);
}

export function hasAdvantage(s: DuelState, side: number, row: Row, u: Unit): boolean {
  if (u.def.coat === 'none') return false;
  const beats = COATS[u.def.coat].beats;
  if (!beats) return false;
  return s.sides[1 - side].rows[row].some((x) => x.def.coat === beats);
}

export function rowScore(s: DuelState, side: number, row: Row): number {
  return s.sides[side].rows[row].reduce((a, u) => a + unitPower(s, side, row, u), 0);
}

export function score(s: DuelState, side: number): number {
  return rowScore(s, side, 'vanguard') + rowScore(s, side, 'arcane');
}

function findUnit(s: DuelState, unitUid: string): { side: number; row: Row; unit: Unit } | null {
  for (let side = 0; side < 2; side++)
    for (const row of ROWS) {
      const unit = s.sides[side].rows[row].find((x) => x.uid === unitUid);
      if (unit) return { side, row, unit };
    }
  return null;
}

/** Remove a unit from the board into its origin's discard. */
function destroy(s: DuelState, side: number, row: Row, u: Unit) {
  const r = s.sides[side].rows[row];
  const i = r.indexOf(u);
  if (i < 0) return;
  r.splice(i, 1);
  if (!u.def.token) s.sides[u.origin].discard.push(u.inst);
  emit(s, { t: 'destroy', side, name: u.def.name });
  log(s, `${u.def.name} is destroyed.`);
  const sd = s.sides[side];
  if (sd.mods.vengeful) {
    const best = strongest(s, side, false);
    if (best.length) {
      best[0].unit.mod += 2;
      emit(s, { t: 'float', uid: best[0].unit.uid, text: '+2 vengeance', good: side !== 0 });
      reveal(s, side, sd.mods.source.vengeful);
    }
  }
}

function damage(s: DuelState, side: number, row: Row, u: Unit, amount: number, kind: 'hex' | 'pounce') {
  if (isLegend(u.def) || amount <= 0) return;
  const sd = s.sides[side];
  if (sd.mods.thickfur) {
    emit(s, { t: 'float', uid: u.uid, text: 'immune', good: side === 0 });
    reveal(s, side, sd.mods.source.thickfur);
    return;
  }
  u.mod -= amount;
  emit(s, { t: 'float', uid: u.uid, text: `-${amount}`, good: side !== 0 });
  log(s, `${u.def.name} takes ${amount} (${kind}).`);
  if (rawPower(u) <= 0) destroy(s, side, row, u);
}

/** Strongest unit(s) of a side by effective power, ties included. */
function strongest(s: DuelState, side: number, includeLegend: boolean, onlyRow?: Row) {
  let best = -1;
  let out: { unit: Unit; row: Row; p: number }[] = [];
  for (const { unit, row } of allUnits(s, side)) {
    if (onlyRow && row !== onlyRow) continue;
    if (!includeLegend && isLegend(unit.def)) continue;
    const p = unitPower(s, side, row, unit);
    if (p > best) {
      best = p;
      out = [{ unit, row, p }];
    } else if (p === best) out.push({ unit, row, p });
  }
  return out;
}

// ---------------------------------------------------------------- playing

export function canPlay(s: DuelState, side: number): boolean {
  return !s.over && s.turn === side && !s.sides[side].passed;
}

function placeUnit(s: DuelState, side: number, inst: CardInst, fromHand: boolean): { unit: Unit; row: Row; boardSide: number } {
  const def = getDef(inst);
  const row = rowOf(def.type);
  const boardSide = def.ability === 'stray' ? 1 - side : side;
  const unit: Unit = {
    uid: uid(s),
    inst,
    def,
    level: inst.level,
    mod: 0,
    ninelivesUsed: false,
    origin: side,
  };
  const me = s.sides[side];
  if (fromHand && boardSide === side) {
    if (me.unitsThisRound === 0 && me.mods.firstUnitBonus !== 0 && !isLegend(def)) {
      unit.mod += me.mods.firstUnitBonus;
      const src = me.mods.source.firstUnitBonus;
      if (src) reveal(s, side, src);
    }
    me.unitsThisRound++;
  }
  s.sides[boardSide].rows[row].push(unit);
  if (row === 'vanguard' && s.sides[boardSide].mods.vanguardBonus) reveal(s, boardSide, s.sides[boardSide].mods.source.vanguardBonus);
  if (row === 'arcane' && s.sides[boardSide].mods.arcaneBonus) reveal(s, boardSide, s.sides[boardSide].mods.source.arcaneBonus);
  const enemy = s.sides[1 - side];
  if (enemy.mods.dread && enemy.mods.dread === def.coat) reveal(s, 1 - side, enemy.mods.source.dread);
  if (s.weather[row]) revealWeather(s, boardSide);
  return { unit, row, boardSide };
}

function revealWeather(s: DuelState, side: number) {
  const m = s.sides[side].mods;
  if (m.weatherImmune) reveal(s, side, m.source.weatherImmune);
  if (m.weatherZero) reveal(s, side, m.source.weatherZero);
}

function triggerUnit(s: DuelState, side: number, unit: Unit, row: Row, depth = 0) {
  const opp = 1 - side;
  const me = s.sides[side];
  switch (unit.def.ability) {
    case 'smite': {
      const targets = strongest(s, opp, false);
      if (targets.length && targets[0].p > 0) {
        for (const t of targets) destroy(s, opp, t.row, t.unit);
      }
      break;
    }
    case 'hex': {
      const t = strongest(s, opp, false)[0];
      if (!t) break;
      const cats = allUnits(s, side).filter((x) => x.unit.def.ability === 'hex' && x.unit.origin === side).length;
      const om = s.sides[opp].mods;
      const dmg = cats + me.mods.hexBonus + om.hexVuln;
      if (om.hexVuln) reveal(s, opp, om.source.hexVuln);
      damage(s, opp, t.row, t.unit, dmg, 'hex');
      break;
    }
    case 'pounce': {
      const t = strongest(s, opp, false, row)[0];
      if (!t) break;
      const om = s.sides[opp].mods;
      let dmg = 3 + me.mods.pounceBonus;
      if (om.pounceVuln) {
        dmg *= 2;
        reveal(s, opp, om.source.pounceVuln);
      }
      damage(s, opp, t.row, t.unit, dmg, 'pounce');
      break;
    }
    case 'groom': {
      if (depth > 3) break;
      let bestI = -1;
      let bestP = -1;
      me.discard.forEach((c, i) => {
        const d = getDef(c);
        if (d.kind !== 'unit' || isLegend(d) || d.ability === 'stray' || d.token) return;
        const p = d.power + levelBonus(c.level);
        if (p > bestP) {
          bestP = p;
          bestI = i;
        }
      });
      if (bestI >= 0) {
        const [inst] = me.discard.splice(bestI, 1);
        const placed = placeUnit(s, side, inst, false);
        emit(s, { t: 'float', uid: placed.unit.uid, text: 'groomed back!', good: side === 0 });
        log(s, `${placed.unit.def.name} is groomed back to health.`);
        triggerUnit(s, side, placed.unit, placed.row, depth + 1);
      }
      break;
    }
    case 'purr': {
      let weakest: { unit: Unit; p: number } | null = null;
      for (const x of allUnits(s, side)) {
        if (x.unit === unit || isLegend(x.unit.def)) continue;
        const p = unitPower(s, side, x.row, x.unit);
        if (!weakest || p < weakest.p) weakest = { unit: x.unit, p };
      }
      if (weakest) {
        weakest.unit.mod += 2;
        emit(s, { t: 'float', uid: weakest.unit.uid, text: '+2 purr', good: side === 0 });
      }
      break;
    }
    case 'muster': {
      const copies = me.deck.filter((c) => c.id === unit.def.id);
      for (const c of copies) {
        me.deck.splice(me.deck.indexOf(c), 1);
        const placed = placeUnit(s, side, c, false);
        emit(s, { t: 'float', uid: placed.unit.uid, text: 'answers the call', good: side === 0 });
      }
      break;
    }
    case 'stray': {
      draw(s, side, 2);
      log(s, `${unit.def.name} wanders over to ${s.sides[opp].name}. ${me.name} draws 2.`);
      break;
    }
    default:
      break;
  }
}

function bestHornRow(s: DuelState, side: number): Row {
  let best: Row = 'vanguard';
  let gain = -1;
  for (const row of ROWS) {
    if (s.sides[side].horn[row]) continue;
    const before = rowScore(s, side, row);
    s.sides[side].horn[row] = true;
    const g = rowScore(s, side, row) - before;
    s.sides[side].horn[row] = false;
    if (g > gain) {
      gain = g;
      best = row;
    }
  }
  return best;
}

function playSpecial(s: DuelState, side: number, inst: CardInst, def: CardDef) {
  const me = s.sides[side];
  switch (def.ability) {
    case 'downpour':
      s.weather.vanguard = true;
      emit(s, { t: 'banner', text: 'Downpour', sub: 'Vanguard units drop to 1' });
      revealWeather(s, 0);
      revealWeather(s, 1);
      break;
    case 'moonfog':
      s.weather.arcane = true;
      emit(s, { t: 'banner', text: 'Moonfog', sub: 'Arcane units drop to 1' });
      revealWeather(s, 0);
      revealWeather(s, 1);
      break;
    case 'sunbeam':
      s.weather.vanguard = false;
      s.weather.arcane = false;
      emit(s, { t: 'banner', text: 'Sunbeam', sub: 'The weather clears' });
      break;
    case 'warhorn': {
      const row = bestHornRow(s, side);
      me.horn[row] = true;
      log(s, `${me.name} rallies the ${row}.`);
      break;
    }
    case 'box': {
      let best: { unit: Unit; row: Row; p: number } | null = null;
      for (const x of allUnits(s, side)) {
        if (isLegend(x.unit.def) || x.unit.origin !== side || x.unit.def.token) continue;
        const p = x.unit.def.power + levelBonus(x.unit.level);
        if (!best || p > best.p) best = { ...x, p };
      }
      if (best) {
        const r = me.rows[best.row];
        r.splice(r.indexOf(best.unit), 1);
        me.hand.push(best.unit.inst);
        log(s, `${best.unit.def.name} hides in a box (back to hand).`);
      }
      break;
    }
    case 'hairball': {
      let top = 0;
      const hits: { side: number; row: Row; unit: Unit }[] = [];
      for (let sd = 0; sd < 2; sd++)
        for (const x of strongest(s, sd, false)) {
          if (x.p > top) {
            top = x.p;
            hits.length = 0;
          }
          if (x.p === top && top > 0) hits.push({ side: sd, row: x.row, unit: x.unit });
        }
      emit(s, { t: 'banner', text: 'Hairball!', sub: hits.length ? `${top}-power units destroyed` : 'Nothing to hit' });
      for (const h of hits) destroy(s, h.side, h.row, h.unit);
      break;
    }
    default:
      break;
  }
  me.discard.push(inst);
}

/** Resolve a card from hand without advancing the turn (used by AI simulation too). */
export function resolvePlay(s: DuelState, side: number, handUid: string): boolean {
  const me = s.sides[side];
  const idx = me.hand.findIndex((c) => c.uid === handUid);
  if (idx < 0) return false;
  const [inst] = me.hand.splice(idx, 1);
  const def = getDef(inst);
  me.played.push(inst.uid);
  log(s, `${me.name} plays ${def.name}.`);
  if (def.kind === 'special') {
    emit(s, { t: 'play', side, name: def.name, uid: '' });
    playSpecial(s, side, inst, def);
  } else {
    const placed = placeUnit(s, side, inst, true);
    emit(s, { t: 'play', side, name: def.name, uid: placed.unit.uid });
    triggerUnit(s, side, placed.unit, placed.row);
  }
  return true;
}

export function playCard(s: DuelState, side: number, handUid: string): boolean {
  if (!canPlay(s, side)) return false;
  if (!resolvePlay(s, side, handUid)) return false;
  endTurn(s, side);
  return true;
}

export function pass(s: DuelState, side: number): void {
  if (s.over || s.sides[side].passed) return;
  s.sides[side].passed = true;
  emit(s, { t: 'pass', side });
  log(s, `${s.sides[side].name} passes.`);
  endTurn(s, side);
}

function endTurn(s: DuelState, side: number) {
  if (s.over) return;
  const [a, b] = s.sides;
  if (a.passed && b.passed) {
    endRound(s);
    return;
  }
  const other = (1 - side) as 0 | 1;
  s.turn = s.sides[other].passed ? (side as 0 | 1) : other;
  autoPass(s);
}

function autoPass(s: DuelState) {
  const cur = s.sides[s.turn];
  if (!s.over && !cur.passed && cur.hand.length === 0) pass(s, s.turn);
}

function startRound(s: DuelState) {
  for (let i = 0; i < 2; i++) {
    const sd = s.sides[i];
    if (sd.mods.bodyguard) {
      const inst: CardInst = { uid: 'g' + s.uidc, id: 'guard', level: 1, xp: 0 };
      const placed = placeUnit(s, i, inst, false);
      placed.unit.def = CARDS.guard;
      reveal(s, i, sd.mods.source.bodyguard);
    }
  }
  autoPass(s);
}

function endRound(s: DuelState) {
  const sc: [number, number] = [score(s, 0), score(s, 1)];
  let winner: RoundRecord['winner'];
  if (sc[0] > sc[1]) winner = 0;
  else if (sc[1] > sc[0]) winner = 1;
  else winner = 2;
  s.rounds.push({ scores: sc, winner });
  if (winner === 0 || winner === 2) s.sides[1].gems--;
  if (winner === 1 || winner === 2) s.sides[0].gems--;
  const label =
    winner === 2 ? 'Round tied' : winner === 0 ? `${s.sides[0].name} takes the round` : `${s.sides[1].name} takes the round`;
  emit(s, { t: 'banner', text: label, sub: `${sc[0]} – ${sc[1]}` });
  log(s, `Round ${s.round}: ${label} (${sc[0]}–${sc[1]}).`);

  const [g0, g1] = [s.sides[0].gems, s.sides[1].gems];
  if (g0 <= 0 || g1 <= 0) {
    s.over = true;
    s.result = g0 > 0 ? 'win' : g1 > 0 ? 'loss' : 'draw';
    return;
  }

  // clean up the board
  for (let i = 0; i < 2; i++) {
    const sd = s.sides[i];
    for (const row of ROWS) {
      const keep: Unit[] = [];
      for (const u of sd.rows[row]) {
        if (u.def.ability === 'ninelives' && !u.ninelivesUsed) {
          u.ninelivesUsed = true;
          keep.push(u);
          emit(s, { t: 'float', uid: u.uid, text: 'nine lives', good: i === 0 });
        } else if (!u.def.token) s.sides[u.origin].discard.push(u.inst);
      }
      sd.rows[row] = keep;
      sd.horn[row] = false;
    }
    sd.passed = false;
    sd.unitsThisRound = 0;
  }
  s.weather = { vanguard: false, arcane: false };
  s.round++;
  for (let i = 0; i < 2; i++) {
    draw(s, i, 1);
    const lost = winner === 1 - i || winner === 2;
    if (lost && s.sides[i].mods.secondWind) {
      draw(s, i, 2);
      reveal(s, i, s.sides[i].mods.source.secondWind);
    }
  }
  // round loser leads the next round
  s.turn = winner === 0 ? 1 : 0;
  emit(s, { t: 'banner', text: `Round ${s.round}`, sub: s.turn === 0 ? `${s.sides[0].name} leads` : `${s.sides[1].name} leads` });
  startRound(s);
}

/** Swap a hand card for a random deck card (pre-duel redraw). */
export function mulligan(s: DuelState, side: number, handUid: string): boolean {
  const sd = s.sides[side];
  const i = sd.hand.findIndex((c) => c.uid === handUid);
  if (i < 0 || !sd.deck.length) return false;
  const [c] = sd.hand.splice(i, 1);
  sd.deck.unshift(c);
  shuffle(s.rng, sd.deck);
  // keep the returned card off the top so it isn't drawn straight back
  const j = sd.deck.indexOf(c);
  if (j === sd.deck.length - 1 && sd.deck.length > 1) [sd.deck[0], sd.deck[j]] = [sd.deck[j], sd.deck[0]];
  sd.hand.splice(i, 0, sd.deck.pop()!);
  return true;
}

export function takeEvents(s: DuelState): DuelEvent[] {
  const e = s.events;
  s.events = [];
  return e;
}

export { findUnit };
