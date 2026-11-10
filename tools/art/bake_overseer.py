#!/usr/bin/env python3
"""Bake the Overseer: the Figma file's flaming shadow cat (assets/img/shadow.png), printed.

The flat vector art becomes a halftone print like the Blunder hero image: red flames screened
with pink and white dots that brighten towards the cat, a cyan inner glow with white and blue
dots, a blue rim, a black cat with glowing red eyes, a pixel of colour misregistration and paper
grain. The flames are warped a little differently in each frame so they flicker when the game
cycles them.

    python3 tools/art/bake_overseer.py

Writes assets/img/overseer-0.png ... overseer-3.png (and prints the eye positions the game
uses for blinking). Needs numpy and Pillow.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "img", "shadow.png")
OUT = os.path.join(ROOT, "assets", "img", "overseer-%d.png")
W = 640          # output width; height follows the source
FRAMES = 4
CELL = 5.0       # halftone cell, in output pixels


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


RED, RED_D, ORANGE, PINK, WHITE = hexc("#e03a26"), hexc("#a8200f"), hexc("#f6683c"), hexc("#ff9fb4"), hexc("#fff1ee")
CYAN, CYAN_L, BLUE, BLUE_D = hexc("#52e3f6"), hexc("#e9fdff"), hexc("#2c7ef2"), hexc("#1546b8")
BLACK, EYE, EYE_L, PUPIL = hexc("#07080b"), hexc("#ff3a26"), hexc("#ff8a5c"), hexc("#5a0a04")


def blur(mask, r):
    im = Image.fromarray(np.clip(mask * 255, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0


def screen(h, w, angle):
    """Distance from each pixel to the nearest halftone dot centre, in cells (0..0.707)."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    a = math.radians(angle)
    u = (x * math.cos(a) + y * math.sin(a)) / CELL
    v = (-x * math.sin(a) + y * math.cos(a)) / CELL
    du, dv = u - np.round(u), v - np.round(v)
    return np.sqrt(du * du + dv * dv)


def dots(dist, amount):
    """A soft-edged dot whose area follows amount (0..1)."""
    r = np.sqrt(np.clip(amount, 0, 1)) * 0.62
    return np.clip((r - dist) * 3.0 + 0.5, 0, 1)


def classify(src):
    rgb, a = src[..., :3].astype(np.int32), src[..., 3]
    R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    solid = a > 128
    # the eyes are the reds the black cat surrounds; every other red is flame
    dark = (solid & (R < 40) & (G < 40) & (B < 40)).astype(np.float32)
    reddish = solid & (R > 90) & (G < 90) & (B < 80)
    inside = blur(dark, 12) > 0.3
    h, w = solid.shape
    face = np.zeros_like(solid)
    face[int(h * 0.62):int(h * 0.9), int(w * 0.33):int(w * 0.62)] = True  # where the eyes are
    eye = reddish & inside & face
    pupil = eye & (R < 150)
    eye = eye & ~pupil
    flame = reddish & ~(inside & face)
    cyan = solid & (G > 170) & (B > 170)
    blue = solid & (B > 90) & ~cyan & ~eye
    black = solid & ~eye & ~pupil & ~flame & ~cyan & ~blue  # dark edges default to the cat
    return {k: v.astype(np.float32) for k, v in dict(eye=eye, pupil=pupil, flame=flame, cyan=cyan, black=black, blue=blue, alpha=solid).items()}


def shrink(masks, size):
    out = {}
    for k, m in masks.items():
        im = Image.fromarray((m * 255).astype(np.uint8)).resize(size, Image.BOX)
        out[k] = np.asarray(im, np.float32) / 255.0
    return out


def warp(m, dx, dy):
    h, w = m.shape
    y, x = np.mgrid[0:h, 0:w]
    sx = np.clip(np.round(x + dx).astype(np.int32), 0, w - 1)
    sy = np.clip(np.round(y + dy).astype(np.int32), 0, h - 1)
    return m[sy, sx]


