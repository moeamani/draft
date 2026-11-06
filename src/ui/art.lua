-- Cat illustrations as clean pixel art.
--
-- Every picture is painted once at its real pixel size (a card's art is 50x48) with no
-- anti-aliasing, dither or blur. Bigger views are exact integer enlargements, so the pixels stay
-- crisp and chunky. A picture has three layers:
--   bg   a backdrop for the cat's coat in a few flat bands: an Ember hall, a Tide shore, a Gilt
--        sunburst, a Shadow night (blood red for the Four Hands)
--   fig  the cat: shoulders and outfit, ears, a two-tone head, its fur pattern, headwear and
--        props, then the face from hand-placed pixel stamps (eyes, nose, mouth). Stray single
--        pixels are cleaned up, and the figure gets a 1px dark outline.
--   fx   what glows: whiskers, orbs, flames, sparkles, notes, runes (no outline)
-- Shapes are placed in a 100-unit-wide logical space and snapped to the pixel grid; the stamps
-- are in real pixels. Results are cached.
local rngm = require("src.core.rng")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
local hex = theme.hex
local C = theme.c
local PI = math.pi
local floor = math.floor

-- ---------------------------------------------------------------- palette (hue-shifted ramps)

local OUTLINE = hex("#140f1c")
local FUR = {
  ember = { dark = hex("#b4502a"), base = hex("#e47e3a"), light = hex("#f8b26a"), stripe = hex("#8a3216"), muzzle = hex("#fde6c8") },
  tide = { dark = hex("#56677e"), base = hex("#8195ab"), light = hex("#b8c8d8"), stripe = hex("#45536c"), muzzle = hex("#e6ecf2") },
  gilt = { dark = hex("#bf9145"), base = hex("#eac67e"), light = hex("#fae8bc"), stripe = hex("#a7772e"), muzzle = hex("#fff6e2") },
  shadow = { dark = hex("#1c1f2b"), base = hex("#343a49"), light = hex("#58617a"), stripe = hex("#12141c"), muzzle = hex("#4a5163") },
  cream = { dark = hex("#cbb99a"), base = hex("#f1e6d2"), light = hex("#fffaf0"), stripe = hex("#7a5a40"), muzzle = hex("#fffdf8") },
}
local PATTERNS = {
  ember = { "tabby", "tabby", "solid", "tux", "patch" },
  tide = { "solid", "tabby", "smoke", "tux" },
  gilt = { "solid", "tabby", "points", "fluff" },
  shadow = { "solid", "solid", "tux", "smoke" },
}
local EYE = {
  gold = hex("#f2c230"), green = hex("#8ed34e"), blue = hex("#5cc6ff"), copper = hex("#ec8a32"),
  red = hex("#ff3b30"), violet = hex("#c48cff"), cyan = hex("#47e7fd"),
}
local EYES_BY_COAT = {
  ember = { "green", "gold", "copper" }, tide = { "gold", "copper", "green" },
  gilt = { "blue", "green", "gold" }, shadow = { "gold", "green", "gold" },
}
local PINK, PINKD = hex("#f4929c"), hex("#c45f6e")
local STEEL = { deep = hex("#3a4250"), dark = hex("#5d6879"), base = hex("#9aa7b9"), light = hex("#d8e2ee") }
local GOLD = { dark = hex("#8f6a06"), base = hex("#e2b022"), light = hex("#ffe27a") }
local WOOD, WOODD = hex("#8a5a32"), hex("#53351c")
local CLOTH = { ember = hex("#c8382c"), tide = hex("#2471fc"), gilt = hex("#d3a200"), shadow = hex("#24503c"), none = hex("#24503c") }
local ROBES = { hex("#2471fc"), hex("#c8382c"), hex("#24503c"), hex("#3b3f8f"), hex("#16352a") }
local WHITE = hex("#ffffff")

local BG = {
  ember = { hex("#5a1d12"), hex("#3e130c"), hex("#260b07"), glow = hex("#ff8a3a") },
  tide = { hex("#164a80"), hex("#0f3460"), hex("#081f3c"), glow = hex("#5cb8ff"), accent = hex("#7fd8ff") },
  gilt = { hex("#6a4e06"), hex("#4a3604"), hex("#2a1e02"), glow = hex("#ffd34a") },
  shadow = { hex("#1d4434"), hex("#122b21"), hex("#07130e"), glow = hex("#47e7fd") },
  menace = { hex("#4a0a0a"), hex("#2c0505"), hex("#140202"), glow = hex("#ff3b30"), accent = hex("#ff8a3a") },
}

-- ---------------------------------------------------------------- drawing helpers

local K = 0.5 -- output pixels per logical unit (set per picture)
local function snap(v) return floor(v * K + 0.5) / K end
local function px(n) return (n or 1) / K end -- n output pixels, in logical units

local function col(c, a) lg.setColor(c[1], c[2], c[3], a or c[4] or 1) end
local function ell(x, y, rx, ry, c, rot)
  col(c)
  x, y = snap(x), snap(y)
  rx, ry = math.max(px(0.5), rx), math.max(px(0.5), ry)
  if rot and rot ~= 0 then
    lg.push(); lg.translate(x, y); lg.rotate(rot)
    lg.ellipse("fill", 0, 0, rx, ry, 32)
    lg.pop()
  else
    lg.ellipse("fill", x, y, rx, ry, 32)
  end
end
local function poly(c, ...) col(c); lg.polygon("fill", ...) end -- convex shapes only
local function rect(c, x, y, w, h, a)
  col(c, a)
  lg.rectangle("fill", snap(x), snap(y), math.max(px(), snap(w)), math.max(px(), snap(h)))
end
local function line(c, n, ...) -- n: thickness in output pixels
  col(c); lg.setLineWidth(px(n)); lg.line(...); lg.setLineWidth(1)
end
local function mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, 1 } end

-- A pixel stamp: rows of characters, each one output pixel, looked up in pal ("." is empty).
-- (x, y) is the stamp's top-left corner in logical units; flip mirrors it horizontally.
local function stamp(x, y, rows, pal, flip)
  x, y = snap(x), snap(y)
  local p = px()
  for j, row in ipairs(rows) do
    local n = #row
    for i = 1, n do
      local c = pal[row:sub(i, i)]
      if c then
        col(c)
        local ii = flip and (n - i) or (i - 1)
        lg.rectangle("fill", x + ii * p, y + (j - 1) * p, p, p)
      end
    end
  end
end

-- flat posterised bands instead of a gradient
local function bands(w, h, cols)
  local n = #cols
  for i = 1, n do
    local y0 = snap((i - 1) / n * h)
    rect(cols[i], 0, y0, w, h - y0 + px())
  end
end

-- a glow as a few flat rings
local function glow(x, y, r, c, a, rings)
  rings = rings or 3
  for k = 1, rings do
    col(c, a * 0.4)
    lg.circle("fill", snap(x), snap(y), r * (1 - (k - 1) / rings), 32)
  end
end

-- a two-tone piece: dark underneath, base shifted up-left, so the shadow falls bottom-right
local function shaded(x, y, rx, ry, R, rot)
  ell(x, y, rx, ry, R.dark, rot)
  ell(x - px(), y - px(), rx - px(), ry - px(), R.base, rot)
end

-- ---------------------------------------------------------------- stamps

local EYES = {
  calm = { ".kkk.", "kwcck", "kcpck", "kdpdk", ".kkk." },
  wide = { ".kkk.", "kwppk", "kpppk", "kdppk", ".kkk." },
  smug = { ".....", "kkkkk", "kcpck", ".kkk.", "....." },
  fierce = { "kk...", "..kkk", ".kcpk", "kdcpk", ".kkk." },
  happy = { ".....", ".kkk.", "k...k", ".....", "....." },
  menace = { "kk...", "..kkk", ".kcpk", "kccpk", ".kkk." },
  patch = { "kkkkk", "kkkkk", "kkkkk", "kkkkk", ".kkk." },
}
local NOSE = { ".ppp.", "..p..", "kk.kk" }
local YOWL = { ".ppp.", ".kkk.", "kwrwk", ".kkk." }
local TONGUE = { ".ppp.", "..p..", "kk.kk", "..t..", "..t.." }
local EMBLEMS = {
  ember = { "..e..", ".eee.", "eeeee", ".eee." },
  tide = { "e...e", ".e.e.", "e.e.e", ".e.e." },
  gilt = { "e.e.e", ".eee.", "eeeee", ".eee.", "e.e.e" },
  sun = { "e.e.e", ".eee.", "eeeee", ".eee.", "e.e.e" },
  shadow = { ".ee..", "eee..", "eee..", ".eee." },
}
local SPARK = { ".s.", "sws", ".s." }
local NOTE = { "..nn", "..n.", "nnn.", "nnn." }
local RUNE = { "r.r", ".r.", "r.r" }
local FLAME = { ".y.", "yoy", "yoy", ".o." }

-- ---------------------------------------------------------------- per-card looks
-- Anything not set here is chosen from the card's type, ability, rarity and seed.

