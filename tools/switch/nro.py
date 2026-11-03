#!/usr/bin/env python3
"""Read and repack Nintendo Switch homebrew executables (.nro) for LÖVE Potion games.

A fused LÖVE Potion game is the stock lovepotion.nro with the game's .love zip appended
(LÖVE Potion's own build does `cat lovepotion.nro game.love`). Before appending, this tool
rewrites the NRO's asset section so the Homebrew Menu shows the game's own icon, title, author
and version. LÖVE Potion's RomFS (its precompiled shaders) is kept as it is.

    python3 tools/switch/nro.py info Draft.nro
    python3 tools/switch/nro.py selftest

Layout (see switchbrew.org/wiki/NRO):
    0x10  "NRO0" magic        0x18  u32 size of the executable part
    size  "ASET" header: u32 version, then (u64 offset, u64 size) for icon, NACP and RomFS,
          offsets relative to the start of the ASET header
    NACP  0x4000 bytes: 16 x (name 0x200, author 0x100), display version at 0x3060
"""
import io
import struct
import sys
import zipfile

ASET_HEADER = struct.Struct("<4sI QQ QQ QQ")  # 0x38 bytes
NACP_SIZE = 0x4000
NACP_TITLE = 0x300
NACP_NAME, NACP_AUTHOR = 0x200, 0x100
NACP_VERSION, NACP_VERSION_LEN = 0x3060, 0x10


class NroError(Exception):
    pass


def parse(data):
    """Split an NRO into its parts. Returns a dict with exe, icon, nacp, romfs and trailing bytes."""
    if len(data) < 0x80 or data[0x10:0x14] != b"NRO0":
        raise NroError("not an NRO file (no NRO0 magic)")
    size = struct.unpack_from("<I", data, 0x18)[0]
    if size > len(data):
        raise NroError("NRO header claims %d bytes but the file has %d" % (size, len(data)))
    out = {"exe": data[:size], "icon": b"", "nacp": b"", "romfs": b"", "trailing": data[size:], "aset": False}
    if len(data) >= size + ASET_HEADER.size and data[size:size + 4] == b"ASET":
        magic, version, io_, is_, no, ns, ro, rs = ASET_HEADER.unpack_from(data, size)
        out.update(aset=True, aset_version=version)
        end = ASET_HEADER.size
        for key, off, sz in (("icon", io_, is_), ("nacp", no, ns), ("romfs", ro, rs)):
            if sz:
                if size + off + sz > len(data):
                    raise NroError("%s runs past the end of the file" % key)
                out[key] = data[size + off:size + off + sz]
                end = max(end, off + sz)
        out["trailing"] = data[size + end:]
    return out


def build_aset(icon, nacp, romfs, version=0):
    """Pack icon, NACP and RomFS into a fresh ASET block (RomFS kept 16-byte aligned)."""
    off = ASET_HEADER.size
    parts, table = [], []
    for blob, align in ((icon, 1), (nacp, 1), (romfs, 16)):
        if blob:
            pad = (-off) % align
            parts.append(b"\0" * pad)
            off += pad
            table.append((off, len(blob)))
            parts.append(blob)
            off += len(blob)
        else:
            table.append((0, 0))
    header = ASET_HEADER.pack(b"ASET", version, *[v for pair in table for v in pair])
    return header + b"".join(parts)


def _cstr(blob, start, length):
    raw = blob[start:start + length]
    return raw.split(b"\0", 1)[0].decode("utf-8", "replace")


def nacp_info(nacp):
    if len(nacp) < NACP_SIZE:
        return {}
    return {
        "title": _cstr(nacp, 0, NACP_NAME),
        "author": _cstr(nacp, NACP_NAME, NACP_AUTHOR),
        "version": _cstr(nacp, NACP_VERSION, NACP_VERSION_LEN),
    }


def _put(buf, start, length, text):
    raw = text.encode("utf-8")[:length - 1]
    buf[start:start + length] = raw + b"\0" * (length - len(raw))


def patch_nacp(nacp, title, author, version):
    """Set every language's title and author, and the display version. Other fields are kept."""
    buf = bytearray(nacp if len(nacp) >= NACP_SIZE else b"\0" * NACP_SIZE)
    for i in range(16):
        base = i * NACP_TITLE
        _put(buf, base, NACP_NAME, title)
        _put(buf, base + NACP_NAME, NACP_AUTHOR, author)
    _put(buf, NACP_VERSION, NACP_VERSION_LEN, version)
    return bytes(buf)


def check_icon(icon):
    """hbmenu wants a 256x256 baseline JPEG."""
    if icon[:2] != b"\xff\xd8":
        raise NroError("the icon must be a JPEG")
    i = 2
    while i + 9 < len(icon):
        if icon[i] != 0xFF:
            raise NroError("malformed JPEG icon")
        marker = icon[i + 1]
        seglen = struct.unpack(">H", icon[i + 2:i + 4])[0]
        if marker in (0xC0, 0xC1):
            h, w = struct.unpack(">HH", icon[i + 5:i + 9])
            if (w, h) != (256, 256):
                raise NroError("the icon must be 256x256 (got %dx%d)" % (w, h))
            return
        if marker == 0xC2:
            raise NroError("the icon must be a baseline (not progressive) JPEG")
        i += 2 + seglen
    raise NroError("no frame header in the JPEG icon")