def frame(base, k):
    h, w = base["alpha"].shape
    inner = np.clip(base["cyan"] + base["blue"] + base["black"] + base["eye"], 0, 1)
    near = np.clip(blur(inner, 26) * 1.9, 0, 1)            # 1 hugging the cat, 0 at the flame tips
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    # the flicker: outer flames sway and lick upwards, more at the tips
    ph = k * 2 * math.pi / FRAMES
    sway = (1 - near) ** 1.3
    dx = sway * (4.0 * np.sin(y * 0.045 + ph) + 2.0 * np.sin(y * 0.11 - 2 * ph))
    dy = sway * (3.0 * np.sin(x * 0.035 - ph) + 3.0) - 1.5
    m = {kk: warp(v, dx, dy) for kk, v in base.items() if kk in ("flame",)}
    # the cyan glow breathes less
    dxc = 0.35 * dx
    m["cyan"] = warp(base["cyan"], dxc, 0.35 * dy)
    for kk in ("blue", "black", "eye", "pupil"):
        m[kk] = base[kk]
    eye = np.clip(m["eye"] + m["pupil"], 0, 1)
    pupil = m["pupil"]
    flame = np.clip(m["flame"] - m["cyan"] - m["blue"] - m["black"] - eye, 0, 1)
    cyan = np.clip(m["cyan"] - m["blue"] - m["black"] - eye, 0, 1)
    blue, black = m["blue"], m["black"]
    alpha = np.clip(flame + cyan + blue + black + eye, 0, 1)

    d45, d15, d75 = screen(h, w, 45), screen(h, w, 15), screen(h, w, 75)
    col = np.zeros((h, w, 3), np.float32)

    # flames: red, screened with orange, pink and white dots as they near the cat
    t = np.clip(near * 1.15, 0, 1)
    f = RED[None, None, :] * np.ones((h, w, 1), np.float32)
    f = f + (ORANGE - RED) * dots(d15, t * 0.9)[..., None]
    f = f + (PINK - f) * dots(d45, np.clip(t * 1.3 - 0.35, 0, 1))[..., None]
    f = f + (WHITE - f) * dots(d75, np.clip(t * 1.6 - 1.0, 0, 1))[..., None]
    f = f + (RED_D - f) * dots(d45, np.clip(0.45 - t, 0, 1))[..., None]
    col += f * flame[..., None]

    # the cyan glow: white towards the flames, blue towards the cat
    cat = np.clip(blur(np.clip(blue + black, 0, 1), 10) * 2.2, 0, 1)
    c = CYAN[None, None, :] * np.ones((h, w, 1), np.float32)
    c = c + (CYAN_L - c) * dots(d45, np.clip(0.75 - cat, 0, 1) * 0.8)[..., None]
    c = c + (BLUE - c) * dots(d15, np.clip(cat * 1.2 - 0.2, 0, 1))[..., None]
    col += c * cyan[..., None]

    # the rim
    rim = BLUE[None, None, :] + (BLUE_D - BLUE) * dots(d45, 0.55)[..., None]
    col += rim * blue[..., None]

    # the cat, with the eyes' glow screened onto the black
    glow = np.clip(blur(eye, 8) * 2.6, 0, 1) * (1 - eye)
    kc = BLACK[None, None, :] + (EYE - BLACK) * dots(d45, glow * 0.9)[..., None]
    col += kc * black[..., None]
    lit = np.clip(blur(eye, 3) - 0.6, 0, 1) * 1.8
    e = EYE[None, None, :] + (EYE_L - EYE) * dots(d15, lit)[..., None]
    e = e + (PUPIL - e) * pupil[..., None]
    col += e * eye[..., None]

    weight = flame + cyan + blue + black + eye
    col = col / np.maximum(weight, 1e-3)[..., None]
    # a pixel of misregistration: the red plate sits a little right, the blue plate a little up
    out = np.zeros((h, w, 4), np.float32)
    def shift(m, dx, dy):
        o = np.zeros_like(m)
        hh, ww = m.shape
        o[max(0, dy):hh + min(0, dy), max(0, dx):ww + min(0, dx)] = m[max(0, -dy):hh - max(0, dy), max(0, -dx):ww - max(0, dx)]
        return o
    out[..., 0] = shift(col[..., 0], 1, 0)
    out[..., 1] = col[..., 1]
    out[..., 2] = shift(col[..., 2], 0, -1)
    a2 = np.maximum(alpha, np.maximum(shift(alpha, 1, 0), shift(alpha, 0, -1)) * 0.6)
    # paper grain, the same in every frame
    rng = np.random.default_rng(7)
    grain = (rng.random((h, w)) - 0.5) * 22
    out[..., :3] = np.clip(out[..., :3] + grain[..., None], 0, 255)
    out[..., 3] = np.clip(a2, 0, 1) * 255
    # the cat is cut off flat at the bottom: the last rows repeat the one above
    out[-3:] = out[-4]
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def main():
    src = np.asarray(Image.open(SRC).convert("RGBA"))
    sh, sw = src.shape[:2]
    h = int(round(sh * W / sw))
    base = shrink(classify(src), (W, h))
    eye = base["eye"]
    ys, xs = np.nonzero(eye > 0.5)
    left = xs < W / 2
    for side, sel in (("left", left), ("right", ~left)):
        print("%s eye: x %d-%d, y %d-%d" % (side, xs[sel].min(), xs[sel].max(), ys[sel].min(), ys[sel].max()))
    for k in range(FRAMES):
        img = frame(base, k)
        img.save(OUT % k, optimize=True)
        print("wrote", os.path.relpath(OUT % k, ROOT), img.size, os.path.getsize(OUT % k), "bytes")


if __name__ == "__main__":
    sys.exit(main())
