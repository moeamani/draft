import { CARD_LIST } from './cards';
import { chance, int, pick, shuffle, weighted, type Rng } from './rng';
import { conflicts, STRENGTHS, TRAITS, WEAKNESSES, type TraitId } from './traits';
import type { AbilityId, CardDef, CardInst, Coat } from './types';

export type Personality = 'brute' | 'schemer' | 'zealot' | 'coward' | 'trickster';

export interface KnownTrait {
  id: TraitId;
  known: boolean;
}

export interface NemesisEvent {
  run: number;
  text: string;
}

export interface Nemesis {
  id: string;
  name: string;
  epithet: string;
  coat: Coat;
  style: AbilityId;
  personality: Personality;
  level: number;
  traits: KnownTrait[];
  scars: number;
  /** Times this nemesis beat the player. */
  wins: number;
  /** Times the player beat this nemesis. */
  losses: number;
  met: boolean;
  status: 'active' | 'slain' | 'recruited' | 'exiled' | 'returning';
  history: NemesisEvent[];
  seed: number;
  /** Was this a lowly stray that got promoted after beating the player? */
  fromStray?: boolean;
  /** Was this nemesis once recruited, and betrayed the player? */
  traitor?: boolean;
  /** Wins over the player this run, turned into new strengths when the Arena moves on. */
  growth?: number;
}

const PREFIX = ['Mor', 'Gal', 'Pell', 'Bal', 'Agra', 'Grim', 'Tor', 'Mal', 'Cal', 'Fel', 'Ur', 'Vor', 'Lyn', 'Bri', 'Gor', 'Dag', 'Sab', 'Kit', 'Tib', 'Hro', 'Ys', 'Cad'];
const MIDDLE = ['ra', 'e', 'i', 'o', 'a', 'ga', 'li', 'dre', 'wa', 'mi', 'ne', ''];
const SUFFIX = ['mew', 'purr', 'claw', 'tail', 'fang', 'whisk', 'paw', 'leus', 'vane', 'dred', 'mog', 'ius', 'hiss', 'mane', 'grin', 'bert', 'ric'];

const EPITHETS: Record<Coat, string[]> = {
  ember: ['Cinder-Claw', 'the Scorched', 'Ash-Whisker', 'the Kindling', 'Hearth-Breaker'],
  tide: ['Rain-Drinker', 'the Drowned', 'Salt-Fang', 'of the Undertow', 'the Grey Wave'],
  gilt: ['the Gilded', 'Gold-Tooth', 'the Gleaming', 'Crown-Licker', 'the Polished'],
  shadow: ['the Unlucky', 'of the Gutter', 'the Hollow Purr', 'Moon-Eater', 'the Unblinking'],
};

const PERSONALITY_EPITHETS: Record<Personality, string[]> = {
  brute: ['Skull-Batter', 'the Heavy', 'Bone-Gnawer'],
  schemer: ['the Patient', 'Whisper-Tail', 'the Ledger'],
  zealot: ['the Devout', 'Flame of the Arena', 'the Sworn'],
  coward: ['the Slippery', 'Quick-Tail', 'the Survivor'],
  trickster: ['the Grin', 'Fish-Thief', 'the Prankster'],
};

const STYLES: AbilityId[] = ['smite', 'hex', 'yowl', 'inspire', 'groom', 'pounce', 'ninelives'];

export function nemesisName(rng: Rng): string {
  const n = pick(rng, PREFIX) + pick(rng, MIDDLE) + pick(rng, SUFFIX);
  return n[0].toUpperCase() + n.slice(1);
}

export function fullName(n: Nemesis): string {
  return `${n.name} ${n.epithet}`;
}

export function addTrait(rng: Rng, n: Nemesis, kind: 'strength' | 'weakness'): TraitId | null {
  const pool = (kind === 'strength' ? STRENGTHS : WEAKNESSES).filter(
    (t) => !conflicts(t, n.traits.map((x) => x.id)),
  );
  if (!pool.length) return null;
  const t = pick(rng, pool);
  n.traits.push({ id: t, known: false });
  return t;
}

