# Draft: design notes

## The design system

Version 1.0 was rebuilt around one idea: **Draft is a deck printed on the Overseer's press and seen
through a CRT.** Every screen is made from the same few parts, so nothing looks like it came from
a different game.

### One pixel grid

- Everything drawn (cats, cards, icons, plates, the Overseer, the backdrop) sits on a 640x360
  virtual grid and is only ever enlarged by whole numbers, so every pixel on screen is the same
  size. The Overseer is 320 pixels wide and is shown 1:1 (menu, High Table, credits) or doubled
  (cutscenes, the defeat screen); bigger cat portraits are exact 2x or 3x enlargements.
- Shading is flat fills and **halftone**: dots on a 45 degree lattice of pixels. The backdrop,
  the table, the card backs and the Overseer all use it, which is what ties the pixel art to the
  poster the Overseer came from.
- Text is the one thing not on the grid (by default): it is rasterised at the screen's real
  resolution, crisp type over chunky print, as on the poster.

### The backdrop (`src/ui/print.lua`, `shaders.paper`)

Dark ink-green paper (blood red for the Hands, the Overseer and defeats), one pool of light, darker
corners and film grain. For each virtual pixel the shader works out how much light falls on it and
then whether it lies inside a halftone dot of that size. The dots never move, only grow and shrink,
so the light can drift in a slow swirl (and swell in a ring where a goblet falls or a cat is
captured: `fx.addPulse`) without the print shimmering. Matches add a mustard table in perspective,
screened the same way. Without shaders the same maths is baked once in Lua and stands still.

### Plates (`src/ui/plates.lua`)

One shape for the whole interface: a flat fill with two pixels cut from each corner, an edge a
shade darker than the fill, a one-pixel highlight along the top, and optionally a **lip** (a darker
band along the bottom).

| Part | Made of |
| --- | --- |
| Panel | a plate in `ink` with a hard two-pixel shadow (`gfx.panel`) |
| Sign (names, stalls, banners, overlay titles) | a coloured plate with a two-pixel lip and a serif label (`plates.header`) |
| Button | a plate with a three-pixel lip; pressed, the face sinks into the lip (`widgets.button`) |
| Tab, chip, tag, slider knob, cushion, card plate | smaller plates |
| Ledger page, feat slip | a plate in cream stock, ruled, with ink text and rubber stamps |

Colours are roles (`theme.role`): `primary` red moves the game on and lives bottom-right; `secondary`
green is every other button; `info` blue is your side and overlay titles; `reward` gold is Renown
and fish; `danger` dark red is destructive. Spacing is on a 4-pixel grid with 8-pixel gutters.

### Type (`src/ui/theme.lua`)

Two families and nine sizes, and nothing else: asking for a size in between snaps to the nearest
step.

| Role | Face | Size |
| --- | --- | --- |
| display, title, heading | Ancizar Serif (the logo's family) | 30, 20, 14 (plus 12, 16, 24 for fitting) |
| body, small | Atkinson Hyperlegible | 10, 8.5 |
| bold, big, huge, label | Atkinson Hyperlegible Bold | 10, 13, 18, 7.5 caps |

Settings > Text switches to **pixel fonts** drawn on the art's grid instead (Fusion Pixel body
text, Coral Pixels bold, Jacquard 12 titles, Jersey 15 numbers, Micro 5 labels), each rasterised
at exactly its design size times the pixel scale, with baselines on whole pixels. The fonts and
their licences are in `assets/fonts` (see `CREDITS.txt`).

### Motion and feedback (`src/ui/fx.lua`, `main.lua`)

- **Iris**: scenes change through a closing and opening circle of ink with a thin fringe of cyan,
  white and pink on its edge, the teaser's orb in reverse.
- **Tags**: what happens to a card pops above it as a small tilted plate ("+3 Coat edge").
- **The scoring ladder**: when a bout is revealed, each modifier pops on its own beat, the Paws
  badge counts along, and a bell climbs the scale one step per event (`audio.note`). Goblets fall
  one after another, each with its own clink.
- **Hit-stop, shake, punch, pulse**: a capture freezes the table for 0.14s, shakes it, bursts the
  CRT's colour fringe (`fx.addPunch`) and sends a ring through the backdrop's dots.
- **Stamps**: a feat arrives as a slip torn from the ledger; a moment later a red rubber stamp
  slams onto it. Renown levels are stamped in blue.
- **Cards** float in your hand on their own phase (in whole screen pixels, so the art stays
  crisp), wobble and shine when picked out, lean when dragged, and bounce when they land.
