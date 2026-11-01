import badgeUrl from '../assets/badge.svg';
import logoUrl from '../assets/logo-lockup.svg';
import mascotUrl from '../assets/mascot.svg';
import shadowUrl from '../assets/shadow.svg';
import { getDef } from '../core/cards';
import type { CharmId } from '../core/charms';
import {
  addCard,
  addCharm,
  advance,
  arenaMovesOn,
  currentBoss,
  decideFate,
  DRAFT_PICKS,
  draftPick,
  EVENTS,
  finishRun,
  genOptions,
  makeMarket,
  newSave,
  rankOf,
  REMOVE_PRICE,
  removeCard,
  setupDuel,
  startRun,
  START_LIVES,
  UPGRADE_PRICE,
  upgradeCard,
  type DuelContext,
  type DuelOutcome,
  type MapNode,
  type MarketStock,
  type Save,
  type WarlordFate,
} from '../core/game';
import { encounterSituation, speak, type Nemesis } from '../core/nemesis';
import { makeRng } from '../core/rng';
import { isMuted, sfx, toggleMute } from './audio';
import {
  cardDetailHTML,
  cardHTML,
  charmHTML,
  deckGridHTML,
  hudHTML,
  nemesisCardHTML,
  nemesisPortrait,
  RING_NAMES,
  traitChips,
} from './components';
import { esc, fitStage, modal, roman, toast } from './dom';
import { showDuel } from './duel-screen';
import { HOW_TO_PLAY } from './help';
import { loadSave, wipeSave, writeSave } from './store';
import { CARDS, COATS } from '../core/cards';

type Handler = (el: HTMLElement, e: MouseEvent) => void;

export class App {
  stage: HTMLElement;
  save: Save | null;
  handlers: Record<string, Handler> = {};
  uiRng = makeRng(Date.now() & 0xffff);

  constructor(stage: HTMLElement) {
    this.stage = stage;
    fitStage(stage);
    this.save = loadSave();
    stage.addEventListener('click', (e) => {
      const el = (e.target as HTMLElement).closest('[data-act]') as HTMLElement | null;
      if (!el || el.closest('.disabled') || el.hasAttribute('disabled')) return;
      const h = this.handlers[el.dataset.act!];
      if (h) {
        sfx.click();
        h(el, e);
      }
    });
    this.title();
  }

  persist() {
    if (this.save) writeSave(this.save);
  }

  render(html: string, cls = '', handlers: Record<string, Handler> = {}) {
    this.stage.querySelectorAll('.modal-back,.banner,.float,.toast').forEach((x) => x.remove());
    this.stage.innerHTML = `<div class="screen ${cls}">${html}</div>`;
    this.handlers = { ...this.hudHandlers(), ...handlers };
  }

  hudHandlers(): Record<string, Handler> {
    return {
      deck: () => this.deckModal(),
      hands: () => this.handsModal(),
      menu: () => this.menuModal(),
    };
  }

  // ------------------------------------------------------------ title

  title() {
    const s = this.save;
    const hasRun = !!s?.run;
    this.render(
      `<img class="title-mascot" src="${mascotUrl}" alt="">
      <div class="title-wrap">
        <img class="title-logo" src="${logoUrl}" alt="Draft — Four Hands. One Arena">
        <div class="title-pitch">A roguelike deck-drafting card battle for medieval cats.<br>Draft your pride. Climb the Arena. Make enemies that remember you.</div>
        <div class="title-menu">
          ${hasRun ? `<button class="btn primary" data-act="continue">Continue run</button>` : ''}
          <button class="btn ${hasRun ? '' : 'primary'}" data-act="new">${hasRun ? 'Abandon & start new run' : 'New run'}</button>
          ${s ? `<button class="btn" data-act="hands">The Four Hands</button>` : ''}
          <button class="btn" data-act="help">How to play</button>
        </div>
        ${s ? `<div class="title-stats">Champion <b>${esc(s.playerName)}</b> · Runs ${s.runs} · Victories ${s.victories} · Furthest ring ${roman(Math.max(1, s.bestRing + 1))}</div>` : ''}
      </div>
      <img class="title-badge" src="${badgeUrl}" alt="In development">
      ${s ? `<button class="link reset" data-act="reset">reset save</button>` : ''}
      <button class="link mute" data-act="mute">${isMuted() ? 'sound off' : 'sound on'}</button>`,
      'title',
      {
        continue: () => this.resume(),
        new: () => {
          if (!this.save) return this.nameScreen();
          if (this.save.run) {
            const m = modal(
              this.stage,
              `<h2>Abandon this run?</h2><p>Your champion flees the Arena. The Four Hands will hear of it.</p>
              <div class="row-btns"><button class="btn primary" data-m="yes">Abandon</button><button class="btn" data-close>Keep playing</button></div>`,
            );
            m.el.querySelector('[data-m=yes]')!.addEventListener('click', () => {
              m.close();
              finishRun(this.save!, 'defeat');
              arenaMovesOn(this.save!);
              this.persist();
              this.newRun();
            });
            return;
          }
          this.newRun();
        },
        help: () => this.helpModal(),
        reset: () => {
          const m = modal(this.stage, `<h2>Erase everything?</h2><p>The Four Hands, their memories and your history will be wiped.</p><div class="row-btns"><button class="btn primary" data-m="yes">Erase</button><button class="btn" data-close>Cancel</button></div>`);
          m.el.querySelector('[data-m=yes]')!.addEventListener('click', () => {
            wipeSave();
            this.save = null;
            m.close();
            this.title();
          });
        },
        mute: () => {
          toggleMute();
          this.title();
        },
      },
    );
  }