def fuse(base, love, icon=None, title=None, author=None, version=None):
    """Return the bytes of a fused NRO: base executable, new ASET block, then the .love zip."""
    parts = parse(base)
    if parts["trailing"]:
        raise NroError("the base NRO already has data appended (is it already fused?)")
    if not zipfile.is_zipfile(io.BytesIO(love)):
        raise NroError("the game is not a zip (.love) file")
    nacp = parts["nacp"]
    if title or author or version:
        info = nacp_info(nacp)
        nacp = patch_nacp(nacp, title or info.get("title", ""), author or info.get("author", ""), version or info.get("version", ""))
    if icon is not None:
        check_icon(icon)
    else:
        icon = parts["icon"]
    return parts["exe"] + build_aset(icon, nacp, parts["romfs"], parts.get("aset_version", 0)) + love


def describe(data):
    parts = parse(data)
    lines = ["executable: %d bytes" % len(parts["exe"])]
    if parts["aset"]:
        lines.append("icon: %d bytes, NACP: %d bytes, RomFS: %d bytes" % (len(parts["icon"]), len(parts["nacp"]), len(parts["romfs"])))
        for k, v in nacp_info(parts["nacp"]).items():
            lines.append("%s: %s" % (k, v))
    else:
        lines.append("no ASET block (no icon, NACP or RomFS)")
    tail = parts["trailing"]
    if tail:
        try:
            with zipfile.ZipFile(io.BytesIO(tail)) as z:
                names = z.namelist()
            lines.append("fused game: %d bytes, %d files%s" % (len(tail), len(names), ", has main.lua" if "main.lua" in names else ", NO main.lua"))
        except zipfile.BadZipFile:
            lines.append("trailing data: %d bytes (not a zip)" % len(tail))
    return "\n".join(lines)


# ------------------------------------------------------------------ self-test

def _fake_nro():
    """A synthetic NRO with the real header and ASET layout (the code is just zeros)."""
    exe = bytearray(0x1000)
    exe[0x10:0x14] = b"NRO0"
    struct.pack_into("<I", exe, 0x18, len(exe))
    icon = b"\xff\xd8\xff\xc0\x00\x11\x08\x01\x00\x01\x00\x03" + b"\0" * 40 + b"\xff\xd9"
    nacp = patch_nacp(b"", "LÖVE Potion", "lovebrew", "3.0.0")
    romfs = b"ROMFS" * 100
    return bytes(exe) + build_aset(icon, nacp, romfs), icon, romfs


def selftest():
    base, old_icon, romfs = _fake_nro()
    p = parse(base)
    assert p["aset"] and p["icon"] == old_icon and p["romfs"] == romfs and not p["trailing"]
    assert nacp_info(p["nacp"])["title"] == "LÖVE Potion"

    love = io.BytesIO()
    with zipfile.ZipFile(love, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("main.lua", "function love.draw() end\n")
        z.writestr("conf.lua", "function love.conf(t) end\n")
    love = love.getvalue()
    icon = b"\xff\xd8\xff\xc0\x00\x11\x08\x01\x00\x01\x00\x03" + b"\x01" * 300 + b"\xff\xd9"
    out = fuse(base, love, icon=icon, title="Draft", author="Draft team", version="1.2.3")

    q = parse(out)
    assert q["exe"] == p["exe"], "executable changed"
    assert q["icon"] == icon, "icon not replaced"
    assert q["romfs"] == romfs, "RomFS changed"
    info = nacp_info(q["nacp"])
    assert info == {"title": "Draft", "author": "Draft team", "version": "1.2.3"}, info
    assert q["nacp"][NACP_TITLE * 15:NACP_TITLE * 15 + 5] == b"Draft", "not every language was patched"
    assert q["trailing"] == love, "game zip not appended intact"
    # the fused file opens as a zip from the front too (how PhysFS mounts it on the console)
    with zipfile.ZipFile(io.BytesIO(out)) as z:
        assert z.read("main.lua").startswith(b"function love.draw")
    for bad, why in ((b"\xff\xd8\xff\xc2\x00\x11\x08\x01\x00\x01\x00\x03" + b"\0" * 20, "progressive"),
                     (b"\xff\xd8\xff\xc0\x00\x11\x08\x00\x80\x00\x80\x03" + b"\0" * 20, "256x256"),
                     (b"PNG", "JPEG")):
        try:
            fuse(base, love, icon=bad)
            raise AssertionError("bad icon accepted: " + why)
        except NroError as e:
            assert why in str(e), e
    try:
        fuse(out, love)
        raise AssertionError("fusing twice was allowed")
    except NroError:
        pass
    print("nro.py self-test passed")


def main(argv):
    if len(argv) >= 2 and argv[0] == "info":
        for path in argv[1:]:
            with open(path, "rb") as f:
                print(path)
                print("  " + describe(f.read()).replace("\n", "\n  "))
        return 0
    if argv == ["selftest"]:
        selftest()
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except NroError as e:
        sys.exit("error: %s" % e)
