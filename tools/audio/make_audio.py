#!/usr/bin/env python3
"""Render Draft's soundtrack and sound effects.

Everything is tuned to the teaser's music: a G sharp drone with an open fifth and a five-note
scale (G#, A#, C#, D#, F#). The soundtrack loops are rendered with their reverb tails folded back
onto the start, so they loop without a seam. Pitched effects use the same scale, so whatever
happens at the table harmonises with the music.

    python3 tools/audio/make_audio.py            # everything
    python3 tools/audio/make_audio.py sfx        # only the effects
    python3 tools/audio/make_audio.py music      # only the loops

Writes assets/audio/music/*.ogg (needs ffmpeg with libvorbis) and assets/audio/sfx/*.wav.
Needs numpy. The teaser's own music (assets/audio/music/teaser.ogg) is not made here: it is cut
from the teaser video with ffmpeg (see docs/DESIGN.md).
"""
import os
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_MUSIC = os.path.join(ROOT, "assets", "audio", "music")
OUT_SFX = os.path.join(ROOT, "assets", "audio", "sfx")
SR = 44100
SR_SFX = 22050
TAU = 2 * np.pi

# The scale, as semitones above G#: G# A# C# D# F#
SCALE = [0, 2, 5, 7, 10]
GS = {2: 103.826, 3: 207.652, 4: 415.305, 5: 830.609, 6: 1661.219}


def note(name):
    """Frequency of a note such as 'G#4', 'D#5', 'A#3'."""
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = names[name[:-1]], int(name[-1])
    return 440.0 * 2 ** ((pitch - 9) / 12 + (octave - 4))


def env_exp(n, sr, decay):
    return np.exp(-np.arange(n) / (decay * sr))


def fade(x, sr, a=0.005, r=0.02):
    n = len(x)
    na, nr = min(n, int(a * sr)), min(n, int(r * sr))
    out = x.copy()
    if na > 0:
        out[:na] *= np.linspace(0, 1, na)
    if nr > 0:
        out[-nr:] *= np.linspace(1, 0, nr)
    return out


def onepole_lp(x, sr, cutoff):
    """A cheap low-pass in the frequency domain (zero phase)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    X *= 1.0 / np.sqrt(1.0 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def bandpass(x, sr, lo, hi):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    g = 1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1e-3)) ** 4) / np.sqrt(1.0 + (f / hi) ** 4)
    return np.fft.irfft(X * g, len(x))


def bell(f, dur, sr, bright=1.0, decay=1.2):
    """A soft glassy bell: a few sine partials, each dying faster than the one below."""
    n = int(dur * sr)
    t = np.arange(n) / sr
    out = np.zeros(n)
    for mult, amp, d in ((1.0, 1.0, 1.0), (2.0, 0.32 * bright, 0.55), (3.01, 0.14 * bright, 0.35), (4.2, 0.06 * bright, 0.2)):
        out += amp * np.sin(TAU * f * mult * t) * np.exp(-t / (decay * d))
    return fade(out, sr, 0.003, 0.03)


def pluck(f, dur, sr, decay=0.35):
    """A thumb-piano pluck: a sine with a quick knock at the front."""
    n = int(dur * sr)
    t = np.arange(n) / sr
    body = np.sin(TAU * f * t) * np.exp(-t / decay) + 0.25 * np.sin(TAU * f * 2.92 * t) * np.exp(-t / (decay * 0.2))
    return fade(body, sr, 0.002, 0.02)


def pad(freqs, dur, sr, attack=2.0, release=2.5):
    """A slow chord: three slightly detuned sines per note, an octave above very quietly."""
    n = int(dur * sr)
    t = np.arange(n) / sr
    out = np.zeros(n)
    for f in freqs:
        for det, amp in ((-0.0025, 0.33), (0.0, 0.34), (0.0031, 0.33)):
            out += amp * np.sin(TAU * f * (1 + det) * t + det * 900)
        out += 0.08 * np.sin(TAU * f * 2 * t)
    a, r = int(attack * sr), int(release * sr)
    e = np.ones(n)
    e[:a] = np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    e[-r:] *= np.cos(np.linspace(0, np.pi / 2, r)) ** 2
    return out * e / max(1, len(freqs))


def shimmer(f, dur, sr, rate=5.5):
    """The teaser's high tremolo shimmer."""
    n = int(dur * sr)
    t = np.arange(n) / sr
    trem = 0.6 + 0.4 * np.sin(TAU * rate * t)
    swell = np.sin(np.linspace(0, np.pi, n)) ** 2
    return (np.sin(TAU * f * t) + 0.5 * np.sin(TAU * f * 1.5 * t + 1.0)) * trem * swell


