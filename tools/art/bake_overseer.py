#!/usr/bin/env python3
"""Bake the Overseer: the Figma file's flaming shadow cat (assets/img/shadow.png), printed in
halftone on the game's pixel grid.

The flat vector art becomes pixel art with the same dot screen as the backdrop: red flames with
orange, pink and white dots that grow towards the cat, a cyan inner glow with white and blue
dots, a blue rim, a black cat whose red eyes glow through a halo of dots, and a pixel of red and
blue misregistration along every edge. Every pixel is one flat colour (no soft edges), so the
frames can be drawn at whole-number scales next to the cats. The outer flames are warped a
little differently in each frame, so they flicker when the game cycles them.

    python3 tools/art/bake_overseer.py

Writes assets/img/overseer-0.png ... overseer-3.png, 320 pixels wide, and prints the eye
positions the game uses for blinking. Needs numpy and Pillow.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "img", "shadow.png")
OUT = os.path.join(ROOT, "assets", "img", "overseer-%d.png")
W = 320          # output width in game pixels; height follows the source
FRAMES = 4
CELL = 4.0       # halftone cell, in game pixels


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


RED, RED_D, ORANGE, PINK, WHITE = hexc("#e03a26"), hexc("#a8200f"), hexc("#f6683c"), hexc("#ff9fb4"), hexc("#fff1ee")
CYAN, CYAN_L, BLUE, BLUE_D = hexc("#52e3f6"), hexc("#e9fdff"), hexc("#2c7ef2"), hexc("#1546b8")
BLACK, EYE, EYE_L, PUPIL = hexc("#07080b"), hexc("#ff3a26"), hexc("#ffb08a"), hexc("#5a0a04")


def blur(mask, r):
    im = Image.fromarray(np.clip(mask * 255, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0


def screen(h, w, angle, phase=0.0):
    """Distance from each pixel to the nearest halftone dot centre, in cells (0..0.707)."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    a = math.radians(angle)
    u = (x * math.cos(a) + y * math.sin(a)) / CELL + phase
    v = (-x * math.sin(a) + y * math.cos(a)) / CELL
    du, dv = u - np.round(u), v - np.round(v)
    return np.sqrt(du * du + dv * dv)


def dots(dist, amount):
    """A hard-edged dot whose area follows amount (0..1)."""
    return dist < np.sqrt(np.clip(amount, 0, 1)) * 0.66


