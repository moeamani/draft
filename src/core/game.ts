import { applyCharms, CHARMS, MAX_CHARMS, type CharmId } from './charms';
import { DRAFTABLE, getDef, XP_FOR_LEVEL, CARDS } from './cards';
import { createDuel, type DuelState } from './duel';
import {
  addTrait,
  fullName,
  generateNemesis,
  generateStray,
  nemesisDeck,
  promoteStray,
  revealRandomTrait,
  SCAR_DESCRIPTIONS,
  signatureCard,
  speak,
  strayDeck,
  traitIds,
  type Nemesis,
  type StrayFoe,
} from './nemesis';
import { chance, int, makeRng, pick, shuffle, weighted, type Rng } from './rng';
import { applyTraits, baseMods, TRAITS, type TraitId } from './traits';
import type { CardInst, Rarity } from './types';

export const START_LIVES = 9;
export const RINGS = 4;
export const STEPS_PER_RING = 3; // two choices, then the Warlord
export const DRAFT_PICKS = 10;

export type NodeKind = 'skirmish' | 'pit' | 'market' | 'shrine' | 'tavern' | 'warlord';

export interface MapNode {
  kind: NodeKind;
  foe?: StrayFoe;
  event?: string;
}

export interface RunState {
  rng: Rng;
  number: number;
  ring: number;
  step: number;
  lives: number;
  fish: number;
  deck: CardInst[];
  charms: CharmId[];
  phase: 'draft' | 'map' | 'over';
  draftPicks: number;
  draftOptions: string[];
  options: MapNode[];
  /** After losing to a Warlord the player gets one extra node before the rematch. */
  detour: boolean;
  bossIds: string[];
  uidc: number;
  outcome?: 'victory' | 'defeat';
  killedBy?: string;
  stats: { won: number; lost: number; slain: number; recruited: number; branded: number };
}

export interface ChronicleEntry {
  run: number;
  text: string;
}

export interface Save {
  version: 1;
  playerName: string;
  rng: Rng;
  hands: Nemesis[]; // index 0 = First Hand (rank 1)
  fallen: Nemesis[];
  chronicle: ChronicleEntry[];
  runs: number;
  victories: number;
  nextId: number;
  bestRing: number;
  run: RunState | null;
}

// ---------------------------------------------------------------- save setup

export function newSave(playerName: string, seed = Date.now()): Save {
  const save: Save = {
    version: 1,
    playerName,
    rng: makeRng(seed),
    hands: [],
    fallen: [],
    chronicle: [],
    runs: 0,
    victories: 0,
    nextId: 1,
    bestRing: 0,
    run: null,
  };
  for (let rank = 1; rank <= 4; rank++) {
    save.hands.push(generateNemesis(save.rng, nid(save), 5 - rank, 0));
  }
  chronicle(save, `The Four Hands rule the Arena: ${save.hands.map((h) => h.name).join(', ')}.`);
  return save;
}

const nid = (save: Save) => 'n' + save.nextId++;

function chronicle(save: Save, text: string) {
  save.chronicle.push({ run: save.runs, text });
  if (save.chronicle.length > 80) save.chronicle.splice(0, save.chronicle.length - 80);
}

function nemLog(save: Save, n: Nemesis, text: string) {
  n.history.push({ run: save.runs, text });
  if (n.history.length > 20) n.history.shift();
}

export function findNemesis(save: Save, id: string): Nemesis | undefined {
  return save.hands.find((n) => n.id === id) ?? save.fallen.find((n) => n.id === id);
}

export function rankOf(save: Save, n: Nemesis): number {
  const i = save.hands.indexOf(n);
  return i < 0 ? 0 : i + 1;
}

// ---------------------------------------------------------------- run

function cardInst(run: RunState, id: string, level = 1): CardInst {
  return { uid: 'c' + run.uidc++, id, level, xp: 0 };
}

