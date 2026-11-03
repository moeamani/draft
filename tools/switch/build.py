#!/usr/bin/env python3
"""Build Draft for Nintendo Switch homebrew (LÖVE Potion).

    python3 tools/switch/build.py --lovepotion path/to/lovepotion.nro

writes
    dist/switch/game.love              the game (main.lua, conf.lua, src/, assets/)
    dist/switch/Draft/Draft.nro        LÖVE Potion fused with the game, with Draft's icon and title
                                       (copy the Draft folder to sdmc:/switch/ on the SD card)

Optional NSP (a Home-menu forwarder that launches the NRO above), built on your machine:

    python3 tools/switch/build.py --lovepotion lovepotion.nro --nsp \\
        --hacbrewpack path/to/hacbrewpack --keys path/to/prod.keys --forwarder path/to/forwarder-exefs

You supply hacBrewPack, a forwarder exefs (`main` and `main.npdm`) and keys dumped from your own
console with Lockpick_RCM. Nothing here downloads or contains any Nintendo keys. See docs/SWITCH.md.
"""
import argparse
import io
import os
import re
import shutil
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import nro  # noqa: E402

GAME_FILES = ["main.lua", "conf.lua"]
GAME_DIRS = ["src", "assets"]
SKIP = re.compile(r"(^|/)(\.|__pycache__)|\.(psd|fig|xcf|kra)$")

TITLE = "Draft"
AUTHOR = "Draft"
NRO_PATH = "sdmc:/switch/Draft/Draft.nro"
DEFAULT_TITLE_ID = "05d4a7f0c1e2a000"


def version():
    """Display version from git (e.g. 0.3.0-12-gabc1234), or 1.0.0."""
    try:
        out = subprocess.run(["git", "describe", "--tags", "--always"], cwd=ROOT, capture_output=True, text=True, check=True)
        v = out.stdout.strip()
        return v if re.match(r"^\d", v) else "1.0.0+" + v
    except (OSError, subprocess.CalledProcessError):
        return "1.0.0"