  nameScreen() {
    this.render(
      `<div class="center-col">
        <h1>Name your champion</h1>
        <p class="muted">The Four Hands will learn this name. They will not forget it.</p>
        <input id="pname" class="text-input" maxlength="18" value="Sir Whiskers" autofocus>
        <button class="btn primary" data-act="go">Enter the Arena</button>
      </div>`,
      'name',
      {
        go: () => {
          const v = (this.stage.querySelector('#pname') as HTMLInputElement).value.trim() || 'Sir Whiskers';
          this.save = newSave(v);
          this.persist();
          this.newRun();
        },
      },
    );
    const input = this.stage.querySelector('#pname') as HTMLInputElement;
    input.select();
    input.addEventListener('keydown', (e) => e.key === 'Enter' && this.handlers.go(input, e as unknown as MouseEvent));
  }

  newRun() {
    startRun(this.save!);
    this.persist();
    this.draft();
  }

  resume() {
    const run = this.save?.run;
    if (!run) return this.title();
    if (run.phase === 'draft') return this.draft();
    if (run.phase === 'over') return this.summary();
    this.map();
  }

  // ------------------------------------------------------------ draft

  draft() {
    const run = this.save!.run!;
    const deckList = deckGridHTML(run.deck);
    this.render(
      `<div class="draft-head">
        <h1>Draft your Pride</h1>
        <div class="muted">Pick 1 of 3 · ${run.draftPicks + 1} / ${DRAFT_PICKS}. Physical cats fight in the Vanguard, Magic cats in the Arcane row.</div>
      </div>
      <div class="draft-picks">
        ${run.draftOptions.map((id) => cardHTML(CARDS[id], { size: 'pick', attrs: `data-act="pick" data-id="${id}"`, cls: 'clickable' })).join('')}
      </div>
      <div class="draft-deck"><div class="label">Your pride so far (${run.deck.length})</div>${deckList}</div>`,
      'draft',
      {
        pick: (el) => {
          const done = draftPick(this.save!, el.dataset.id!);
          const d = CARDS[el.dataset.id!];
          if (d.ability === 'litter' || d.ability === 'muster') toast(this.stage, `${d.name} brought a sibling!`, 'good');
          this.persist();
          if (done) this.map();
          else this.draft();
        },
      },
    );
  }

  // ------------------------------------------------------------ map

  map() {
    const save = this.save!;
    const run = save.run!;
    if (run.phase === 'over') return this.summary();
    if (!run.options.length) run.options = genOptions(save);
    const boss = currentBoss(save);
    const bossRank = boss ? rankOf(save, boss) : 0;
    this.render(
      `${hudHTML(run)}
      <div class="map">
        <div class="map-main">
          <div class="ring-title"><span class="label">Ring ${roman(run.ring)} of IV</span><h1>${esc(RING_NAMES[run.ring])}</h1></div>
          ${run.detour && boss ? `<div class="notice bad">${esc(boss.name)} beat you. Regroup with one more stop before the rematch.</div>` : ''}
          <div class="choose-label">${run.options[0]?.kind === 'warlord' ? 'The Warlord awaits.' : 'Choose your path'}</div>
          <div class="nodes">${run.options.map((n, i) => this.nodeHTML(n, i)).join('')}</div>
        </div>
        <div class="map-side">
          <div class="label">Warlord of this ring</div>
          ${boss ? nemesisCardHTML(boss, bossRank, { attrs: 'data-act="hands"' }) : ''}
          <div class="muted small">Beat strays to interrogate them and reveal Warlord traits.</div>
        </div>
      </div>`,
      'map-screen',
      {
        node: (el) => this.enterNode(run.options[Number(el.dataset.i)]),
      },
    );
  }

