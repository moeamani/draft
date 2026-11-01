import type { SideMods } from './traits';

export type CharmId =
  | 'cream'
  | 'collar'
  | 'cloak'
  | 'bell'
  | 'fishbone'
  | 'banner_ember'
  | 'banner_tide'
  | 'banner_gilt'
  | 'whetstone'
  | 'crown'
  | 'yarn'
  | 'spyglass'
  | 'catnip';

export interface CharmInfo {
  name: string;
  icon: string;
  desc: string;
  price: number;
}

export const MAX_CHARMS = 5;

export const CHARMS: Record<CharmId, CharmInfo> = {
  cream: { name: 'Saucer of Cream', icon: '◒', desc: 'Your first unit each round gets +2.', price: 45 },
  collar: { name: 'Lucky Collar', icon: '☾', desc: 'Your Hexes deal +1 damage.', price: 40 },
  cloak: { name: 'Oiled Cloak', icon: '☂', desc: 'Weather drops your units to 2 instead of 1.', price: 40 },
  bell: { name: 'Brass Bell', icon: '♫', desc: 'Draw 1 extra card at the start of every duel.', price: 60 },
  fishbone: { name: 'Fishbone Charm', icon: '⋔', desc: '+8 fish after every victory.', price: 35 },
  banner_ember: { name: 'Ember Banner', icon: '⚑', desc: 'Your Ember units get +1.', price: 45 },
  banner_tide: { name: 'Tide Banner', icon: '⚑', desc: 'Your Tide units get +1.', price: 45 },
  banner_gilt: { name: 'Gilt Banner', icon: '⚑', desc: 'Your Gilt units get +1.', price: 45 },
  whetstone: { name: 'Whetstone', icon: '◆', desc: 'Your Pounces deal +2 damage.', price: 35 },
  crown: { name: 'Paper Crown', icon: '♛', desc: 'Your Legendary units get +2.', price: 50 },
  yarn: { name: 'Ball of Yarn', icon: '●', desc: "The enemy's first unit each round is distracted: -2.", price: 45 },
  spyglass: { name: 'Spyglass', icon: '⌕', desc: 'Reveal a hidden trait of every Warlord you face.', price: 40 },
  catnip: { name: 'Catnip Pouch', icon: '✿', desc: 'If you lose a round, draw 2 cards.', price: 50 },
};

export function applyCharms(me: SideMods, enemy: SideMods, charms: CharmId[]): void {
  for (const c of charms) {
    switch (c) {
      case 'cream':
        me.firstUnitBonus += 2;
        break;
      case 'collar':
        me.hexBonus += 1;
        break;
      case 'cloak':
        me.weatherFloor = 2;
        break;
      case 'bell':
        me.extraDraw += 1;
        break;
      case 'banner_ember':
        me.coatBonus.ember = (me.coatBonus.ember ?? 0) + 1;
        break;
      case 'banner_tide':
        me.coatBonus.tide = (me.coatBonus.tide ?? 0) + 1;
        break;
      case 'banner_gilt':
        me.coatBonus.gilt = (me.coatBonus.gilt ?? 0) + 1;
        break;
      case 'whetstone':
        me.pounceBonus += 2;
        break;
      case 'crown':
        me.legendBonus += 2;
        break;
      case 'yarn':
        enemy.firstUnitBonus -= 2;
        break;
      case 'catnip':
        me.secondWind = true;
        break;
      case 'fishbone':
      case 'spyglass':
        break;
    }
  }
}
