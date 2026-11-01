import type { Coat } from './types';

/** Modifiers that apply to one side of a duel. Built from nemesis traits and player charms. */
export interface SideMods {
  thickfur: boolean;
  weatherImmune: boolean;
  weatherZero: boolean;
  weatherFloor: number;
  vanguardBonus: number;
  arcaneBonus: number;
  extraDraw: number;
  vengeful: boolean;
  bodyguard: boolean;
  secondWind: boolean;
  /** Extra damage this side takes from enemy hexes. */
  hexVuln: number;
  /** Pounce against this side deals double. */
  pounceVuln: boolean;
  /** Enemy units of this coat get +2 against this side. */
  dread: Coat | null;
  /** Bonus/malus applied to the first unit this side plays each round. */
  firstUnitBonus: number;
  hexBonus: number;
  pounceBonus: number;
  legendBonus: number;
  coatBonus: Partial<Record<Coat, number>>;
  /** AI behaviour: passes early when ahead. */
  arrogant: boolean;
  /** Map from mod key -> trait id, so the engine can reveal the trait when it fires. */
  source: Record<string, string>;
}

export function baseMods(): SideMods {
  return {
    thickfur: false,
    weatherImmune: false,
    weatherZero: false,
    weatherFloor: 1,
    vanguardBonus: 0,
    arcaneBonus: 0,
    extraDraw: 0,
    vengeful: false,
    bodyguard: false,
    secondWind: false,
    hexVuln: 0,
    pounceVuln: false,
    dread: null,
    firstUnitBonus: 0,
    hexBonus: 0,
    pounceBonus: 0,
    legendBonus: 0,
    coatBonus: {},
    arrogant: false,
    source: {},
  };
}

export type TraitId =
  | 'thickfur'
  | 'rainsoaked'
  | 'warlord'
  | 'archmage'
  | 'hoarder'
  | 'vengeful'
  | 'bodyguard'
  | 'grudge'
  | 'secondwind'
  | 'ninelives'
  | 'hydrophobic'
  | 'superstitious'
  | 'arrogant'
  | 'glassjaw'
  | 'dread_ember'
  | 'dread_tide'
  | 'dread_gilt'
  | 'sluggish'
  | 'lazy';

export interface TraitInfo {
  name: string;
  kind: 'strength' | 'weakness';
  desc: string;
}

export const TRAITS: Record<TraitId, TraitInfo> = {
  thickfur: { name: 'Thick Fur', kind: 'strength', desc: 'Their units are immune to Hex and Pounce.' },
  rainsoaked: { name: 'Rain-Soaked', kind: 'strength', desc: 'Their units ignore weather.' },
  warlord: { name: 'Warlord', kind: 'strength', desc: 'Their Vanguard units get +1.' },
  archmage: { name: 'Archmage', kind: 'strength', desc: 'Their Arcane units get +1.' },
  hoarder: { name: 'Hoarder', kind: 'strength', desc: 'They draw 1 extra card.' },
  vengeful: { name: 'Vengeful', kind: 'strength', desc: 'When one of their units is destroyed, their strongest unit gains +2.' },
  bodyguard: { name: 'Bodyguard', kind: 'strength', desc: 'A 3-power Arena Guard joins them every round.' },
  grudge: { name: 'Grudge', kind: 'strength', desc: 'Their first unit each round gets +2 for every time they have beaten you (max +6).' },
  secondwind: { name: 'Second Wind', kind: 'strength', desc: 'If they lose a round, they draw 2 cards.' },
  ninelives: { name: 'Nine Lives', kind: 'strength', desc: 'Slaying them never sticks. They always come back.' },
  hydrophobic: { name: 'Hydrophobic', kind: 'weakness', desc: 'Weather drops their units to 0 instead of 1.' },
  superstitious: { name: 'Superstitious', kind: 'weakness', desc: 'Your Hexes deal 2 extra damage to them.' },
  arrogant: { name: 'Arrogant', kind: 'weakness', desc: 'They pass too early when they think they are ahead.' },
  glassjaw: { name: 'Glass Jaw', kind: 'weakness', desc: 'Your Pounces deal double damage to them.' },
  dread_ember: { name: 'Fears Fire', kind: 'weakness', desc: 'Your Ember units get +2 against them.' },
  dread_tide: { name: 'Fears Water', kind: 'weakness', desc: 'Your Tide units get +2 against them.' },
  dread_gilt: { name: 'Fears Gold', kind: 'weakness', desc: 'Your Gilt units get +2 against them.' },
  sluggish: { name: 'Sluggish', kind: 'weakness', desc: 'They draw 1 fewer card.' },
  lazy: { name: 'Lazy', kind: 'weakness', desc: 'Their first unit each round is played at -2.' },
};

