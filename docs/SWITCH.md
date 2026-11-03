# Draft on Nintendo Switch (homebrew)

Draft runs on the Switch through [LÖVE Potion](https://github.com/lovebrew/lovepotion), the
community port of LÖVE for Nintendo homebrew. The output is a homebrew app (`.nro`) for the
Homebrew Menu, and on your own machine you can also make an `.nsp` forwarder that puts Draft on
the Home menu.

> **Only for modded consoles.** Homebrew needs a Switch running custom firmware (for example
> Atmosphère). It isn't a retail release: it isn't signed by Nintendo, can't go on the eShop and won't
> run on an unmodified console. Publishing on the eShop needs Nintendo's developer programme and SDK.

## What's different on the console

LÖVE Potion has no runtime GLSL: Switch shaders are precompiled deko3d binaries. `src/platform.lua`
detects LÖVE Potion and switches the game to its shader-free path:

| Effect | Desktop | Switch |
| --- | --- | --- |
| Backdrop (`stage`) | live shader | PNG baked from the same maths (`assets/switch/stage-*.png`) |
| Figma dither on plates and title cards | `fdither` shader | a 16x16 Bayer dot tile laid over each plate |
| Lens smear on title cards and card backs | `smear` shader | PNG baked per plate colour (`assets/switch/smear-*.png`) |
| VS portrait smear | `smear` shader | colour ghosts trailing the portrait |
| Card flash and dissolve | shaders | additive wash and fade |
| Screen wipe | shader | fade |
| CRT filter (F2) | optional shader | not available |

The baked PNGs come from `tools/switch/bake_assets.py`, which ports the shaders to numpy and
reads its presets, colour ramps and tints from `src/ui/bakes.lua`, the same table the game
uses. If you change that file, re-run the baker:

```bash
python3 tools/switch/bake_assets.py
```

The sound effects are synthesised at load as on desktop, at 11 kHz to keep start-up short.

You can try the console paths on a desktop with `love . --console`: no shaders, the baked art and
the controller cursor.

## Controls

| Joy-Con / Pro Controller | Action |
| --- | --- |
| Left stick or d-pad | move the paw cursor |
| A | click; hold and move to drag a card onto a cushion |
| X | Charge! (also Fight! on the VS screen, and confirms your name) |
| Y | take your cards back off the cushions |
| B | close the open panel |
| + or − | menu |
| L / R | scroll lists |
| Touchscreen (handheld) | tap to click, drag cards with a finger |

When you start your first festival, the system keyboard opens so you can name your champion.
Tap the name box, or press A on it, to change the name.

## Build the .nro

You need Python 3 and a LÖVE Potion 3.x release.

1. Download `lovepotion.nro` for Switch from the
   [LÖVE Potion releases](https://github.com/lovebrew/lovepotion/releases).
2. From the repository root, run:

   ```bash
   python3 tools/switch/build.py --lovepotion path/to/lovepotion.nro
   ```

   This writes:
   - `dist/switch/game.love`: the game.
   - `dist/switch/Draft/Draft.nro`: LÖVE Potion fused with the game, with Draft's icon
     (`tools/switch/icon.jpg`), title, author and version in the Homebrew Menu.
3. Copy the `dist/switch/Draft` folder to `sdmc:/switch/` on the SD card. You should end up
   with `sdmc:/switch/Draft/Draft.nro`.
4. Open the Homebrew Menu and launch **Draft**. Launch it by holding R while starting a game
   (title override), not from the album applet, so it gets the full memory budget.

To check an NRO, run:

```bash
python3 tools/switch/nro.py info dist/switch/Draft/Draft.nro
```

The packer checks itself against a synthetic NRO:

```bash
python3 tools/switch/nro.py selftest
```

Saves go to LÖVE Potion's save directory on the SD card, under the identity `draft-four-hands`.

## Optional: an .nsp forwarder (Home menu icon)

An NSP can't be made without Nintendo's signing keys, and none ship with this project or are
downloaded by it. To build an NSP for your own console, you supply three things:

- **hacBrewPack**: the open-source NCA/NSP packer.
- **`prod.keys`** dumped from **your own console** with Lockpick_RCM.
- **A forwarder's exefs**: a folder with `main` and `main.npdm` from an NRO-forwarder project you
  trust. The forwarder reads `nextNroPath` from its RomFS and chain-loads that NRO.

Then run:

```bash
python3 tools/switch/build.py --lovepotion path/to/lovepotion.nro --nsp \
    --hacbrewpack path/to/hacbrewpack --keys path/to/prod.keys --forwarder path/to/forwarder-exefs
```

The script:

1. lays out `exefs/` (your forwarder), `romfs/nextNroPath` pointing at
   `sdmc:/switch/Draft/Draft.nro`, and `control/` with Draft's NACP and icon;
2. runs hacBrewPack with `--titleid 05d4a7f0c1e2a000` (change it with `--title-id`, and pass
   `--keygeneration N` if your firmware needs a newer key generation);
3. writes `dist/switch/Draft-<titleid>.nsp`.

The forwarder only launches the NRO, so the `Draft` folder must also be on the SD card. Installing
an NSP that isn't signed by Nintendo needs a custom-firmware setup that allows it.

**Untested.** This path wasn't run here. The tool has no hacBrewPack, keys, forwarder or console
to test against, so treat the NSP step as a starting point. The `.nro` build was tested against a
synthetic NRO, and the console code paths were run in a LÖVE Potion simulation (no shaders, no
mouse, a fake gamepad and touchscreen), not on hardware.

## Known limits

- The game draws a 640x360 canvas at 2x (1280x720). Handheld mode is 1:1. Docked at 1080p it's
  scaled by 1.5 with linear filtering, so pixels are slightly soft.
- `conf.lua` asks for LÖVE 11.4. LÖVE Potion 3 follows the LÖVE 12 API. Everything the game
  calls exists in both, but LÖVE Potion may print a version notice.
- If LÖVE Potion can't create sound data on your version, the game runs silently rather than
  failing.