export function startRun(save: Save): RunState {
  save.runs++;
  const run: RunState = {
    rng: makeRng(int(save.rng, 1e9)),
    number: save.runs,
    ring: 1,
    step: 0,
    lives: START_LIVES,
    fish: 20,
    deck: [],
    charms: [],
    phase: 'draft',
    draftPicks: 0,
    draftOptions: [],
    options: [],
    detour: false,
    bossIds: [...save.hands].reverse().map((n) => n.id),
    uidc: 1,
    stats: { won: 0, lost: 0, slain: 0, recruited: 0, branded: 0 },
  };
  // a few reliable basics
  for (const id of ['squire', 'squire', 'hedgedruid', 'sunbeam']) run.deck.push(cardInst(run, id));
  run.draftOptions = draftOptions(run, 1);
  save.run = run;
  return run;
}

const RARITY_WEIGHTS: Record<number, [Rarity, number][]> = {
  0: [['common', 62], ['rare', 30], ['epic', 7], ['legendary', 1]],
  1: [['common', 50], ['rare', 36], ['epic', 12], ['legendary', 2]],
  2: [['common', 20], ['rare', 50], ['epic', 24], ['legendary', 6]],
  3: [['common', 0], ['rare', 40], ['epic', 40], ['legendary', 20]],
};

export function rollCards(rng: Rng, n: number, quality: number, exclude: string[] = []): string[] {
  const out: string[] = [];
  let guard = 0;
  while (out.length < n && guard++ < 200) {
    const rarity = weighted(rng, RARITY_WEIGHTS[Math.max(0, Math.min(3, quality))]);
    const pool = DRAFTABLE.filter((c) => c.rarity === rarity && !out.includes(c.id) && !exclude.includes(c.id));
    if (!pool.length) continue;
    out.push(pick(rng, pool).id);
  }
  return out;
}

export function draftOptions(run: RunState, quality: number) {
  return rollCards(run.rng, 3, quality);
}

/** Pick a draft card (or null to skip). Returns true when drafting is finished. */
export function draftPick(save: Save, id: string): boolean {
  const run = save.run!;
  run.deck.push(cardInst(run, id));
  // Litter and Call-the-Pride cards need friends: drafting one adds a second copy.
  const d = CARDS[id];
  if (d && (d.ability === 'litter' || d.ability === 'muster')) run.deck.push(cardInst(run, id));
  run.draftPicks++;
  if (run.draftPicks >= DRAFT_PICKS) {
    run.phase = 'map';
    run.options = genOptions(save);
    return true;
  }
  // a quality pick every few rounds keeps drafts exciting
  run.draftOptions = draftOptions(run, run.draftPicks % 4 === 3 ? 2 : 1);
  return false;
}

export function currentBoss(save: Save): Nemesis | undefined {
  const run = save.run!;
  return findNemesis(save, run.bossIds[run.ring - 1]);
}

export function atWarlord(run: RunState) {
  return run.step >= STEPS_PER_RING - 1 && !run.detour;
}

export function genOptions(save: Save): MapNode[] {
  const run = save.run!;
  if (atWarlord(run)) return [{ kind: 'warlord' }];
  const tier = run.ring;
  const opts: MapNode[] = [{ kind: 'skirmish', foe: generateStray(run.rng, tier, false) }];
  const extra: NodeKind[] = shuffle(run.rng, ['pit', 'market', 'shrine', 'tavern', 'shrine', 'market'] as NodeKind[]);
  for (const k of extra) {
    if (opts.length >= 3) break;
    if (opts.some((o) => o.kind === k)) continue;
    if (k === 'tavern' && run.lives >= START_LIVES) continue;
    if (k === 'pit') opts.push({ kind: 'pit', foe: generateStray(run.rng, tier, true) });
    else if (k === 'shrine') opts.push({ kind: 'shrine', event: pick(run.rng, EVENT_IDS) });
    else opts.push({ kind: k });
  }
  return shuffle(run.rng, opts);
}

/** Advance after a node is completed. */
export function advance(save: Save) {
  const run = save.run!;
  if (run.detour) run.detour = false;
  else run.step++;
  if (run.step >= STEPS_PER_RING) {
    run.ring++;
    run.step = 0;
    save.bestRing = Math.max(save.bestRing, run.ring - 1);
    if (run.ring > RINGS) {
      finishRun(save, 'victory');
      return;
    }
  }
  run.options = genOptions(save);
}

