# Draft: design notes

## Art direction

The references are clean pixel art: crisp clusters, bold dark outlines, limited hue-shifted
palettes, no noise. Every screen follows that, with the Figma file's palette, logo and title cards:

- **Pixel art at its real size.** Cats, cards, plates and icons are drawn at their true pixel size
  on a 640x360 grid, with no anti-aliasing, dither or blur. Bigger views (the inspect panel, the
  Cattery, portraits) are exact 2x or 3x enlargements, so pixels stay square and crisp.
- **One dithered surface.** Only the backdrop (`stage` in `src/ui/shaders.lua`) keeps the Figma
  Dither effect (Bayer 16x16, 8 levels per channel). Everything on top of it is flat. On the menus
  and the VS screen the backdrop carries a slow paint **swirl** (a spiral folded twice, drifting
  with time) in the room's own greens; the dither turns it into moving pixel bands. The match
  table stays still.
- **Plates** (`src/ui/plates.lua`) are flat palette fills with a 1px dark outline, notched corners
  and a 1px bevel. Panels, buttons, cushions and card plates all use them.
- **Title cards** (the Figma "Card Name / Ability / Power" plates) are plates with the mascot's
  chromatic smear on one end as an accent, and a live serif label.
- **Cat illustrations** (`src/ui/art.lua`) are bust portraits in three layers:
  - **Backdrop** by coat, in three flat bands: an Ember hall with pennants and embers, a rainy
    Tide shore, a Gilt sunburst over a castle, a Shadow night with the moon. The Hands get blood red
    and flames.
  - **Figure**: outfit (plate, mail, tunic, robe, rags, apron, cape with ermine), ears, a two-tone
    head, a fur pattern (tabby, tuxedo, points, patches, smoke, fluff), headwear and props. Stray
    single pixels are cleaned up, then the face is stamped in pixel by pixel (eyes per expression:
    calm, wide, smug, fierce, happy, menace; nose, mouth, fangs, tongue), and the figure gets a 1px
    outline. Shadow cats and the Hands get a coloured rim outside it, like moonlight.
  - **Glow**: whiskers, orbs, flames, sparkles, notes and runes, with no outline.
  - `SPEC` gives the named cats their signature looks: Artheline's crown and Sword Hammer,
    Merline's hat and orb, the Alley Stray's eyepatch and fishbone. The rest are dressed by type,
    ability, rarity and seed.
  - Tricks are small scenes: the storm, the fog with eyes, the cat asleep in the sunbeam, the box
    with ears.
- **Card faces**: the rarity frame, the 50x48 illustration, the name on its coat's colour, the
  ability, a type badge and the cat's hearts. Names, abilities and Paws are live text.
- **The menu** is a festival night: bunting, your champion facing the Four Hands, and the logo.

### The CRT screen

The finished frame goes to the window through a CRT pass (`crt` in `src/ui/shaders.lua`), on by
default and switched off in Settings or with F2:

- barrel curvature (`CRT_CURVE` in `main.lua`, 0.07), with the mouse warped through the same curve
  (`shaders.warp`) so clicks land where the pointer looks;
- one scanline per virtual pixel row, so the scanlines line up with the pixel art at any size;
- a soft bloom on bright pixels, a chromatic fringe that grows towards the edges, a vignette and a
  little grain.

Without shaders (LÖVE Potion) there's no CRT and no swirl.

### Juice

- **Feat medals** slide in at the top right, one at a time, with a shine sweep (`fx.medal`). They
  survive scene changes, so a feat earned on the last swat still shows on the result screen.
- **Hit-stop**: a capture freezes the table for 0.14s, a crushing win for 0.08s (`G.hitstop`), with
  a screen shake.
- **Number pops**: floating numbers punch in two sizes larger and settle in 0.14s.
- **Card shine**: a slanted band of light sweeps across a card the moment you point at it.
- The Hot Seat burns: a flickering ring of fire around the card and a flame Warmth badge.

### Readable type

Text is never pixel art. Fonts are rasterised at the screen's real resolution (K canvas pixels per
virtual pixel, set from the window), so type is sharp at any size and on Retina screens:

| Role | Font | Size (virtual px) |
| --- | --- | --- |
| Titles, plates, names on title cards | Ancizar Serif (the Figma font) | 13–34 |
| Anything you read: rules, card text, dialogue | Atkinson Hyperlegible | 10–11.5 |
| Buttons, numbers, labels | Atkinson Hyperlegible Bold | 7.5–18 |

Atkinson Hyperlegible was designed by the Braille Institute for low-vision readers. A body line is
20px tall at 720p and 30px at 1080p.

### Contrast (WCAG 2.x AA)

- Every text colour token passes 4.5:1 on every dark ground (deep, ink, ink2, ink3, night). Plate
  colours pass 4.5:1 with white labels (gold takes black). `tests/run.lua` checks all of it.
- `gfx.text` runs every colour through `theme.readable(fg, bg)`, which lightens (or darkens) a
  colour that misses 4.5:1 against its ground, so a stray red or blue label can't fail.

### The window

- The game is laid out on a 640x360 safe area. The visible area grows to fill any window shape:
  the backdrop covers the margin, so there are no black bars (on a 16:10 Mac it's 640x400).
- Everything is drawn into one canvas at K = ceil(scale) canvas pixels per virtual pixel, then shown
  at exactly the window's size. At whole scales (720p, 1080p, 1440p) it's pixel-perfect.
- Fullscreen is the desktop kind (F11, Alt+Enter, Ctrl+Cmd+F, or Settings) and is remembered.
- The old bug: the scale was snapped down to multiples of 0.5, so a 1440x900 screen showed the
  1280x720 game in the middle with black all round. The new layout has no snapping.

### Without shaders (Switch)

LÖVE Potion can't compile GLSL, so `src/platform.lua` switches the one shader-dependent surface, the
backdrop, to PNGs baked by `tools/switch/bake_assets.py`. Everything else is shader-free already.
The pixel cleanup pass reads canvases back; where that isn't possible it is skipped. The baked
backdrops have no swirl, and there's no CRT pass.

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

### Stolen Lives

The new core rule, and the nemesis system's teeth:

- Every cat brings **lives** (hearts) into a match: 2 for commons and rares, 3 for epics and
  legendaries (`cards.LIVES`, +1 with the Scruff Ribbon charm).
- The loser of a duel loses a life. A **crushing** loss, by `match.CRUSH` (5) Paws or more, costs
  two. Naps, fog and unopposed swats cost nothing. Nine Lives cats never lose lives.
- At 0 lives the winner **captures** the cat (`apply` in `src/core/match.lua`): it leaves the
  table, not to the discard pile, and is carried across.
- After the match (`game.settleLives`):
  - your captured cats leave your pride. A **Hand** keeps them (`n.captives`, up to 6) and fields
    them in its deck, a level higher, marked YOURS and down to 1 life. A **stray** pawns them:
    they turn up at the Mews Market for 15–50 fish.
  - beat one of your captives in a duel and it comes home. Beat the Hand and every captive comes
    home.
  - the rival cats you captured are your **spoils**: they head the reward offer after a win.
  - a pride never drops below 8: the Arena lends guards.
- The UI: hearts on every card (shown as they were until the duel takes them), "-1 life",
  "Crushed! -2 lives", "CAPTURED!" and "RESCUED!" as the cats change sides, a red **!** on a
  placed cat that could be captured, and the hub and Four Hands screens list who holds whom.
- The AI weighs the chance a cat on its last lives gets captured (`style.guard`).
- In the simulation you lose about 0.56 cats a match (half to Hands), capture about 1, and rescue
  about 0.1 a match.

### Hold the Cushion

The rule that makes every bout matter twice:

- A cat that **wins its duel stays seated** (face-up) instead of leaving the table, and gains a point
  of **Warmth**: +1 Paw per point, up to `match.WARMTH_MAX` (5). Losers, the unopposed, the
  sleeping, tricks and captured cats leave as before.
- At `match.HOT` (3) Warmth the cat is a **Hot Seat**: every swat knocks off one more goblet.
- A seated cat keeps its cushion: you fill only the empty ones. It's face-up, so the side that
  answers sees exactly what it faces, and can aim a coat edge or a crushing cat at it.
- **Pull back**: click a seated cat (or drop another card on it) to take it back into your hand. It
  loses its Warmth. Pulling back is free, so the question each bout is whether a warm cat is worth
  the risk of being crushed and captured.
- The AI enumerates every subset of its seated cats to pull back, times every placement on the free
  cushions, adding a keep bonus for Warmth and the capture risk (`choose` in `src/core/match.lua`).
- In the simulation you have about 1.5 cats seated per bout (the rival 1.2), a Hot Seat about
  every six bouts, and you pull back about one cat every two bouts.

### The AI

- **Leading**, it scores every placement of its hand against unknown "phantom" cards built from your deck's average Paws. It slightly prefers dark backs, which give nothing away.
- **Answering**, it sees only your backs, the same information you get. Each back becomes a phantom of that coat with your average Paws for it.
- Duels against phantoms count as probabilities. Personality sets the noise, how much it hoards strong cats, and how much it fears losing goblets.
- `match.suggest` is the same search for the player's side. The autotest and the balance simulation use it.

## Story mode: "Stray to Champion"

`src/core/story.lua` holds the chapters and the script; `src/scenes/story.lua` is the road map and
`src/scenes/cutscene.lua` plays the scenes (portrait, name plate, typed lines, Skip).

| Chapter | Festival | Omen | Goal |
| --- | --- | --- | --- |
| Prologue: The Bin Yard | practice match with Old Bedimew | | finish the tutorial, then name your cat |
| I: Midsummer | Midsummer Festival of Claws | Ember +1 | reach the knockouts |
| II: The Harvest Moot | Harvest Moot | Gilt +1 | defeat the Fourth Hand |
| III: The Winter Yowl | Winter Yowl | coat edge +4 | reach the semi-finals |
| IV: Moonlit Mews | Moonlit Mews | Shadow +1 | reach the final |
| V: The Gilded Saucer | Tourney of the Gilded Saucer | +1 goblet | win and dethrone the First Hand |

- The Hands' lines are spoken by whoever holds each rank when you play the chapter: the nemesis
  system keeps running between chapters, so the story's villains can change.
- Your pride, charms and the Hands' captives carry from chapter to chapter. Failing a chapter offers
  a retry with your pride as it was when the chapter began (the captives taken in the failed
  attempt go back too).
- Story and free festivals have separate saves (`story.lua`, `festival.lua`).

### The tutorial

`src/core/tutorial.lua` deals fixed hands for a 4-goblet match against Old Bedimew, who leads bout 1
with an Ember back, a Gilt back and a dark-backed Sunbeam. Thirteen lessons walk through coat
backs, the coat edge, placing (each step waits for the right card on the right cushion, with a
bouncing arrow), Charge, lives and capture (your Barn Brawler crushes his Squire Kitten), tricks,
holding the cushion (your winners stay seated with their Warmth), and leading. Charge is locked until the lesson asks for it; after the lessons the match plays out
normally.

## The Cattery

A collection that lasts across festivals (`save.seen`). Every cat you own, and every rival card you see face up, is recorded. The Cattery (from the title screen or the pause menu) shows all 43 cards in a grid, with `?` for the ones not found yet. Hover one to see its big illustration, Paws, coat, ability, bonds (marked when the partner isn't found yet) and flavour text.

## Renown, Feats and Crests

The progression that outlives every festival (`src/core/renown.lua`, saved on its own as
`renown.lua`, so resetting a story or festival save keeps it):

- **Renown** comes from every match, in both modes: 12 for a win (plus 4–10 in the knockouts, 8 for
  beating a Hand, 5 for a flawless match), 4 for a loss, 3 per cat captured, 4 per cat brought
  home, 2 per Hot Seat. A festival adds 10–50 by how far you got, and a story chapter 30. The
  result screen fills a Renown bar.
- **Levels** need 15·(L−1)·(L+2) Renown in total (60, 150, 270, 420, 600...). Each level gives a
  title, from Nameless Stray to Lord of Cushions.
- **25 Feats**, each earned once and worth 10–120 Renown, pop up as medals: at the table (Hot Seat,
  Throne Warmer, Clean Sweep, Flattened, Legend Napper, Cat Burglar, Untouchable, Last Goblet
  Standing, Blitz, Homecoming), at the festival (First Lesson, Hand Slayer, Kingslayer, Oathkeeper,
  Mercy, No Quarter, Fat Cat, Through the Gate, Finalist, Champion) and over a life (Collector,
  Dynasty, Colours, Stray No More, Living Legend).
- **Crests** unlock with levels and are picked when a Free Festival starts:

| Crest | Level | Start with |
| --- | --- | --- |
| Stray | 1 | the usual random pride |
| Ember, Tide, Gilt | 2, 3, 4 | two more cats of that coat and its Banner charm |
| Moon | 5 | two more Shadow cats and the Witch's Candle |
| Velvet | 6 | a Velvet middle cushion and a Saucer of Cream |
| Merchant | 7 | 40 more fish and the Fishbone Charm |
| Lion | 9 | an Epic cat at level 2 and the Scruff Ribbon |
| Royal | 12 | a Legendary cat and the Paper Crown |

- Pacing in the simulation: level 3 after the first festival, 4.3 after the second, 5.5 after the
  third. The Royal Crest takes about 14 festivals.
- The Renown screen (main menu) lists the level, lifetime stats, every feat and every crest.

## Crash safety

`love.update` and `love.draw` run under `xpcall` (`safely` in `main.lua`). An error inside a frame
is printed, appended to `crash.log` in the save folder (capped at 60 KB), the save is written, any
canvas, shader, scissor or overlay is reset, and the game returns to the menu with a message. Four
errors within three seconds fall through to LÖVE's error screen, so a broken menu can't loop.

The crash hunt behind round 6 used a strict emulator (every draw call checks its arguments: numbers,
polygon vertex counts, drawables) and a fuzzer that clicks recorded button rectangles, drags cards,
presses keys and controller buttons, types text and pushes the game through its main flow, across
thousands of frames per seed.

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

`luajit tests/run.lua` plays 90 festivals (30 players, 3 festivals each) with the AI choosing for
you. Each player earns Renown and starts each festival with their best unlocked Crest. It takes the
first reward (spoils first) and never shops, so it never upholsters a cushion or buys back a pawned
cat:

- About 67% of matches won, about 57% against Hands, and about 3.9 bouts per match.
- About 20% of festivals won; a quarter end in the groups.
- The sim is chaotic: any change moves single-seed numbers by about ±5%.

Tuning knobs:
- Goblets per side: `match.GOBLETS`. Coat edge: `match.COAT_EDGE`. Crushing margin: `match.CRUSH`.
- Warmth cap and the Hot Seat: `match.WARMTH_MAX`, `match.HOT`. AI noise per personality: `match.STYLES`.
- Renown per match, festival and feat, level curve and Crests: `src/core/renown.lua`.
- Lives: `cards.LIVES`. Captives a Hand keeps: `game.MAX_CAPTIVES`. Pawn prices: `game.PAWN_PRICE`.
- Hex strength: `compute` in `src/core/match.lua`.
- Stage scaling (hand size, extra goblets): `game.setupMatch`. Hands get one extra goblet per 4 levels.
- Bond strength: `cards.BOND_PAWS`. Cushion price and the Hands' cushions: `game.CUSHION_PRICE`, `game.handCushions`.
- Card Paws: `src/core/cards.lua`. Reward quality: `game.RARITY_WEIGHTS`. Stray ratings: `festival.create`.

## From the Figma file

| Figma | In game |
| --- | --- |
| Title frame: two-tone "Draft" lockup and tagline | main menu, victory summary (`assets/img/logo.png`) |
| Title cards: Card Name, Type, Ability, Power, Rarity | `plates.titleCard`, used for every heading, banner, plaque, stall and card back |
| Dither effect (Bayer 16x16, 8 levels, 2px) | the `stage` backdrop only |
| Lens distortion effect (anamorphic, chromatic) | baked once (`tools/switch/bake_assets.py`), drawn as the title-card and card-back accent |
| Red/blue cat mascot | window icon; its silhouette drives the smear (`assets/img/mascot-silhouette.png`) |
| Shadow creature with flames | defeat summary |
| Card sheet (Artheline, Merline, the Black Cats) | the first entries in `src/core/cards.lua`, with signature looks in `art.lua` |

## Ideas for later

- Trick cards that move between cushions after the reveal.
- Bond quests: a market or event that offers the missing partner of a cat you own.
- Cattery rewards: a Crest or a cosmetic backdrop for finding every bond.
- Stakes: harder festivals (the Hands start with more goblets) unlocked by winning, for more Renown.
- A ransom: pay fish to a Hand to buy back one captive between festivals.
- Music beyond the generated ambient loop.