local SPEC = {
  artheline = { pattern = "tabby", eyes = "green", outfit = "plate", hat = "crown", prop = "hammer", cape = hex("#c8382c"), expr = "calm" },
  merline = { pattern = "smoke", eyes = "gold", hat = "wizard", robe = hex("#2471fc"), prop = "orb", expr = "smug", cape = false },
  lanceline = { pattern = "solid", eyes = "green", hat = "hood", robe = hex("#16352a"), prop = "wand", expr = "fierce" },
  morgelius = { pattern = "tux", eyes = "gold", hat = "hood", robe = hex("#3b3f8f"), prop = "goblet", expr = "smug" },
  circaleus = { pattern = "solid", eyes = "green", hat = "wizard", robe = hex("#16352a"), prop = "wand", expr = "wide" },
  purrceval = { pattern = "smoke", eyes = "gold", hat = "coif", outfit = "mail", prop = "grail", expr = "calm" },
  purrlinore = { pattern = "tux", eyes = "green", hat = "hood", robe = hex("#24503c"), prop = "mouse", expr = "fierce" },
  mordraleus = { pattern = "solid", eyes = "red", hat = "hornhelm", outfit = "plate", steel = "dark", prop = "sword", expr = "menace" },
  merlinus = { pattern = "tux", eyes = "blue", hat = "bigwizard", robe = hex("#3b3f8f"), prop = "book", expr = "wide" },
  uther = { pattern = "tabby", eyes = "gold", hat = "crown", outfit = "plate", prop = "banner", cape = hex("#2471fc"), expr = "yowl" },
  greenmouser = { pattern = "smoke", eyes = "green", hat = "none", outfit = "plate", steel = "green", prop = "axe", halo = true, expr = "calm" },
  mewdred = { pattern = "tabby", eyes = "copper", hat = "helm", outfit = "plate", prop = "claws", expr = "fierce" },
  galahiss = { pattern = "solid", fur = "cream", eyes = "blue", hat = "none", outfit = "plate", steel = "white", prop = "sword", halo = "gold", expr = "calm" },
  gawpaw = { pattern = "tabby", eyes = "gold", hat = "helm", outfit = "plate", prop = "claws", emblem = "sun", expr = "fierce" },
  bedimew = { pattern = "points", eyes = "blue", hat = "coif", outfit = "mail", prop = "sword", expr = "smug", tongue = true },
  borscat = { pattern = "tabby", eyes = "gold", hat = "helm", outfit = "mail", prop = "sword", halo = true, scars = 2 },
  lamoracat = { pattern = "fluff", eyes = "copper", hat = "none", outfit = "mail", prop = "shield", headW = 1.1, expr = "smug" },
  pelliroar = { pattern = "fluff", eyes = "green", hat = "crownTilt", outfit = "tunic", prop = "banner", expr = "yowl" },
  tristripe = { pattern = "tabby", eyes = "green", hat = "none", outfit = "tunic", prop = "lute", expr = "happy" },
  alleystray = { pattern = "tux", eyes = "gold", hat = "bandana", outfit = "rags", prop = "fishbone", eyepatch = true, torn = true, expr = "smug" },
  kaytail = { pattern = "tabby", eyes = "green", hat = "helm", outfit = "tunic", prop = "spear" },
  pikecat = { pattern = "tabby", eyes = "gold", hat = "coif", outfit = "mail", prop = "spear" },
  squire = { pattern = "solid", eyes = "blue", hat = "bighelm", outfit = "tunic", prop = "banner", expr = "wide" },
  gareth = { pattern = "tux", eyes = "gold", hat = "none", outfit = "apron", prop = "ladle", expr = "happy" },
  agravain = { pattern = "solid", eyes = "gold", hat = "helm", outfit = "mail", prop = "shield", expr = "fierce" },
  ironpaw = { pattern = "tabby", eyes = "copper", hat = "helm", outfit = "mail", prop = "claws", expr = "fierce" },
  barnbrawler = { pattern = "patch", eyes = "green", hat = "bandage", outfit = "rags", prop = "shield", torn = true, scars = 1, expr = "fierce" },
  nimew = { pattern = "smoke", eyes = "cyan", hat = "veil", robe = hex("#2471fc"), prop = "excalibur", expr = "calm" },
  morgana = { pattern = "solid", eyes = "violet", hat = "hoodCirclet", robe = hex("#16352a"), prop = "wand", expr = "smug", cape = false },
  vivipurr = { pattern = "solid", eyes = "green", hat = "circlet", robe = hex("#24503c"), prop = "orb" },
  taliesing = { pattern = "tabby", eyes = "blue", hat = "beret", robe = hex("#c8382c"), prop = "lute", expr = "yowl" },
  seer = { pattern = "points", eyes = "violet", hat = "hoodCirclet", robe = hex("#3b3f8f"), prop = "crystal", expr = "smug", eyepatch = false },
  hedgedruid = { pattern = "tabby", eyes = "green", hat = "leaves", robe = hex("#24503c"), prop = "staff" },
  emberadept = { pattern = "tabby", eyes = "gold", hat = "wizard", robe = hex("#c8382c"), prop = "fireball", expr = "fierce" },
  elaine = { pattern = "points", eyes = "blue", hat = "circlet", robe = hex("#d3a200"), prop = "needle", expr = "happy" },
  novice = { pattern = "solid", eyes = "gold", hat = "bigwizard", robe = hex("#2471fc"), prop = "orb", expr = "wide" },
  candlewitch = { pattern = "tabby", eyes = "green", hat = "witch", robe = hex("#16352a"), prop = "candle", expr = "smug" },
  guard = { pattern = "solid", eyes = "gold", hat = "helm", outfit = "mail", prop = "spear", expr = "calm" },
}
M.SPEC = SPEC

local PROP_PHYS = { smite = "hammer", none = "shield", litter = "spear", muster = "banner", yowl = "banner", pounce = "claws", ninelives = "sword", stray = "fishbone", groom = "sword", purr = "lute" }
local PROP_MAGIC = { inspire = "orb", hex = "wand", litter = "staff", pounce = "fireball", muster = "orb", yowl = "lute", stray = "crystal", purr = "book", groom = "staff", none = "candle" }
local EXPR = { purr = "happy", yowl = "yowl", hex = "smug", pounce = "fierce", stray = "smug", muster = "wide" }

