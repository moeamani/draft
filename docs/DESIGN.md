# Draft: design notes

## Art direction

Everything follows the Figma file (the title frames and the "title cards" of the card sheet), so
every screen uses the same handful of parts:

- **One dither.** Figma's Dither effect is Bayer 16x16 at 8 levels per channel, with 2px cells.
  - It is ported as `fdither` in `src/ui/shaders.lua`, at one cell per virtual pixel (2 screen pixels, as in Figma).
  - Every surface goes through it: the backdrop, plates, title cards, serif text, card faces and backs, portraits, and the Figma art.
  - That gives one consistent dot texture on every flat colour.
- **Title cards** (`src/ui/plates.lua`):
  - A palette plate with a white Ancizar Serif label.
  - Featured cards add the mascot silhouette run through a port of Figma's **Lens distortion** effect (anamorphic chromatic mode). That paints the cyan, pink and white streaks of the "Ability" card, or the full spectrum of the black "Power" card.
  - They're used for screen titles, panel headers, the HUD, banners, plaques and stalls.
- **Plates.** Panels, buttons, cushions and the bars on a card face are dithered palette plates with a 1px outline. Buttons carry serif labels that shrink to fit.
- **Two type families.**
  - Ancizar Serif (static Regular and Italic) for display type. It is always baked and dithered, like the Figma cards.
  - Jersey 10/15/20/25 at their native pixel sizes for everything you need to read.
- **One palette** from Figma: `#0e2119` ink, `#e8483b` red, `#2471fc` / `#2378f7` blue, `#d3a200` gold, `#47e7fd` cyan and `#f4f1e8` cream, plus black for the Power plate.
- **The logo** is the two-tone Figma lockup: a red "D" and cream "raft", with the red cat, and the tagline "Four Hands." in cream with *One Arena* in red italic. The title screen is the Figma title frame.
- **Cat illustrations** (`src/ui/art.lua`) are bust portraits painted with plain primitives in three layers:
  - **Backdrop** by coat: an Ember hall with pennants and embers, a rainy Tide shore, a Gilt sunburst over a castle, a Shadow night with the moon. The Hands get blood red and flames.
  - **Figure**: outfit (plate, mail, tunic, robe, rags, apron, cape with ermine), ears, a two-tone shaded head, a fur pattern (tabby, tuxedo, points, patches, smoke, fluff), the face, headwear and props. It gets a 1px dark outline. Dark cats also get a moonlit rim.
  - **Glow**: whiskers, orbs, candle flames, sparkles, notes and runes, drawn after the outline.
  - Everything is painted at 2x, box-filtered down and run through the Figma dither, so it matches the title cards.
  - `SPEC` gives the named cats their signature looks: Artheline's crown and Sword Hammer, Merline's hat and orb, the Alley Stray's eyepatch and fishbone. Other cats are dressed by their type, ability, rarity and seed. Litter cats bring kittens, Purr cats hum notes and Hex cats trail runes.
  - Tricks get small scenes: the storm, the fog with eyes, the cat asleep in the sunbeam, the box with ears.
  - Card faces show the art at 50x48. The inspect panel, tooltips and the Cattery show it at 100x96.
- **Card faces**: the rarity frame, the illustration, the name on its coat's colour (so the coat reads at a glance), the ability, and a sword or orb badge for the type.
- **Card backs** are small title cards:
  - Ember, Tide and Gilt use their coat's plate with the mascot smear.
  - Shadow cats and tricks share the black Power plate with its spectrum smear.
- **The backdrop** (`stage` shader) is dithered ink green with a soft, static pool of light.
  - The match and the VS screen add a table top in perspective, with the rival looming beyond it.
  - Hand matches and defeats use the blood-red stage.
- **No shimmer.** Nothing animates the dither:
  - The light never moves.
  - Resting cards draw 1:1 on whole pixels, with no idle wobble, tilt or foil.
  - Cards are only drawn scaled or rotated while dealing, flipping or moving fast.
  - The CRT filter is optional (F2) and off by default.

### Without shaders (Switch)

LÖVE Potion can't compile GLSL, so `src/platform.lua` switches to a shader-free path that keeps the same look:

- The backdrops and the mascot smears are baked to PNG by `tools/switch/bake_assets.py`, a numpy port of the `stage` and `smear` shaders. It reads the presets, ramps and tints from `src/ui/bakes.lua`, so the game and the baker share one source.
- Plates and title cards get a 16x16 Bayer dot tile in place of the `fdither` pass.
- Nothing uses custom meshes. Gradients are 1px rows, glows are stacked circles, and moving cards are drawn scaled and rotated.

