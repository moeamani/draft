import type { AbilityId, CardDef, CardInst, Coat, Rarity } from './types';

export interface AbilityInfo {
  name: string;
  icon: string;
  desc: string;
}

export const ABILITIES: Record<AbilityId, AbilityInfo> = {
  none: { name: 'Steadfast', icon: '', desc: 'No ability. Just a very good cat.' },
  smite: {
    name: 'Sword Hammer',
    icon: '⚒',
    desc: 'Smite: destroy the strongest enemy unit(s). Legendaries are immune.',
  },
  inspire: {
    name: 'Aural Orb',
    icon: '◉',
    desc: 'Inspire: every other unit in this row gets +1.',
  },
  hex: {
    name: 'Black Cat',
    icon: '☾',
    desc: 'Hex: the strongest enemy unit loses 1 power for every Black Cat you have on the board (this one included).',
  },
  litter: {
    name: 'Litter',
    icon: '❀',
    desc: 'Litter: power is multiplied by the number of cats with this name in the row.',
  },
  pounce: {
    name: 'Pounce',
    icon: '➶',
    desc: 'Pounce: deal 3 damage to the strongest enemy unit in the opposite row.',
  },
  ninelives: {
    name: 'Nine Lives',
    icon: '❾',
    desc: 'Nine Lives: stays on the board for the next round (once).',
  },
  stray: {
    name: 'Stray',
    icon: '⌖',
    desc: "Stray: wanders onto the enemy's side (they get the points). You draw 2 cards.",
  },
  groom: {
    name: 'Groom',
    icon: '✚',
    desc: 'Groom: revive the strongest non-legendary unit from your discard pile.',
  },
  purr: {
    name: 'Purr',
    icon: '♪',
    desc: 'Purr: your weakest other unit permanently gains +2.',
  },
  yowl: {
    name: 'War Yowl',
    icon: '♬',
    desc: 'War Yowl: doubles the power of every other unit in this row.',
  },
  muster: {
    name: 'Call the Pride',
    icon: '⇈',
    desc: 'Call the Pride: every copy of this cat in your deck joins the fight too.',
  },
  downpour: {
    name: 'Downpour',
    icon: '☂',
    desc: 'Weather: all Vanguard units (both sides) drop to 1 power. Cats hate rain.',
  },
  moonfog: {
    name: 'Moonfog',
    icon: '☁',
    desc: 'Weather: all Arcane units (both sides) drop to 1 power.',
  },
  sunbeam: {
    name: 'Sunbeam',
    icon: '☀',
    desc: 'Clear all weather. Everyone has a nice nap in the sun.',
  },
  warhorn: {
    name: 'Rallying Yowl',
    icon: '♬',
    desc: 'Double the power of all units in your strongest-benefiting row.',
  },
  box: {
    name: 'Cardboard Box',
    icon: '▣',
    desc: 'Return your strongest non-legendary unit to your hand. If it fits, it sits.',
  },
  hairball: {
    name: 'Hairball',
    icon: '✺',
    desc: 'Destroy the strongest non-legendary unit(s) on the WHOLE board. Both sides.',
  },
};

export const COATS: Record<Coat, { name: string; color: string; beats: Coat | null; desc: string }> = {
  ember: { name: 'Ember', color: '#e8483b', beats: 'gilt', desc: 'Ginger fire-coats. Ember scorches Gilt.' },
  gilt: { name: 'Gilt', color: '#d3a200', beats: 'tide', desc: 'Golden noble-coats. Gilt dams the Tide.' },
  tide: { name: 'Tide', color: '#2378f7', beats: 'ember', desc: 'Blue-grey sea-coats. Tide drowns Ember.' },
  shadow: { name: 'Shadow', color: '#7d8a99', beats: null, desc: 'Black cats. No advantage, but they Hex.' },
};

export const COAT_ADVANTAGE = 2;

export const RARITY_COLOR: Record<Rarity, string> = {
  common: '#e9e6dc',
  rare: '#2378f7',
  epic: '#e8483b',
  legendary: '#d3a200',
};