class Mix:
    """A stereo mix that wraps anything past its end back to the start, so it loops."""

    def __init__(self, seconds, sr=SR):
        self.sr = sr
        self.n = int(seconds * sr)
        self.buf = np.zeros((self.n, 2))

    def add(self, x, at, gain=1.0, pan=0.0):
        i0 = int(at * self.sr) % self.n
        l, r = gain * np.sqrt((1 - pan) / 2), gain * np.sqrt((1 + pan) / 2)
        idx = (i0 + np.arange(len(x))) % self.n
        np.add.at(self.buf[:, 0], idx, x * l)
        np.add.at(self.buf[:, 1], idx, x * r)

    def reverb(self, seconds=2.6, wet=0.35, seed=3):
        """Convolve with decaying noise. Circular, so the tail wraps into the loop."""
        rng = np.random.default_rng(seed)
        m = int(seconds * self.sr)
        out = np.zeros_like(self.buf)
        for ch in range(2):
            ir = rng.standard_normal(m) * np.exp(-np.arange(m) / (seconds * 0.28 * self.sr))
            ir = onepole_lp(ir, self.sr, 3800)
            ir[: int(0.012 * self.sr)] = 0
            ir /= np.sqrt((ir ** 2).sum())
            padded = np.zeros(self.n)
            padded[:m] = ir
            out[:, ch] = np.fft.irfft(np.fft.rfft(self.buf[:, ch]) * np.fft.rfft(padded), self.n)
        self.buf = self.buf * (1 - wet * 0.4) + out * wet

    def finish(self, peak=0.7):
        self.buf -= self.buf.mean(axis=0)
        self.buf *= peak / np.abs(self.buf).max()
        return self.buf