def classify(src):
    """Split the flat source art into its regions by colour (and, for the eyes, by place)."""
    rgb, a = src[..., :3].astype(np.int32), src[..., 3]
    R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    solid = a > 128
    cyan = solid & (G > 170) & (B > 170)
    # the eyes are the reds the black cat surrounds; every other red is flame
    dark = (solid & (R < 40) & (G < 40) & (B < 40)).astype(np.float32)
    reddish = solid & (R > 90) & (G < 90) & (B < 80)
    inside = blur(dark, 12) > 0.3
    h, w = solid.shape
    face = np.zeros_like(solid)
    face[int(h * 0.62):int(h * 0.9), int(w * 0.33):int(w * 0.62)] = True
    eye = reddish & inside & face
    pupil = eye & (R < 150)
    eye = eye & ~pupil
    flame = reddish & ~(inside & face)
    blue = solid & (B > 90) & ~cyan & ~eye
    black = solid & ~eye & ~pupil & ~flame & ~cyan & ~blue  # dark edges default to the cat
    return {k: v.astype(np.float32) for k, v in dict(eye=eye, pupil=pupil, flame=flame, cyan=cyan, black=black, blue=blue).items()}


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
    h, w = base["flame"].shape
    inner = np.clip(base["cyan"] + base["blue"] + base["black"] + base["eye"] + base["pupil"], 0, 1)
    near = np.clip(blur(inner, 13) * 1.9, 0, 1)            # 1 hugging the cat, 0 at the flame tips
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    # the flicker: outer flames sway and lick upwards, more at the tips
    ph = k * 2 * math.pi / FRAMES
    sway = (1 - near) ** 1.3
    dx = sway * (2.2 * np.sin(y * 0.09 + ph) + 1.2 * np.sin(y * 0.22 - 2 * ph))
    dy = sway * (1.8 * np.sin(x * 0.07 - ph) + 1.8) - 0.9
    flame_m = warp(base["flame"], dx, dy)
    cyan_m = warp(base["cyan"], 0.35 * dx, 0.35 * dy)
    # every pixel belongs to exactly one region (the innermost that claims it), or to none
    eye = base["eye"] > 0.5
    pupil = (base["pupil"] > 0.5) & ~eye
    black = (base["black"] > 0.3) & ~eye & ~pupil      # low thresholds keep the thin ears and rim
    blue = (base["blue"] > 0.3) & ~eye & ~pupil & ~black
    cyan = (cyan_m > 0.5) & ~eye & ~pupil & ~black & ~blue
    flame = (flame_m > 0.5) & ~eye & ~pupil & ~black & ~blue & ~cyan
    alpha = eye | pupil | black | blue | cyan | flame

    d45, d15, d75 = screen(h, w, 45), screen(h, w, 15, 0.5), screen(h, w, 75, 0.25)
    col = np.zeros((h, w, 3), np.float32)

    # flames: red, with orange, pink and white dots as they near the cat, darker at the tips
    t = np.clip(near * 1.15, 0, 1)
    f = np.broadcast_to(RED, (h, w, 3)).copy()
    f[dots(d45, np.clip(0.45 - t, 0, 1))] = RED_D
    f[dots(d15, t * 0.85)] = ORANGE
    f[dots(d45, np.clip(t * 1.3 - 0.35, 0, 1))] = PINK
    f[dots(d75, np.clip(t * 1.6 - 1.0, 0, 1))] = WHITE
    col[flame] = f[flame]

    # the cyan glow: white towards the flames, blue towards the cat
    cat = np.clip(blur((blue | black).astype(np.float32), 5) * 2.2, 0, 1)
    c = np.broadcast_to(CYAN, (h, w, 3)).copy()
    c[dots(d45, np.clip(0.7 - cat, 0, 1) * 0.4)] = CYAN_L
    c[dots(d15, np.clip(cat * 1.2 - 0.2, 0, 1))] = BLUE
    col[cyan] = c[cyan]

    # the rim
    rim = np.broadcast_to(BLUE, (h, w, 3)).copy()
    rim[dots(d45, 0.5)] = BLUE_D
    col[blue] = rim[blue]

    # the cat, with the eyes' glow screened onto the black
    eyes = (eye | pupil).astype(np.float32)
    glow = np.clip(blur(eyes, 3.2) * 2.4, 0, 1)
    kc = np.broadcast_to(BLACK, (h, w, 3)).copy()
    kc[dots(d45, glow * 0.7)] = EYE
    col[black] = kc[black]
    e = np.broadcast_to(EYE, (h, w, 3)).copy()
    e[blur(eyes, 1.5) > 0.86] = EYE_L
    col[eye] = e[eye]
    col[pupil] = PUPIL

    # a pixel of misregistration: the red plate sits one pixel right, the blue plate one pixel up
    def shift(m, sx, sy):
        o = np.zeros_like(m)
        hh, ww = m.shape[:2]
        o[max(0, sy):hh + min(0, sy), max(0, sx):ww + min(0, sx)] = m[max(0, -sy):hh - max(0, sy), max(0, -sx):ww - max(0, sx)]
        return o
    out = np.zeros((h, w, 4), np.float32)
    out[..., 0] = shift(col[..., 0], 1, 0)
    out[..., 1] = col[..., 1]
    out[..., 2] = shift(col[..., 2], 0, -1)
    a = alpha.astype(np.float32)
    out[..., 3] = np.maximum(a, np.maximum(shift(a, 1, 0), shift(a, 0, -1))) * 255
    out[-2:] = out[-3]  # cut off flat at the bottom
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def main():
    src = np.asarray(Image.open(SRC).convert("RGBA"))
    sh, sw = src.shape[:2]
    h = int(round(sh * W / sw))
    base = shrink(classify(src), (W, h))
    ys, xs = np.nonzero((base["eye"] + base["pupil"]) > 0.5)
    left = xs < W / 2
    for side, sel in (("left", left), ("right", ~left)):
        print("%s eye: x %d-%d, y %d-%d" % (side, xs[sel].min(), xs[sel].max(), ys[sel].min(), ys[sel].max()))
    for k in range(FRAMES):
        img = frame(base, k)
        img.save(OUT % k, optimize=True)
        print("wrote", os.path.relpath(OUT % k, ROOT), img.size, os.path.getsize(OUT % k), "bytes")


if __name__ == "__main__":
    sys.exit(main())