- **Game speed** (1x, 1.5x, 2x) scales everything at the table; "Shake and motion" off stills the
  backdrop, the shake and the punch.

### The CRT screen (`shaders.crt`)

On by default (Options or F2): barrel curvature with the mouse warped through the same curve, one
scanline per virtual pixel row, a soft bloom, a chromatic fringe that grows towards the edges, a
vignette and a little grain.

### The intro (`src/scenes/intro.lua`)

The teaser, replayed by the game over the teaser's own music: a point of white light opens in the
dark green and grows, ringed in cyan, blue, magenta and orange (thirty thin translucent discs, so
no shader is needed), until the screen is white; the "Draft" lockup resolves out of a red and
cyan fringe on the music's chime at about 8.3 seconds, the tagline follows, and the iris closes
on the title. Any key, click or button skips it; `--skip-intro` starts at the title.

### Sound (`src/audio.lua`, `tools/audio/make_audio.py`)

The teaser's music is a G sharp drone with an open fifth, a high tremolo shimmer and a chime motif
on five notes (G#, A#, C#, D#, F#). Everything else is tuned to it:

- `teaser.ogg` is cut from the teaser and plays over the intro.
- Three seamless loops are rendered with numpy on that scale: `menu` (the drone, the shimmer and
  the teaser's motif played slowly), `table` (a thumb-piano figure over a slow pulse) and `high`
  (the same scale turned minor, for the Hands and the Overseer). Their reverb tails are folded
  back onto their starts, so they loop without a seam. Scenes name their track (`S.music`) and
  the manager crossfades.
- 31 effects, the pitched ones on the same scale. The scoring bell is one sample replayed at the
  scale's ratios, so a run of them is always an arpeggio in key.
- Music and effects have separate volumes; F3 mutes.

The loops and effects were designed from the teaser's measured pitches and balance, not by ear:
nobody has listened to them yet, so their levels may want adjusting (`make_audio.py` re-renders
everything in a few seconds).

### Cards (`src/ui/cardview.lua`, `src/ui/art.lua`)

- **Faces** are printed on worn cream paper: the illustration in a window framed in the rarity's
  colour, the Paws badge top-left, a **coat badge** top-right (flame, drop, crown or moon in the
  coat's colour, so coats read by shape as well as colour), the name on the coat's colour, the
  ability with the cat's type (sword or orb) at its end, and the cat's hearts.
- **Backs** are a halftone field in the coat's colour with the coat's shape large in the middle
  and the Overseer's mark (a black cat's head with two red eyes) below it. Shadow cats and tricks
  share the dark back with a moon.
- **Printings** are drawn into the copy: a Proof has blue registration corners on its art, Gold
  Leaf has a gilt paper edge, and a Misprint's art is printed out of register in red and cyan.
- **Cat illustrations** are bust portraits in three layers (backdrop by coat, figure, glow), with
  signature looks for the named cats (`SPEC` in `art.lua`); tricks are small scenes.

### Contrast (WCAG 2.x AA)

- Every text colour token passes 4.5:1 on every dark ground. Plate colours pass 4.5:1 with white
  labels (gold takes black). Ink on cream passes too. `tests/run.lua` checks the tokens.
- `gfx.text` runs every colour through `theme.readable(fg, bg)`, which lightens (or darkens) a
  colour that misses 4.5:1 against its ground.

### The window

- The game is laid out on a 640x360 safe area. The visible area grows to fill any window shape:
  the backdrop covers the margin, so there are no black bars (on a 16:10 Mac it's 640x400).
- Everything is drawn into one canvas at K = ceil(scale) canvas pixels per virtual pixel, then shown
  at exactly the window's size. At whole scales (720p, 1080p, 1440p) it's pixel-perfect.
- Fullscreen is the desktop kind (F11, Alt+Enter, Ctrl+Cmd+F, or Options) and is remembered.

### Without shaders (Switch)

LÖVE Potion can't compile GLSL. Only two things need it: the backdrop's motion (it is baked still
from the same maths) and the CRT. Everything else, the intro included, is drawn without shaders.
Where ImageData isn't available either, the backdrop falls back to the PNGs printed by
`tools/switch/bake_assets.py`, which runs the same Lua (`src/ui/bakes.lua`).

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

### Printings

How one particular copy of a cat came off the Overseer's press (`cards.PRINTS`; the printing
belongs to the copy, `inst.print`, and only cats have them):

| Printing | Effect | On the card |
| --- | --- | --- |
| Proof | 1 more life | blue registration corners on the art |
| Gold Leaf | 4 fish in every match where it wins a duel | a gilt paper edge |
| Misprint | +2 Paws, and its back shows the wrong coat | art printed out of register |

- About one offered cat in eight carries one (`game.rollPrint`): reward offers (never the spoils)
  and market cats, which cost 8 fish more.
- A **Misprint's back lies** (`match.backOf`): the rival reads the wrong coat when it answers your
  lead, so it aims the wrong edge at it. The Overseer's eye isn't fooled.
- Printings stay with the copy: a captured Misprint comes back at you from a Hand's deck with its
  lying back, and comes home with it.

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
| VI: The High Table | one match against the Overseer | | beat the Overseer at its own table |

**The Overseer** is the story's villain: the flaming shadow cat in the high box over the Arena,
who put the Four Hands on their cushions and keeps the ledger (Renown). It watches from the
prologue, speaks at key moments, and shows itself after you take the Gilded Saucer. Chapter VI is
one match at its table (`story.bossMatch`): your pride as the Gilded Saucer left it, against the
Four Hands' signature cats and the best rares, with an extra goblet and its **eye**: when it
answers, it sees your cards face up (`mods.allSeeing`, read in `visibleFoe`). The tuning lives
in `story.BOSS_TUNING`; with it the AI player wins about a third of the time with a late pride,
and losing just sends you back down the stairs to try again. Winning finishes the story and earns
Over the Overseer.

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
- **27 Feats**, each earned once and worth 10–150 Renown, are stamped into the ledger by the
  Overseer (a slip with its eyes slides in, and a red stamp lands on it): at the table (Hot Seat,
  Throne Warmer, Clean Sweep, Flattened, Legend Napper, Cat Burglar, Untouchable, Last Goblet
  Standing, Blitz, Homecoming), at the festival (First Lesson, Hand Slayer, Kingslayer, Oathkeeper,
  Mercy, No Quarter, Fat Cat, Through the Gate, Finalist, Champion) and over a life (Collector,
  Dynasty, Colours, Stray No More, Over the Overseer, Signed in Red, Living Legend).
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
- The Renown screen (title menu, pause menu) is the Overseer's ledger, a cream page: the level,
  lifetime stats, every feat (the earned ones stamped in red ink) and every crest.

### Stakes

The Overseer's wager on a Free Festival (`renown.STAKES`). Each stake adds its rule to the ones
below it and multiplies the Renown from every match and from the festival's placing:

| Stake | Adds | Renown |
| --- | --- | --- |
| Paper | nothing | x1 |
| Ink | knockout rivals bring 1 more goblet | x1.2 |
| Red Ink | the Four Hands' prides are a level higher | x1.4 |
| Gold Ink | strays stop going easy in the groups (full hand, full goblets) | x1.6 |
| Overseer's Ink | every rival cat has 1 more life | x2 |

Winning a festival at your highest open stake opens the next (`renown.noteStake`), and each Crest
remembers the highest stake it has won at ("Won at Red Ink" on its card). The new-festival panel
picks the Crest and the stake together; the top bar shows the stake during the festival. Story
chapters are always played at Paper. The balance simulation runs at Paper; the higher stakes are
tested for their rules but not yet tuned by simulation.

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

- About 69% of matches won, about 63% against Hands, and about 3.9 bouts per match.
- About 20% of festivals won; a quarter end in the groups.
- Against the Overseer the same AI wins about 3 times in 10 with a late-story pride.
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
| Title cards: Card Name, Type, Ability, Power, Rarity | `plates.titleCard`, used for every heading, banner, plaque and stall (now engraved signs) |
| Dither effect (Bayer 16x16, 8 levels, 2px) | became the halftone and grain of the print backdrops (`src/ui/print.lua`) |
| Lens distortion effect (anamorphic, chromatic) | no longer drawn; its red and cyan split lives on in the intro's logo, the iris, misprinted cards and the CRT's punch |
| Red/blue cat mascot | window icon and the Switch Homebrew Menu icon |
| Shadow creature with flames | the Overseer, printed in halftone by `tools/art/bake_overseer.py` |
| Card sheet (Artheline, Merline, the Black Cats) | the first entries in `src/core/cards.lua`, with signature looks in `art.lua` |

## Ideas for later

- Trick cards that move between cushions after the reveal.
- Bond quests: a market or event that offers the missing partner of a cat you own.
- Cattery rewards: a Crest or a cosmetic backdrop for finding every bond.
- A ransom: pay fish to a Hand to buy back one captive between festivals.
- More printings (a Foil that keeps its Warmth when pulled back), and a press at the market that
  reprints a cat for fish.
- Tuning the higher stakes with the simulation, and a daily festival on a shared seed.
