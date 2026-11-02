# Draft: design notes

## Art direction

One look everywhere: **a candle-lit card table in a dark room**, drawn in Draft's own pixel art and palette.

- **Full pixel art.** Everything is drawn in a 640x360 virtual pixel space, rendered at 2x with nearest filtering.
- **One palette**, taken from the Figma file:
  - `#0e2119` ink, `#e8483b` red, `#2378f7` blue, `#d3a200` gold, `#47e7fd` cyan and `#f4f1e8` paper (`src/ui/theme.lua`).
  - The table adds a walnut rim and a candle tone. Hand matches and defeats swap the green baize for blood red.
- **One backdrop** (`table` shader in `src/ui/shaders.lua`) behind every scene:
  - A dark room, a green baize table and one flickering candle.
  - Light is worked out per virtual pixel and quantised with ordered dithering, so it has the same chunky grain as the art.
  - The match, VS and title screens tilt the table into perspective, so the rival (or the mascot) looms in the dark beyond its far edge. Menus look straight down at the table top.
- **The rival is a presence, not a panel.** In a match their portrait is a cut-out silhouette in the darkness, with glowing eyes that blink.
- **Diegetic state on the table**:
  - Goblets stand on each side. Swats knock them off with a crash and a splash.
  - Three velvet cushions per side hold the cards.
  - Draw piles sit on the table.
  - Taunts and fortunes are parchment notes.
- **Screen pass**: "lamplight" by default, a soft vignette and film grain with no blur, so text stays crisp. F2 switches to CRT (scanlines, slight curve) or plain.

### Readable type

Every font is drawn **at the size it was designed for**, so letters sit on the art's pixel grid. Nothing is blown up 2x or 3x.

| Role | Font | Size |
| --- | --- | --- |
| Anything you need to read (rules, card text, logs) | Jersey 15 | 15 px |
| Buttons, names, numbers | Jersey 20 | 20 px |
| Headline numbers | Jersey 25 | 25 px |
| Names on cards, chips | Jersey 10 | 10 px |
| Screen titles, champion names | Jacquard 24 | 24 px |
| Short all-caps labels only | Tiny5 | 8 px |

Secondary text uses `paper2`/`muted`, both lifted for contrast against the dark baize. The match has an **inspect panel** on the right in place of tiny tooltips. Hover any card and its full text appears there in Jersey 15. With nothing hovered, it explains the current bout.

## The match: three cushions

Each **bout**:

1. Both sides draw back up to 5 cards.
2. One side **leads**: it places up to 3 cards face-down on its cushions. The rival leads the first bout, and the lead alternates.
3. The other side **answers**, seeing only the backs:
   - Ember, Tide and Gilt cats have coloured backs.
   - **Shadow cats and tricks share the same dark back**, so you can bluff.
4. Everything flips over, and the cards on facing cushions **duel**:
   - **Paws** decide it.
   - The **coat edge** (Ember > Gilt > Tide > Ember) is +3 Paws. Shadow has no edge either way.
   - **Ties go to the leader**. Steadfast cats and the Lucky Tail win ties anyway.
5. The winning cat **swats a goblet** off the loser's side. A cat facing an empty cushion or a trick walks in **unopposed** and swats too.
6. Knock off all of the rival's goblets (7 each by default) to win. After 12 bouts, whoever has more goblets standing wins.

The decisions are:

- which cards to commit and which to hold back;
- where to put them, since some abilities depend on neighbours;
- how to read and answer the rival's backs;
- how to lead when the rival will be reading yours.

**Abilities** work while the cat sits on a cushion:

| Ability | Effect |
| --- | --- |
| Steadfast | wins ties |
| Sword Hammer | swats 2 goblets |
| Aural Orb | your other Magic cats get +2 |
| Black Cat | the cat facing it loses 2 |
| Litter | +2 per other cat of its coat |
| Pounce | +3 more with the coat edge |
| Nine Lives | returns to hand once per match |
| Stray | unopposed, swats 2 |
| Groom | its swats set one of your goblets back up |
| Purr | the cats beside it get +2 |
| War Yowl | every rival cat loses 1 |
| Call the Pride | +1 per copy in your pride |

