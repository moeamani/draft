# Draft: Four Hands. One Arena.

A pixel-art roguelike card duel about medieval cats, built in **LÖVE 11 (Lua)**.

- Each run is an **Arena Festival**: 16 cats, four groups of four, a live points table, then an 8-cat knockout bracket.
- Every match is played across a table, with the rival looming in the dark on the far side. Both of you have three cushions, and the cats on facing cushions duel. A winner swats a goblet off the loser's side. Knock all of their goblets off the table to win.
- The look comes straight from the Figma file. The two-tone logo, Ancizar Serif title cards, the chromatic mascot smear and one ordered dither are used on every screen.
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
| F2 | CRT filter on/off |
| F3 | sound on/off |
| Esc | menu |

A controller works too: the stick or d-pad moves a paw cursor, A clicks and drags, X charges, Y clears your cushions, B closes panels, and + opens the menu.

## Nintendo Switch (homebrew)

Draft runs on modded Switch consoles through [LÖVE Potion](https://github.com/lovebrew/lovepotion). There's a shader-free render path with pre-baked art, controller and touchscreen input, and a packer that builds `Draft.nro` from a LÖVE Potion release:

```bash
python3 tools/switch/build.py --lovepotion path/to/lovepotion.nro
```

It can also build an `.nsp` forwarder on your machine with hacBrewPack and keys from your own console. Steps, controls and limits are in [docs/SWITCH.md](docs/SWITCH.md). To try the console code paths on a desktop, run `love . --console`.

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
src/platform.lua       desktop LÖVE vs LÖVE Potion (Switch): shader and mouse stand-ins, which render path to use
src/input.lua          mouse, touchscreen and controller folded into one pointer
src/core/              pure game logic, no LÖVE: match engine + AI, festival, nemesis, cards, traits, charms, run/meta
src/ui/                theme (palette, type scale), plates (Figma title cards, dithered plates, serif text), gfx (panels,
                       text), icons (ASCII pixel sprites), cardview (faces, coat backs), art (dithered cats), shaders (stage
                       backdrop, Figma dither, chromatic smear, CRT, dissolve, wipe), widgets, fx, sfx, hud, picker, overlays
src/scenes/            title, hub (festival grounds), vs, match, result, market, event (fortune teller), summary
src/autotest.lua       scripted walkthrough that saves screenshots: love . --autotest shots
tests/run.lua          duel-rule tests + 90-festival AI simulation: luajit tests/run.lua
assets/                fonts (OFL) and images from the Figma file; assets/switch holds the baked shader art
tools/switch/          Switch build: bake_assets.py (shader art to PNG), nro.py (NRO packer), build.py, icon.jpg
```

To tweak the look, start with `src/ui/theme.lua` (palette, type scale), `src/ui/plates.lua` (title cards and plates), and the `stage`, `fdither` and `smear` shaders in `src/ui/shaders.lua`. Design notes and balance knobs are in [docs/DESIGN.md](docs/DESIGN.md).
