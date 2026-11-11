#!/usr/bin/env python3
"""Print the game's backdrops to PNG for LÖVE Potion (Nintendo Switch homebrew).

On desktop the halftone backdrop is a live shader. Without shaders the game bakes the same
picture itself, pixel by pixel (src/ui/print.lua). These PNGs are the last stand-in, for a
build of LÖVE Potion where images can't be built from pixels either:

  assets/switch/stage-<preset>-<stock>.png   one pixel per virtual pixel, 640x360
  tools/switch/icon.jpg                      the 256x256 Homebrew Menu icon

The script doesn't port any maths. It runs src/ui/bakes.lua, the file the game itself paints
from, so the PNGs match the game's own bake exactly. Re-run it after changing that file:

    python3 tools/switch/bake_assets.py

Needs numpy and Pillow, plus lupa (pip install lupa) or a `lua`/`luajit` on PATH.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
W, H = 640, 360  # virtual resolution (theme.W, theme.H)

# Paints every preset on every stock, plus the icon's ground, and writes raw RGB bytes.
LUA = r"""
package.path = ROOT .. "/?.lua;" .. package.path
local b = require("src.ui.bakes")
local function raw(path, w, h, paint)
  local rows = {}
  for y = 0, h - 1 do
    local row = {}
    for x = 0, w - 1 do
      local r, g, bl = paint(x, y)
      row[x + 1] = string.char(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(bl * 255 + 0.5))
    end
    rows[y + 1] = table.concat(row)
  end
  local f = assert(io.open(path, "wb"))
  f:write(table.concat(rows))
  f:close()
end
local names = {}
for preset, p in pairs(b.STAGES) do
  for stock in pairs(b.PAPER) do
    local name = preset .. "-" .. stock
    raw(OUT .. "/" .. name .. ".rgb", 640, 360, b.painter(p, stock))
    names[#names + 1] = name
  end
end
-- the icon's ground: a square of felt with the light behind the mascot, 128 pixels a side
-- (shown at twice the size, so the dots read in the Homebrew Menu)
local icon = b.painter({ horizon = 0, light = { 0.5, 0.48 }, radius = 0.34, power = 1.0 }, "felt")
raw(OUT .. "/icon.rgb", 128, 128, function(x, y) return icon(x + 256, y + 116) end)
table.sort(names)
return table.concat(names, " ")
"""


def run_lua(out):
    """Run LUA with lupa, or with a lua binary. Returns the list of stage names it painted."""
    try:
        from lupa import LuaRuntime
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().ROOT = ROOT
        lua.globals().OUT = out
        return str(lua.execute(LUA)).split()
    except ImportError:
        pass
    for exe in ("luajit", "lua5.1", "lua"):
        path = shutil.which(exe)
        if path:
            code = "ROOT = %s\nOUT = %s\nprint((function()\n%s\nend)())" % (json.dumps(ROOT), json.dumps(out), LUA)
            res = subprocess.run([path, "-"], input=code, capture_output=True, text=True, check=True)
            return res.stdout.split()
    sys.exit("bake_assets.py needs lupa (pip install lupa) or a lua/luajit binary to run src/ui/bakes.lua")


def load(path, w, h):
    with open(path, "rb") as f:
        return Image.frombytes("RGB", (w, h), f.read())


def save_png(im, path):
    """Three inks and their grain are a few dozen colours: a palette PNG holds them exactly."""
    colours = im.getcolors(256)
    if colours:
        pal = im.quantize(colors=len(colours), dither=Image.NONE)
        if pal.convert("RGB").tobytes() == im.tobytes():
            im = pal
    im.save(path, optimize=True)


def icon(ground):
    """256x256 baseline JPEG: the red and blue mascot on the game's felt."""
    canvas = ground.resize((256, 256), Image.NEAREST).convert("RGBA")
    mascot = Image.open(os.path.join(ROOT, "assets/img/mascot.png")).convert("RGBA").resize((224, 224), Image.LANCZOS)
    shadow = Image.new("RGBA", mascot.size, (3, 10, 7, 255))
    shadow.putalpha(mascot.getchannel("A").point(lambda a: a * 150 // 255))
    canvas.alpha_composite(shadow, (16 + 4, 16 + 6))
    canvas.alpha_composite(mascot, (16, 16))
    path = os.path.join(ROOT, "tools/switch/icon.jpg")
    canvas.convert("RGB").save(path, "JPEG", quality=92, progressive=False, optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    with tempfile.TemporaryDirectory() as tmp:
        names = run_lua(tmp)
        if sys.argv[1:] != ["--icon"]:
            os.makedirs(os.path.join(ROOT, "assets/switch"), exist_ok=True)
            for name in names:
                path = os.path.join(ROOT, "assets/switch/stage-%s.png" % name)
                save_png(load(os.path.join(tmp, name + ".rgb"), W, H), path)
                print("wrote", os.path.relpath(path, ROOT))
        icon(load(os.path.join(tmp, "icon.rgb"), 128, 128))


if __name__ == "__main__":
    main()
