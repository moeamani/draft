# Draft: design notes

## Art direction

- **Full pixel art.** Everything is drawn in a 640x360 virtual pixel space, rendered at 2x with nearest filtering, then post-processed.
- **One palette**, taken from the Figma file: `#0e2119` ink, `#e8483b` red, `#2378f7` blue, `#d3a200` gold, `#47e7fd` cyan and `#f4f1e8` paper (`src/ui/theme.lua`).
- **One type scale** with three OFL pixel fonts:
  - Jacquard 12, a pixel blackletter, for titles and names.
  - Tiny5 for UI text.
  - Jersey 10 for numbers and buttons.
- **One panel style** and **one button style** (`src/ui/gfx.lua`, `src/ui/widgets.lua`):
  - Panels: 1px notched corners, a black outline, a 1px highlight and a drop shadow.
  - Buttons: the same box with a pressable lip.
- **Icons** are hand-placed ASCII pixel sprites (`src/ui/icons.lua`), baked per tint.
- **Cat portraits** are procedural. They're drawn with primitives and ordered-dithered to the palette at their final pixel size (`src/ui/art.lua`).
- **Figma vectors** (the logo, mascot, shadow creature and badge) are *baked* to crisp palette pixels at load (`art.bake`).
- **CRT** (`src/ui/shaders.lua`): subtle barrel curve, one scanline per virtual pixel row, slight RGB split, bloom, vignette and grain. F2 cycles subtle / flat / off.

## The match: Formations

Each exchange:

1. You hold 8 cards. Select up to 5. **Redraw** twice per exchange, tossing up to 5 selected cards.
2. Your rival commits face-down. You can see how many cards they're playing.
3. Both reveal. Each side's best **Formation** among its selected cats scores: `(formation Paws + each scoring cat's Paws + bonuses) x (formation Cheer + bonuses)`.
4. The higher score wins the exchange. The loser loses `16 + 32 x (1 - lower/higher)` Pride, clamped to 16–48. Matches start at 100 Pride.

| Formation | Needs | Paws x Cheer |
| --- | --- | --- |
| Lone Paw | 1 cat | 5 x 1 |
| Duet | 2 of a coat | 10 x 2 |
| Vanguard | 3–5 Physical | 15 x 2 |
| Conclave | 3–5 Magic | 15 x 2 |
| Litter | 3 of a coat | 25 x 3 |
| Charge | 3 cats rising one Paw at a time | 30 x 3 |
| Coven | 3–5 Black Cats | 30 x 4 |
| Round Table | one of each coat | 40 x 4 |
| Pride | 4 of a coat | 45 x 4 |
| Grand Charge | 5 rising | 60 x 5 |
| Full Pride | 5 of a coat | 60 x 6 |

**Coats**: Ember beats Gilt, Gilt beats Tide, and Tide beats Ember. If your Formation's coat beats theirs, you get +2 Cheer.

**Abilities** trigger when a cat scores:
- Sword Hammer: x2 Cheer.
- Aural Orb: +2 Cheer for each other Magic cat.
- Black Cat: the rival loses 6 Paws.
- Litter: +6 Paws for each other cat of the same coat.
- Pounce: +12 Paws on coat advantage.
- Groom: heals.
- Purr: Paws for each scored cat.
- War Yowl: your strongest other cat scores again.
- Call the Pride: Cheer for each copy of this cat in your deck.
- Nine Lives: the cat returns to your hand.
- Stray: you draw extra next exchange.

**Tricks** are played alongside your cats and bend the scoring:
- Sunbeam: +3 Cheer.
- Rallying Yowl: x1.5 Cheer.
- Downpour: the rival loses Cheer.
- Moonfog: the rival's best cat doesn't score.
- Hairball: the rival's Cheer is halved.
- Cardboard Box: one of your cats counts as any coat.

**Charms** (up to 5) are festival favours that change the rules, for example the Tally Stick, Round Seal, Lucky Tail and Witch's Candle.

The UI animates the engine's step-by-step scoring breakdown (`match.evaluate` and `cross` record every step), so the numbers you watch count up are exactly what the engine computed.

## The festival

- 16 entrants. The Four Hands seed groups A–D. You're in group D with the Fourth Hand, and you meet them in round 3.
- Round-robin groups: 3 points per win, with Pride difference as the tie-breaker. The top 2 go to the knockout: A1-B2, C1-D2, B1-A2, D1-C2.
- Matches between other entrants are simulated by rating. Upsets show up in the hub ticker.
- Rival strength rises with the stage: stray card levels, extra Pride in knockouts, and Hands get Pride per level.

## The Four Hands (nemesis system)

- **Persistent.** Each Hand keeps a name, epithet, coat, personality (which drives the AI style), level, scars, a win/loss record against you, and history.
- **Traits** (10 strengths and 9 weaknesses) start hidden. You can learn them in several ways:
  - They reveal themselves when they fire mid-match.
  - Strays you beat squeal one.
  - The Fortune Teller's rat informant sells two.
  - The Spyglass charm reveals one.
  - Some are visible on sight (Arrogant, Bodyguard, Hoarder).
- **When a Hand beats you**, they gain a level and a Grudge, and train a new strength between festivals.
- **When you beat a Hand**, you choose their fate:
  - **Slay**: they forfeit the festival, and may return "the Returned".
  - **Recruit**: only after a flawless match. They join your deck as a Legendary, and may betray you next festival.
  - **Brand**: they get a weakness and a grudge.
- **Between festivals**:
  - The champion climbs the hierarchy. A stray champion takes the lowest seat.
  - A stray that knocks you out may be promoted.
  - The Hands hold power struggles.
  - Dialogue reacts to your shared history.

## Balance snapshot

`luajit tests/run.lua` plays 90 festivals with the AI choosing for you. It takes the first reward and never shops:

- about 63% of matches won, about 50% against Hands, and about 5.7 exchanges per match.
- About 17% of festivals won: roughly 1/3 out in the groups, 1/5 quarter-finalists, 1/5 semi-finalists, and the rest finalists.

Tuning knobs:
- Damage: `match.damageFor`.
- Pride: `match.PRIDE`.
- Stage scaling: `game.setupMatch`.
- Formation values: `formations.LIST`.
- Reward quality: `game.RARITY_WEIGHTS`.
- Stray ratings: `festival.create`.

## From the Figma file

| Figma | In game |
| --- | --- |
| "Draft" wordmark and tagline | title and victory screens (baked to pixels) |
| Red/blue cat mascot | title background, window icon |
| Shadow creature with flames | defeat summary |
| "In development" badge | title screen |
| Card sheet (Artheline, Merline, the Black Cats) | the first entries in `src/core/cards.lua` |

## Ideas for later

- Formation levels earned from festival trophies.
- More tricks and charms.
- Duo formations that need specific named cats.
- Hand-drawn card art to replace the procedural cats. Swap `art.card`.
- Music beyond the generated ambient loop.