export function generateNemesis(rng: Rng, id: string, level: number, run: number): Nemesis {
  const coat = pick<Coat>(rng, ['ember', 'tide', 'gilt', 'shadow']);
  const personality = pick<Personality>(rng, ['brute', 'schemer', 'zealot', 'coward', 'trickster']);
  const n: Nemesis = {
    id,
    name: nemesisName(rng),
    epithet: chance(rng, 0.6) ? pick(rng, EPITHETS[coat]) : pick(rng, PERSONALITY_EPITHETS[personality]),
    coat,
    style: coat === 'shadow' && chance(rng, 0.6) ? 'hex' : pick(rng, STYLES),
    personality,
    level,
    traits: [],
    scars: 0,
    wins: 0,
    losses: 0,
    met: false,
    status: 'active',
    history: [{ run, text: 'Entered the Arena hierarchy.' }],
    seed: int(rng, 1e9),
  };
  const strengths = 1 + Math.min(2, Math.floor(level / 2));
  for (let i = 0; i < strengths; i++) addTrait(rng, n, 'strength');
  addTrait(rng, n, 'weakness');
  if (level <= 2 || chance(rng, 0.4)) addTrait(rng, n, 'weakness');
  if (personality === 'brute' && !n.traits.some((t) => t.id === 'arrogant') && chance(rng, 0.4)) {
    n.traits.push({ id: 'arrogant', known: false });
  }
  return n;
}

export function traitIds(n: Nemesis): TraitId[] {
  const ids = n.traits.map((t) => t.id);
  if (n.wins > 0 && !ids.includes('grudge')) ids.push('grudge');
  return ids;
}

export function hiddenTraits(n: Nemesis): KnownTrait[] {
  return n.traits.filter((t) => !t.known);
}

export function revealRandomTrait(rng: Rng, n: Nemesis): TraitId | null {
  const hidden = hiddenTraits(n);
  if (!hidden.length) return null;
  const t = pick(rng, hidden);
  t.known = true;
  return t.id;
}

/** The nemesis as a playable Legendary card. */
export function signatureCard(n: Nemesis): CardDef {
  const magic = ['hex', 'inspire', 'groom'].includes(n.style);
  return {
    id: 'sig_' + n.id,
    name: n.name,
    kind: 'unit',
    type: magic ? 'magic' : 'physical',
    power: 7 + n.level * 2,
    ability: n.style,
    rarity: 'legendary',
    coat: n.coat,
    flavor: `${fullName(n)}. ${n.losses ? 'Bears the scars of your claws.' : 'Undefeated in the Arena.'}`,
    signature: { nemesisId: n.id },
    artSeed: n.seed,
    scars: n.scars,
  };
}

// ---------------------------------------------------------------- decks

let enemyUid = 0;
const inst = (id: string, level: number): CardInst => ({ uid: 'e' + enemyUid++, id, level, xp: 0 });

function poolFor(coat: Coat | null, style: AbilityId | null) {
  return CARD_LIST.filter((c) => !c.token && c.rarity !== 'legendary').map(
    (c) =>
      [
        c,
        (c.rarity === 'common' ? 6 : c.rarity === 'rare' ? 3 : 1) *
          (coat && c.coat === coat ? 2.5 : 1) *
          (style && c.ability === style ? 2 : 1) *
          (c.kind === 'special' ? 0.6 : 1),
      ] as [CardDef, number],
  );
}