  nodeHTML(n: MapNode, i: number) {
    const save = this.save!;
    const info: Record<string, { icon: string; title: string; desc: string }> = {
      skirmish: { icon: '⚔', title: 'Skirmish', desc: `${n.foe?.name ?? ''}. Win for fish, a new cat and intel on a Warlord.` },
      pit: { icon: '☠', title: 'The Pit', desc: `${n.foe?.name ?? ''}, a veteran fighter. Harder duel, rarer cards.` },
      market: { icon: '⋔', title: 'Mews Market', desc: 'Buy cats and charms, train a cat, or send one home.' },
      shrine: { icon: '✧', title: EVENTS.find((e) => e.id === n.event)?.title ?? 'Shrine', desc: 'Something strange is happening down this alley.' },
      tavern: { icon: '☕', title: 'The Sleeping Fox', desc: 'Rest (+3 lives) or train a cat.' },
      warlord: { icon: '♛', title: `Face ${currentBoss(save)?.name ?? 'the Warlord'}`, desc: 'One of the Four Hands. They will remember how this goes.' },
    };
    const it = info[n.kind];
    const coat = n.foe ? COATS[n.foe.coat] : null;
    return `<div class="node node-${n.kind}" data-act="node" data-i="${i}">
      <div class="node-icon">${it.icon}</div>
      <div class="node-title">${esc(it.title)}</div>
      <div class="node-desc">${esc(it.desc)}</div>
      ${coat ? `<div class="node-coat" style="color:${coat.color}">${coat.name} coat${n.foe?.elite ? ' · elite' : ''}</div>` : ''}
    </div>`;
  }

  enterNode(n: MapNode) {
    if (!n) return;
    switch (n.kind) {
      case 'skirmish':
      case 'pit':
        return this.startDuel(n);
      case 'warlord':
        return this.encounter(n);
      case 'market':
        return this.market(makeMarket(this.save!.run!));
      case 'shrine':
        return this.shrine(n.event!);
      case 'tavern':
        return this.tavern();
    }
  }

  completeNode() {
    advance(this.save!);
    this.persist();
    const run = this.save!.run!;
    if (run.phase === 'over') this.summary();
    else this.map();
  }

  // ------------------------------------------------------------ encounter

  encounter(node: MapNode) {
    const save = this.save!;
    const n = currentBoss(save)!;
    const rank = rankOf(save, n);
    const line = speak(this.uiRng, n, encounterSituation(n), save.playerName, rank);
    const hist = n.history.slice(-4).reverse();
    this.render(
      `<img class="enc-flames" src="${shadowUrl}" alt="">
      <div class="encounter">
        <div class="enc-portrait" style="background-image:url(${nemesisPortrait(n, rank)})"></div>
        <div class="enc-info">
          <div class="label">${rank ? ['', 'The First Hand', 'The Second Hand', 'The Third Hand', 'The Fourth Hand'][rank] : 'Warlord'} · Level ${n.level} · <span style="color:${COATS[n.coat].color}">${COATS[n.coat].name}</span></div>
          <h1>${esc(n.name)}</h1>
          <div class="enc-epithet">${esc(n.epithet)}</div>
          <div class="speech">“${esc(line)}”</div>
          <div class="label">What you know</div>
          <div class="traits big">${traitChips(n)}</div>
          <div class="label">Their story</div>
          <div class="enc-history">${hist.map((h) => `<div>${esc(h.text)}</div>`).join('')}</div>
          <div class="row-btns"><button class="btn primary big" data-act="fight">Fight</button></div>
        </div>
      </div>`,
      'encounter-screen',
      { fight: () => this.startDuel(node) },
    );
  }

  // ------------------------------------------------------------ duel + reward

  startDuel(node: MapNode) {
    const ctx = setupDuel(this.save!, node);
    this.persist();
    showDuel(this, ctx, (out) => this.reward(ctx, out));
  }