// ---------------------------------------------------------------- duels

export interface DuelContext {
  node: MapNode;
  foeName: string;
  nemesis?: Nemesis;
  state: DuelState;
  personality: string;
  spyglass?: TraitId | null;
}

export function setupDuel(save: Save, node: MapNode): DuelContext {
  const run = save.run!;
  const playerMods = baseMods();
  const enemyMods = baseMods();
  let deck: CardInst[];
  let foeName: string;
  let nemesis: Nemesis | undefined;
  let personality: string;
  let spyglass: TraitId | null = null;
  if (node.kind === 'warlord') {
    nemesis = currentBoss(save)!;
    applyTraits(enemyMods, traitIds(nemesis), nemesis.wins);
    deck = nemesisDeck(run.rng, nemesis, run.ring);
    foeName = nemesis.name;
    personality = nemesis.personality;
    if (run.charms.includes('spyglass')) spyglass = revealRandomTrait(run.rng, nemesis);
  } else {
    const foe = node.foe!;
    deck = strayDeck(run.rng, foe);
    foeName = foe.name.split(' the ')[0];
    personality = foe.personality;
    // elite pit fighters have a random strength
    if (foe.elite) applyTraits(enemyMods, [pick(run.rng, ['warlord', 'archmage', 'hoarder', 'vengeful'] as TraitId[])], 0);
    // strays in the early rings are scrappy but under-equipped
    if (run.ring <= 2) enemyMods.extraDraw -= 1;
  }
  applyCharms(playerMods, enemyMods, run.charms);
  const state = createDuel(
    { name: save.playerName, deck: run.deck, mods: playerMods },
    { name: foeName, deck, mods: enemyMods },
    int(run.rng, 1e9),
    chance(run.rng, 0.5) ? 0 : 1,
  );
  return { node, foeName, nemesis, state, personality, spyglass };
}

export interface DuelOutcome {
  result: 'win' | 'loss' | 'draw';
  flawless: boolean;
  fish: number;
  livesLost: number;
  levelUps: { name: string; level: number }[];
  intel: string[];
  line: string;
  cardChoices: string[];
  charmChoices: CharmId[];
  runOver: boolean;
  promoted?: string;
}

