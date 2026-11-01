import { getDef, isLegend } from './cards';
import { cloneDuel, resolvePlay, score, type DuelState } from './duel';

export type AiAction = { type: 'pass' } | { type: 'play'; uid: string };

export interface AiStyle {
  /** Lead at which the AI is happy to pass in a non-decisive round. */
  passLead: number;
  /** How far behind before conceding a non-decisive round. */
  concedeAt: number;
}

export const STYLE_BY_PERSONALITY: Record<string, AiStyle> = {
  brute: { passLead: 14, concedeAt: 30 },
  schemer: { passLead: 8, concedeAt: 16 },
  zealot: { passLead: 11, concedeAt: 40 },
  coward: { passLead: 7, concedeAt: 12 },
  trickster: { passLead: 9, concedeAt: 20 },
  default: { passLead: 10, concedeAt: 22 },
};

interface Eval {
  uid: string;
  gain: number;
  value: number;
  special: boolean;
  legend: boolean;
}

function evaluate(s: DuelState, me: number): Eval[] {
  const opp = 1 - me;
  const base = score(s, me) - score(s, opp);
  const handBefore = s.sides[me].hand.length;
  return s.sides[me].hand.map((c) => {
    const c2 = cloneDuel(s);
    resolvePlay(c2, me, c.uid);
    const diff = score(c2, me) - score(c2, opp);
    const handAfter = c2.sides[me].hand.length;
    // cards drawn (stray) or returned (box) are worth something
    const cardSwing = handAfter - (handBefore - 1);
    const gain = diff - base;
    const d = getDef(c);
    return {
      uid: c.uid,
      gain,
      value: gain + cardSwing * 4,
      special: d.kind === 'special',
      legend: isLegend(d),
    };
  });
}

export function aiChoose(s: DuelState, me: number, style: AiStyle = STYLE_BY_PERSONALITY.default): AiAction {
  const opp = 1 - me;
  const mine = s.sides[me];
  const theirs = s.sides[opp];
  if (!mine.hand.length) return { type: 'pass' };

  const lead = score(s, me) - score(s, opp);
  const mustWin = mine.gems === 1;
  const theyMustWin = theirs.gems === 1;
  const evals = evaluate(s, me).sort((a, b) => b.value - a.value);
  const best = evals[0];
  const passLead = mine.mods.arrogant ? Math.max(3, style.passLead - 6) : style.passLead;

  if (theirs.passed) {
    if (lead > 0) return { type: 'pass' };
    // cheapest single card that wins the round
    const winners = evals.filter((e) => lead + e.gain > 0).sort((a, b) => a.gain - b.gain);
    if (winners.length) {
      const w = winners[0];
      if (mustWin || theyMustWin || mine.hand.length > 2 || w.gain <= 12) return { type: 'play', uid: w.uid };
    }
    if (mustWin && best.gain > 0) return { type: 'play', uid: best.uid };
    // two-card win with spare cards?
    const pos = evals.filter((e) => e.gain > 0);
    if (!mustWin && pos.length >= 2 && mine.hand.length >= 4 && lead + pos[0].gain + pos[1].gain > 0)
      return { type: 'play', uid: pos[0].uid };
    // a tie is better than a loss when they must win
    if (lead === 0 || evals.some((e) => lead + e.gain === 0)) {
      const tie = evals.find((e) => lead + e.gain === 0);
      if (tie && theyMustWin) return { type: 'play', uid: tie.uid };
    }
    return { type: 'pass' };
  }

  const cardAdv = mine.hand.length - theirs.hand.length;

  if (!mustWin) {
    if (lead >= passLead && (cardAdv >= -1 || lead > passLead + 8)) return { type: 'pass' };
    if (lead <= -style.concedeAt && cardAdv <= 1 && !theyMustWin) return { type: 'pass' };
  }

  if (best.value <= 0) {
    if (lead > 0 || !mustWin) return { type: 'pass' };
  }

  // In early rounds, hold legendaries and specials back if a decent unit exists.
  if (!mustWin && !theyMustWin) {
    const modest = evals.filter((e) => !e.legend && !e.special && e.value > 0);
    if (modest.length) {
      // play the strongest modest card, but avoid massive overkill when far ahead
      return { type: 'play', uid: modest[0].uid };
    }
  }
  return { type: 'play', uid: best.uid };
}