  reward(ctx: DuelContext, out: DuelOutcome) {
    const save = this.save!;
    const run = save.run!;
    this.persist();
    const n = ctx.nemesis;
    const win = out.result === 'win';
    win ? sfx.win() : sfx.lose();

    const header = `<div class="reward-head ${win ? 'good' : 'bad'}">
      <h1>${win ? 'Victory' : out.result === 'draw' ? 'A Bitter Draw' : 'Defeat'}</h1>
      <div class="muted">${win ? `+${out.fish} fish${out.flawless ? ' · flawless' : ''}` : `−${out.livesLost} li${out.livesLost === 1 ? 'fe' : 'ves'} · ${run.lives} remaining`}</div>
    </div>`;
    const quote = n && out.line
      ? `<div class="reward-quote"><div class="mini-portrait" style="background-image:url(${nemesisPortrait(n, rankOf(save, n))})"></div><div><b>${esc(n.name)}:</b> “${esc(out.line)}”</div></div>`
      : out.line
        ? `<div class="reward-quote"><div>${esc(out.line)}</div></div>`
        : '';
    const notes = [
      ...out.levelUps.map((l) => `<div class="note good">★ ${esc(l.name)} reached level ${l.level}!</div>`),
      ...out.intel.map((t) => `<div class="note intel">⌕ ${esc(t)}</div>`),
      out.promoted ? `<div class="note bad">☠ ${esc(out.promoted)}</div>` : '',
    ].join('');

    const after = () => {
      if (out.runOver) {
        finishRun(save, 'defeat');
        this.persist();
        return this.summary();
      }
      if (win) return this.completeNode();
      run.options = genOptions(save);
      this.persist();
      this.map();
    };

    const cardStep = () => {
      if (!win || !out.cardChoices.length) return charmStep();
      this.render(
        `${header}${quote}<div class="notes">${notes}</div>
        <div class="label center">Choose a cat to join your pride</div>
        <div class="draft-picks">${out.cardChoices.map((id) => cardHTML(CARDS[id], { size: 'pick', attrs: `data-act="take" data-id="${id}"`, cls: 'clickable' })).join('')}</div>
        <div class="row-btns center"><button class="btn ghost" data-act="skip">Skip (+10 fish)</button></div>`,
        'reward',
        {
          take: (el) => {
            addCard(run, el.dataset.id!);
            this.persist();
            charmStep();
          },
          skip: () => {
            run.fish += 10;
            this.persist();
            charmStep();
          },
        },
      );
    };

    const charmStep = () => {
      if (!win || !out.charmChoices.length || run.charms.length >= 5) return after();
      this.render(
        `${header}<div class="label center">The Warlord's hoard: choose a charm</div>
        <div class="charm-picks">${out.charmChoices.map((c) => charmHTML(c, { attrs: `data-act="charm" data-id="${c}"`, cls: 'clickable big' })).join('')}</div>
        <div class="row-btns center"><button class="btn ghost" data-act="skip">Leave it</button></div>`,
        'reward',
        {
          charm: (el) => {
            addCharm(run, el.dataset.id as CharmId);
            this.persist();
            after();
          },
          skip: () => after(),
        },
      );
    };

    if (win && n) {
      // Shadow-of-War style: decide the beaten Warlord's fate
      const rank = rankOf(save, n);
      this.render(
        `${header}
        <div class="fate">
          <div class="enc-portrait small" style="background-image:url(${nemesisPortrait(n, rank)})"></div>
          <div>
            <h2>${esc(n.name)} is at your mercy.</h2>
            <div class="speech">“${esc(out.line)}”</div>
            <div class="notes">${notes}</div>
            <div class="fate-btns">
              <button class="btn primary" data-act="fate" data-f="slay"><b>Slay</b><span>Remove them from the Hands. They might not stay dead.</span></button>
              <button class="btn ${out.flawless ? '' : 'disabled'}" data-act="fate" data-f="recruit" ${out.flawless ? '' : 'disabled'}><b>Recruit</b><span>${out.flawless ? 'They join your deck as a Legendary card.' : 'Only after a flawless 2–0 win.'}</span></button>
              <button class="btn" data-act="fate" data-f="brand"><b>Brand</b><span>Spare them, but leave a weakness. They will hate you for it.</span></button>
            </div>
          </div>
        </div>`,
        'reward',
        {
          fate: (el) => {
            const fate = el.dataset.f as WarlordFate;
            const txt = decideFate(save, n, fate);
            const line = speak(this.uiRng, n, fate === 'slay' ? 'slain' : fate === 'recruit' ? 'recruit' : 'brand', save.playerName);
            this.persist();
            toast(this.stage, txt, fate === 'slay' ? 'bad' : 'good');
            const m = modal(this.stage, `<h2>${esc(n.name)}</h2><div class="speech">“${esc(line)}”</div><p>${esc(txt)}</p><div class="row-btns"><button class="btn primary" data-close>Continue</button></div>`, {
              onClose: () => cardStep(),
            });
            void m;
          },
        },
      );
      return;
    }

    if (!win) {
      this.render(
        `${header}${quote}<div class="notes">${notes}</div>
        ${n ? `<div class="muted center">${esc(n.name)} grows stronger from this. Their next appearance will be harder.</div>` : ''}
        <div class="row-btns center"><button class="btn primary" data-act="go">${out.runOver ? 'Your last life...' : 'Lick your wounds'}</button></div>`,
        'reward',
        { go: () => after() },
      );
      return;
    }
    cardStep();
  }