/** Apply the consequences of a finished duel to the save. */
export function resolveDuel(save: Save, ctx: DuelContext): DuelOutcome {
  const run = save.run!;
  const s = ctx.state;
  const result = s.result ?? 'loss';
  const flawless = result === 'win' && s.sides[0].gems === 2;
  const out: DuelOutcome = {
    result,
    flawless,
    fish: 0,
    livesLost: 0,
    levelUps: [],
    intel: [],
    line: '',
    cardChoices: [],
    charmChoices: [],
    runOver: false,
  };
  const n = ctx.nemesis;

  // traits revealed during the fight become permanent knowledge
  if (n) {
    for (const t of s.revealed[1]) {
      const kt = n.traits.find((x) => x.id === t);
      if (kt && !kt.known) {
        kt.known = true;
        out.intel.push(`Learned: ${n.name} has ${TRAITS[t as TraitId].name}.`);
      }
    }
    if (ctx.spyglass) out.intel.push(`Spyglass: ${n.name} has ${TRAITS[ctx.spyglass].name}.`);
    n.met = true;
  }

  if (result === 'win') {
    run.stats.won++;
    const base = ctx.node.kind === 'warlord' ? 30 + 10 * run.ring : ctx.node.kind === 'pit' ? 22 + 5 * run.ring : 12 + 4 * run.ring;
    out.fish = base + (run.charms.includes('fishbone') ? 8 : 0) + (flawless ? 5 : 0);
    run.fish += out.fish;
    // XP for every card played
    const played = new Set(s.sides[0].played);
    for (const c of run.deck) {
      if (!played.has(c.uid) || getDef(c).kind !== 'unit' || c.level >= 3) continue;
      c.xp++;
      if (c.xp >= XP_FOR_LEVEL[c.level + 1]) {
        c.level++;
        out.levelUps.push({ name: getDef(c).name, level: c.level });
      }
    }
    const quality = ctx.node.kind === 'warlord' ? 3 : ctx.node.kind === 'pit' ? 2 : run.ring >= 3 ? 1 : 0;
    out.cardChoices = rollCards(run.rng, 3, quality);
    if (ctx.node.kind === 'warlord') {
      out.charmChoices = charmOffer(run, 2);
      out.line = n ? speak(run.rng, n, 'beaten', save.playerName) : '';
    } else {
      // interrogate the beaten stray: SoW-style intel on a Warlord
      const targets = save.hands.filter((h) => h.traits.some((t) => !t.known));
      if (targets.length) {
        const target = pick(run.rng, targets);
        const t = revealRandomTrait(run.rng, target);
        if (t) out.intel.push(`The beaten stray squeals: "${target.name} has ${TRAITS[t].name}! ${TRAITS[t].desc}"`);
      }
    }
  } else {
    run.stats.lost++;
    out.livesLost = result === 'draw' ? 1 : ctx.node.kind === 'warlord' ? 3 : 2;
    run.lives = Math.max(0, run.lives - out.livesLost);
    if (n) {
      n.wins++;
      n.level++;
      n.growth = (n.growth ?? 0) + 1;
      nemLog(save, n, `Defeated ${save.playerName} in ring ${run.ring}.`);
      if (!n.epithet.startsWith('Bane')) n.epithet = `Bane of ${save.playerName}`;
      out.line = speak(run.rng, n, 'gloat', save.playerName);
      chronicle(save, `${n.name} defeated ${save.playerName} and grows in power (level ${n.level}).`);
      run.detour = true;
    } else if (ctx.node.foe) {
      out.line = 'The stray licks its paw, unimpressed.';
      // Shadow-of-War rule: whoever beats you gets noticed by the Arena
      if (run.lives <= 0 || chance(run.rng, 0.25)) {
        const promoted = promoteStray(run.rng, ctx.node.foe, nid(save), save.runs, save.playerName);
        const ousted = save.hands.pop()!;
        ousted.status = 'exiled';
        nemLog(save, ousted, `Ousted from the Fourth Hand by ${promoted.name}.`);
        save.fallen.push(ousted);
        save.hands.push(promoted);
        out.promoted = `${promoted.name} is promoted to the Fourth Hand for beating you! ${ousted.name} is cast out.`;
        chronicle(save, out.promoted);
        // if the ousted Hand was a future boss this run, the newcomer takes their place
        const bi = run.bossIds.indexOf(ousted.id);
        if (bi >= 0) run.bossIds[bi] = promoted.id;
      }
    }
    if (run.lives <= 0) {
      run.killedBy = n ? n.id : undefined;
      out.runOver = true;
    }
  }
  return out;
}

export function charmOffer(run: RunState, n: number): CharmId[] {
  const pool = (Object.keys(CHARMS) as CharmId[]).filter((c) => !run.charms.includes(c));
  return shuffle(run.rng, pool).slice(0, n);
}

export function addCharm(run: RunState, c: CharmId): boolean {
  if (run.charms.length >= MAX_CHARMS || run.charms.includes(c)) return false;
  run.charms.push(c);
  return true;
}

export function addCard(run: RunState, id: string, level = 1) {
  run.deck.push(cardInst(run, id, level));
}

export type WarlordFate = 'slay' | 'recruit' | 'brand';

