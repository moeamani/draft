# Draft: design notes

## From the Figma file (`Draft.fig`)

| Figma | In game |
| --- | --- |
| Wordmark "Draft" with the arched cat, tagline "Four Hands. One Arena" | `src/assets/logo-lockup.svg`, `wordmark.svg`, `tagline.svg` (title and victory screens) |
| Red/blue cat head | `src/assets/mascot.svg` (title background, favicon) |
| Black shadow creature with red eyes and flames | `src/assets/shadow.svg` (Warlord encounter, defeat screen) |
| "Draft / IN DEVELOPMENT" badge | `src/assets/badge.svg` (title screen) |
| Colours `#0e2119` `#e8483b` `#2378f7` `#d3a200` `#47e7fd` | CSS variables in `src/style.css` and the dither palette |
| Font *Ancizar Serif* | loaded from Google Fonts, with a Georgia fallback |
| Genre: Roguelike · Art style: Dithered · Card types: Medieval Cats · Content: 284 cards | roguelike run structure, ordered-dither procedural portraits, Arthurian cat roster |
| Card sheet columns: Name / Type / Ability / Power / Rarity | `CardDef` fields `name`, `type`, `ability`, `power`, `rarity` |
| Artheline · Physical · Sword Hammer · 20 · Legendary | `artheline` (Sword Hammer = smite) |
| Merline · Magic · Aural Orb · 15 | `merline` (Aural Orb = inspire), made Legendary |
| Lanceline, Morgelius, Circaleus, Purrceval, Purrlinore, Mordraleus, Merlinus · Magic · Black Cat | Black Cat (hex) cats; powers and rarities filled in |

The SVGs were extracted directly from the `.fig` binary (kiwi schema + zstd), not traced.

### Interpretation of "Four Hands. One Arena"

The Arena's ruling council of four Warlords is called **the Four Hands**. You face one per ring, from the Fourth Hand up to the First. If you meant something else, such as 2v2 or four-player matches, the engine's `sides` array is the place to extend.

## Systems

### Duel (`src/core/duel.ts`)

- Hand of 8 (charms and traits adjust this). +1 card each new round. Up to 2 redraws before the duel.
- Power is calculated in this order: base + level bonus + permanent mods → weather (sets to 1) → Litter multiplier → Inspire (+1 per inspirer) → War Yowl/horn ×2 → row and coat bonuses → coat advantage (+2) → nemesis dread (+2). Legendaries skip weather, multipliers, damage and smite.
- Round ties cost both sides a gem. 0 gems on both sides is a draw, which the player loses 1 life for.
- Every state change also emits UI events (`float`, `banner`, `trait`…). The AI simulates moves on a `structuredClone` of the state with events off.

### AI (`src/core/ai.ts`)

The AI tries every card in hand on a cloned state and scores the gain, adding value for cards drawn or returned. It passes when comfortably ahead, concedes non-decisive rounds when far behind, and plays the cheapest winning card when the opponent has passed. It holds Legendaries and specials back in early rounds. Nemesis personality sets the pass and concede thresholds, and the *Arrogant* trait makes it pass early.

### Nemesis (`src/core/nemesis.ts`, `src/core/game.ts`)

- 19 traits (10 strengths, 9 weaknesses) with conflict rules. All start hidden.
- Each nemesis keeps a history log, scars, wins/losses, status (`active / slain / returning / recruited / exiled`), personality and a signature Legendary card generated from its level and style.
- `arenaMovesOn()` runs between runs. It returns the slain who survived, resolves betrayals by recruited Hands, converts wins over you into new strengths, fills empty seats, and runs a random power struggle.

## Balance snapshot

`npm test` plays 180 full runs with the AI on both sides. The bot always takes the first draft card and never shops:

- about 57% duel win rate, about 38% against Warlords, about 8% run victories.

A human who drafts for synergy, uses markets and reads Warlord traits should clear runs far more often. Tuning knobs: `enemyDeck` levels in `nemesis.ts`, the early-ring stray hand penalty in `game.setupDuel`, `RARITY_WEIGHTS`, and the life costs in `resolveDuel`.

## Roadmap ideas

- Grow the roster towards the 284 cards in the Figma brief. Each card is one line in `CARD_LIST`.
- Hand-drawn dithered art to replace the procedural portraits. Set `artSeed` or swap `cardArt()` for real images.
- Manual targeting for Cardboard Box and the horn.
- Animations for card travel. Music.
- Leader abilities per champion. More shrine events. Nemesis-to-nemesis rivalries shown in the Four Hands screen.