export function enemyDeck(rng: Rng, opts: { coat: Coat | null; style: AbilityId | null; tier: number; size: number; bonusLevels: number }): CardInst[] {
  const pool = poolFor(opts.coat, opts.style);
  const out: CardInst[] = [];
  let specials = 0;
  while (out.length < opts.size) {
    const c = weighted(rng, pool);
    if (c.kind === 'special') {
      if (specials >= 2) continue;
      specials++;
    }
    const lvl = Math.min(3, 1 + (chance(rng, Math.max(0, 0.1 * (opts.tier - 1) + 0.08 * opts.bonusLevels)) ? 1 : 0) + (opts.bonusLevels >= 3 && chance(rng, 0.3) ? 1 : 0));
    out.push(inst(c.id, lvl));
    // litter/muster cards come in packs
    if ((c.ability === 'litter' || c.ability === 'muster') && out.length < opts.size) out.push(inst(c.id, lvl));
  }
  return shuffle(rng, out.slice(0, opts.size));
}

export function nemesisDeck(rng: Rng, n: Nemesis, tier: number): CardInst[] {
  const deck = enemyDeck(rng, { coat: n.coat, style: n.style, tier, size: 12 + tier, bonusLevels: n.level - 1 });
  const sig = signatureCard(n);
  deck.push({ uid: 'e' + enemyUid++, id: sig.id, level: 1, xp: 0, def: sig });
  if (n.level >= 4) {
    const legends = CARD_LIST.filter((c) => c.rarity === 'legendary' && (c.coat === n.coat || c.ability === n.style));
    if (legends.length) deck.push(inst(pick(rng, legends).id, 1));
  }
  return shuffle(rng, deck);
}

// ---------------------------------------------------------------- strays (grunts)

export interface StrayFoe {
  name: string;
  coat: Coat;
  level: number;
  seed: number;
  personality: Personality;
  elite: boolean;
}

const STRAY_TITLES = ['Alley Brawler', 'Pit Fighter', 'Gutter Knight', 'Sellsword', 'Dock Mouser', 'Bin Raider', 'Rooftop Duelist', 'Hedge Squire'];

export function generateStray(rng: Rng, tier: number, elite: boolean): StrayFoe {
  return {
    name: `${nemesisName(rng)} the ${pick(rng, STRAY_TITLES)}`,
    coat: pick<Coat>(rng, ['ember', 'tide', 'gilt', 'shadow']),
    level: tier,
    seed: int(rng, 1e9),
    personality: pick<Personality>(rng, ['brute', 'schemer', 'zealot', 'coward', 'trickster']),
    elite,
  };
}

export function strayDeck(rng: Rng, foe: StrayFoe): CardInst[] {
  return enemyDeck(rng, {
    coat: foe.coat,
    style: null,
    tier: foe.level,
    size: 11 + foe.level * 2 + (foe.elite ? 2 : 0),
    bonusLevels: foe.elite ? foe.level : foe.level - 2,
  });
}

/** A stray that beat the player is promoted into the hierarchy. */
export function promoteStray(rng: Rng, foe: StrayFoe, id: string, run: number, playerName: string): Nemesis {
  const n = generateNemesis(rng, id, Math.max(1, foe.level), run);
  n.name = foe.name.split(' the ')[0];
  n.epithet = `Bane of ${playerName}`;
  n.coat = foe.coat;
  n.personality = foe.personality;
  n.seed = foe.seed;
  n.wins = 1;
  n.met = true;
  n.fromStray = true;
  n.history = [{ run, text: `A nameless stray who beat ${playerName} in the pits. Promoted for it.` }];
  return n;
}

// ---------------------------------------------------------------- dialogue

type Situation = 'first' | 'theyWon' | 'youWon' | 'returned' | 'traitor' | 'promoted' | 'gloat' | 'beaten' | 'slain' | 'recruit' | 'brand';