export function decideFate(save: Save, n: Nemesis, fate: WarlordFate): string {
  const run = save.run!;
  n.losses++;
  if (fate === 'recruit') {
    const card = signatureCard(n);
    run.deck.push({ uid: 'c' + run.uidc++, id: card.id, level: 1, xp: 0, def: card });
    n.status = 'recruited';
    nemLog(save, n, `Swore loyalty to ${save.playerName} after a flawless defeat.`);
    moveToFallen(save, n);
    run.stats.recruited++;
    chronicle(save, `${n.name} bends the knee and joins ${save.playerName}.`);
    return `${n.name} joins your pride as a Legendary card.`;
  }
  if (fate === 'brand') {
    n.level = Math.max(1, n.level - 1);
    const w = addTrait(run.rng, n, 'weakness');
    n.scars++;
    n.epithet = 'the Branded';
    nemLog(save, n, `Branded and spared by ${save.playerName}.${w ? ` Now ${TRAITS[w].name}.` : ''}`);
    run.stats.branded++;
    chronicle(save, `${save.playerName} spared ${n.name} but left a brand.`);
    return `${n.name} is branded and humiliated${w ? `, and is now ${TRAITS[w].name} (${TRAITS[w].desc})` : ''}. They will remember.`;
  }
  // slay
  run.stats.slain++;
  const survives = n.traits.some((t) => t.id === 'ninelives') || chance(run.rng, 0.25);
  if (survives) {
    n.status = 'returning';
    n.scars++;
    nemLog(save, n, `Struck down by ${save.playerName}... but the body was never found.`);
  } else {
    n.status = 'slain';
    nemLog(save, n, `Slain by ${save.playerName}.`);
  }
  moveToFallen(save, n);
  chronicle(save, `${save.playerName} struck down ${fullName(n)}.`);
  return survives ? `${n.name} falls into the river... the body is never found.` : `${n.name} is slain. A Hand is empty.`;
}

function moveToFallen(save: Save, n: Nemesis) {
  const i = save.hands.indexOf(n);
  if (i >= 0) save.hands.splice(i, 1);
  if (!save.fallen.includes(n)) save.fallen.push(n);
}

// ---------------------------------------------------------------- market / tavern

export const CARD_PRICE: Record<Rarity, number> = { common: 14, rare: 28, epic: 48, legendary: 85 };
export const REMOVE_PRICE = 20;
export const UPGRADE_PRICE = 25;

export interface MarketStock {
  cards: { id: string; price: number; sold: boolean }[];
  charms: { id: CharmId; price: number; sold: boolean }[];
  removed: boolean;
  upgraded: boolean;
}

export function makeMarket(run: RunState): MarketStock {
  return {
    cards: rollCards(run.rng, 4, run.ring >= 3 ? 2 : 1).map((id) => ({ id, price: CARD_PRICE[CARDS[id].rarity], sold: false })),
    charms: charmOffer(run, 2).map((id) => ({ id, price: CHARMS[id].price, sold: false })),
    removed: false,
    upgraded: false,
  };
}

export function upgradeCard(run: RunState, uid: string): boolean {
  const c = run.deck.find((x) => x.uid === uid);
  if (!c || c.level >= 3 || getDef(c).kind !== 'unit') return false;
  c.level++;
  c.xp = XP_FOR_LEVEL[c.level];
  return true;
}

export function removeCard(run: RunState, uid: string): boolean {
  const i = run.deck.findIndex((x) => x.uid === uid);
  if (i < 0 || run.deck.length <= 10) return false;
  run.deck.splice(i, 1);
  return true;
}

// ---------------------------------------------------------------- shrine events

export interface EventChoice {
  label: string;
  hint?: string;
  enabled: (save: Save) => boolean;
  apply: (save: Save) => string;
}

export interface GameEvent {
  id: string;
  title: string;
  text: (save: Save) => string;
  choices: EventChoice[];
}

const leave: EventChoice = { label: 'Walk away', enabled: () => true, apply: () => 'You leave with your tail high.' };

function randomHandWithSecrets(save: Save): Nemesis | undefined {
  const pool = save.hands.filter((h) => h.traits.some((t) => !t.known));
  return pool.length ? pick(save.run!.rng, pool) : undefined;
}

