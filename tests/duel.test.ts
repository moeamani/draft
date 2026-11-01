import { describe, expect, it } from 'vitest';
import { createDuel, pass, playCard, score, unitPower, type DuelState } from '../src/core/duel';
import { baseMods } from '../src/core/traits';
import type { CardInst } from '../src/core/types';

let n = 0;
const c = (id: string, level = 1): CardInst => ({ uid: 'x' + n++, id, level, xp: 0 });

function duel(a: string[], b: string[], seed = 1): DuelState {
  // decks are exactly the hand: draw 8 of 8
  const pad = (ids: string[]) => [...ids, ...Array(Math.max(0, 8 - ids.length)).fill('agravain')].map((id) => c(id));
  return createDuel({ name: 'A', deck: pad(a) }, { name: 'B', deck: pad(b) }, seed, 0);
}

const handUid = (s: DuelState, side: number, id: string) => s.sides[side].hand.find((x) => x.id === id)!.uid;

describe('duel engine', () => {
  it('places physical units in the vanguard and magic in the arcane', () => {
    const s = duel(['barnbrawler', 'candlewitch'], []);
    playCard(s, 0, handUid(s, 0, 'barnbrawler'));
    pass(s, 1);
    playCard(s, 0, handUid(s, 0, 'candlewitch'));
    expect(s.sides[0].rows.vanguard.map((u) => u.def.id)).toContain('barnbrawler');
    expect(s.sides[0].rows.arcane.map((u) => u.def.id)).toContain('candlewitch');
  });

  it('litter multiplies by copies in the row', () => {
    const s = duel(['kaytail', 'kaytail'], []);
    playCard(s, 0, handUid(s, 0, 'kaytail'));
    pass(s, 1);
    playCard(s, 0, handUid(s, 0, 'kaytail'));
    const row = s.sides[0].rows.vanguard;
    expect(row.map((u) => unitPower(s, 0, 'vanguard', u))).toEqual([6, 6]);
  });

  it('downpour sets vanguard to 1 but not legendaries', () => {
    const s = duel(['lamoracat', 'artheline'], ['downpour']);
    playCard(s, 0, handUid(s, 0, 'lamoracat'));
    playCard(s, 1, handUid(s, 1, 'downpour'));
    playCard(s, 0, handUid(s, 0, 'artheline'));
    const [lam, art] = s.sides[0].rows.vanguard;
    expect(unitPower(s, 0, 'vanguard', lam)).toBe(1);
    expect(unitPower(s, 0, 'vanguard', art)).toBe(20);
  });

  it('smite destroys the strongest enemy unit', () => {
    const s = duel(['artheline'], ['lamoracat', 'barnbrawler']);
    s.turn = 1;
    playCard(s, 1, handUid(s, 1, 'lamoracat'));
    playCard(s, 0, handUid(s, 0, 'artheline'));
    expect(s.sides[1].rows.vanguard.length).toBe(0);
  });

  it('hex scales with black cats on board', () => {
    const s = duel(['merlinus', 'circaleus'], ['lamoracat', 'agravain']);
    s.turn = 1;
    playCard(s, 1, handUid(s, 1, 'lamoracat')); // 7 power
    playCard(s, 0, handUid(s, 0, 'merlinus')); // 1 damage -> 6
    playCard(s, 1, handUid(s, 1, 'agravain'));
    playCard(s, 0, handUid(s, 0, 'circaleus')); // 2 damage -> 4
    const lam = s.sides[1].rows.vanguard.find((u) => u.def.id === 'lamoracat')!;
    expect(unitPower(s, 1, 'vanguard', lam)).toBe(4);
  });

  it('coat advantage gives +2', () => {
    const s = duel(['pikecat'], ['barnbrawler']); // tide vs ember
    s.turn = 1;
    playCard(s, 1, handUid(s, 1, 'barnbrawler'));
    playCard(s, 0, handUid(s, 0, 'pikecat'));
    expect(unitPower(s, 0, 'vanguard', s.sides[0].rows.vanguard[0])).toBe(5);
  });

  it('best of three ends with a result', () => {
    const s = duel(['lamoracat', 'barnbrawler'], ['agravain']);
    let guard = 0;
    while (!s.over && guard++ < 100) {
      const side = s.turn;
      const h = s.sides[side].hand[0];
      if (h && score(s, side) <= score(s, 1 - side)) playCard(s, side, h.uid);
      else pass(s, side);
    }
    expect(s.over).toBe(true);
    expect(s.result).not.toBeNull();
  });

  it('mods: thick fur blocks hex', () => {
    const mods = baseMods();
    mods.thickfur = true;
    mods.source.thickfur = 'thickfur';
    const pad = (ids: string[]) => [...ids, ...Array(8 - ids.length).fill('agravain')].map((id) => c(id));
    const s = createDuel({ name: 'A', deck: pad(['merlinus']) }, { name: 'B', deck: pad(['lamoracat']), mods }, 3, 1);
    playCard(s, 1, handUid(s, 1, 'lamoracat'));
    playCard(s, 0, handUid(s, 0, 'merlinus'));
    expect(unitPower(s, 1, 'vanguard', s.sides[1].rows.vanguard[0])).toBe(7);
    expect(s.revealed[1]).toContain('thickfur');
  });
});
