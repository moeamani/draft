export type Row = 'vanguard' | 'arcane';
export type CardType = 'physical' | 'magic';
export type Coat = 'ember' | 'tide' | 'gilt' | 'shadow';
export type Rarity = 'common' | 'rare' | 'epic' | 'legendary';

export type AbilityId =
  | 'none'
  | 'smite'
  | 'inspire'
  | 'hex'
  | 'litter'
  | 'pounce'
  | 'ninelives'
  | 'stray'
  | 'groom'
  | 'purr'
  | 'yowl'
  | 'muster'
  // specials
  | 'downpour'
  | 'moonfog'
  | 'sunbeam'
  | 'warhorn'
  | 'box'
  | 'hairball';

export interface CardDef {
  id: string;
  name: string;
  kind: 'unit' | 'special';
  type?: CardType;
  power: number;
  ability: AbilityId;
  rarity: Rarity;
  coat: Coat | 'none';
  flavor: string;
  /** Token cards never appear in drafts or shops. */
  token?: boolean;
  /** Signature card generated from a nemesis. */
  signature?: { nemesisId: string };
  /** Seed override for the portrait generator. */
  artSeed?: number;
  /** Extra portrait decorations (scars, crown) for signature cards. */
  scars?: number;
}

/** A card the player (or an enemy) owns. Level/xp make cats grow over a run. */
export interface CardInst {
  uid: string;
  id: string;
  level: number;
  xp: number;
  /** Inline definition for dynamic cards (nemesis signatures). */
  def?: CardDef;
}

export const ROWS: Row[] = ['vanguard', 'arcane'];

export const rowOf = (t: CardType | undefined): Row => (t === 'magic' ? 'arcane' : 'vanguard');
