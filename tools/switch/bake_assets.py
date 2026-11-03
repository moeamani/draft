#!/usr/bin/env python3
"""Pre-render the game's shader effects to PNG for LÖVE Potion (Nintendo Switch homebrew).

LÖVE Potion can't compile GLSL at runtime, so the two effects that can't be faked with plain
draws are baked here with the same maths as src/ui/shaders.lua:

  assets/switch/stage-<preset>-<ramp>.png   the dithered backdrop, one pixel per virtual pixel
  assets/switch/smear-<name>.png            the mascot silhouette through the Figma lens smear
  tools/switch/icon.jpg                     the 256x256 Homebrew Menu icon

Presets, colour ramps and smear tints come from src/ui/bakes.lua, so the game and this script
can't drift apart. Re-run it after changing that file:

    python3 tools/switch/bake_assets.py

Needs numpy and Pillow, plus lupa (pip install lupa) or a `lua`/`luajit` on PATH to read bakes.lua.
"""
import json
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
W, H = 640, 360  # virtual resolution (theme.W, theme.H)

DUMP = r"""
package.path = ROOT .. "/?.lua;" .. package.path
local b = require("src.ui.bakes")
local function enc(v)
  local t = type(v)
  if t == "table" then
    if #v > 0 or next(v) == nil then
      local out = {}
      for i = 1, #v do out[i] = enc(v[i]) end
      return "[" .. table.concat(out, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do if type(k) == "string" then keys[#keys + 1] = k end end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do
      if type(v[k]) ~= "function" then out[#out + 1] = string.format("%q", k) .. ":" .. enc(v[k]) end
    end
    return "{" .. table.concat(out, ",") .. "}"
  elseif t == "string" then return string.format("%q", v)
  elseif t == "number" then return string.format("%.17g", v)
  elseif t == "boolean" then return tostring(v) end
  return "null"
end
return enc(b)
"""


def read_bakes():
    """Evaluate src/ui/bakes.lua and return it as a dict."""
    try:
        import lupa  # noqa: F401
        from lupa import LuaRuntime
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().ROOT = ROOT
        return json.loads(lua.execute(DUMP))
    except ImportError:
        pass
    for exe in ("luajit", "lua5.1", "lua"):
        path = shutil.which(exe)
        if path:
            code = "ROOT = " + json.dumps(ROOT) + "\n" + DUMP.replace("return enc(b)", "print(enc(b))")
            out = subprocess.run([path, "-"], input=code, capture_output=True, text=True, check=True)
            return json.loads(out.stdout)
    sys.exit("bake_assets.py needs lupa (pip install lupa) or a lua/luajit binary to read src/ui/bakes.lua")


def hex3(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float64)


# ------------------------------------------------------------------ the Figma dither (fdither)

def b2(x, y):
    x, y = np.floor(x), np.floor(y)
    v = x / 2.0 + y * y * 0.75
    return v - np.floor(v)


def bayer4(x, y): return b2(0.5 * x, 0.5 * y) * 0.25 + b2(x, y)
def bayer8(x, y): return bayer4(0.5 * x, 0.5 * y) * 0.25 + b2(x, y)
def bayer16(x, y): return bayer8(0.5 * x, 0.5 * y) * 0.25 + b2(x, y)


def fdither(rgb, cx, cy):
    t = bayer16(cx, cy) + 0.5 / 256.0
    off = ((t - 0.5) / 7.0)[..., None]
    return np.clip(np.floor((rgb + off) * 7.0 + 0.5) / 7.0, 0.0, 1.0)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------------------------ stage backdrop

def stage(preset, ramp):
    """Port of shaders.src.stage at one sample per virtual pixel."""
    vy, vx = np.mgrid[0:H, 0:W].astype(np.float64)
    ux, uy = (vx + 0.5) / W, (vy + 0.5) / H
    lx, ly = preset["light"]
    dx, dy = (ux - lx) * (W / H), uy - ly
    L = np.clip(preset["power"] * (1.0 - smoothstep(0.0, preset["radius"], np.sqrt(dx * dx + dy * dy))), 0, 1)
    A, B = hex3(ramp["baseA"]), hex3(ramp["baseB"])
    col = A + (B - A) * L[..., None]
    horizon = preset["horizon"]
    if horizon > 0:
        voidc, edge = hex3(ramp["voidc"]), hex3(ramp["edge"])
        t = (uy - horizon) / (1.0 - horizon)
        halfw = 0.36 + (0.8 - 0.36) * t
        u = (ux - 0.5) / halfw
        px = 1.0 / (halfw * W)
        above = uy < horizon
        outside = (np.abs(u) > 1.0) & ~above
        isedge = ((vy - np.floor(horizon * H) < 1.5) | (np.abs(u) > 1.0 - 2.0 * px)) & ~above & ~outside
        col = np.where(isedge[..., None], edge, col)
        col = np.where((above | outside)[..., None], voidc, col)
    return fdither(col, vx, vy)


# ------------------------------------------------------------------ lens smear

def bilinear(img, x, y):
    """Sample a premultiplied RGBA float image at pixel-space coords like Texel() with linear filtering;
    outside the frame is transparent (sampleZ)."""
    h, w = img.shape[:2]
    u, v = x / w, y / h
    inside = (u >= 0) & (u <= 1) & (v >= 0) & (v <= 1)
    fx, fy = np.clip(x - 0.5, 0, w - 1), np.clip(y - 0.5, 0, h - 1)
    x0, y0 = np.floor(fx).astype(int), np.floor(fy).astype(int)
    x1, y1 = np.minimum(x0 + 1, w - 1), np.minimum(y0 + 1, h - 1)
    ax, ay = (fx - x0)[..., None], (fy - y0)[..., None]
    top = img[y0, x0] * (1 - ax) + img[y0, x1] * ax
    bot = img[y1, x0] * (1 - ax) + img[y1, x1] * ax
    s = top * (1 - ay) + bot * ay
    return np.where(inside[..., None], s, 0.0)