def make_love():
    """Zip the game the way LÖVE expects: main.lua at the root of the archive."""
    buf = io.BytesIO()
    count = 0
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in GAME_FILES:
            z.write(os.path.join(ROOT, name), name)
            count += 1
        for d in GAME_DIRS:
            for base, dirs, files in os.walk(os.path.join(ROOT, d)):
                dirs.sort()
                for f in sorted(files):
                    full = os.path.join(base, f)
                    rel = os.path.relpath(full, ROOT).replace(os.sep, "/")
                    if SKIP.search(rel):
                        continue
                    # PNGs and fonts are already compressed
                    kind = zipfile.ZIP_STORED if f.endswith((".png", ".jpg", ".ogg")) else zipfile.ZIP_DEFLATED
                    z.write(full, rel, compress_type=kind)
                    count += 1
    missing = [p for p in ("assets/switch/stage-menu-felt.png", "assets/switch/smear-blue.png") if not os.path.exists(os.path.join(ROOT, p))]
    if missing:
        sys.exit("baked Switch assets are missing (%s): run python3 tools/switch/bake_assets.py" % ", ".join(missing))
    return buf.getvalue(), count


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    print("wrote %s (%d KB)" % (os.path.relpath(path, ROOT), (len(data) + 1023) // 1024))


def build_nsp(args, nacp, icon, out_dir):
    """Lay out exefs/romfs/control for hacBrewPack and run it. Untested on hardware: see docs/SWITCH.md."""
    for need, what in ((args.hacbrewpack, "--hacbrewpack"), (args.keys, "--keys"), (args.forwarder, "--forwarder")):
        if not need:
            sys.exit("--nsp needs %s" % what)
    exe = shutil.which(args.hacbrewpack) or args.hacbrewpack
    if not os.path.isfile(exe):
        sys.exit("hacBrewPack not found at %s" % args.hacbrewpack)
    if not os.path.isfile(args.keys):
        sys.exit("keys file not found at %s (dump prod.keys from your own console)" % args.keys)
    for f in ("main", "main.npdm"):
        if not os.path.isfile(os.path.join(args.forwarder, f)):
            sys.exit("the forwarder folder needs exefs files main and main.npdm (missing %s)" % f)
    if not re.fullmatch(r"0[0-9a-f]{12}000", args.title_id):
        sys.exit("--title-id must be 16 hex digits ending in 000, e.g. %s" % DEFAULT_TITLE_ID)

    work = os.path.join(out_dir, "nsp-work")
    shutil.rmtree(work, ignore_errors=True)
    exefs, romfs, control = (os.path.join(work, d) for d in ("exefs", "romfs", "control"))
    shutil.copytree(args.forwarder, exefs)
    os.makedirs(romfs)
    os.makedirs(control)
    # the usual forwarder convention: RomFS tells it which NRO to chain-load
    with open(os.path.join(romfs, "nextNroPath"), "w") as f:
        f.write(NRO_PATH)
    with open(os.path.join(romfs, "nextArgv"), "w") as f:
        f.write(NRO_PATH)
    with open(os.path.join(control, "control.nacp"), "wb") as f:
        f.write(nacp)
    with open(os.path.join(control, "icon_AmericanEnglish.dat"), "wb") as f:
        f.write(icon)
    cmd = [exe, "-k", os.path.abspath(args.keys), "--titleid", args.title_id, "--exefsdir", "exefs",
           "--romfsdir", "romfs", "--controldir", "control", "--nologo"]
    if args.keygeneration:
        cmd += ["--keygeneration", str(args.keygeneration)]
    print("running:", " ".join(cmd))
    subprocess.run(cmd, cwd=work, check=True)
    produced = os.path.join(work, "hacbrewpack_nsp", args.title_id + ".nsp")
    if not os.path.isfile(produced):
        sys.exit("hacBrewPack finished but %s was not produced" % produced)
    final = os.path.join(out_dir, "Draft-%s.nsp" % args.title_id)
    shutil.move(produced, final)
    print("wrote %s" % os.path.relpath(final, ROOT))
    print("The NSP only launches %s, so copy the Draft folder to the SD card too." % NRO_PATH)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lovepotion", help="lovepotion.nro from a LÖVE Potion 3.x release (lovebrew/lovepotion on GitHub)")
    ap.add_argument("--love-only", action="store_true", help="only build dist/switch/game.love")
    ap.add_argument("--out", default=os.path.join(ROOT, "dist", "switch"))
    ap.add_argument("--version", default=None, help="display version (default: from git)")
    ap.add_argument("--nsp", action="store_true", help="also build an NSP forwarder with hacBrewPack")
    ap.add_argument("--hacbrewpack")
    ap.add_argument("--keys", help="prod.keys dumped from your own console")
    ap.add_argument("--forwarder", help="folder with a forwarder's exefs: main and main.npdm")
    ap.add_argument("--title-id", default=DEFAULT_TITLE_ID)
    ap.add_argument("--keygeneration", type=int)
    args = ap.parse_args()

    love, count = make_love()
    write(os.path.join(args.out, "game.love"), love)
    print("  %d files" % count)
    if args.love_only:
        return
    if not args.lovepotion:
        ap.error("--lovepotion is required (or pass --love-only)")
    with open(args.lovepotion, "rb") as f:
        base = f.read()
    with open(os.path.join(HERE, "icon.jpg"), "rb") as f:
        icon = f.read()
    ver = args.version or version()
    fused = nro.fuse(base, love, icon=icon, title=TITLE, author=AUTHOR, version=ver)
    write(os.path.join(args.out, "Draft", "Draft.nro"), fused)
    print("  " + nro.describe(fused).replace("\n", "\n  "))
    if args.nsp:
        nacp = nro.parse(fused)["nacp"]
        build_nsp(args, nacp, icon, args.out)


if __name__ == "__main__":
    try:
        main()
    except nro.NroError as e:
        sys.exit("error: %s" % e)