export const STRENGTHS = (Object.keys(TRAITS) as TraitId[]).filter(
  (t) => TRAITS[t].kind === 'strength' && t !== 'grudge',
);
export const WEAKNESSES = (Object.keys(TRAITS) as TraitId[]).filter((t) => TRAITS[t].kind === 'weakness');

/** Pairs that cannot coexist on one nemesis. */
export const CONFLICTS: [TraitId, TraitId][] = [
  ['rainsoaked', 'hydrophobic'],
  ['hoarder', 'sluggish'],
  ['thickfur', 'glassjaw'],
  ['thickfur', 'superstitious'],
  ['dread_ember', 'dread_tide'],
  ['dread_ember', 'dread_gilt'],
  ['dread_tide', 'dread_gilt'],
];

export function conflicts(a: TraitId, list: TraitId[]): boolean {
  return list.some((b) => b === a || CONFLICTS.some(([x, y]) => (x === a && y === b) || (x === b && y === a)));
}

/** Apply nemesis traits to a side's mods. `defeatsOfPlayer` powers the Grudge trait. */
export function applyTraits(m: SideMods, traits: TraitId[], defeatsOfPlayer: number): SideMods {
  for (const t of traits) {
    switch (t) {
      case 'thickfur':
        m.thickfur = true;
        m.source.thickfur = t;
        break;
      case 'rainsoaked':
        m.weatherImmune = true;
        m.source.weatherImmune = t;
        break;
      case 'warlord':
        m.vanguardBonus += 1;
        m.source.vanguardBonus = t;
        break;
      case 'archmage':
        m.arcaneBonus += 1;
        m.source.arcaneBonus = t;
        break;
      case 'hoarder':
        m.extraDraw += 1;
        m.source.extraDraw = t;
        break;
      case 'sluggish':
        m.extraDraw -= 1;
        m.source.extraDraw = t;
        break;
      case 'vengeful':
        m.vengeful = true;
        m.source.vengeful = t;
        break;
      case 'bodyguard':
        m.bodyguard = true;
        m.source.bodyguard = t;
        break;
      case 'grudge':
        m.firstUnitBonus += Math.min(6, 2 * Math.max(1, defeatsOfPlayer));
        m.source.firstUnitBonus = t;
        break;
      case 'lazy':
        m.firstUnitBonus -= 2;
        m.source.firstUnitBonus = t;
        break;
      case 'secondwind':
        m.secondWind = true;
        m.source.secondWind = t;
        break;
      case 'hydrophobic':
        m.weatherZero = true;
        m.source.weatherZero = t;
        break;
      case 'superstitious':
        m.hexVuln += 2;
        m.source.hexVuln = t;
        break;
      case 'arrogant':
        m.arrogant = true;
        m.source.arrogant = t;
        break;
      case 'glassjaw':
        m.pounceVuln = true;
        m.source.pounceVuln = t;
        break;
      case 'dread_ember':
      case 'dread_tide':
      case 'dread_gilt':
        m.dread = t.slice(6) as Coat;
        m.source.dread = t;
        break;
      case 'ninelives':
        break;
    }
  }
  return m;
}
