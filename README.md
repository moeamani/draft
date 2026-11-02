# Draft: Four Hands. One Arena.

A pixel-art roguelike card duel about medieval cats, built in **LÖVE 11 (Lua)**.

- Each run is an **Arena Festival**: 16 cats, four groups of four, a live points table, then an 8-cat knockout bracket.
- Every match is played on a **candle-lit table**. The rival looms in the dark across from you. Both of you have three cushions, and the cats on facing cushions duel. A winner swats a goblet off the loser's side. Knock all of their goblets off the table to win.
- **Lead and answer.** Each bout one side leads, placing its cards face-down. The other side answers, seeing only the card backs. A back shows the cat's coat, but Shadow cats and tricks share the same dark back. The lead swaps every bout.
- The **Four Hands** are persistent nemesis Warlords. They enter every festival, remember you, hide strengths and weaknesses, and scheme between festivals.

![The rival leads; you answer](docs/screenshots/04_match_place.png)

## Run it

1. Install LÖVE 11.4 or newer from https://love2d.org.
2. From this folder, run:

```bash
love .
```

On Windows you can also drag the folder onto `love.exe`. To package a `.love` file:

```bash
tools/build-love.sh
```

| Key | Action |
| --- | --- |
| Click a card | put it on the first free cushion (click it on the cushion to take it back) |
| Drag a card | put it on a particular cushion (drop on a full one to swap) |
| 1 / 2 / 3 | put the card under the mouse on that cushion |
| Enter / Space | Charge! (reveal and duel) |
| Backspace | clear your cushions |
| F11 / Alt+Enter | fullscreen |
| F2 | screen style: lamplight / CRT / plain |
| F3 | sound on/off |
| Esc | menu |

## How a match plays

1. You hold 5 cards. The rival leads the first bout: three face-down cards slide onto their cushions.
2. Read their backs. An **Ember**, **Tide** or **Gilt** back tells you the cat's coat. A **dark** back is either a Shadow cat or a trick.
3. Answer by putting up to 3 cards on your cushions, then press **Charge!**
4. Everything flips over. Each pair of facing cards duels:
   - The higher Paws wins.
   - **Coat edge**: Ember beats Gilt, Gilt beats Tide, Tide beats Ember. The winning coat gets +3 Paws.
   - A cat facing an empty cushion, or a trick, walks in unopposed.
   - Ties go to the leader.
5. Every winner swats a goblet off the loser's side of the table.
6. Next bout, you lead and the rival answers your backs.

## How a festival plays

1. You're dealt a random pride of 15 cats.
2. **Group stage**: 3 matches. A win is worth 3 points, and goblet difference breaks ties. The top 2 of each group go through.
3. **Knockouts**: quarter-final, semi-final, final. Lose once and you're out.
4. Before every match the rival sits down at the table and taunts you. Between matches you visit one stall: the **Mews Market**, the **Fortune Teller** (random events) or the **Training Yard**.
5. After the festival, **the Arena moves on**:
   - The festival champion climbs the hierarchy, or takes a seat among the Hands if they were a stray.
   - Slain Hands may return, and recruited Hands may betray you.
   - Hands who beat you train new strengths.

## Code layout

```
main.lua, conf.lua     boot, 640x360 virtual canvas (rendered 2x), scene manager, table backdrop, screen pass, input
src/core/              pure game logic, no LÖVE: match engine + AI, festival, nemesis, cards, traits, charms, run/meta
src/ui/                theme (palette, type scale), gfx (panels, parchment, text), icons (ASCII pixel sprites), cardview
                       (faces, coat backs), art (dithered cats), shaders (table, lamplight/CRT, foil, dissolve, dither, bake),
                       widgets, fx, sfx, hud, picker, overlays
src/scenes/            title, hub (festival grounds), vs, match, result, market, event (fortune teller), summary
src/autotest.lua       scripted walkthrough that saves screenshots: love . --autotest shots
tests/run.lua          duel-rule tests + 90-festival AI simulation: luajit tests/run.lua
assets/                pixel fonts (OFL) and images from the Figma file
```

To tweak the look, start with `src/ui/theme.lua` (palette, type scale), the `table` shader in `src/ui/shaders.lua` (room, baize and lamplight), and `src/ui/gfx.lua` (panel and parchment styles). Design notes and balance knobs are in [docs/DESIGN.md](docs/DESIGN.md).