  // ------------------------------------------------------------ market

  market(stock: MarketStock) {
    const run = this.save!.run!;
    const rerender = () => this.market(stock);
    this.render(
      `${hudHTML(run)}
      <div class="market">
        <h1>Mews Market</h1>
        <div class="muted">“Fresh cats! Slightly used charms! No refunds!”</div>
        <div class="label">Cats for hire</div>
        <div class="shop-cards">${stock.cards
          .map((c, i) =>
            c.sold
              ? `<div class="card sz-pick sold">SOLD</div>`
              : cardHTML(CARDS[c.id], { size: 'pick', price: c.price, attrs: `data-act="buy" data-i="${i}"`, cls: `clickable ${run.fish < c.price ? 'cant' : ''}` }),
          )
          .join('')}</div>
        <div class="shop-bottom">
          <div>
            <div class="label">Charms (${run.charms.length}/5)</div>
            <div class="charm-picks">${stock.charms
              .map((c, i) => (c.sold ? `<div class="charm sold">SOLD</div>` : charmHTML(c.id, { price: c.price, attrs: `data-act="charm" data-i="${i}"`, cls: `clickable ${run.fish < c.price ? 'cant' : ''}` })))
              .join('')}</div>
          </div>
          <div>
            <div class="label">Services</div>
            <div class="services">
              <button class="btn ${stock.upgraded || run.fish < UPGRADE_PRICE ? 'disabled' : ''}" data-act="upgrade"><b>Train a cat</b><span>+1 level (+2 power) · ${UPGRADE_PRICE} ⋔</span></button>
              <button class="btn ${stock.removed || run.fish < REMOVE_PRICE || run.deck.length <= 10 ? 'disabled' : ''}" data-act="remove"><b>Send a cat home</b><span>Remove a card · ${REMOVE_PRICE} ⋔</span></button>
            </div>
          </div>
        </div>
        <div class="row-btns"><button class="btn primary" data-act="leave">Leave market</button></div>
      </div>`,
      'market-screen',
      {
        buy: (el) => {
          const c = stock.cards[Number(el.dataset.i)];
          if (c.sold || run.fish < c.price) return toast(this.stage, 'Not enough fish.', 'bad');
          run.fish -= c.price;
          c.sold = true;
          addCard(run, c.id);
          this.persist();
          rerender();
        },
        charm: (el) => {
          const c = stock.charms[Number(el.dataset.i)];
          if (c.sold || run.fish < c.price) return toast(this.stage, 'Not enough fish.', 'bad');
          if (!addCharm(run, c.id)) return toast(this.stage, 'You can only carry 5 charms.', 'bad');
          run.fish -= c.price;
          c.sold = true;
          this.persist();
          rerender();
        },
        upgrade: () =>
          this.pickCardModal('Train which cat?', (c) => getDef(c).kind === 'unit' && c.level < 3, (uid) => {
            run.fish -= UPGRADE_PRICE;
            upgradeCard(run, uid);
            stock.upgraded = true;
            this.persist();
            rerender();
          }),
        remove: () =>
          this.pickCardModal('Send which cat home?', () => true, (uid) => {
            run.fish -= REMOVE_PRICE;
            removeCard(run, uid);
            stock.removed = true;
            this.persist();
            rerender();
          }),
        leave: () => this.completeNode(),
      },
    );
  }