export const EVENTS: GameEvent[] = [
  {
    id: 'rat',
    title: 'The Whispering Gutter',
    text: () => 'A rat informant peeks out of a drain. "Secrets, champion. Secrets about the Hands. Only 15 fish."',
    choices: [
      {
        label: 'Pay 15 fish',
        hint: 'Reveal 2 hidden Warlord traits',
        enabled: (s) => s.run!.fish >= 15,
        apply: (s) => {
          s.run!.fish -= 15;
          const out: string[] = [];
          for (let i = 0; i < 2; i++) {
            const h = randomHandWithSecrets(s);
            const t = h && revealRandomTrait(s.run!.rng, h);
            if (h && t) out.push(`${h.name}: ${TRAITS[t].name} (${TRAITS[t].desc})`);
          }
          return out.length ? 'The rat whispers:\n' + out.join('\n') : 'The rat has nothing new. It keeps your fish anyway.';
        },
      },
      leave,
    ],
  },
  {
    id: 'sword',
    title: 'The Sword in the Scratching Post',
    text: () => 'A gleaming blade is stuck deep in an old scratching post. Many paws have tried.',
    choices: [
      {
        label: 'Pull the sword',
        hint: '35%: a Legendary card. Otherwise lose 2 lives.',
        enabled: (s) => s.run!.lives > 2,
        apply: (s) => {
          const run = s.run!;
          if (chance(run.rng, 0.35)) {
            const legends = DRAFTABLE.filter((c) => c.rarity === 'legendary');
            const c = pick(run.rng, legends);
            addCard(run, c.id);
            return `It slides free! ${c.name} answers your call.`;
          }
          run.lives -= 2;
          return 'You pull until something in your back goes "pop". Lose 2 lives.';
        },
      },
      leave,
    ],
  },
  {
    id: 'bard',
    title: 'A Wandering Bard',
    text: () => 'A scruffy bard with a lute made from a sardine tin offers to sing of your deeds.',
    choices: [
      {
        label: 'Hear a ballad',
        hint: 'A random cat in your deck gains a level',
        enabled: (s) => s.run!.deck.some((c) => c.level < 3 && getDef(c).kind === 'unit'),
        apply: (s) => {
          const run = s.run!;
          const c = pick(run.rng, run.deck.filter((x) => x.level < 3 && getDef(x).kind === 'unit'));
          upgradeCard(run, c.uid);
          return `${getDef(c).name} is so inspired they reach level ${c.level}.`;
        },
      },
      {
        label: 'Ask for rumours',
        hint: 'Reveal a Warlord trait',
        enabled: () => true,
        apply: (s) => {
          const h = randomHandWithSecrets(s);
          const t = h && revealRandomTrait(s.run!.rng, h);
          return h && t ? `"They say ${h.name} is ${TRAITS[t].name}. ${TRAITS[t].desc}"` : 'The bard only knows songs about fish.';
        },
      },
    ],
  },
  {
    id: 'discord',
    title: 'Sow Discord',
    text: (s) => {
      const [a, b] = discordPair(s);
      return `A forged letter could convince ${a.name} that ${b.name} is plotting against them. Cats are very easily offended.`;
    },
    choices: [
      {
        label: 'Forge the letter (25 fish)',
        hint: 'Two Hands fight. The loser is exiled.',
        enabled: (s) => s.run!.fish >= 25,
        apply: (s) => {
          const run = s.run!;
          run.fish -= 25;
          const [a, b] = discordPair(s);
          const aWins = chance(run.rng, a.level / (a.level + b.level));
          const [w, l] = aWins ? [a, b] : [b, a];
          return powerStruggle(s, w, l, true);
        },
      },
      leave,
    ],
  },
  {
    id: 'sabotage',
    title: "The Warlord's Supper",
    text: (s) => `You find the kitchen where ${currentBoss(s)?.name ?? 'the Warlord'}'s supper is prepared. There is a suspicious bottle of "Essence of Cucumber".`,
    choices: [
      {
        label: 'Poison the supper (20 fish)',
        hint: 'Your next Warlord gains a weakness and loses a level',
        enabled: (s) => s.run!.fish >= 20 && !!currentBoss(s),
        apply: (s) => {
          const run = s.run!;
          run.fish -= 20;
          const n = currentBoss(s)!;
          const w = addTrait(run.rng, n, 'weakness');
          if (w) n.traits.find((t) => t.id === w)!.known = true;
          n.level = Math.max(1, n.level - 1);
          nemLog(s, n, `Was poisoned by ${s.playerName} with cucumber essence.`);
          return `${n.name} sees a cucumber and panics for a week.${w ? ` They are now ${TRAITS[w].name}.` : ''}`;
        },
      },
      leave,
    ],
  },
  {
    id: 'milk',
    title: 'Fountain of Warm Milk',
    text: () => 'An ancient fountain bubbles with warm milk. It smells... mostly fine.',
    choices: [
      { label: 'Drink deeply', hint: 'Gain 2 lives', enabled: (s) => s.run!.lives < START_LIVES, apply: (s) => {
        s.run!.lives = Math.min(START_LIVES, s.run!.lives + 2);
        return 'Warm. Creamy. You feel two lives younger.';
      } },
      { label: 'Bottle it to sell', hint: 'Gain 25 fish', enabled: () => true, apply: (s) => {
        s.run!.fish += 25;
        return 'A merchant pays 25 fish for "artisanal fountain milk".';
      } },
    ],
  },
  {
    id: 'basket',
    title: 'Kittens in a Basket',
    text: () => 'Three kittens tumble out of a basket and look at you with enormous eyes.',
    choices: [
      { label: 'Adopt them', hint: 'Add 2 Squire Kittens', enabled: () => true, apply: (s) => {
        addCard(s.run!, 'squire');
        addCard(s.run!, 'squire');
        return 'The squires swear an oath. It is mostly squeaking.';
      } },
      leave,
    ],
  },
  {
    id: 'bookie',
    title: 'The Arena Bookmaker',
    text: () => 'A fat tabby with a ledger offers odds on your next fight. "Double or nothing, champ."',
    choices: [
      { label: 'Bet 20 fish', hint: '50%: win 40', enabled: (s) => s.run!.fish >= 20, apply: (s) => {
        const run = s.run!;
        if (chance(run.rng, 0.5)) {
          run.fish += 20;
          return 'The ledger says you win. Somehow. +20 fish.';
        }
        run.fish -= 20;
        return 'The ledger says you lose. The ledger is never wrong. -20 fish.';
      } },
      leave,
    ],
  },
];