const u = (
  id: string,
  name: string,
  type: 'physical' | 'magic',
  power: number,
  ability: AbilityId,
  rarity: Rarity,
  coat: Coat,
  flavor: string,
): CardDef => ({ id, name, kind: 'unit', type, power, ability, rarity, coat, flavor });

const sp = (id: string, name: string, ability: AbilityId, rarity: Rarity, flavor: string): CardDef => ({
  id,
  name,
  kind: 'special',
  power: 0,
  ability,
  rarity,
  coat: 'none',
  flavor,
});

// The first rows come straight from the Figma card sheet (Artheline, Merline, and the Black Cats).
export const CARD_LIST: CardDef[] = [
  // ---- From the Figma sheet ----
  u('artheline', 'Artheline', 'physical', 20, 'smite', 'legendary', 'gilt', 'Drew the Sword Hammer from the scratching post. The once and future queen of the alley.'),
  u('merline', 'Merline', 'magic', 15, 'inspire', 'legendary', 'tide', 'Her Aural Orb hums at the frequency of a contented purr.'),
  u('lanceline', 'Lanceline', 'magic', 7, 'hex', 'epic', 'shadow', 'Crosses your path on purpose.'),
  u('morgelius', 'Morgelius', 'magic', 5, 'hex', 'rare', 'shadow', 'Knocked a goblet off the Round Table. Unrepentant.'),
  u('circaleus', 'Circaleus', 'magic', 3, 'hex', 'common', 'shadow', 'Walks in circles. Curses in circles.'),
  u('purrceval', 'Purrceval', 'magic', 5, 'hex', 'rare', 'shadow', 'Quests for the Holy Grail. Will settle for the holy gravy.'),
  u('purrlinore', 'Purrlinore', 'magic', 4, 'hex', 'common', 'shadow', 'Hunts the Questing Mouse, forever.'),
  u('mordraleus', 'Mordraleus', 'magic', 8, 'hex', 'epic', 'shadow', 'His shadow arrives a second before he does.'),
  u('merlinus', 'Merlinus', 'magic', 2, 'hex', 'common', 'shadow', 'An apprentice of bad luck. Studying hard.'),

  // ---- Vanguard (Physical) ----
  u('uther', 'Uther Pawndragon', 'physical', 12, 'yowl', 'legendary', 'ember', 'When he yowls, the whole line stands taller.'),
  u('greenmouser', 'The Green Mouser', 'physical', 11, 'ninelives', 'legendary', 'tide', 'Lost his head once. Grew it back.'),
  u('mewdred', 'Mewdred', 'physical', 9, 'pounce', 'epic', 'ember', 'Rightful heir to absolutely nothing.'),
  u('galahiss', 'Galahiss the Pure', 'physical', 8, 'groom', 'epic', 'gilt', 'So clean. So very clean.'),
  u('gawpaw', 'Sir Gawpaw', 'physical', 6, 'pounce', 'rare', 'ember', 'Strongest at noon, sleepiest at 12:01.'),
  u('bedimew', 'Sir Bedimew', 'physical', 4, 'groom', 'rare', 'gilt', 'Licks wounds. Everyone\'s.'),
  u('borscat', 'Sir Borscat', 'physical', 5, 'ninelives', 'rare', 'tide', 'Has died four times. Still has five to go.'),
  u('lamoracat', 'Lamoracat', 'physical', 7, 'none', 'rare', 'tide', 'Big. Fluffy. Unmovable.'),
  u('pelliroar', 'King Pelliroar', 'physical', 4, 'yowl', 'rare', 'gilt', 'His roar is mostly a squeak, but it works.'),
  u('tristripe', 'Sir Tristripe', 'physical', 5, 'purr', 'rare', 'ember', 'Purrs in harmony with whoever is losing.'),
  u('alleystray', 'Alley Stray', 'physical', 6, 'stray', 'rare', 'shadow', 'Goes wherever the fish are.'),
  u('kaytail', 'Sir Kaytail', 'physical', 3, 'litter', 'common', 'ember', 'There are always more of him.'),
  u('pikecat', 'Tabby Pikecat', 'physical', 3, 'litter', 'common', 'tide', 'Holds the line. Mostly holds the snacks.'),
  u('squire', 'Squire Kitten', 'physical', 2, 'muster', 'common', 'gilt', 'Where one squeaks, the whole litter follows.'),
  u('gareth', 'Gareth the Scullion', 'physical', 4, 'purr', 'common', 'tide', 'Kitchen-trained. Knows where the cream is.'),
  u('agravain', 'Agravain', 'physical', 5, 'none', 'common', 'shadow', 'Grumpy. Effective.'),
  u('ironpaw', 'Ironpaw Sergeant', 'physical', 3, 'pounce', 'common', 'gilt', 'Pounces by the book.'),
  u('barnbrawler', 'Barn Brawler', 'physical', 5, 'none', 'common', 'ember', 'Raised on mice and bad decisions.'),

  // ---- Arcane (Magic) ----
  u('nimew', 'Nimew of the Lake', 'magic', 12, 'groom', 'legendary', 'tide', 'Hands out swords from the water. Hates getting wet.'),
  u('morgana', 'Morgana le Fur', 'magic', 13, 'hex', 'legendary', 'shadow', 'The blackest cat of all. Luck flees from her.'),
  u('vivipurr', 'Vivipurr', 'magic', 4, 'inspire', 'rare', 'tide', 'Her orb glows brighter for every friend nearby.'),
  u('taliesing', 'Taliesing the Bard', 'magic', 3, 'yowl', 'rare', 'gilt', 'Sings the songs that make knights double-brave.'),
  u('seer', 'Crystal Seer', 'magic', 3, 'stray', 'rare', 'gilt', 'Saw her future in the enemy camp. Went there.'),
  u('hedgedruid', 'Hedge Druid', 'magic', 3, 'litter', 'common', 'tide', 'Druids come in circles.'),
  u('emberadept', 'Ember Adept', 'magic', 4, 'pounce', 'common', 'ember', 'Throws fireballs. Mostly hairballs, on fire.'),
  u('elaine', 'Elaine of Astocat', 'magic', 3, 'purr', 'common', 'gilt', 'Weaves tapestries of everyone\'s naps.'),
  u('novice', 'Orb Novice', 'magic', 2, 'muster', 'common', 'tide', 'Never studies alone.'),
  u('candlewitch', 'Candle Witch', 'magic', 6, 'none', 'common', 'ember', 'Keeps the flame lit and the tail clear of it.'),

  // ---- Specials ----
  sp('downpour', 'Downpour', 'downpour', 'rare', 'The single most effective weapon against cats.'),
  sp('moonfog', 'Moonfog', 'moonfog', 'rare', 'Nobody can see their orbs in this.'),
  sp('sunbeam', 'Sunbeam', 'sunbeam', 'common', 'Everyone stops fighting to lie down in it.'),
  sp('warhorn', 'Rallying Yowl', 'warhorn', 'rare', 'A sound that wakes the whole street.'),
  sp('box', 'Cardboard Box', 'box', 'common', 'If it fits, it sits. If it sits, it hides.'),
  sp('hairball', 'Hairball', 'hairball', 'epic', 'Hrrk. Hrrrk. HRRRK.'),

  // ---- Tokens ----
  { ...u('guard', 'Arena Guard', 'physical', 3, 'none', 'common', 'shadow', 'Paid in fish. Loyal until the fish run out.'), token: true },
];

export const CARDS: Record<string, CardDef> = Object.fromEntries(CARD_LIST.map((c) => [c.id, c]));

export const DRAFTABLE = CARD_LIST.filter((c) => !c.token);

export function getDef(inst: CardInst | string): CardDef {
  if (typeof inst === 'string') return CARDS[inst];
  return inst.def ?? CARDS[inst.id];
}

export const levelBonus = (level: number) => (level - 1) * 2;
export const XP_FOR_LEVEL = [0, 0, 2, 5]; // xp needed to reach level 2, 3
export const LEVEL_TITLES = ['', '', 'Knight', 'Paladin'];

export function displayName(inst: CardInst): string {
  return getDef(inst).name;
}

export const isUnit = (d: CardDef) => d.kind === 'unit';
export const isLegend = (d: CardDef) => d.rarity === 'legendary';