  pickCardModal(title: string, filter: (c: import('../core/types').CardInst) => boolean, done: (uid: string) => void) {
    const run = this.save!.run!;
    const cards = run.deck.filter(filter);
    const m = modal(this.stage, `<h2>${esc(title)}</h2>${deckGridHTML(cards, () => 'data-m="pick"')}`, { wide: true });
    m.el.addEventListener('click', (e) => {
      const el = (e.target as HTMLElement).closest('[data-uid]') as HTMLElement | null;
      if (!el) return;
      m.close();
      done(el.dataset.uid!);
    });
  }

  // ------------------------------------------------------------ shrine / tavern

  shrine(eventId: string) {
    const save = this.save!;
    const ev = EVENTS.find((e) => e.id === eventId)!;
    const text = ev.text(save);
    this.render(
      `${hudHTML(save.run!)}
      <div class="event">
        <div class="event-icon">✧</div>
        <h1>${esc(ev.title)}</h1>
        <p class="event-text">${esc(text)}</p>
        <div class="event-choices">${ev.choices
          .map((c, i) => {
            const ok = c.enabled(save);
            return `<button class="btn ${ok ? '' : 'disabled'}" data-act="choose" data-i="${i}"><b>${esc(c.label)}</b>${c.hint ? `<span>${esc(c.hint)}</span>` : ''}</button>`;
          })
          .join('')}</div>
      </div>`,
      'event-screen',
      {
        choose: (el) => {
          const c = ev.choices[Number(el.dataset.i)];
          if (!c.enabled(save)) return;
          const result = c.apply(save);
          this.persist();
          this.render(
            `${hudHTML(save.run!)}
            <div class="event"><div class="event-icon">✧</div><h1>${esc(ev.title)}</h1>
            <p class="event-text result">${esc(result).replace(/\n/g, '<br>')}</p>
            <div class="row-btns center"><button class="btn primary" data-act="go">Continue</button></div></div>`,
            'event-screen',
            {
              go: () => {
                if (save.run!.lives <= 0) {
                  finishRun(save, 'defeat');
                  this.persist();
                  return this.summary();
                }
                this.completeNode();
              },
            },
          );
        },
      },
    );
  }

  tavern() {
    const run = this.save!.run!;
    this.render(
      `${hudHTML(run)}
      <div class="event">
        <div class="event-icon">☕</div>
        <h1>The Sleeping Fox</h1>
        <p class="event-text">A warm inn that smells of fish pie. The fox behind the bar is, as promised, asleep.</p>
        <div class="event-choices">
          <button class="btn ${run.lives >= START_LIVES ? 'disabled' : ''}" data-act="rest"><b>Rest by the fire</b><span>Recover 3 lives</span></button>
          <button class="btn" data-act="train"><b>Spar in the cellar</b><span>A cat of your choice gains a level</span></button>
        </div>
      </div>`,
      'event-screen',
      {
        rest: () => {
          run.lives = Math.min(START_LIVES, run.lives + 3);
          toast(this.stage, 'You wake up feeling three lives better.', 'good');
          this.completeNode();
        },
        train: () =>
          this.pickCardModal('Who trains tonight?', (c) => getDef(c).kind === 'unit' && c.level < 3, (uid) => {
            upgradeCard(run, uid);
            toast(this.stage, `${getDef(run.deck.find((c) => c.uid === uid)!).name} levels up!`, 'good');
            this.completeNode();
          }),
      },
    );
  }

  // ------------------------------------------------------------ run end