**Tricks** sit on a cushion but never duel, so the cat facing one walks in unopposed unless the trick stops it:

| Trick | Effect |
| --- | --- |
| Sunbeam | the facing cat naps |
| Hairball | the facing cat is disgusted and won't fight, and its neighbours lose 2 |
| Cardboard Box | the one trick that fights: a 4-Paw cat with whichever coat beats the cat facing it |
| Downpour | every rival cat loses 2 |
| Moonfog | the rival's strongest cat gets lost and doesn't fight |
| Rallying Yowl | your other cats get +3 |

**Charms** (up to 5) bend the table rules. For example:

- Festival Drum: +1 Paw when you lead.
- Catnip Pouch: +1 Paw when you answer.
- Round Seal: three different coats give +2 each.
- Spyglass: peek at a card when the rival leads.
- Ball of Yarn: the rival's left cat loses 2.

The engine (`match.compute`) records every modifier on every card. The UI replays those numbers, so the floating "+3 Coat edge" and "-2 Hexed" texts are exactly what decided each duel.

### The AI

- **Leading**, it scores every placement of its hand against unknown "phantom" cards built from your deck's average Paws. It slightly prefers dark backs, which give nothing away.
- **Answering**, it sees only your backs, the same information you get. Each back becomes a phantom of that coat with your average Paws for it.
- Duels against phantoms count as probabilities. Personality sets the noise, how much it hoards strong cats, and how much it fears losing goblets.
- `match.suggest` is the same search for the player's side. The autotest and the balance simulation use it.

## The festival

- 16 entrants. The Four Hands seed groups A–D. You're in group D with the Fourth Hand, and you meet them in round 3.
- Round-robin groups: 3 points per win, with goblet difference as the tie-breaker. The top 2 go to the knockout: A1-B2, C1-D2, B1-A2, D1-C2.
- Matches between other entrants are simulated by rating. Upsets show up in the hub ticker.
- Rival strength rises with the stage:
  - Early strays hold one card fewer and start a goblet down.
  - Later rivals bring levelled cards.
  - Semi-final and final rivals get an extra goblet. High-level Hands do too.

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
  - **Recruit**: only if you never lost a bout. They join your deck as a Legendary, and may betray you next festival.
  - **Brand**: they get a weakness and a grudge.
- **Between festivals**:
  - The champion climbs the hierarchy. A stray champion takes the lowest seat.
  - A stray that knocks you out may be promoted.
  - The Hands hold power struggles.
  - Dialogue reacts to your shared history.

## Balance snapshot

`luajit tests/run.lua` plays 90 festivals with the AI choosing for you. It takes the first reward and never shops:

- About 64% of matches won, about 52% against Hands, and about 4.2 bouts per match.
- About 14% of festivals won: roughly 1/3 out in the groups, 3/10 quarter-finalists, 1/6 semi-finalists, and the rest finalists.

Tuning knobs:
- Goblets per side: `match.GOBLETS`.
- Coat edge: `match.COAT_EDGE`.
- Hex strength: `compute` in `src/core/match.lua`.
- Stage scaling (hand size, extra goblets): `game.setupMatch`.
- Card Paws: `src/core/cards.lua`.
- Reward quality: `game.RARITY_WEIGHTS`.
- Stray ratings: `festival.create`.

## From the Figma file

| Figma | In game |
| --- | --- |
| "Draft" wordmark and tagline | title and victory screens (baked to pixels) |
| Red/blue cat mascot | looms over the table on the title screen; window icon |
| Shadow creature with flames | defeat summary |
| "In development" badge | title screen |
| Card sheet (Artheline, Merline, the Black Cats) | the first entries in `src/core/cards.lua` |

## Ideas for later

- Cushion upgrades bought at the market (a velvet cushion that gives +1 to whatever sits on it).
- Trick cards that move between cushions after the reveal.
- Duo bonuses for specific named cats sitting side by side.
- Hand-drawn card art to replace the procedural cats. Swap `art.card`.
- Music beyond the generated ambient loop.