def write_wav(path, data, sr):
    data = np.clip(data, -1, 1)
    pcm = (data * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1 if pcm.ndim == 1 else pcm.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def write_ogg(name, data):
    os.makedirs(OUT_MUSIC, exist_ok=True)
    tmp = os.path.join(OUT_MUSIC, name + ".tmp.wav")
    out = os.path.join(OUT_MUSIC, name + ".ogg")
    write_wav(tmp, data, SR)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3", out], check=True)
    os.remove(tmp)
    rms = 20 * np.log10(np.sqrt((data ** 2).mean()))
    print("wrote %s  %.1fs  peak %.2f  rms %.1f dB  %d KB" % (os.path.relpath(out, ROOT), len(data) / SR, np.abs(data).max(), rms, os.path.getsize(out) // 1024))


# ---------------------------------------------------------------- the soundtrack

CHORDS = {
    "I": ["G#2", "D#3", "G#3", "A#3"],    # G# with an open fifth, the teaser's drone
    "IV": ["C#3", "G#3", "C#4", "D#4"],
    "VII": ["F#2", "C#3", "F#3", "G#3"],
    "V": ["D#3", "A#3", "D#4", "G#3"],
    "i": ["D#2", "A#2", "D#3", "F#3"],    # the darker home for the Hands and the Overseer
    "iv": ["G#2", "D#3", "G#3", "C#4"],
    "VI": ["C#3", "G#3", "C#4", "F#3"],
}


def menu_theme():
    """The title: the teaser's drone and shimmer, with its chime motif played slowly."""
    bar = 8.0
    mix = Mix(8 * bar)
    for k, ch in enumerate(["I", "IV", "I", "V", "I", "VII", "IV", "I"]):
        mix.add(pad([2 * note(x) for x in CHORDS[ch]], bar + 3.0, SR), k * bar, 0.3)
        mix.add(pad([note(CHORDS[ch][0])], bar + 3.0, SR), k * bar, 0.07)
    for k in range(4):
        mix.add(shimmer(note("D#6"), 14.0, SR), k * 16.0 + 1.0, 0.075, -0.3)
        mix.add(shimmer(note("G#6"), 12.0, SR, 6.3), k * 16.0 + 4.0, 0.04, 0.4)
    # the teaser's motif (D#5 C#5 C#6 G#6 F#5 A#5 D#6), then answers that walk back home
    phrases = [
        [("D#5", 1.0), ("C#5", 2.5), ("C#6", 4.5), ("G#6", 5.5), ("F#5", 8.0), ("A#5", 10.0), ("D#6", 12.0)],
        [("G#5", 1.0), ("F#5", 2.5), ("D#5", 4.0), ("C#5", 6.5), ("A#4", 9.0), ("G#4", 11.5)],
        [("D#5", 1.0), ("C#5", 2.5), ("C#6", 4.5), ("A#5", 6.0), ("G#5", 8.0), ("F#5", 10.0), ("D#5", 12.5)],
        [("A#4", 1.5), ("C#5", 3.0), ("D#5", 4.5), ("G#5", 7.0), ("D#6", 9.5), ("G#5", 12.0)],
    ]
    for k, ph in enumerate(phrases):
        for i, (nm, at) in enumerate(ph):
            f = note(nm)
            soft = 0.5 if f > 1000 else 1.0
            mix.add(bell(f, 4.5, SR, 0.8, 1.6), k * 16.0 + at, 0.22 * soft, ((i % 3) - 1) * 0.35)
    mix.reverb(3.2, 0.45)
    return mix.finish(0.62)


def table_theme():
    """The match: a thumb-piano figure over a slow pulse."""
    beat = 60.0 / 80
    bar = 4 * beat
    bars = 20
    mix = Mix(bars * bar)
    prog = ["I", "I", "IV", "IV", "VII", "VII", "V", "V", "I", "I", "IV", "IV", "VII", "V", "I", "I", "IV", "VII", "V", "I"]
    figure = {
        "I": ["G#4", "D#5", "A#4", "D#5", "G#4", "D#5", "C#5", "D#5"],
        "IV": ["C#5", "G#5", "D#5", "G#5", "C#5", "G#5", "F#5", "G#5"],
        "VII": ["F#4", "C#5", "G#4", "C#5", "F#4", "C#5", "A#4", "C#5"],
        "V": ["D#4", "A#4", "G#4", "A#4", "D#4", "A#4", "C#5", "A#4"],
    }
    rng = np.random.default_rng(11)
    for b, ch in enumerate(prog):
        t0 = b * bar
        if b % 2 == 0:
            mix.add(pad([2 * note(x) for x in CHORDS[ch]], 2 * bar + 1.5, SR, 1.0, 1.5), t0, 0.2)
            mix.add(pad([note(CHORDS[ch][0])], 2 * bar + 1.5, SR, 1.0, 1.5), t0, 0.06)
        for k in range(8):
            if b >= 2 and (k % 2 == 0 or rng.random() < 0.72):
                f = note(figure[ch][k])
                mix.add(pluck(f, 0.9, SR, 0.3), t0 + k * beat / 2, 0.16 if k % 2 == 0 else 0.1, 0.25 if k % 2 else -0.25)
        for k in (0, 2):  # the pulse: a low, round thump
            n = int(0.22 * SR)
            t = np.arange(n) / SR
            thump = np.sin(TAU * (52 + 30 * np.exp(-t / 0.03)) * t) * np.exp(-t / 0.09)
            mix.add(fade(thump, SR, 0.002, 0.02), t0 + k * beat, 0.17)
        if b >= 4:
            for k in (1, 3):  # a shaker on the off beats
                n = int(0.05 * SR)
                sh = bandpass(rng.standard_normal(n), SR, 5000, 11000) * env_exp(n, SR, 0.012)
                mix.add(sh, t0 + k * beat + beat / 2, 0.06, 0.5)
        if b % 4 == 3:  # a chime from the teaser's motif at the end of each line
            f = note(["D#5", "C#6", "F#5", "A#5", "D#6"][(b // 4) % 5])
            mix.add(bell(f, 3.5, SR, 0.8, 1.3), t0 + 2 * beat, 0.15, -0.4)
    mix.reverb(2.2, 0.3, 5)
    return mix.finish(0.62)


def high_theme():
    """Against a Hand or the Overseer: the same scale turned minor, lower and more urgent."""
    beat = 60.0 / 96
    bar = 4 * beat
    bars = 24
    mix = Mix(bars * bar)
    prog = ["i", "i", "iv", "i", "VI", "VI", "iv", "V"] * 3
    rng = np.random.default_rng(23)
    for b, ch in enumerate(prog):
        t0 = b * bar
        chord = [note(x) for x in CHORDS[ch]]
        if b % 2 == 0:
            mix.add(pad([2 * f for f in chord], 2 * bar + 1.2, SR, 0.8, 1.2), t0, 0.2)
            mix.add(pad(chord[:1], 2 * bar + 1.2, SR, 0.8, 1.2), t0, 0.08)
            n = int((2 * bar + 0.5) * SR)  # a darker, reedier layer under the pad
            t = np.arange(n) / SR
            low = sum(np.sin(TAU * chord[0] * h * t) / h for h in (1, 2, 3, 4, 5))
            low = onepole_lp(low, SR, 420) * np.sin(np.linspace(0, np.pi, n)) ** 0.7
            mix.add(low, t0, 0.045)
        for k in range(4):  # the pulse on every beat, heavier on one
            n = int(0.2 * SR)
            t = np.arange(n) / SR
            thump = np.sin(TAU * (48 + 34 * np.exp(-t / 0.025)) * t) * np.exp(-t / 0.08)
            mix.add(fade(thump, SR, 0.002, 0.02), t0 + k * beat, 0.2 if k == 0 else 0.1)
        root = chord[2]
        for k in range(8):  # a restless figure: root, fifth, octave
            if k in (0, 3, 6) or rng.random() < 0.35:
                f = root * (1.0, 1.5, 2.0, 1.5, 1.0, 2.0, 1.5, 1.0)[k]
                mix.add(pluck(2 * f, 0.7, SR, 0.22), t0 + k * beat / 2, 0.13, 0.3 if k % 2 else -0.3)
        if b % 4 == 2:
            for j, nm in enumerate(["D#5", "F#5", "G#5"] if (b // 4) % 2 == 0 else ["A#5", "G#5", "F#5"]):
                mix.add(bell(note(nm), 3.0, SR, 1.0, 1.1), t0 + j * beat, 0.15, 0.4 - j * 0.4)
        if b % 8 == 7:  # a rising noise swell into the next line
            n = int(bar * SR)
            sw = bandpass(rng.standard_normal(n), SR, 900, 6000) * np.linspace(0, 1, n) ** 3
            mix.add(sw, t0, 0.03)
    mix.reverb(2.4, 0.32, 9)
    return mix.finish(0.62)


# ---------------------------------------------------------------- the effects

def sfx_set():
    sr = SR_SFX
    rng = np.random.default_rng(42)
    out = {}

    def noise(dur):
        return rng.standard_normal(int(dur * sr))

    def tone(f0, dur, f1=None, decay=None, shape="sine"):
        n = int(dur * sr)
        t = np.arange(n) / sr
        f = np.full(n, float(f0)) if f1 is None else f0 + (f1 - f0) * (1 - np.exp(-t / (dur * 0.25)))
        ph = TAU * np.cumsum(f) / sr
        x = np.sin(ph) if shape == "sine" else (2 / np.pi) * np.arcsin(np.sin(ph))
        return x * (np.exp(-t / decay) if decay else 1.0)

    def mixdown(parts, dur):
        n = int(dur * sr)
        buf = np.zeros(n)
        for x, at, g in parts:
            i = int(at * sr)
            m = min(len(x), n - i)
            if m > 0:
                buf[i:i + m] += x[:m] * g
        return fade(buf, sr, 0.002, 0.015)

    def paper(dur, lo, hi, decay):
        n = int(dur * sr)
        return bandpass(noise(dur), sr, lo, hi) * env_exp(n, sr, decay)

    gs5, ds6, gs6 = note("G#5"), note("D#6"), note("G#6")

    # interface
    out["hover"] = mixdown([(tone(gs6, 0.03, decay=0.01), 0, 0.18)], 0.04)
    out["click"] = mixdown([(tone(260, 0.07, 150, 0.025), 0, 0.7), (paper(0.02, 1500, 6000, 0.004), 0, 0.25)], 0.09)
    out["back"] = mixdown([(tone(200, 0.08, 110, 0.03), 0, 0.6), (paper(0.02, 900, 4000, 0.005), 0, 0.2)], 0.1)
    out["select"] = mixdown([(tone(note("D#5"), 0.09, decay=0.035), 0, 0.4), (tone(note("G#5"), 0.1, decay=0.04), 0.03, 0.3)], 0.14)
    out["tick"] = mixdown([(tone(note("G#6"), 0.025, decay=0.008, shape="tri"), 0, 0.22)], 0.03)
    # cards
    out["card"] = mixdown([(paper(0.09, 1800, 9000, 0.022), 0, 0.5), (tone(420, 0.05, 260, 0.02), 0, 0.12)], 0.11)
    out["place"] = mixdown([(tone(150, 0.09, 90, 0.03), 0, 0.6), (paper(0.05, 700, 5000, 0.012), 0, 0.35)], 0.11)
    out["flip"] = mixdown([(paper(0.07, 2500, 10000, 0.02) * np.linspace(0.3, 1, int(0.07 * sr)), 0, 0.45)], 0.08)
    out["whoosh"] = mixdown([(bandpass(noise(0.26), sr, 500, 5000) * np.sin(np.linspace(0, np.pi, int(0.26 * sr))) ** 2, 0, 0.35)], 0.27)
    out["deal"] = mixdown([(paper(0.06, 2200, 9500, 0.014), 0, 0.42)], 0.07)
    # the scoring ladder: one bell, pitched up the scale by the game
    out["note"] = mixdown([(bell(note("G#4"), 0.6, sr, 1.1, 0.26), 0, 0.55)], 0.6)
    out["pluck"] = mixdown([(pluck(note("G#4"), 0.3, sr, 0.12), 0, 0.6)], 0.3)
    # the duel
    out["hit"] = mixdown([(tone(120, 0.16, 55, 0.05), 0, 0.8), (paper(0.06, 400, 3500, 0.015), 0, 0.5)], 0.18)
    out["swat"] = mixdown([(bandpass(noise(0.1), sr, 1200, 8000) * np.linspace(1, 0, int(0.1 * sr)) ** 2, 0, 0.4),
                           (tone(900, 0.06, 300, 0.02), 0.01, 0.2)], 0.12)
    clink = sum(tone(f, 0.35, decay=d) * a for f, d, a in ((2093, 0.09, 1.0), (3360, 0.06, 0.6), (5270, 0.04, 0.35), (1244, 0.12, 0.3)))
    out["goblet"] = mixdown([(clink, 0, 0.3), (clink, 0.11, 0.13), (clink, 0.19, 0.06), (paper(0.02, 3000, 9000, 0.004), 0, 0.2)], 0.45)
    out["pass"] = mixdown([(tone(note("G#3"), 0.2, note("D#3"), 0.08), 0, 0.4)], 0.22)
    out["enemy"] = mixdown([(tone(note("D#3"), 0.14, note("A#2"), 0.06, "tri"), 0, 0.5), (paper(0.05, 500, 3000, 0.02), 0, 0.2)], 0.17)
    out["reveal"] = mixdown([(bell(note("D#5"), 0.3, sr, 0.8, 0.14), 0, 0.35), (bell(note("G#5"), 0.4, sr, 0.8, 0.18), 0.07, 0.35)], 0.5)
    out["capture"] = mixdown([(bell(note("C#5"), 0.3, sr, 1.0, 0.16), 0, 0.4), (bell(note("A#4"), 0.3, sr, 1.0, 0.16), 0.1, 0.4),
                              (bell(note("D#4"), 0.6, sr, 1.0, 0.3), 0.2, 0.45), (tone(90, 0.2, 50, 0.07), 0.2, 0.5)], 0.85)
    out["rescue"] = mixdown([(bell(note("G#4"), 0.3, sr, 0.9, 0.16), 0, 0.38), (bell(note("D#5"), 0.3, sr, 0.9, 0.16), 0.09, 0.38),
                             (bell(note("G#5"), 0.7, sr, 0.9, 0.34), 0.18, 0.42)], 0.9)
    flame = bandpass(noise(0.55), sr, 300, 4500) * (np.linspace(0, 1, int(0.55 * sr)) ** 0.5) * env_exp(int(0.55 * sr), sr, 0.22)
    out["hot"] = mixdown([(flame, 0, 0.45), (bell(note("D#5"), 0.5, sr, 1.0, 0.2), 0.05, 0.25), (bell(note("A#5"), 0.5, sr, 1.0, 0.2), 0.13, 0.22)], 0.6)
    out["burn"] = mixdown([(flame, 0, 0.5), (tone(180, 0.4, 70, 0.14, "tri"), 0, 0.2)], 0.56)
    # the ledger
    out["stamp"] = mixdown([(tone(140, 0.2, 50, 0.05), 0, 0.9), (paper(0.05, 300, 2500, 0.012), 0, 0.6), (tone(note("G#3"), 0.25, decay=0.09), 0.01, 0.15)], 0.27)
    out["coin"] = mixdown([(bell(gs6, 0.25, sr, 0.6, 0.09), 0, 0.3), (bell(gs6 * 1.5, 0.3, sr, 0.6, 0.11), 0.06, 0.28)], 0.38)
    out["chip"] = out["coin"]
    out["level"] = mixdown([(bell(note(nm), 0.9, sr, 0.9, 0.4), i * 0.08, 0.3) for i, nm in enumerate(["G#4", "D#5", "G#5", "A#5", "D#6"])], 1.3)
    # the match and the festival
    out["round"] = mixdown([(bell(note("G#3"), 1.0, sr, 1.2, 0.5), 0, 0.5), (bell(note("D#4"), 1.0, sr, 0.8, 0.45), 0.02, 0.25)], 1.05)
    out["slam"] = mixdown([(tone(110, 0.3, 45, 0.09), 0, 0.9), (paper(0.12, 200, 2500, 0.03), 0, 0.6)], 0.34)
    crowd = bandpass(noise(0.8), sr, 600, 3200) * np.sin(np.linspace(0, np.pi, int(0.8 * sr))) ** 1.5
    out["cheer"] = mixdown([(crowd, 0, 0.22), (bell(note("G#5"), 0.4, sr, 0.8, 0.2), 0.05, 0.16), (bell(note("D#6"), 0.5, sr, 0.8, 0.22), 0.14, 0.14)], 0.82)
    out["win"] = mixdown([(bell(note(nm), 1.2, sr, 0.9, 0.5), i * 0.11, 0.3) for i, nm in enumerate(["G#4", "A#4", "D#5", "G#5", "D#6"])]
                         + [(crowd, 0.1, 0.12)], 1.7)
    out["lose"] = mixdown([(bell(note(nm), 1.3, sr, 1.0, 0.55), i * 0.19, 0.32) for i, nm in enumerate(["D#5", "C#5", "A#4", "D#4"])]
                          + [(tone(70, 0.5, 45, 0.2), 0.57, 0.4)], 1.9)
    return out


def main(argv):
    what = argv[1] if len(argv) > 1 else "all"
    if what in ("all", "music"):
        write_ogg("menu", menu_theme())
        write_ogg("table", table_theme())
        write_ogg("high", high_theme())
    if what in ("all", "sfx"):
        os.makedirs(OUT_SFX, exist_ok=True)
        total = 0
        for name, data in sorted(sfx_set().items()):
            peak = np.abs(data).max()
            data = data * (0.8 / peak) if peak > 0.8 else data
            path = os.path.join(OUT_SFX, name + ".wav")
            write_wav(path, data, SR_SFX)
            total += os.path.getsize(path)
        print("wrote %d effects to %s (%d KB)" % (len(sfx_set()), os.path.relpath(OUT_SFX, ROOT), total // 1024))


if __name__ == "__main__":
    main(sys.argv)