  summary() {
    const save = this.save!;
    const run = save.run!;
    const victory = run.outcome === 'victory';
    const killer = run.killedBy ? save.hands.find((h) => h.id === run.killedBy) ?? save.fallen.find((h) => h.id === run.killedBy) : undefined;
    this.render(
      `<div class="summary ${victory ? 'good' : 'bad'}">
        ${victory ? `<img class="summary-logo" src="${logoUrl}" alt="">` : `<img class="enc-flames static" src="${shadowUrl}" alt="">`}
        <h1>${victory ? 'Champion of the Arena' : 'Your ninth life is spent'}</h1>
        <p class="muted">${victory ? `All Four Hands have faced ${esc(save.playerName)}. For now.` : killer ? `${esc(killer.name)} ${esc(killer.epithet)} ended your run.` : 'The Arena claims another champion.'}</p>
        <div class="stats">
          <div><b>${run.ring > 4 ? 'IV' : roman(run.ring)}</b><span>ring reached</span></div>
          <div><b>${run.stats.won}</b><span>duels won</span></div>
          <div><b>${run.stats.slain}</b><span>Warlords slain</span></div>
          <div><b>${run.stats.recruited}</b><span>recruited</span></div>
          <div><b>${run.stats.branded}</b><span>branded</span></div>
        </div>
        <button class="btn primary big" data-act="go">The Arena moves on…</button>
      </div>`,
      'summary-screen',
      {
        go: () => {
          const news = arenaMovesOn(save);
          this.persist();
          this.news(news);
        },
      },
    );
  }

  news(news: string[]) {
    const save = this.save!;
    this.render(
      `<div class="news">
        <h1>The Arena Moves On</h1>
        <div class="news-list">${(news.length ? news : ['The Hands lick their wounds and wait.']).map((t) => `<div class="note">${esc(t)}</div>`).join('')}</div>
        <div class="label">The Four Hands now</div>
        <div class="hands-row">${save.hands.map((h, i) => nemesisCardHTML(h, i + 1, { compact: true })).join('')}</div>
        <div class="row-btns center"><button class="btn primary" data-act="again">Start a new run</button><button class="btn" data-act="title">Title</button></div>
      </div>`,
      'news-screen',
      { again: () => this.newRun(), title: () => this.title() },
    );
  }

  // ------------------------------------------------------------ modals

  deckModal() {
    const run = this.save?.run;
    if (!run) return;
    const m = modal(
      this.stage,
      `<h2>Your Pride (${run.deck.length})</h2>
      <div class="deck-modal"><div class="deck-scroll">${deckGridHTML(run.deck)}</div><div class="deck-detail muted">Hover a cat to inspect it.</div></div>`,
      { wide: true },
    );
    const detail = m.el.querySelector('.deck-detail') as HTMLElement;
    m.el.addEventListener('mouseover', (e) => {
      const el = (e.target as HTMLElement).closest('[data-uid]') as HTMLElement | null;
      if (!el) return;
      const c = run.deck.find((x) => x.uid === el.dataset.uid);
      if (c) detail.innerHTML = cardDetailHTML(c);
    });
  }

  handsModal() {
    const save = this.save;
    if (!save) return;
    const fallen = save.fallen.filter((n) => n.status !== 'exiled' || n.met).slice(-6).reverse();
    modal(
      this.stage,
      `<h2>The Four Hands</h2>
      <p class="muted">The Arena's ruling council. They remember every fight, grow stronger when they beat you, and scheme between runs.</p>
      <div class="hands-row">${save.hands.map((h, i) => nemesisCardHTML(h, i + 1)).join('')}</div>
      <div class="hands-bottom">
        <div><div class="label">Chronicle</div><div class="chronicle">${save.chronicle.slice(-12).reverse().map((c) => `<div><span class="muted">Run ${c.run}</span> ${esc(c.text)}</div>`).join('')}</div></div>
        <div><div class="label">Fallen & gone</div><div class="chronicle">${fallen.length ? fallen.map((n: Nemesis) => `<div><b>${esc(n.name)}</b> <span class="muted">${n.status}</span></div>`).join('') : '<div class="muted">None yet.</div>'}</div></div>
      </div>`,
      { wide: true },
    );
  }

  helpModal() {
    modal(this.stage, HOW_TO_PLAY, { wide: true });
  }

  menuModal() {
    const m = modal(
      this.stage,
      `<h2>Paused</h2>
      <div class="col-btns">
        <button class="btn" data-close>Resume</button>
        <button class="btn" data-m="help">How to play</button>
        <button class="btn" data-m="mute">${isMuted() ? 'Turn sound on' : 'Turn sound off'}</button>
        <button class="btn" data-m="title">Save & quit to title</button>
      </div>`,
    );
    m.el.addEventListener('click', (e) => {
      const a = (e.target as HTMLElement).closest('[data-m]') as HTMLElement | null;
      if (!a) return;
      m.close();
      if (a.dataset.m === 'help') this.helpModal();
      if (a.dataset.m === 'mute') toggleMute();
      if (a.dataset.m === 'title') {
        this.persist();
        this.title();
      }
    });
  }
}