-- Fill in everything a painter needs. o: seed, coat, magic, ability, legendary, rarity, scars,
-- menace, crown, cutout; plus any SPEC fields.
local function derive(o)
  if o.derived then return o end
  local r = rngm.new(o.seed or 1)
  local function nx() return rngm.next(r) end
  local function pick(t) return t[floor(nx() * #t) + 1] end
  o.coat = (FUR[o.coat] and o.coat ~= "cream") and o.coat or "shadow"
  o.pattern = o.pattern or pick(PATTERNS[o.coat] or PATTERNS.shadow)
  o.fur = o.fur or (o.pattern == "points" and "cream" or o.coat)
  o.eyes = o.eyes or (o.menace and "red" or pick(EYES_BY_COAT[o.coat] or EYES_BY_COAT.shadow))
  o.expr = o.expr or (o.menace and "menace") or EXPR[o.ability] or pick({ "calm", "calm", "smug", "fierce", "wide" })
  if o.menace and o.expr ~= "yowl" then o.expr = "menace" end
  if o.magic then
    o.outfit = o.outfit or "robe"
    o.hat = o.hat or (o.crown and "crown") or (o.legendary and "circlet") or (o.ability == "hex" and pick({ "hood", "hood", "wizard", "witch" }))
      or pick({ "wizard", "hood", "circlet", "witch", "none" })
    o.prop = o.prop or PROP_MAGIC[o.ability] or pick({ "staff", "wand", "book" })
  else
    o.outfit = o.outfit or (o.legendary and "plate") or ({ common = pick({ "tunic", "mail", "mail" }), rare = pick({ "mail", "plate" }), epic = "plate" })[o.rarity or "common"] or "mail"
    o.hat = o.hat or (o.crown and "crown") or (o.legendary and "crown") or pick({ "helm", "helm", "coif", "none", "none" })
    o.prop = o.prop or PROP_PHYS[o.ability] or pick({ "sword", "spear", "shield" })
  end
  if o.crown and o.hat ~= "crown" and o.hat ~= "crownTilt" then o.hat = o.magic and "circlet" or "crown" end
  if o.cape == nil then o.cape = o.legendary and pick({ hex("#c8382c"), hex("#2471fc"), hex("#3b3f8f") }) or false end
  o.robe = o.robe or pick(ROBES)
  o.cloth = o.cloth or CLOTH[o.coat]
  o.headW = o.headW or (0.96 + nx() * 0.1)
  o.earH = o.earH or (0.85 + nx() * 0.3)
  if o.ability == "litter" and o.kittens == nil then o.kittens = true end
  if o.ability == "groom" and o.tongue == nil then o.tongue = true end
  if o.ability == "purr" and o.notes == nil then o.notes = true end
  if o.ability == "ninelives" and o.halo == nil then o.halo = true end
  if o.ability == "hex" and o.runes == nil then o.runes = true end
  if (o.ability == "inspire" or o.legendary) and o.sparkles == nil then o.sparkles = true end
  if o.ability == "stray" and o.eyepatch == nil then o.eyepatch = nx() < 0.6 end
  if (o.scars or 0) >= 3 then o.torn = true end
  o.derived = true
  return o
end

-- ---------------------------------------------------------------- backgrounds

local function bgPaint(w, h, o)
  local key = o.menace and "menace" or o.coat
  local B = BG[key] or BG.shadow
  local r = rngm.new((o.seed or 1) + 77)
  local function nx() return rngm.next(r) end
  bands(w, h, { B[1], B[2], B[3] })
  local cx, cy = w / 2, h - 52
  if key == "ember" then
    -- a hall with hanging pennants, lit by a brazier
    for _, x0 in ipairs({ 6, w - 18 }) do
      rect(hex("#2a0a06"), x0, 0, 12, 30)
      poly(hex("#2a0a06"), snap(x0), snap(30), snap(x0 + 12), snap(30), snap(x0 + 6), snap(38))
      rect(hex("#8a2418"), x0 + 2, 0, 8, 28)
    end
    glow(cx, cy + 4, 46, B.glow, 0.45)
    for _ = 1, 10 do rect(nx() < 0.5 and B.glow or GOLD.light, nx() * w, nx() * h * 0.85, px(), px()) end
  elseif key == "tide" then
    glow(cx, cy, 46, B.glow, 0.35)
    for _ = 1, 12 do rect(B.accent, nx() * w, nx() * h * 0.6, px(), px(3), 0.7) end
    for k = 0, 1 do
      local y = h - 22 + k * 10
      for x = -4, w, 16 do rect(B.accent, x + (k % 2) * 8, y, px(4), px(), 0.6) end
    end
  elseif key == "gilt" then
    for i = 0, 7 do
      local a1 = i / 8 * 2 * PI
      col(B.glow, 0.18)
      lg.polygon("fill", cx, cy - 4, cx + math.cos(a1) * 140, cy - 4 + math.sin(a1) * 140, cx + math.cos(a1 + 0.3) * 140, cy - 4 + math.sin(a1 + 0.3) * 140)
    end
    glow(cx, cy - 4, 40, B.glow, 0.4)
    local base = h - 24
    for _, t in ipairs({ { 4, 14 }, { 18, 22 }, { w - 30, 18 }, { w - 14, 10 } }) do
      rect(hex("#221800"), t[1], base - t[2], 10, t[2] + 26)
      for k = 0, 2 do rect(hex("#221800"), t[1] + k * 4, base - t[2] - px(2), px(2), px(2)) end
    end
  elseif key == "shadow" then
    local mx, my = w - 20, 16
    ell(mx, my, 9, 9, C.paper)
    stamp(mx - px(2), my - px(2), { "dd.", "d.." }, { d = hex("#d8d3c2") })
    for _ = 1, 10 do rect(C.paper, nx() * w, nx() * h * 0.55, px(), px(), 0.8) end
    glow(cx, cy, 44, B.glow, 0.22)
    rect(C.paper, 0, h - 18, w, px(2), 0.12)
  elseif key == "menace" then
    glow(cx, cy, 52, B.glow, 0.4)
    for i = 0, 7 do
      local fx_ = i * (w / 7)
      local fh = 12 + nx() * 18
      col(i % 2 == 0 and B.glow or B.accent, 0.7)
      lg.polygon("fill", snap(fx_ - 7), h, snap(fx_ + 7), h, snap(fx_), snap(h - fh))
    end
  end
  if o.legendary then
    for i = 0, 5 do
      local a = i / 6 * 2 * PI + 0.2
      col(GOLD.light, 0.14)
      lg.polygon("fill", cx, cy, cx + math.cos(a) * 120, cy + math.sin(a) * 120, cx + math.cos(a + 0.14) * 120, cy + math.sin(a + 0.14) * 120)
    end
  end
end

-- ---------------------------------------------------------------- the cat

local function steelOf(o)
  if o.steel == "dark" then return { deep = hex("#101216"), dark = hex("#22252e"), base = hex("#3e4350"), light = hex("#6b7487") } end
  if o.steel == "green" then return { deep = hex("#152a1a"), dark = hex("#2c5536"), base = hex("#4f8a5c"), light = hex("#8fd19c") } end
  if o.steel == "white" then return { deep = hex("#5d6879"), dark = hex("#9aa7b9"), base = hex("#dce3ec"), light = hex("#ffffff") } end
  return STEEL
end

local function emblem(kind, x, y, c)
  local rows = EMBLEMS[kind] or EMBLEMS.shadow
  stamp(x - px(floor(#rows[1] / 2)), y - px(floor(#rows / 2)), rows, { e = c })
end

local function body(w, h, o, cx)
  local S = steelOf(o)
  local by = h + 18
  if o.cape then
    ell(cx, by + 4, 52, 50, theme.shade(o.cape, -0.45))
    ell(cx - px(), by + 2, 50, 49, o.cape)
  end
  local outfit = o.outfit
  if outfit == "plate" or outfit == "mail" then
    shaded(cx, by, 44, 44, S)
    if outfit == "mail" then
      for yy = h - 26, h, px(2) do
        for xx = cx - 40, cx + 40, px(2) do
          if ((xx - cx) / 44) ^ 2 + ((yy - by) / 44) ^ 2 < 0.97 and floor((xx + yy) / px(2) + 0.5) % 2 == 0 then rect(S.dark, xx, yy, px(), px()) end
        end
      end
    else
      for sgn = -1, 1, 2 do
        local x0 = cx + sgn * 31
        shaded(x0, h - 14, 15, 12, S)
        ell(x0 - 3, h - 20, 6, 2.5, S.light, sgn * 0.2)
      end
    end
    rect(theme.shade(o.cloth, -0.4), cx - 12, h - 26, 24, 26)
    rect(o.cloth, cx - 11, h - 26, 22, 26)
    rect(theme.shade(o.cloth, 0.25), cx - 11, h - 26, 22, px())
    emblem(o.emblem or o.coat, cx, h - 13, o.coat == "gilt" and C.paper or GOLD.light)
  elseif outfit == "robe" then
    local R = o.robe
    shaded(cx, by, 44, 44, { dark = theme.shade(R, -0.45), base = R })
    ell(cx - 16, h - 18, 9, 3, theme.shade(R, 0.3), -0.3)
    poly(theme.shade(R, -0.25), snap(cx - 22), snap(h - 20), snap(cx - 8), snap(h - 26), snap(cx - 16), snap(h - 40))
    poly(theme.shade(R, -0.25), snap(cx + 22), snap(h - 20), snap(cx + 8), snap(h - 26), snap(cx + 16), snap(h - 40))
    line(GOLD.base, 1, snap(cx - 20), snap(h - 21), snap(cx - 15), snap(h - 38))
    line(GOLD.base, 1, snap(cx + 20), snap(h - 21), snap(cx + 15), snap(h - 38))
    rect(GOLD.base, cx - px(0.5), h - 24, px(), 24)
    stamp(cx - px(1.5), h - 20, { ".g.", "gcg", ".g." }, { g = GOLD.dark, c = o.magic and EYE.cyan or C.red })
  else -- tunic, apron, rags
    local T = outfit == "rags" and hex("#6b5440") or o.cloth
    shaded(cx, by, 44, 44, { dark = theme.shade(T, -0.45), base = T })
    ell(cx - 16, h - 18, 9, 3, theme.shade(T, 0.25), -0.3)
    poly(theme.shade(T, -0.35), snap(cx - 9), snap(h - 26), snap(cx + 9), snap(h - 26), snap(cx), snap(h - 14))
    if outfit == "apron" then
      rect(C.paper, cx - 14, h - 22, 28, 22)
      rect(hex("#d8d3c2"), cx - 14, h - 22, 28, px())
    elseif outfit == "rags" then
      rect(hex("#8a6a4a"), cx - 26, h - 16, 9, 7)
      rect(hex("#4a3828"), cx + 14, h - 10, 8, 6)
      line(hex("#c9a66b"), 1, cx - 30, h - 30, cx + 22, h)
    else
      line(WOODD, 2, cx - 30, h - 28, cx + 26, h)
      rect(GOLD.base, cx - 3, h - 15, 5, 4)
    end
  end
  if o.cape then
    ell(cx, h - 24, 30, 6, C.paper)
    for i = -3, 3 do rect(OUTLINE, cx + i * 8, h - 25 + (i % 2), px(), px(2)) end
  end
end

-- the head: skull, cheeks and chin
local function headShape(cx, cy, o, c, dx, dy)
  local wf = o.headW
  ell(cx + dx, cy + dy, 22 * wf, 18.5, c)
  ell(cx - 12 * wf + dx, cy + 7 + dy, 12.5 * wf, 10.5, c)
  ell(cx + 12 * wf + dx, cy + 7 + dy, 12.5 * wf, 10.5, c)
  ell(cx + dx, cy + 11 + dy, 11, 8.5, c)
end

local function ears(cx, cy, o, F)
  local wf, eh = o.headW, o.earH
  for sgn = -1, 1, 2 do
    local bx1, by1 = snap(cx + sgn * 22 * wf), snap(cy - 2)
    local bx2, by2 = snap(cx + sgn * 6 * wf), snap(cy - 16)
    local tx, ty = snap(cx + sgn * 21 * wf), snap(cy - 16 - 18 * eh)
    local earBase = (o.pattern == "points") and FUR[o.coat == "gilt" and "ember" or o.coat].stripe or F.base
    poly(F.dark, bx1, by1, bx2, by2, tx, ty)
    poly(earBase, bx1 - sgn * px(), by1 - px(), bx2, by2, tx, ty + px())
    poly(PINK, snap(bx1 - sgn * 5), snap(by1 - 4), snap(bx2 + sgn * 3.5), snap(by2 - 1), snap(tx - sgn * 1.5), snap(ty + 7))
    if o.torn and sgn == 1 then
      local mxp, myp = (bx1 + tx) / 2, (by1 + ty) / 2
      lg.setBlendMode("replace")
      lg.setColor(0, 0, 0, 0)
      lg.polygon("fill", snap(mxp + 3), snap(myp - 4), snap(mxp + 3), snap(myp + 3), snap(mxp - 2), snap(myp))
      lg.setBlendMode("alpha")
    end
  end
end

local function pattern(cx, cy, o, F)
  local wf = o.headW
  local p = o.pattern
  if p == "tabby" or p == "patch" then
    rect(F.stripe, cx - px(0.5), cy - 18, px(), 7)
    rect(F.stripe, cx - 6, cy - 17, px(), 5)
    rect(F.stripe, cx + 6 - px(), cy - 17, px(), 5)
    rect(F.stripe, cx - 24 * wf, cy + 3, 7 * wf, px())
    rect(F.stripe, cx + 17 * wf, cy + 3, 7 * wf, px())
    rect(F.stripe, cx - 24 * wf, cy + 8, 6 * wf, px())
    rect(F.stripe, cx + 18 * wf, cy + 8, 6 * wf, px())
    if p == "patch" then
      ell(cx - 11, cy - 8, 7, 5, FUR.shadow.base)
      ell(cx + 14, cy + 4, 5, 4, FUR.cream.base)
    end
  elseif p == "smoke" then
    ell(cx - 3, cy - 12, 7, 3, F.light)
  elseif p == "points" then
    local P = FUR[o.coat == "gilt" and "ember" or o.coat] or FUR.ember
    ell(cx, cy + 6, 12 * wf, 9, mix(F.base, P.stripe, 0.5))
  elseif p == "fluff" then
    for sgn = -1, 1, 2 do
      for k = 0, 2 do
        poly(F.light, snap(cx + sgn * (17 + k * 2) * wf), snap(cy + 6 + k * 4), snap(cx + sgn * (27 + k) * wf), snap(cy + 10 + k * 5), snap(cx + sgn * (18 + k * 2) * wf), snap(cy + 13 + k * 4))
      end
    end
  end
end

-- Headwear that sits behind the head (drawn before the ears).
local function hatBack(cx, cy, o)
  local hat = o.hat
  if hat == "hood" or hat == "hoodCirclet" or hat == "veil" then
    local R = hat == "veil" and hex("#9fd8ff") or o.robe
    ell(cx, cy + 2, 31, 30, theme.shade(R, -0.4))
    ell(cx - px(), cy + 1, 29.5, 29, R)
    poly(R, snap(cx - 14), snap(cy - 22), snap(cx + 14), snap(cy - 22), snap(cx + 4), snap(cy - 40))
  elseif hat == "coif" then
    local S = steelOf(o)
    ell(cx, cy + 4, 30, 29, S.deep)
    ell(cx - px(), cy + 3, 28.5, 27.5, S.dark)
    for yy = cy - 22, cy + 30, px(2) do
      for xx = cx - 28, cx + 28, px(2) do
        if ((xx - cx) / 28) ^ 2 + ((yy - cy - 4) / 27) ^ 2 < 0.95 and floor((xx + yy) / px(2) + 0.5) % 2 == 0 then rect(S.base, xx, yy, px(), px()) end
      end
    end
  end
end

-- Headwear on top of the head. Returns true if the ears should be drawn over it.
local function hatFront(cx, cy, o)
  local hat = o.hat
  local top = cy - 18.5
  local wf = o.headW
  if hat == "helm" or hat == "bighelm" or hat == "hornhelm" then
    local S = hat == "hornhelm" and steelOf({ steel = "dark" }) or steelOf(o)
    local big = hat == "bighelm" and 1.18 or 1
    local hy = snap(cy - 8 + (big > 1 and 4 or 0))
    local r = 23.5 * wf * big
    if hat == "hornhelm" then
      for sgn = -1, 1, 2 do
        poly(C.paper, snap(cx + sgn * 16), snap(hy - 12), snap(cx + sgn * 24), snap(hy - 8), snap(cx + sgn * 30), snap(hy - 30))
      end
    end
    col(S.dark); lg.arc("fill", snap(cx), hy, r + px(), PI, 2 * PI, 32)
    col(S.base); lg.arc("fill", snap(cx - px()), hy - px(), r - px(0.5), PI, 2 * PI, 32)
    ell(cx - 8, hy - r * 0.6, 5, 2, S.light, -0.3)
    rect(S.dark, cx - r - px(), hy - px(), 2 * r + px(2), px(2))
    rect(S.dark, cx - px(1.5), hy - px(), px(3), 11)
    rect(S.base, cx - px(0.5), hy - px(), px(1), 10)
    if hat == "bighelm" then poly(C.red, snap(cx - 3), snap(hy - r), snap(cx + 3), snap(hy - r), snap(cx + 9), snap(hy - r - 12)) end
    return hat ~= "hornhelm"
  elseif hat == "crown" or hat == "crownTilt" then
    local tilt = hat == "crownTilt" and 1 or 0
    rect(GOLD.dark, cx - 13, top - px(), 26, 6)
    rect(GOLD.base, cx - 12, top, 24, 4)
    for k = -2, 2 do
      local kx = cx + k * 5.5
      local ky = top + k * tilt
      poly(GOLD.base, snap(kx - 3), snap(ky), snap(kx + 3), snap(ky), snap(kx), snap(ky - 8 + math.abs(k)))
    end
    rect(GOLD.light, cx - 11, top, 22, px())
    stamp(cx - px(1), top + px(), { "rr", "rr" }, { r = C.red })
    rect(EYE.blue, cx - 8, top + px(), px(), px())
    rect(EYE.blue, cx + 8 - px(), top + px(), px(), px())
  elseif hat == "circlet" or hat == "hoodCirclet" then
    rect(GOLD.base, cx - 18 * wf, top + 5, 36 * wf, px())
    stamp(cx - px(1.5), top + 4 - px(), { ".g.", "gcg", ".g." }, { g = GOLD.dark, c = EYE.cyan })
    if hat == "hoodCirclet" then
      col(theme.shade(o.robe, -0.2)); lg.setLineWidth(px(2)); lg.arc("line", "open", snap(cx), snap(cy + 2), 27, PI * 1.05, PI * 1.95, 32); lg.setLineWidth(1)
    end
  elseif hat == "hood" or hat == "veil" then
    local R = hat == "veil" and hex("#9fd8ff") or o.robe
    col(theme.shade(R, -0.2)); lg.setLineWidth(px(2))
    lg.arc("line", "open", snap(cx), snap(cy + 3), 26.5, PI * 1.02, PI * 1.98, 32)
    lg.setLineWidth(1)
    return true
  elseif hat == "wizard" or hat == "bigwizard" or hat == "witch" then
    local R = hat == "witch" and hex("#16352a") or o.robe
    local big = hat == "bigwizard" and 1.25 or 1
    local byy = top + 4 + (big > 1 and 4 or 0)
    local brim = hat == "witch" and 30 or 24
    ell(cx, byy + px(), brim * big, 4.5 * big, theme.shade(R, -0.45))
    ell(cx, byy, brim * big, 3.5 * big, R)
    poly(theme.shade(R, -0.25), snap(cx - 14 * big), snap(byy), snap(cx + 15 * big), snap(byy), snap(cx + 6 * big), snap(byy - 22 * big))
    poly(R, snap(cx - 13 * big), snap(byy - px()), snap(cx + 12 * big), snap(byy - px()), snap(cx + 5 * big), snap(byy - 21 * big))
    poly(R, snap(cx + 4 * big), snap(byy - 19 * big), snap(cx + 7 * big), snap(byy - 21 * big), snap(cx + 16 * big), snap(byy - 32 * big))
    if hat == "witch" then
      rect(hex("#0a1a12"), cx - 12, byy - 5, 25, 4)
      rect(GOLD.base, cx - 2, byy - 5, 4, 4)
    else
      rect(GOLD.base, cx - 13 * big, byy - px(2), 26 * big, px())
    end
  elseif hat == "beret" then
    ell(cx - 2, top + 2, 20, 6, hex("#7a2016"), -0.15)
    ell(cx - 3, top + 1, 19, 5, C.red, -0.15)
    poly(C.paper, snap(cx + 10), snap(top), snap(cx + 14), snap(top + 1), snap(cx + 20), snap(top - 14))
  elseif hat == "leaves" then
    for k = -3, 3 do
      local a = k * 0.3
      ell(cx + math.sin(a) * 20, top + 5 - math.cos(a) * 3, 3, 5, k % 2 == 0 and hex("#5fd38d") or hex("#2f8a52"), a)
    end
    rect(C.red, cx - px(), top, px(2), px(2))
  elseif hat == "bandana" or hat == "bandage" then
    local B = hat == "bandana" and C.red or C.paper
    rect(theme.shade(B, -0.35), cx - 22 * wf, top + 3, 44 * wf, 7)
    rect(B, cx - 21 * wf, top + 3, 42 * wf, 5)
    if hat == "bandana" then
      poly(B, snap(cx + 20 * wf), snap(top + 4), snap(cx + 30 * wf), snap(top + 2), snap(cx + 28 * wf), snap(top + 12))
      for k = -2, 2 do rect(C.paper, cx + k * 8, top + 5, px(), px()) end
    else
      rect(PINKD, cx + 5, top + 5, px(2), px())
    end
    return true
  end
  return false
end

local function kitten(x, y, F)
  ell(x, y + 2, 8, 6, F.dark)
  for sgn = -1, 1, 2 do
    poly(F.dark, snap(x + sgn * 7), snap(y - 1), snap(x + sgn * 1.5), snap(y - 5), snap(x + sgn * 7), snap(y - 11))
  end
  ell(x - px(), y - px(), 7.5, 6.5, F.base)
  ell(x, y + 3, 4, 2.5, F.muzzle)
end
local function kittenFace(x, y, o)
  local e = EYE[o.eyes] or EYE.gold
  stamp(x - px(2), y - px(1), { "k...k", "e...e" }, { k = OUTLINE, e = e })
  stamp(x, y + px(1), { "p" }, { p = PINK })
end

-- Props held in front of (or behind) the cat.
local function prop(w, h, o, cx, F, back)
  local p = o.prop
  local S = steelOf(o)
  if back then
    if p == "banner" then
      local x0 = cx - 34
      rect(WOODD, x0 - px(), 4, px(2), h)
      rect(GOLD.base, x0 - px(), 2, px(2), px(2))
      rect(theme.shade(o.cloth, -0.35), x0 + px(), 8, 24, 24)
      rect(o.cloth, x0 + px(), 8, 23, 22)
      poly(o.cloth, snap(x0 + 1), snap(30), snap(x0 + 12), snap(30), snap(x0 + 1), snap(38))
      poly(o.cloth, snap(x0 + 12), snap(30), snap(x0 + 24), snap(30), snap(x0 + 24), snap(38))
      emblem(o.coat, x0 + 12, 19, o.coat == "gilt" and C.paper or GOLD.light)
    elseif p == "spear" then
      local x0 = cx + 34
      rect(WOODD, x0 - px(), 10, px(2), h)
      poly(S.base, snap(x0 - 3.5), snap(12), snap(x0 + 3.5), snap(12), snap(x0), snap(-2))
      poly(C.red, snap(x0 + 1), snap(14), snap(x0 + 12), snap(17), snap(x0 + 1), snap(21))
    elseif p == "staff" then
      local x0 = cx - 34
      rect(WOOD, x0 - px(), 14, px(2), h)
      poly(EYE.cyan, snap(x0 - 4), snap(10), snap(x0 + 4), snap(10), snap(x0), snap(2))
      poly(hex("#2bb0d0"), snap(x0 - 4), snap(10), snap(x0 + 4), snap(10), snap(x0), snap(16))
    elseif p == "axe" then
      local x0 = cx + 33
      rect(WOODD, x0 - px(), 8, px(2), h)
      col(STEEL.dark); lg.arc("fill", snap(x0 + 1), snap(18), 13, -PI / 2, PI / 2, 24)
      col(STEEL.base); lg.arc("fill", snap(x0 + 1), snap(18), 11, -PI / 2, PI / 2, 24)
    elseif p == "excalibur" then
      local x0 = cx + 30
      poly(S.light, snap(x0 - 2), snap(60), snap(x0 + 2), snap(60), snap(x0 + 2), snap(8), snap(x0), snap(2), snap(x0 - 2), snap(8))
      rect(GOLD.base, x0 - 8, 58, 16, px(3))
      rect(WOODD, x0 - px(), 61, px(2), 9)
    end
    return
  end
  if p == "sword" then
    local x0 = cx + 31
    poly(S.light, snap(x0 - 2), snap(h - 18), snap(x0 + 2), snap(h - 18), snap(x0 + 2), snap(h - 62), snap(x0), snap(h - 67), snap(x0 - 2), snap(h - 62))
    rect(S.dark, x0 - px(0.5), h - 62, px(), 42)
    rect(GOLD.dark, x0 - 8, h - 19, 16, px(3))
    rect(GOLD.base, x0 - 8, h - 19, 16, px(2))
    rect(WOODD, x0 - px(), h - 15, px(2), 10)
    shaded(x0 - 10, h - 6, 6, 5, F)
  elseif p == "hammer" then
    lg.push(); lg.translate(snap(cx + 30), snap(h - 40)); lg.rotate(0.35)
    col(WOODD); lg.rectangle("fill", -px(), -6, px(2), 52)
    col(S.dark); lg.rectangle("fill", -11, -16, 22, 14)
    col(S.base); lg.rectangle("fill", -10, -15, 20, 11)
    col(S.light); lg.rectangle("fill", -10, -15, 20, px())
    col(GOLD.base); lg.rectangle("fill", -11, -9, 22, px(2))
    lg.pop()
    shaded(cx + 25, h - 12, 6, 5, F)
  elseif p == "shield" then
    local sx, sy = cx - 24, h - 16
    poly(S.dark, snap(sx - 14), snap(sy - 16), snap(sx + 14), snap(sy - 16), snap(sx + 14), snap(sy + 2), snap(sx), snap(sy + 16), snap(sx - 14), snap(sy + 2))
    poly(o.cloth, snap(sx - 12), snap(sy - 14), snap(sx + 12), snap(sy - 14), snap(sx + 12), snap(sy + 1), snap(sx), snap(sy + 13), snap(sx - 12), snap(sy + 1))
    rect(theme.shade(o.cloth, 0.3), sx - 12, sy - 14, 24, px())
    emblem(o.coat, sx, sy - 3, o.coat == "gilt" and C.paper or GOLD.light)
  elseif p == "claws" then
    local x0, y0 = cx + 24, h - 18
    shaded(x0, y0, 9, 8, F)
    for k = -1, 1 do
      poly(WHITE, snap(x0 + k * 4 - 1.5), snap(y0 - 6), snap(x0 + k * 4 + 1.5), snap(y0 - 6), snap(x0 + k * 4), snap(y0 - 13))
    end
    ell(x0, y0 + 2.5, 3, 2.2, PINK)
  elseif p == "lute" then
    local lx, ly = cx + 22, h - 12
    lg.push(); lg.translate(snap(lx), snap(ly)); lg.rotate(0.55)
    col(WOODD); lg.rectangle("fill", -px(), -30, px(2), 24); lg.rectangle("fill", -3, -34, 6, 5)
    lg.pop()
    shaded(lx, ly, 11, 9, { dark = WOODD, base = WOOD })
    ell(lx, ly, 3, 3, hex("#2a1a0c"))
    shaded(lx - 10, ly + 3, 5, 4.5, F)
  elseif p == "orb" or p == "crystal" or p == "fireball" then
    if p == "crystal" then
      rect(GOLD.dark, cx - 9, h - 8, 18, 5)
      rect(GOLD.base, cx - 7, h - 10, 14, px(2))
    end
    for sgn = -1, 1, 2 do shaded(cx + sgn * 10, h - 14, 6, 5, F) end
  elseif p == "wand" then
    lg.push(); lg.translate(snap(cx + 22), snap(h - 22)); lg.rotate(0.6)
    col(WOODD); lg.rectangle("fill", -px(), -16, px(2), 22)
    lg.pop()
    shaded(cx + 24, h - 12, 5.5, 4.5, F)
  elseif p == "book" then
    rect(hex("#4a1a12"), cx - 34, h - 26, 22, 26)
    rect(hex("#8a2418"), cx - 33, h - 25, 20, 24)
    rect(C.paper, cx - 31, h - 24, px(2), 22)
    emblem("gilt", cx - 22, h - 14, GOLD.base)
    shaded(cx - 13, h - 10, 5.5, 4.5, F)
  elseif p == "goblet" or p == "grail" then
    local gx, gy = cx + 25, h - 22
    poly(GOLD.dark, snap(gx - 8), snap(gy - 8), snap(gx + 8), snap(gy - 8), snap(gx + 4), snap(gy + 4), snap(gx - 4), snap(gy + 4))
    poly(GOLD.base, snap(gx - 7), snap(gy - 7), snap(gx + 6), snap(gy - 7), snap(gx + 3), snap(gy + 3), snap(gx - 3), snap(gy + 3))
    rect(GOLD.light, gx - 6, gy - 7, 12, px())
    rect(GOLD.dark, gx - px(), gy + 3, px(2), 10)
    rect(GOLD.base, gx - 6, gy + 12, 12, px(2))
    if p == "grail" then rect(C.red, gx - px(), gy - 2, px(2), px(2)) end
    shaded(gx - 10, gy + 6, 5.5, 4.5, F)
  elseif p == "fishbone" then
    local fx0, fy0 = cx + 22, h - 16
    rect(C.paper, fx0 - 10, fy0, 18, px())
    for k = 0, 3 do rect(C.paper, fx0 - 6 + k * 4, fy0 - 4, px(), 8) end
    poly(C.paper, snap(fx0 + 8), snap(fy0), snap(fx0 + 14), snap(fy0 - 5), snap(fx0 + 14), snap(fy0 + 5))
    ell(fx0 - 12, fy0, 3.5, 3, C.paper)
  elseif p == "mouse" then
    local mx, my = cx - 26, h - 10
    ell(mx, my, 8, 6, hex("#9aa0a8"))
    ell(mx - 6, my - 4, 3, 3, hex("#9aa0a8"))
    line(PINK, 1, mx + 7, my + 2, mx + 14, my - 4)
  elseif p == "ladle" then
    lg.push(); lg.translate(snap(cx + 26), snap(h - 30)); lg.rotate(0.25)
    col(S.base); lg.rectangle("fill", -px(), -10, px(2), 30)
    lg.pop()
    shaded(cx + 23, h - 41, 6, 4.5, S)
    shaded(cx + 28, h - 10, 5.5, 4.5, F)
  elseif p == "candle" then
    local x0 = cx + 26
    rect(GOLD.dark, x0 - 8, h - 8, 16, px(3))
    rect(C.paper, x0 - 3, h - 30, 6, 22)
    rect(hex("#d8d3c2"), x0 + 1, h - 30, px(), 22)
    shaded(x0 - 9, h - 10, 5.5, 4.5, F)
  elseif p == "needle" then
    rect(C.paper, cx - 34, h - 24, 24, 22)
    for k = 0, 3 do rect(k % 2 == 0 and C.red or C.blue, cx - 32, h - 22 + k * 5, 20, px(2)) end
    line(STEEL.light, 1, cx - 10, h - 30, cx - 18, h - 14)
  end
end

-- The face, in pixel stamps (drawn after the shapes are cleaned up). Positions are worked out
-- in whole output pixels so both eyes are exact mirror images.
local function face(cx, cy, o)
  local ec = EYE[o.eyes] or EYE.gold
  local pal = { k = OUTLINE, w = WHITE, c = ec, d = theme.shade(ec, -0.35), p = OUTLINE }
  if o.expr == "menace" then pal.p = theme.shade(ec, -0.6) end
  local ex = floor(10 * o.headW * K + 0.5)
  local ey = floor((cy + 1) * K + 0.5)
  local cxp = floor(cx * K + 0.5)
  for sgn = -1, 1, 2 do
    local rows = EYES[o.expr] or EYES.calm
    if o.expr == "yowl" then rows = EYES.fierce end
    if o.eyepatch and sgn == -1 then rows = EYES.patch end
    stamp((cxp + sgn * ex - 2) / K, (ey - 2) / K, rows, pal, sgn == 1)
  end
  if o.eyepatch then line(OUTLINE, 1, (cxp - ex - 4) / K, (ey - 4) / K, (cxp + ex + 4) / K, (ey - 8) / K) end
  local npal = { p = PINK, k = OUTLINE, w = WHITE, r = hex("#8a1f2a"), t = PINK }
  local rows = o.expr == "yowl" and YOWL or (o.tongue and TONGUE or NOSE)
  stamp((cxp - 2) / K, (ey + 3) / K, rows, npal)
  local scars = o.scars or 0
  if scars > 0 then stamp((cxp - ex - 3) / K, (ey - 4) / K, { "..s", ".s.", "s.." }, { s = C.paper }) end
  if scars > 1 then stamp((cxp + ex + 1) / K, (ey - 6) / K, { "s..", ".s.", "..s" }, { s = PINKD }) end
end

local function fxLayer(w, h, o, cx, cy)
  local r = rngm.new((o.seed or 1) + 501)
  local function nx() return rngm.next(r) end
  -- whiskers: two light pixel lines a side, past the cheeks
  local wc = o.fur == "shadow" and hex("#b8cbc0") or C.paper
  local cxp, eyp = floor(cx * K + 0.5), floor((cy + 1) * K + 0.5)
  local hw = floor(23 * o.headW * K)
  for i = 0, 1 do
    local y = (eyp + 4 + i * 2) / K
    col(wc, 0.9)
    lg.rectangle("fill", (cxp - hw - 3) / K, y, px(4), px())
    lg.rectangle("fill", (cxp + hw - 1) / K, y, px(4), px())
  end
  local p = o.prop
  if p == "orb" or p == "crystal" or p == "fireball" then
    local c = p == "fireball" and hex("#ff8a3a") or (o.ability == "hex" and EYE.violet or EYE.cyan)
    local ox, oy = cx, h - 22
    glow(ox, oy, 14, c, 0.8)
    ell(ox, oy, 6, 6, mix(c, WHITE, 0.25))
    rect(WHITE, ox - px(2), oy - px(2), px(), px())
    if p == "fireball" then stamp(ox - px(1), oy - 14, FLAME, { y = GOLD.light, o = hex("#ff8a3a") }) end
  elseif p == "candle" then
    local x0 = cx + 26
    glow(x0, h - 34, 9, hex("#ff8a3a"), 0.7)
    stamp(x0 - px(1), h - 30 - px(4), FLAME, { y = GOLD.light, o = hex("#ff8a3a") })
  elseif p == "wand" then
    stamp(cx + 30 - px(1), h - 38, SPARK, { s = o.ability == "hex" and EYE.violet or GOLD.light, w = WHITE })
  elseif p == "staff" then
    glow(cx - 34, 9, 8, EYE.cyan, 0.6)
  elseif p == "excalibur" then
    glow(cx + 30, 26, 10, EYE.cyan, 0.4)
    stamp(cx + 30 - px(1), 10, SPARK, { s = WHITE, w = WHITE })
  end
  if o.halo then
    col(o.halo == "gold" and GOLD.light or EYE.cyan)
    lg.setLineWidth(px())
    lg.ellipse("line", snap(cx), snap(cy - 32), 13, 3, 24)
    lg.setLineWidth(1)
  end
  if o.runes then
    for _ = 1, 3 do
      local rx, ry = 6 + nx() * (w - 12), 6 + nx() * 36
      if math.abs(rx - cx) > 24 then stamp(rx, ry, RUNE, { r = EYE.violet }) end
    end
  end
  if o.notes then
    for i = 1, 2 do stamp(cx + 24 + i * 6, cy - 12 - i * 9, NOTE, { n = GOLD.light }) end
  end
  if o.sparkles then
    for _ = 1, 3 do
      local sx, sy = 4 + nx() * (w - 8), 4 + nx() * (h * 0.5)
      if math.abs(sx - cx) > 26 then stamp(sx, sy, SPARK, { s = GOLD.light, w = WHITE }) end
    end
  end
  if o.kittens then
    kittenFace(cx - 30, h - 10, o)
    kittenFace(cx + 18, h - 7, o)
  end
end

-- the figure, in two passes: shapes (cleaned up), then the face stamps
local function figureShapes(w, h, o)
  local cx, cy = snap(w / 2), snap(h - 52)
  local F = FUR[o.fur] or FUR.shadow
  prop(w, h, o, cx, F, true)
  body(w, h, o, cx)
  ell(cx, h - 30, 16, 9, F.dark)
  ell(cx, h - 31, 14.5, 8, F.base)
  hatBack(cx, cy, o)
  local helmLike = o.hat == "helm" or o.hat == "bighelm" or o.hat == "hood" or o.hat == "veil" or o.hat == "bandana" or o.hat == "bandage"
  if not helmLike then ears(cx, cy, o, F) end
  headShape(cx, cy, o, F.dark, 0, 0)
  headShape(cx, cy, o, F.base, -px(), -px())
  ell(cx - 8, cy - 10, 7, 3.5, F.light, -0.35)
  pattern(cx, cy, o, F)
  local muz = o.pattern == "tux" and C.paper or F.muzzle
  if o.pattern == "tux" then poly(C.paper, snap(cx - 6), snap(cy - 2), snap(cx + 6), snap(cy - 2), snap(cx + 9), snap(cy + 14), snap(cx - 9), snap(cy + 14)) end
  ell(cx - 5, cy + 9.5, 6, 4.5, muz)
  ell(cx + 5, cy + 9.5, 6, 4.5, muz)
  ell(cx, cy + 13, 5, 3.5, muz)
  local earsOver = hatFront(cx, cy, o)
  if helmLike and earsOver then ears(cx, cy, o, F) end
  if o.kittens then
    kitten(cx - 30, h - 10, F)
    kitten(cx + 18, h - 7, F)
  end
  prop(w, h, o, cx, F, false)
end

local function figureDetails(w, h, o)
  face(snap(w / 2), snap(h - 52), o)
end

-- ---------------------------------------------------------------- tricks

local TRICK_BG = {
  downpour = { hex("#1c3048"), hex("#122236"), hex("#0a1422") },
  moonfog = { hex("#1d4434"), hex("#122b21"), hex("#07130e") },
  sunbeam = { hex("#3a2a10"), hex("#2a1e0a"), hex("#160f04") },
  warhorn = { hex("#5a1d12"), hex("#3e130c"), hex("#260b07") },
  box = { hex("#2f6a4f"), hex("#24503c"), hex("#16352a") },
  hairball = { hex("#33461a"), hex("#243212"), hex("#141c08") },
}

local function trickBg(w, h, o)
  bands(w, h, TRICK_BG[o.ability] or TRICK_BG.box)
  local cx, cy = w / 2, h / 2
  local ab = o.ability
  if ab == "downpour" then
    for i = 1, 26 do rect(hex("#5cb8ff"), (i * 37) % w, (i * 53) % h, px(), px(3), 0.8) end
  elseif ab == "moonfog" then
    glow(cx + 16, 24, 26, EYE.cyan, 0.2)
    ell(cx + 16, 24, 14, 14, C.paper)
    for k = 0, 3 do
      col(C.paper, 0.18 + k * 0.08)
      lg.ellipse("fill", snap(cx + (k % 2 == 0 and -10 or 12)), snap(44 + k * 11), 48, 6, 28)
    end
  elseif ab == "sunbeam" then
    rect(hex("#3a2a10"), 8, 6, 28, 30)
    for _, q in ipairs({ { 10, 8 }, { 23, 8 }, { 10, 22 }, { 23, 22 } }) do rect(GOLD.light, q[1], q[2], 11, 12) end
    col(GOLD.light, 0.22)
    lg.polygon("fill", snap(10), snap(8), snap(34), snap(8), w, h, w - 58, h)
  elseif ab == "warhorn" then
    glow(cx, cy, 40, hex("#ff8a3a"), 0.4)
  elseif ab == "box" then
    glow(cx, cy + 6, 38, GOLD.base, 0.25)
  elseif ab == "hairball" then
    glow(cx, cy, 36, hex("#a8d14f"), 0.3)
  end
end

local function trickFig(w, h, o)
  local cx, cy = w / 2, h / 2
  local ab = o.ability
  if ab == "downpour" then
    for _, c in ipairs({ { cx - 18, 24, 16, 11 }, { cx + 2, 18, 20, 14 }, { cx + 22, 26, 14, 10 }, { cx, 30, 28, 8 } }) do
      shaded(c[1], c[2], c[3], c[4], { dark = hex("#56677c"), base = hex("#9aa7b9") })
    end
    local F = FUR.tide
    shaded(cx, h - 6, 22, 12, F)
    poly(F.dark, snap(cx - 20), snap(h - 12), snap(cx - 8), snap(h - 16), snap(cx - 26), snap(h - 20))
    poly(F.dark, snap(cx + 20), snap(h - 12), snap(cx + 8), snap(h - 16), snap(cx + 26), snap(h - 20))
  elseif ab == "sunbeam" then
    shaded(cx + 10, h - 14, 30, 8, { dark = hex("#7a2016"), base = C.red })
    local F = FUR.gilt
    shaded(cx + 10, h - 25, 22, 10, F)
    shaded(cx - 6, h - 29, 11, 9, F)
    poly(F.dark, snap(cx - 15), snap(h - 34), snap(cx - 9), snap(h - 37), snap(cx - 15), snap(h - 44))
    poly(F.dark, snap(cx + 1), snap(h - 34), snap(cx - 5), snap(h - 37), snap(cx + 1), snap(h - 44))
  elseif ab == "warhorn" then
    lg.push(); lg.translate(snap(cx - 4), snap(cy + 6)); lg.rotate(-0.35)
    poly(GOLD.dark, -26, -4, -26, 4, 10, 10, 10, -10)
    poly(GOLD.base, -25, -3, -25, 3, 9, 8, 9, -8)
    col(GOLD.light); lg.rectangle("fill", -25, -3, 34, px())
    col(GOLD.dark); lg.ellipse("fill", 12, 0, 5, 12, 24)
    col(hex("#2a1e00")); lg.ellipse("fill", 12, 0, 3.5, 10, 24)
    col(C.red); lg.rectangle("fill", -18, -5, 4, 10); lg.rectangle("fill", -4, -7, 4, 14)
    lg.pop()
  elseif ab == "box" then
    local bx, by = snap(cx - 26), snap(cy - 4)
    poly(hex("#8c5a24"), bx, by, bx + 52, by, bx + 52, by + 36, bx, by + 36)
    poly(hex("#b07a3a"), bx + px(), by + px(), bx + 51, by + px(), bx + 51, by + 35, bx + px(), by + 35)
    rect(hex("#d9a35a"), bx + 22, by + 1, 8, 34)
    poly(hex("#9a6a2c"), bx, by, bx + 26, by, bx + 18, by - 10, bx - 8, by - 10)
    poly(hex("#c08844"), bx + 26, by, bx + 52, by, bx + 60, by - 10, bx + 34, by - 10)
    rect(hex("#120a04"), bx + 4, by - 2, 44, 6)
    poly(FUR.shadow.base, snap(bx + 12), snap(by + 1), snap(bx + 20), snap(by + 1), snap(bx + 14), snap(by - 9))
    poly(FUR.shadow.base, snap(bx + 28), snap(by + 1), snap(bx + 36), snap(by + 1), snap(bx + 34), snap(by - 9))
  elseif ab == "hairball" then
    local hx, hy = cx, cy + 6
    shaded(hx, hy, 17, 15, { dark = hex("#5c3a1f"), base = hex("#8c6a2c") })
    for i = 0, 11 do
      local a = i / 12 * 2 * PI
      line(i % 2 == 0 and hex("#d0602a") or hex("#3a2412"), 1, hx + math.cos(a) * 6, hy + math.sin(a) * 5, hx + math.cos(a + 0.6) * 17, hy + math.sin(a + 0.6) * 15)
    end
  end
end

local function trickFx(w, h, o)
  local cx, cy = w / 2, h / 2
  local ab = o.ability
  if ab == "box" then
    local bx, by = snap(cx - 26), snap(cy - 4)
    for _, ex in ipairs({ bx + 18, bx + 30 }) do rect(EYE.gold, ex - px(), by, px(2), px()) end
  elseif ab == "hairball" then
    for k = -1, 1 do stamp(cx + k * 12 - px(), cy - 30, { ".g", "g.", ".g", "g." }, { g = hex("#a8d14f") }) end
  elseif ab == "sunbeam" then
    for k = 0, 1 do stamp(cx + 4 + k * 10, h - 54 - k * 12, { "zzz", "..z", ".z.", "z..", "zzz" }, { z = C.paper }) end
  elseif ab == "moonfog" then
    for sgn = -1, 1, 2 do rect(EYE.gold, cx - 14 + sgn * 6 - px(), 62, px(2), px()) end
  elseif ab == "downpour" then
    for sgn = -1, 1, 2 do rect(EYE.gold, cx + sgn * 7 - px(), h - 10, px(2), px()) end
  elseif ab == "warhorn" then
    col(GOLD.light, 0.8)
    lg.setLineWidth(px())
    for i = 1, 3 do lg.arc("line", "open", snap(cx + 18), snap(cy - 8), 8 + i * 7, -0.9, 0.9, 16) end
    lg.setLineWidth(1)
  end
end

-- ---------------------------------------------------------------- compositing

local cache = {}

local function begin(cv, opaque)
  lg.push("all")
  lg.origin()
  lg.setScissor()
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, opaque and 1 or 0)
end

-- Replace stray single pixels with their surroundings. Needs canvas read-back; skipped where
-- the platform can't.
local function cleanup(cv)
  local ok, data = pcall(function() return cv:newImageData() end)
  if not ok or not data then return cv end
  local w, h = data:getDimensions()
  local P = {}
  for y = 0, h - 1 do
    local row = {}
    for x = 0, w - 1 do
      local r, g, b, a = data:getPixel(x, y)
      row[x] = { r, g, b, a }
    end
    P[y] = row
  end
  local function same(p, q)
    return math.abs(p[1] - q[1]) < 0.02 and math.abs(p[2] - q[2]) < 0.02 and math.abs(p[3] - q[3]) < 0.02 and (p[4] > 0.5) == (q[4] > 0.5)
  end
  local changed = false
  for y = 1, h - 2 do
    for x = 1, w - 2 do
      local p = P[y][x]
      if p[4] > 0.5 then
        local n = { P[y - 1][x], P[y + 1][x], P[y][x - 1], P[y][x + 1] }
        local alike = false
        for _, q in ipairs(n) do if same(p, q) then alike = true; break end end
        if not alike then
          local best, bestN = nil, 0
          for _, q in ipairs(n) do
            if q[4] > 0.5 then
              local c = 0
              for _, q2 in ipairs(n) do if same(q, q2) then c = c + 1 end end
              if c > bestN then best, bestN = q, c end
            end
          end
          if best and bestN >= 2 then data:setPixel(x, y, best[1], best[2], best[3], best[4]); changed = true end
        end
      end
    end
  end
  if not changed then return cv end
  local img = lg.newImage(data)
  img:setFilter("nearest", "nearest")
  return img
end

local OFFSETS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
local RIM = { shadow = hex("#5fbf94"), menace = hex("#c8382c") }

-- Paint a picture of outW x outH pixels. The logical space is 100 units wide.
local function compose(key, outW, outH, layers, o, transparent)
  if cache[key] then return cache[key] end
  K = outW / 100
  local lw, lh = 100, outH / K
  -- 1. the figure's shapes, cleaned up, then its details
  local shapes = lg.newCanvas(outW, outH)
  shapes:setFilter("nearest", "nearest")
  begin(shapes)
  lg.scale(K)
  layers.fig(lw, lh, o)
  lg.pop()
  local clean = cleanup(shapes)
  local fig = lg.newCanvas(outW, outH)
  fig:setFilter("nearest", "nearest")
  begin(fig)
  lg.setColor(1, 1, 1)
  lg.draw(clean, 0, 0)
  if layers.details then
    lg.scale(K)
    layers.details(lw, lh, o)
  end
  lg.pop()
  if clean ~= shapes then clean:release() end
  shapes:release()
  -- 2. backdrop, outline (with a rim light for dark cats), figure, glow
  local out = lg.newCanvas(outW, outH)
  out:setFilter("nearest", "nearest")
  begin(out, not transparent)
  if not transparent then
    lg.push(); lg.scale(K); layers.bg(lw, lh, o); lg.pop()
  end
  if o.ghost then
    lg.setColor(0.25, 0.7, 0.75, 0.35)
    lg.draw(fig, -6, 0)
  end
  local rim = o.menace and RIM.menace or (o.coat == "shadow" and RIM.shadow) or nil
  if rim then
    lg.setColor(rim[1], rim[2], rim[3], 1)
    for _, d in ipairs(OFFSETS) do lg.draw(fig, d[1] * 2, d[2] * 2) end
    for _, d in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do lg.draw(fig, d[1], d[2]) end
  end
  lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
  for _, d in ipairs(OFFSETS) do lg.draw(fig, d[1], d[2]) end
  lg.setColor(1, 1, 1, 1)
  lg.draw(fig, 0, 0)
  lg.push(); lg.scale(K); layers.fx(lw, lh, o); lg.pop()
  lg.pop()
  fig:release()
  cache[key] = out
  return out
end

-- an exact integer enlargement of a picture
local function enlarge(key, img, n)
  if n == 1 then return img end
  if cache[key] then return cache[key] end
  local w, h = img:getDimensions()
  local out = lg.newCanvas(w * n, h * n)
  out:setFilter("nearest", "nearest")
  begin(out)
  lg.setColor(1, 1, 1)
  lg.draw(img, 0, 0, 0, n, n)
  lg.pop()
  cache[key] = out
  return out
end

local CAT = {
  bg = bgPaint,
  fig = figureShapes,
  details = figureDetails,
  fx = function(w, h, o) fxLayer(w, h, o, snap(w / 2), snap(h - 52)) end,
}
local TRICK = { bg = trickBg, fig = trickFig, fx = trickFx }

-- ---------------------------------------------------------------- public API

M.CARD_W, M.CARD_H = 50, 48

local function cardSpec(def)
  local o = {
    seed = def.artSeed or rngm.hash(def.id), coat = def.coat, magic = def.type == "magic", ability = def.ability,
    legendary = def.rarity == "legendary", rarity = def.rarity, scars = def.scars,
  }
  local s = SPEC[def.id]
  if s then for k, v in pairs(s) do o[k] = v end end
  if def.scars and def.scars > (o.scars or 0) then o.scars = def.scars end
  return derive(o)
end
M.cardSpec = cardSpec

-- The picture on a card face (50x48); scale 2 or 3 gives an exact enlargement for the inspect
-- panel, tooltips and the Cattery.
function M.card(def, scale)
  scale = scale or 1
  local key = ("card:%s:%d"):format(def.id, def.scars or 0)
  local base = cache[key]
  if not base then
    if def.kind == "special" then
      base = compose(key, M.CARD_W, M.CARD_H, TRICK, { ability = def.ability, seed = rngm.hash(def.id), coat = "shadow" }, false)
    else
      base = compose(key, M.CARD_W, M.CARD_H, CAT, cardSpec(def), false)
    end
  end
  return enlarge(key .. ":x" .. scale, base, scale)
end
function M.illustration(def) return M.card(def, 2) end

-- Square portraits. Painted at up to 64px and enlarged by whole steps beyond that.
-- Returns the image and the eye positions {x1, y1, x2, y2, colour} in output pixels.
local eyes = {}
function M.portrait(o, size)
  size = size or 48
  local n = math.max(1, math.ceil(size / 64))
  local base = floor(size / n)
  local key = ("p:%d:%s:%s:%s:%s:%d:%s:%s:%d:%s:%s"):format(o.seed or 0, o.coat, tostring(o.magic), tostring(o.ability), tostring(o.legendary), o.scars or 0,
    tostring(o.crown), tostring(o.menace), base, tostring(o.cutout), tostring(o.id))
  if not cache[key] then
    derive(o)
    compose(key, base, base, CAT, o, o.cutout)
    local k = base / 100
    local cx, cy = floor(50 * k + 0.5), floor((100 - 52 + 1) * k + 0.5)
    local ex = floor(10 * o.headW * k + 0.5)
    eyes[key] = { cx - ex, cy, cx + ex, cy, EYE[o.eyes] or EYE.gold }
  end
  local e = eyes[key]
  local img = enlarge(key .. ":x" .. n, cache[key], n)
  return img, { e[1] * n, e[2] * n, e[3] * n, e[4] * n, e[5] }
end

function M.nemesis(n, rank, size, cutout)
  return M.portrait({ seed = n.seed, coat = n.coat, magic = n.style == "hex" or n.style == "inspire" or n.style == "groom",
    ability = n.style, legendary = false, crown = rank == 1, scars = n.scars, menace = true, cutout = cutout,
    rarity = "epic" }, size)
end

function M.player(name, size, cutout)
  return M.portrait({ seed = rngm.hash(name), coat = "gilt", magic = false, ability = "smite", legendary = false, cutout = cutout,
    rarity = "rare", prop = "sword", hat = "none", outfit = "plate", expr = "calm", eyes = "green", pattern = "tabby" }, size)
end

function M.stray(foe, size, cutout)
  return M.portrait({ seed = foe.seed, coat = foe.coat, magic = false, ability = "none", legendary = false, menace = foe.elite, cutout = cutout,
    rarity = "common" }, size)
end

-- Story characters: Old Bedimew (your mentor) and the Crier.
function M.character(id, size, cutout)
  local o
  if id == "bedimew" then
    o = { id = id, seed = 4040, coat = "gilt", magic = false, ability = "groom", rarity = "rare", cutout = cutout, scars = 2 }
    for k, v in pairs(SPEC.bedimew) do o[k] = v end
  elseif id == "crier" then
    o = { id = id, seed = 777, coat = "gilt", magic = true, ability = "yowl", rarity = "rare", cutout = cutout }
    for k, v in pairs(SPEC.taliesing) do o[k] = v end
  else
    return nil
  end
  return M.portrait(o, size)
end

-- Portrait for any festival entrant. cutout: no backdrop, just the cat (for looming over the table).
function M.entrant(save, e, size, cutout)
  if e.kind == "player" then return M.player(save.playerName, size, cutout) end
  if e.kind == "hand" then
    local game = require("src.core.game")
    local n = game.findNemesis(save, e.id)
    if n then return M.nemesis(n, game.rankOf(save, n), size, cutout) end
  end
  return M.stray(e.foe or { seed = e.seed or 1, coat = e.coat or "shadow" }, size, cutout)
end

function M.bake(img, w) return require("src.ui.plates").image(img, w) end

return M