def smear(sil, tint, aberration, amount=1.0):
    """Port of shaders.src.smear on a square side x side frame. Returns premultiplied RGBA."""
    side = sil.shape[0]
    src = sil.copy()
    src[..., :3] = tint[None, None, :] * sil[..., 3:4]  # setColor(tint) over the white silhouette
    ys, xs = np.mgrid[0:side, 0:side].astype(np.float64)
    lx, ly = xs + 0.5, ys + 0.5
    span = (1.0 + abs(amount)) * aberration * side * 0.15
    c = side * 0.5
    R = np.sqrt(2.0) * side * 0.5

    def lens(px, py):
        qx, qy = px - c, py - c
        d2 = (qx / R) ** 2 + (qy / R) ** 2
        k = 1.0 + amount * (d2 + d2 * d2)
        return qx * k + c, qy * k + c

    acc = np.zeros((side, side, 4))
    for jx, jy in ((0.0, 0.0), (0.5, -1 / 3), (-0.25, 1 / 3), (0.25, -1 / 9)):
        tx, ty = lx + jx * 1.4, ly + jy * 1.4
        tc = np.zeros_like(acc)
        wsum = 0.0
        for i in range(32):
            fi = i / 31.0 - 0.5
            wgt = 1.0 - abs(fi * 2.0)
            rS = bilinear(src, *lens(tx + (fi + 0.5) * span, ty))
            gS = bilinear(src, *lens(tx + fi * span, ty))
            bS = bilinear(src, *lens(tx + (fi - 0.5) * span, ty))
            rs = np.where(rS[..., 3] > 0.01, rS[..., 0] / np.maximum(0.001, rS[..., 3]), 1.0)
            gs = np.where(gS[..., 3] > 0.01, gS[..., 1] / np.maximum(0.001, gS[..., 3]), 1.0)
            bs = np.where(bS[..., 3] > 0.01, bS[..., 2] / np.maximum(0.001, bS[..., 3]), 1.0)
            al = np.maximum(np.maximum(rS[..., 3], gS[..., 3]), bS[..., 3])
            tc += np.stack([rs * al, gs * al, bs * al, al], -1) * wgt
            wsum += wgt
        acc += tc / max(wsum, 1e-4)
    return acc / 4.0


def unpremultiply(rgba):
    a = rgba[..., 3:4]
    out = rgba.copy()
    out[..., :3] = np.where(a > 1e-4, rgba[..., :3] / np.maximum(a, 1e-4), 0.0)
    return np.clip(out, 0, 1)


def save(arr, path, mode):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = np.round(np.clip(arr, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(data, mode).save(path, optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


def icon(bakes):
    """256x256 baseline JPEG: the mascot over its own smear on the dithered menu backdrop."""
    n = 256
    vy, vx = np.mgrid[0:n, 0:n].astype(np.float64)
    ramp = bakes["RAMPS"]["felt"]
    d = np.sqrt(((vx + 0.5) / n - 0.5) ** 2 + ((vy + 0.5) / n - 0.45) ** 2)
    L = np.clip(1.0 - smoothstep(0.0, 0.75, d), 0, 1)
    A, B = hex3(ramp["baseA"]), hex3(ramp["baseB"])
    bg = fdither(A + (B - A) * L[..., None], np.floor(vx / 2), np.floor(vy / 2))
    canvas = Image.fromarray(np.round(bg * 255).astype(np.uint8), "RGB").convert("RGBA")
    streak = Image.open(os.path.join(ROOT, "assets/switch/smear-night.png")).convert("RGBA").resize((236, 236), Image.LANCZOS)
    canvas.alpha_composite(streak, (22, 14))
    mascot = Image.open(os.path.join(ROOT, "assets/img/mascot.png")).convert("RGBA").resize((212, 212), Image.LANCZOS)
    canvas.alpha_composite(mascot, (22, 30))
    path = os.path.join(ROOT, "tools/switch/icon.jpg")
    canvas.convert("RGB").save(path, "JPEG", quality=92, progressive=False, optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    bakes = read_bakes()
    if sys.argv[1:] == ["--icon"]:  # just the icon (the smears must already exist)
        icon(bakes)
        return
    for pname, preset in sorted(bakes["STAGES"].items()):
        for rname, ramp in sorted(bakes["RAMPS"].items()):
            path = os.path.join(ROOT, "assets/switch/stage-%s-%s.png" % (pname, rname))
            save(stage(preset, ramp), path, "RGB")

    side = int(bakes["SMEAR_SIDE"])
    sil_img = Image.open(os.path.join(ROOT, "assets/img/mascot-silhouette.png")).convert("RGBA")
    sil_img = sil_img.resize((side, side), Image.BILINEAR)
    sil = np.asarray(sil_img).astype(np.float64) / 255.0
    sil[..., :3] = 1.0  # only the shape matters; the tint is applied per smear
    sil[..., :3] *= sil[..., 3:4]
    for sm in bakes["SMEARS"]:
        path = os.path.join(ROOT, "assets/switch/smear-%s.png" % sm["name"])
        save(unpremultiply(smear(sil, hex3(sm["tint"]), float(sm["aberration"]))), path, "RGBA")
    icon(bakes)


if __name__ == "__main__":
    main()
