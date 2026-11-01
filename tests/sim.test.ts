import { describe, expect, it } from 'vitest';
import { aiChoose } from '../src/core/ai';
import { getDef } from '../src/core/cards';
import { pass, playCard, type DuelState } from '../src/core/duel';
import {
  addCard, advance, arenaMovesOn, decideFate, draftPick, EVENTS, finishRun, genOptions, newSave, resolveDuel, setupDuel, startRun,
} from '../src/core/game';

function autoplay(s: DuelState) {
  let guard = 0;
  while (!s.over) {
    if (guard++ > 400) throw new Error('duel did not terminate');
    const side = s.turn;
    const a = aiChoose(s, side);
    if (a.type === 'pass') pass(s, side);
    else if (!playCard(s, side, a.uid)) throw new Error('illegal AI play');
  }
}

describe('full-run simulation', () => {
  it('plays many runs end to end without errors', () => {
    const tally = { victories: 0, defeats: 0, rings: [0, 0, 0, 0, 0, 0], duels: 0, wins: 0, warlordWins: 0, warlordDuels: 0 };
    for (let r = 0; r < 60; r++) {
      const save = newSave('Tester', 1000 + r);
      for (let k = 0; k < 3; k++) {
        const run = startRun(save);
        while (run.phase === 'draft') draftPick(save, run.draftOptions[0]);
        let guard = 0;
        while (run.phase === 'map') {
          if (guard++ > 100) throw new Error('run stuck');
          const node = run.options.find((o) => o.kind === 'warlord' || o.kind === 'skirmish' || o.kind === 'pit') ?? run.options[0];
          if (node.kind === 'market' || node.kind === 'tavern') { advance(save); continue; }
          if (node.kind === 'shrine') {
            const ev = EVENTS.find((e) => e.id === node.event)!;
            ev.text(save);
            const ch = ev.choices.find((c) => c.enabled(save))!;
            ch.apply(save);
            if (run.lives <= 0) { finishRun(save, 'defeat'); break; }
            advance(save);
            continue;
          }
          const ctx = setupDuel(save, node);
          autoplay(ctx.state);
          tally.duels++;
          const out = resolveDuel(save, ctx);
          if (node.kind === 'warlord') tally.warlordDuels++;
          if (out.result === 'win') {
            tally.wins++;
            if (out.cardChoices[0]) addCard(run, out.cardChoices[0]);
            if (ctx.nemesis) {
              tally.warlordWins++;
              decideFate(save, ctx.nemesis, out.flawless ? 'recruit' : 'slay');
            }
            advance(save);
          } else if (out.runOver) {
            finishRun(save, 'defeat');
          } else {
            run.options = genOptions(save);
          }
        }
        tally.rings[Math.min(5, run.ring)]++;
        if (run.outcome === 'victory') tally.victories++; else tally.defeats++;
        arenaMovesOn(save);
        expect(save.hands.length).toBe(4);
        for (const h of save.hands) expect(h.status).toBe('active');
        expect(new Set(save.hands.map((h) => h.id)).size).toBe(4);
        for (const c of save.run?.deck ?? []) expect(getDef(c)).toBeTruthy();
      }
    }
    console.log(JSON.stringify(tally));
    expect(tally.duels).toBeGreaterThan(100);
  });
});