export const EVENT_IDS = EVENTS.map((e) => e.id);

function discordPair(s: Save): [Nemesis, Nemesis] {
  // the two lowest Hands that are not this ring's boss
  const boss = currentBoss(s);
  const pool = s.hands.filter((h) => h !== boss);
  const a = pool[pool.length - 1] ?? s.hands[3];
  const b = pool[pool.length - 2] ?? s.hands[2];
  return [a, b];
}

function powerStruggle(save: Save, winner: Nemesis, loser: Nemesis, exile: boolean): string {
  winner.level++;
  nemLog(save, winner, `Defeated ${loser.name} in a power struggle.`);
  const wi = save.hands.indexOf(winner);
  const li = save.hands.indexOf(loser);
  let text: string;
  if (exile) {
    loser.status = 'exiled';
    nemLog(save, loser, `Exiled after losing to ${winner.name}.`);
    save.hands.splice(li, 1);
    save.fallen.push(loser);
    // winner takes the higher rank
    if (li < wi) {
      save.hands.splice(save.hands.indexOf(winner), 1);
      save.hands.splice(li, 0, winner);
    }
    const fresh = generateNemesis(save.rng, nid(save), 1, save.runs);
    save.hands.push(fresh);
    nemLog(save, fresh, `Claimed the empty seat after ${loser.name}'s exile.`);
    text = `${winner.name} mauls ${loser.name}, who is exiled from the Arena. ${fresh.name} claims the empty seat.`;
    const run = save.run;
    if (run) {
      const bi = run.bossIds.indexOf(loser.id);
      if (bi >= 0) run.bossIds[bi] = fresh.id;
    }
  } else {
    if (li < wi) {
      save.hands[li] = winner;
      save.hands[wi] = loser;
    }
    text = `${winner.name} defeats ${loser.name} in a duel for rank.`;
  }
  chronicle(save, text);
  return text;
}