const LINES: Record<Situation, Partial<Record<Personality | 'any', string[]>>> = {
  first: {
    brute: ['Another little champion. I eat little champions.', 'You smell like a house cat. Soft bed. Soft paws.'],
    schemer: ['So you are {player}. I have heard... very little. Good.', 'I have studied every cat who walked into this ring. You will be a short chapter.'],
    zealot: ['The Arena chose me. It did not choose you.', 'Kneel, and I will make it quick.'],
    coward: ["Oh! Oh, you're bigger than they said. W-we can talk about this.", 'Let us keep this civil, yes? Mostly civil.'],
    trickster: ['A new toy! Do you squeak when you lose?', 'Heh. They let anyone in these days.'],
  },
  theyWon: {
    any: ['{player}! Back for another beating? I still remember how you squealed.', 'I beat you {wins} time{s}. Let us make it {wins1}.', 'Nine lives, they say. How many do you have left, {player}?'],
    brute: ['You again. I thought I broke you.', 'Last time you ran with your tail between your legs.'],
    schemer: ['I wrote down every mistake you made last time. It is a long list.'],
    trickster: ['My favourite chew toy has returned!'],
  },
  youWon: {
    any: ['You did this to me, {player}. I have thought of nothing else.', 'I remember your claws. Now remember mine.', 'Look at this scar. Look at it! Today I return the favour.'],
    coward: ['I-I have been practising since last time. A lot.'],
    zealot: ['The Arena tested me with you. I will not fail it twice.'],
  },
  returned: {
    any: ['You thought you finished me? The Arena does not let go of its own.', 'I crawled out of the river for this, {player}.', 'Dead? Me? You should have checked twice.'],
  },
  traitor: {
    any: ['You trusted me, {player}. That was your first mistake.', 'I fought for you once. I remember all your weaknesses.'],
  },
  promoted: {
    any: ['They call me {rank} now. Thanks to you, {player}.', 'Every win over you lifted me higher. Look where I stand.'],
  },
  gloat: {
    any: ['Stay down, {player}.', 'Go lick your wounds.', 'That is one less life for you.', 'Tell the others who did this.'],
    trickster: ['Squeak squeak! Hah!'],
    brute: ['Crushed. Like a mouse.'],
  },
  beaten: {
    any: ['This... is not over.', 'Lucky. You were lucky.', 'Hhhss... I will remember this.'],
    coward: ['Please! Please, mercy, I have kittens! Probably!'],
  },
  slain: {
    any: ['The Arena... will remember... me...', 'Finish it, then.'],
    coward: ['Wait, wait, wai—'],
  },
  recruit: {
    any: ['You beat me without a scratch. Fine. My claws are yours.', 'A champion like that... I would rather follow than fall.'],
  },
  brand: {
    any: ['You... you mark me? Every cat in the Arena will see this.', 'I will wear this brand until I pay it back.'],
  },
};

export const RANK_TITLES = ['', 'the First Hand', 'the Second Hand', 'the Third Hand', 'the Fourth Hand'];

export function speak(rng: Rng, n: Nemesis, sit: Situation, playerName: string, rank = 4): string {
  const set = LINES[sit];
  const opts = [...(set[n.personality] ?? []), ...(set.any ?? [])];
  const line = opts.length ? pick(rng, opts) : '...';
  return line
    .replace(/\{player\}/g, playerName)
    .replace(/\{wins\}/g, String(n.wins))
    .replace(/\{wins1\}/g, String(n.wins + 1))
    .replace(/\{s\}/g, n.wins === 1 ? '' : 's')
    .replace(/\{rank\}/g, RANK_TITLES[rank] ?? '');
}

export function encounterSituation(n: Nemesis): Situation {
  if (n.traitor && !n.met) return 'traitor';
  if (!n.met) return 'first';
  const last = n.history[n.history.length - 1]?.text ?? '';
  if (last.startsWith('Returned')) return 'returned';
  if (last.startsWith('Promoted') && n.wins) return 'promoted';
  if (n.losses > 0 && n.losses >= n.wins) return 'youWon';
  if (n.wins > 0) return 'theyWon';
  return 'first';
}

export const SCAR_DESCRIPTIONS = ['a torn ear', 'a scar across the eye', 'a crooked tail', 'a burned whisker-pad', 'a missing fang'];

export function describeTraitShort(t: TraitId) {
  return TRAITS[t];
}