See [SWITCH.md](SWITCH.md).

### Readable type

| Role | Font | Size |
| --- | --- | --- |
| Titles, names, buttons (baked and dithered) | Ancizar Serif | 13–34 px |
| Anything you need to read (rules, card text, logs) | Jersey 15 | 15 px |
| Numbers | Jersey 20 / 25 | 20 / 25 px |
| Names on cards, chips, short labels | Jersey 10 | 10 px |

The match has an **inspect panel** on the right in place of tiny tooltips. Hover any card and its full text appears there in Jersey 15. With nothing hovered, it explains the current bout.

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

**Bonds** are 22 pairs from the old stories, listed in `cards.BONDS`. Side by side on your cushions, each cat gets +2 Paws, and a gold link shows it. Rivals' cats bond too. In the simulation both sides get bonds about equally often (254 against 274 in 1,551 bouts).

**Cushions** can be upholstered at the market, one offer per visit for 30 fish. The upgrade lasts the whole festival:

| Cushion | Effect |
| --- | --- |
| Velvet | the cat on it gets +1 Paw |
| Thistle | the rival cat facing it loses 1 Paw |
| Silk | you win ties on it (after the Lucky Tail, before Steadfast) |

The Hands upholster their own cushions as they rise: one at level 5, two at level 7.

**Omens**: every festival has one rule twist, matching its name (`festival.OMENS`):

| Festival | Omen |
| --- | --- |
| Midsummer Festival of Claws | Ember cats +1 |
| Harvest Moot | Gilt cats +1 |
| Feast of Nine Lives | everyone holds 6 cards |
| Winter Yowl | the coat edge is +4 |
| Tourney of the Gilded Saucer | everyone starts with 1 more goblet |
| Moonlit Mews | Shadow cats +1 |
| Spring Tide Regatta | Tide cats +1 |
| Festival of Long Naps | ties go to the side that answers |

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

## The Cattery

A collection that lasts across festivals (`save.seen`). Every cat you own, and every rival card you see face up, is recorded. The Cattery (from the title screen or the pause menu) shows all 43 cards in a grid, with `?` for the ones not found yet. Hover one to see its big illustration, Paws, coat, ability, bonds (marked when the partner isn't found yet) and flavour text.

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

`luajit tests/run.lua` plays 90 festivals with the AI choosing for you. It takes the first reward and never shops, so it never upholsters a cushion:

- About 58–62% of matches won, about 44–47% against Hands, and about 4.2 bouts per match. The range covers two seed sets. The sim is chaotic, so single-seed numbers move by about ±5% with any change.
- About 11–17% of festivals won, and about a third of festivals end in the groups.

Tuning knobs:
- Goblets per side: `match.GOBLETS`.
- Coat edge: `match.COAT_EDGE`.
- Hex strength: `compute` in `src/core/match.lua`.
- Stage scaling (hand size, extra goblets): `game.setupMatch`. Hands get one extra goblet per 5 levels.
- Bond strength: `cards.BOND_PAWS`. Cushion price and the Hands' cushions: `game.CUSHION_PRICE`, `game.handCushions`.
- Card Paws: `src/core/cards.lua`.
- Reward quality: `game.RARITY_WEIGHTS`.
- Stray ratings: `festival.create`.

## From the Figma file

| Figma | In game |
| --- | --- |
| Title frame: two-tone "Draft" lockup and tagline | title screen, victory summary (`assets/img/logo.png`) |
| Title cards: Card Name, Type, Ability, Power, Rarity | `plates.titleCard`, used for every heading, banner, plaque, stall and card back |
| Dither effect (Bayer 16x16, 8 levels, 2px) | `fdither` shader, applied to every surface |
| Lens distortion effect (anamorphic, chromatic) | `smear` shader: title-card streaks, card backs, the VS portrait |
| Red/blue cat mascot | window icon; its silhouette drives the smear (`assets/img/mascot-silhouette.png`) |
| Shadow creature with flames | defeat summary |
| Card sheet (Artheline, Merline, the Black Cats) | the first entries in `src/core/cards.lua`, with signature looks in `art.lua` |

## Ideas for later

- Trick cards that move between cushions after the reveal.
- Bond quests: a market or event that offers the missing partner of a cat you own.
- Cattery rewards: unlock a starting cat or a cosmetic backdrop for finding every bond.
- Music beyond the generated ambient loop.