// ---------------------------------------------------------------- end of run: the Arena moves on

export function finishRun(save: Save, outcome: 'victory' | 'defeat') {
  const run = save.run!;
  run.phase = 'over';
  run.outcome = outcome;
  if (outcome === 'victory') save.victories++;
}

/** Called when the player leaves the run summary. Shifts the hierarchy and returns what happened. */
export function arenaMovesOn(save: Save): string[] {
  const run = save.run;
  const news: string[] = [];
  const rng = save.rng;
  if (run?.outcome === 'defeat' && run.killedBy) {
    const k = findNemesis(save, run.killedBy);
    if (k) news.push(`${k.name} boasts of ending your run. Their legend grows.`);
  }
  // returning and betraying nemeses
  for (const n of [...save.fallen]) {
    if (n.status === 'returning') {
      n.status = 'active';
      n.level++;
      addTrait(rng, n, 'strength');
      n.epithet = 'the Returned';
      nemLog(save, n, `Returned from the dead, bearing ${pick(rng, SCAR_DESCRIPTIONS)}.`);
      save.fallen.splice(save.fallen.indexOf(n), 1);
      const ousted = save.hands.length >= 4 ? save.hands.pop() : undefined;
      if (ousted) {
        ousted.status = 'exiled';
        save.fallen.push(ousted);
      }
      save.hands.push(n);
      news.push(`${n.name} has returned from the dead${ousted ? `, throwing ${ousted.name} out of the Fourth Hand` : ''}.`);
    } else if (n.status === 'recruited') {
      if (chance(rng, 0.3)) {
        n.status = 'active';
        n.traitor = true;
        n.met = false;
        n.epithet = 'the Traitor';
        n.level++;
        nemLog(save, n, `Betrayed ${save.playerName} and clawed back into the hierarchy.`);
        save.fallen.splice(save.fallen.indexOf(n), 1);
        if (save.hands.length >= 4) {
          const o = save.hands.pop()!;
          o.status = 'exiled';
          save.fallen.push(o);
        }
        save.hands.push(n);
        news.push(`${n.name}, once sworn to you, has betrayed you and rejoined the Hands!`);
      } else {
        n.status = 'exiled';
        news.push(`${n.name} retires from the Arena, loyal to the end.`);
      }
    }
  }
  // nemeses who beat you this run learn from it
  for (const h of save.hands) {
    if (h.growth) {
      const t = addTrait(rng, h, 'strength');
      if (t) news.push(`${h.name} trained hard after beating you, and gained ${TRAITS[t].name}.`);
      h.growth = 0;
    }
  }
  // fill empty seats: everyone shuffles up, new blood at the bottom
  while (save.hands.length < 4) {
    const fresh = generateNemesis(rng, nid(save), 1 + int(rng, 2), save.runs);
    save.hands.push(fresh);
    news.push(`${fresh.name} ${fresh.epithet} claims a seat among the Hands.`);
  }
  // a power struggle between neighbours
  if (chance(rng, 0.5)) {
    const i = 1 + int(rng, 3); // challenger at index i challenges i-1
    const challenger = save.hands[i];
    const holder = save.hands[i - 1];
    const wins = chance(rng, 0.4 + 0.1 * (challenger.level - holder.level));
    news.push(powerStruggle(save, wins ? challenger : holder, wins ? holder : challenger, false));
  }
  // promotions/levels are visible in the hierarchy; record ranks in history
  save.hands.forEach((h, i) => {
    const last = h.history[h.history.length - 1];
    const tag = `Holds the rank of ${['First', 'Second', 'Third', 'Fourth'][i]} Hand.`;
    if (!last || last.text !== tag) nemLog(save, h, tag);
  });
  for (const t of news) chronicle(save, t);
  save.run = null;
  return news;
}

export function deckSummary(deck: CardInst[]) {
  const units = deck.filter((c) => getDef(c).kind === 'unit');
  return {
    size: deck.length,
    units: units.length,
    specials: deck.length - units.length,
    power: units.reduce((a, c) => a + getDef(c).power + (c.level - 1) * 2, 0),
  };
}

