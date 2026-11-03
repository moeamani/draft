-- Cat illustrations, painted with plain primitives so they work everywhere (LÖVE Potion too).
--
-- Every picture is a bust portrait in three layers, in a 100-unit-wide logical space:
--   bg   a themed backdrop for the cat's coat (an Ember hall, a Tide shore, a Gilt sunburst, a
--        Shadow moon), or blood red for the Four Hands
--   fig  the cat: shoulders and outfit, ears, a shaded head with its fur pattern, the face, the
--        headwear and the props. It's painted on its own layer and gets a 1px dark outline.
--   fx   what glows and shouldn't be outlined: whiskers, orbs, flames, sparkles, notes, runes
-- Pictures are painted at 2x and box-filtered down, then quantised with the Figma dither like
-- every other surface. Results are cached.
local rngm = require("src.core.rng")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
local hex = theme.hex
local C = theme.c
local PI = math.pi

-- ---------------------------------------------------------------- palette

local FUR = {
  ember = { base = hex("#e07a3a"), light = hex("#f7ad6a"), dark = hex("#b0502a"), stripe = hex("#8a3216"), muzzle = hex("#fbe3c6") },
  tide = { base = hex("#7f93a8"), light = hex("#b6c6d6"), dark = hex("#56677c"), stripe = hex("#44526a"), muzzle = hex("#e4eaf0") },
  gilt = { base = hex("#e8c47c"), light = hex("#f9e7bb"), dark = hex("#bd9045"), stripe = hex("#a5762d"), muzzle = hex("#fff6e2") },
  shadow = { base = hex("#333844"), light = hex("#5a6274"), dark = hex("#1b1e25"), stripe = hex("#101216"), muzzle = hex("#474d5c") },
  cream = { base = hex("#f1e6d2"), light = hex("#fffaf0"), dark = hex("#cdbb9c"), stripe = hex("#7a5a40"), muzzle = hex("#fffdf8") },
}
local PATTERNS = {
  ember = { "tabby", "tabby", "solid", "tux", "patch" },
  tide = { "solid", "tabby", "smoke", "tux" },
  gilt = { "solid", "tabby", "points", "fluff" },
  shadow = { "solid", "solid", "tux", "smoke" },
}
local EYE = {
  gold = hex("#f2c230"), green = hex("#8fd14f"), blue = hex("#5cc6ff"), copper = hex("#e8822e"),
  red = hex("#ff3b30"), violet = hex("#c18cff"), cyan = hex("#47e7fd"),
}
local EYES_BY_COAT = {
  ember = { "green", "gold", "copper" }, tide = { "gold", "copper", "green" },
  gilt = { "blue", "green", "gold" }, shadow = { "gold", "green", "gold" },
}
local OUTLINE = hex("#07090a")
local PINK, PINKD = hex("#f2909a"), hex("#c25f6c")
local STEEL = { base = hex("#9aa6b8"), light = hex("#dce4ee"), dark = hex("#5d6878"), deep = hex("#3c4552") }
local GOLD = { base = hex("#e0b021"), light = hex("#ffe27a"), dark = hex("#9a7408") }
local WOOD, WOODD = hex("#8a5a32"), hex("#5c3a1f")
local CLOTH = { ember = hex("#c8382c"), tide = hex("#2471fc"), gilt = hex("#d3a200"), shadow = hex("#24503c"), none = hex("#24503c") }
local ROBES = { hex("#2471fc"), hex("#c8382c"), hex("#24503c"), hex("#3b3f8f"), hex("#16352a") }

local BG = {
  ember = { top = hex("#5a1d12"), bottom = hex("#160806"), glow = hex("#ff8a3a"), accent = hex("#e8483b") },
  tide = { top = hex("#123d6e"), bottom = hex("#061326"), glow = hex("#5cb8ff"), accent = hex("#47e7fd") },
  gilt = { top = hex("#5e4500"), bottom = hex("#1c1300"), glow = hex("#ffd34a"), accent = hex("#ffe27a") },
  shadow = { top = hex("#16352a"), bottom = hex("#030605"), glow = hex("#47e7fd"), accent = hex("#f4f1e8") },
  menace = { top = hex("#3c0707"), bottom = hex("#0a0202"), glow = hex("#ff3b30"), accent = hex("#ff8a3a") },
}

-- ---------------------------------------------------------------- drawing helpers

local function col(c, a) lg.setColor(c[1], c[2], c[3], a or c[4] or 1) end
local function ell(x, y, rx, ry, c, rot, a)
  col(c, a)
  if rot and rot ~= 0 then
    lg.push(); lg.translate(x, y); lg.rotate(rot)
    lg.ellipse("fill", 0, 0, math.max(0.1, rx), math.max(0.1, ry), 28)
    lg.pop()
  else
    lg.ellipse("fill", x, y, math.max(0.1, rx), math.max(0.1, ry), 28)
  end
end
local function poly(c, ...) col(c); lg.polygon("fill", ...) end -- convex shapes only
local function ln(c, w, ...) col(c); lg.setLineWidth(w); lg.line(...); lg.setLineWidth(1) end
local function rect(c, x, y, w, h, a) col(c, a); lg.rectangle("fill", x, y, w, h) end
local function rrect(c, x, y, w, h, rot) -- rotated rectangle around its centre
  col(c)
  lg.push(); lg.translate(x, y); lg.rotate(rot or 0); lg.rectangle("fill", -w / 2, -h / 2, w, h); lg.pop()
end
local function vgrad(x, y, w, h, top, bottom)
  for i = 0, math.ceil(h) - 1 do
    local t = h > 1 and i / (h - 1) or 0
    lg.setColor(top[1] + (bottom[1] - top[1]) * t, top[2] + (bottom[2] - top[2]) * t, top[3] + (bottom[3] - top[3]) * t, 1)
    lg.rectangle("fill", x, y + i, w, 1)
  end
end
-- a soft radial glow from stacked circles (alphas compound to a linear falloff)
local function glow(x, y, r, c, a, rings)
  rings = rings or 12
  local prev = 0
  for k = 1, rings do
    local target = a * k / rings
    col(c, (target - prev) / (1 - prev))
    lg.circle("fill", x, y, r * (1 - (k - 1) / rings), 32)
    prev = target
  end
end
local function sparkle(x, y, s, c, a)
  ell(x, y, s * 0.35, s * 1.6, c, 0, a)
  ell(x, y, s * 1.6, s * 0.35, c, 0, a)
  ell(x, y, s * 0.5, s * 0.5, C.white, 0, a)
end
local function mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, 1 } end

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
  mordraleus = { pattern = "solid", eyes = "red", hat = "hornhelm", outfit = "plate", steel = "dark", prop = "sword", expr = "fierce", ghost = true },
  merlinus = { pattern = "tux", eyes = "blue", hat = "bigwizard", robe = hex("#3b3f8f"), prop = "book", expr = "wide" },
  uther = { pattern = "tabby", eyes = "gold", hat = "crown", outfit = "plate", prop = "banner", cape = hex("#2471fc"), expr = "yowl" },
  greenmouser = { pattern = "smoke", eyes = "green", hat = "none", outfit = "plate", steel = "green", prop = "axe", halo = true, expr = "calm" },
  mewdred = { pattern = "tabby", eyes = "copper", hat = "helm", outfit = "plate", prop = "claws", expr = "fierce" },
  galahiss = { pattern = "solid", fur = "cream", eyes = "blue", hat = "none", outfit = "plate", steel = "white", prop = "sword", halo = "gold", expr = "calm", tongue = true },
  gawpaw = { pattern = "tabby", eyes = "gold", hat = "helm", outfit = "plate", prop = "claws", emblem = "sun", expr = "fierce" },
  bedimew = { pattern = "points", eyes = "blue", hat = "coif", outfit = "mail", prop = "sword", expr = "smug", tongue = true },
  borscat = { pattern = "tabby", eyes = "gold", hat = "helm", outfit = "mail", prop = "sword", halo = true, scars = 2 },
  lamoracat = { pattern = "fluff", eyes = "copper", hat = "none", outfit = "mail", prop = "shield", headW = 1.12, expr = "smug" },
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

local PROP_PHYS = { smite = "hammer", none = "shield", litter = "spear", muster = "banner", yowl = "banner", pounce = "claws", ninelives = "sword", stray = "fishbone", groom = "sword", purr = "lute" }
local PROP_MAGIC = { inspire = "orb", hex = "wand", litter = "staff", pounce = "fireball", muster = "orb", yowl = "lute", stray = "crystal", purr = "book", groom = "staff", none = "candle" }
local EXPR = { purr = "happy", yowl = "yowl", hex = "smug", pounce = "fierce", stray = "smug", muster = "wide" }

-- Fill in everything a painter needs. o: seed, coat, magic, ability, legendary, rarity, scars,
-- menace, crown, cutout; plus any SPEC fields.
local function derive(o)
  local r = rngm.new(o.seed or 1)
  local function nx() return rngm.next(r) end
  local function pick(t) return t[math.floor(nx() * #t) + 1] end
  o.coat = FUR[o.coat] and o.coat or "shadow"
  o.pattern = o.pattern or pick(PATTERNS[o.coat] or PATTERNS.shadow)
  o.fur = o.fur or (o.pattern == "points" and "cream" or o.coat)
  o.eyes = o.eyes or (o.menace and "red" or pick(EYES_BY_COAT[o.coat] or EYES_BY_COAT.shadow))
  o.expr = o.expr or (o.menace and "fierce") or EXPR[o.ability] or pick({ "calm", "calm", "smug", "fierce", "wide" })
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
  o.headW = o.headW or (0.95 + nx() * 0.12)
  o.earH = o.earH or (0.85 + nx() * 0.35)
  o.jx = o.jx or (nx() - 0.5) * 3
  if o.ability == "litter" and o.kittens == nil then o.kittens = true end
  if o.ability == "groom" and o.tongue == nil then o.tongue = true end
  if o.ability == "purr" and o.notes == nil then o.notes = true end
  if o.ability == "ninelives" and o.halo == nil then o.halo = true end
  if o.ability == "hex" and o.runes == nil then o.runes = true end
  if (o.ability == "inspire" or o.legendary) and o.sparkles == nil then o.sparkles = true end
  if o.ability == "stray" and o.eyepatch == nil then o.eyepatch = nx() < 0.6 end
  if (o.scars or 0) >= 3 then o.torn = true end
  o.rng = r
  return o
end

-- ---------------------------------------------------------------- backgrounds

local function bgPaint(w, h, o)
  local key = o.menace and "menace" or o.coat
  local B = BG[key] or BG.shadow
  local r = rngm.new((o.seed or 1) + 77)
  local function nx() return rngm.next(r) end
  vgrad(0, 0, w, h, B.top, B.bottom)
  local cx, cy = w / 2 + (o.jx or 0), h - 52
  if key == "ember" then
    -- a hall with hanging pennants, lit by a brazier
    for _, px in ipairs({ 8, w - 20 }) do
      rect(hex("#3a0e0a"), px, 0, 12, 34)
      poly(hex("#3a0e0a"), px, 34, px + 12, 34, px + 6, 40)
      rect(hex("#7a2016"), px + 2, 0, 8, 30)
    end
    glow(cx, cy + 4, 58, B.glow, 0.55)
    for i = 1, 16 do
      local ex, ey = nx() * w, nx() * h * 0.9
      rect(nx() < 0.5 and B.glow or GOLD.light, ex, ey, 1.4, 1.4, 0.5 + nx() * 0.5)
    end
  elseif key == "tide" then
    glow(cx, cy, 60, B.glow, 0.45)
    for i = 1, 18 do
      local rx, ry = nx() * w, nx() * h * 0.7
      ln(B.accent, 0.8, rx, ry, rx - 3, ry + 7)
    end
    for k = 0, 2 do
      local y = h - 30 + k * 9
      for x = -6, w, 14 do
        col(B.accent, 0.25 + k * 0.08); lg.setLineWidth(1.4)
        lg.arc("line", "open", x + (k % 2) * 7, y, 7, PI, 2 * PI)
      end
    end
    lg.setLineWidth(1)
  elseif key == "gilt" then
    -- sunburst
    for i = 0, 15 do
      local a1, a2 = i / 16 * 2 * PI, (i + 0.5) / 16 * 2 * PI
      if i % 2 == 0 then
        col(B.glow, 0.16)
        lg.polygon("fill", cx, cy - 4, cx + math.cos(a1) * 140, cy - 4 + math.sin(a1) * 140, cx + math.cos(a2) * 140, cy - 4 + math.sin(a2) * 140)
      end
    end
    glow(cx, cy - 4, 50, B.glow, 0.5)
    -- castle on the horizon
    local base = h - 26
    for _, t in ipairs({ { 6, 14 }, { 20, 22 }, { w - 34, 20 }, { w - 16, 12 } }) do
      rect(hex("#2a1e00"), t[1], base - t[2], 11, t[2] + 26)
      for k = 0, 2 do rect(hex("#2a1e00"), t[1] + k * 4, base - t[2] - 3, 3, 3) end
    end
  elseif key == "shadow" then
    local mx, my = w - 22, 18
    glow(mx, my, 30, B.glow, 0.25)
    ell(mx, my, 10, 10, C.paper)
    ell(mx - 3, my - 2, 2.4, 2, hex("#d8d3c2")); ell(mx + 3, my + 3, 1.8, 1.6, hex("#d8d3c2")); ell(mx + 4, my - 4, 1.2, 1.2, hex("#d8d3c2"))
    for i = 1, 14 do
      local sx, sy = nx() * w, nx() * h * 0.6
      rect(C.paper, sx, sy, 1, 1, 0.4 + nx() * 0.6)
    end
    glow(cx, cy, 52, B.glow, 0.3)
    for k = 0, 2 do rect(C.paper, 0, h - 26 + k * 8, w, 3, 0.05 + k * 0.03) end
  elseif key == "menace" then
    glow(cx, cy, 64, B.glow, 0.5)
    for i = 0, 9 do
      local fx = i * (w / 9)
      local fh = 14 + nx() * 22
      col(i % 2 == 0 and B.glow or B.accent, 0.55)
      lg.polygon("fill", fx - 9, h, fx + 9, h, fx + (nx() - 0.5) * 6, h - fh)
    end
  end
  if o.legendary then
    for i = 0, 7 do
      local a = i / 8 * 2 * PI + 0.2
      col(GOLD.light, 0.12)
      lg.polygon("fill", cx, cy, cx + math.cos(a) * 120, cy + math.sin(a) * 120, cx + math.cos(a + 0.12) * 120, cy + math.sin(a + 0.12) * 120)
    end
  end
end

-- ---------------------------------------------------------------- the cat

local function emblem(kind, x, y, s, c)
  if kind == "ember" then
    poly(c, x - 3 * s, y + 3 * s, x + 3 * s, y + 3 * s, x, y - 4 * s)
    poly(c, x - 4 * s, y + 3 * s, x - 1 * s, y + 3 * s, x - 3 * s, y - 1 * s)
    poly(c, x + 1 * s, y + 3 * s, x + 4 * s, y + 3 * s, x + 3 * s, y - 1 * s)
  elseif kind == "tide" then
    col(c); lg.setLineWidth(1.4 * s)
    lg.arc("line", "open", x - 2 * s, y, 2.5 * s, PI, 2 * PI); lg.arc("line", "open", x + 3 * s, y, 2.5 * s, 0, PI)
    lg.setLineWidth(1)
  elseif kind == "gilt" or kind == "sun" then
    ell(x, y, 2.4 * s, 2.4 * s, c)
    for i = 0, 7 do
      local a = i / 8 * 2 * PI
      ln(c, 0.9 * s, x + math.cos(a) * 3 * s, y + math.sin(a) * 3 * s, x + math.cos(a) * 4.6 * s, y + math.sin(a) * 4.6 * s)
    end
  else -- shadow: a moon
    ell(x, y, 3.2 * s, 3.2 * s, c)
  end
end

local function steelOf(o)
  if o.steel == "dark" then return { base = hex("#3a3f4c"), light = hex("#6b7487"), dark = hex("#1d2027"), deep = hex("#101216") } end
  if o.steel == "green" then return { base = hex("#4f8a5c"), light = hex("#8fd19c"), dark = hex("#2c5536"), deep = hex("#1a3320") } end
  if o.steel == "white" then return { base = hex("#d9dee6"), light = hex("#ffffff"), dark = hex("#9aa6b8"), deep = hex("#6b7487") } end
  return STEEL
end

local function body(w, h, o, cx)
  local S = steelOf(o)
  local by = h + 18
  if o.cape then
    ell(cx, by + 4, 52, 50, theme.darken and theme.darken(o.cape, 0.6) or o.cape)
    ell(cx - 2, by + 2, 50, 49, o.cape)
  end
  local outfit = o.outfit
  if outfit == "plate" then
    ell(cx, by, 44, 44, S.dark); ell(cx - 1.5, by - 1.5, 42, 42.5, S.base)
    ell(cx - 14, by - 32, 12, 4, S.light, -0.3)
    -- pauldrons
    for sgn = -1, 1, 2 do
      local px = cx + sgn * 31
      ell(px, h - 14, 15, 12, S.dark); ell(px - 1, h - 15, 13.5, 10.5, S.base)
      ell(px - 3, h - 19, 7, 3, S.light, sgn * 0.2)
      ln(S.deep, 1, px - 13, h - 10, px + 13, h - 10)
    end
    -- tabard
    rect(mix(o.cloth, C.black, 0.35), cx - 12, h - 26, 24, 26)
    rect(o.cloth, cx - 11, h - 26, 22, 26)
    emblem(o.emblem or o.coat, cx, h - 13, 1.3, o.coat == "gilt" and C.paper or GOLD.light)
  elseif outfit == "mail" then
    ell(cx, by, 44, 44, S.dark); ell(cx - 1.5, by - 1.5, 42, 42.5, S.base)
    for yy = h - 26, h, 3 do
      for xx = cx - 40, cx + 40, 3 do
        if ((xx - cx) / 44) ^ 2 + ((yy - by) / 44) ^ 2 < 1 then rect(S.dark, xx + (yy % 2) * 1.5, yy, 1, 1) end
      end
    end
    rect(mix(o.cloth, C.black, 0.35), cx - 13, h - 24, 26, 24)
    rect(o.cloth, cx - 12, h - 24, 24, 24)
    emblem(o.emblem or o.coat, cx, h - 12, 1.2, o.coat == "gilt" and C.paper or GOLD.light)
  elseif outfit == "robe" then
    local R = o.robe
    ell(cx, by, 44, 44, mix(R, C.black, 0.45)); ell(cx - 1.5, by - 1.5, 42, 42.5, R)
    ell(cx - 16, by - 34, 12, 4, mix(R, C.white, 0.3), -0.3)
    -- high collar
    poly(mix(R, C.black, 0.25), cx - 22, h - 20, cx - 8, h - 26, cx - 16, h - 40)
    poly(mix(R, C.black, 0.25), cx + 22, h - 20, cx + 8, h - 26, cx + 16, h - 40)
    ln(GOLD.base, 1.4, cx - 20, h - 21, cx - 15, h - 38)
    ln(GOLD.base, 1.4, cx + 20, h - 21, cx + 15, h - 38)
    ln(GOLD.base, 1.6, cx, h - 24, cx, h)
    ell(cx, h - 18, 3.4, 3.4, GOLD.dark); ell(cx, h - 18, 2.4, 2.4, o.magic and EYE.cyan or C.red)
  elseif outfit == "apron" or outfit == "tunic" or outfit == "rags" then
    local T = outfit == "rags" and hex("#6b5440") or o.cloth
    ell(cx, by, 44, 44, mix(T, C.black, 0.45)); ell(cx - 1.5, by - 1.5, 42, 42.5, T)
    ell(cx - 16, by - 34, 12, 4, mix(T, C.white, 0.25), -0.3)
    poly(mix(T, C.black, 0.35), cx - 9, h - 26, cx + 9, h - 26, cx, h - 14) -- v-neck
    if outfit == "apron" then
      rect(C.paper, cx - 14, h - 22, 28, 22)
      rect(hex("#d8d3c2"), cx - 14, h - 22, 28, 2)
      ln(hex("#d8d3c2"), 1, cx - 14, h - 22, cx - 22, h - 34)
      ln(hex("#d8d3c2"), 1, cx + 14, h - 22, cx + 22, h - 34)
    elseif outfit == "rags" then
      rect(hex("#8a6a4a"), cx - 26, h - 16, 9, 7)
      rect(hex("#4a3828"), cx + 14, h - 10, 8, 6)
      ln(hex("#c9a66b"), 1.6, cx - 30, h - 30, cx + 22, h)
    else
      ln(WOODD, 2.4, cx - 30, h - 28, cx + 26, h)
      rect(GOLD.base, cx - 3, h - 15, 5, 4)
    end
  end
  if o.cape then
    -- ermine collar
    ell(cx, h - 24, 30, 6, C.paper)
    for i = -3, 3 do rect(C.black, cx + i * 8 - 0.5, h - 25 + (i % 2), 1.2, 2) end
  end
end

-- Union of the head shapes (skull, cheeks, chin), offset and shrunk for shading.
local function headShape(cx, cy, o, c, dx, dy, s)
  local wf = o.headW
  ell(cx + dx, cy + dy, 22 * wf - s, 18.5 - s, c)
  ell(cx - 12 * wf + dx, cy + 7 + dy, 12.5 * wf - s, 10.5 - s, c)
  ell(cx + 12 * wf + dx, cy + 7 + dy, 12.5 * wf - s, 10.5 - s, c)
  ell(cx + dx, cy + 11 + dy, 11 - s, 8.5 - s, c)
end

local function ears(cx, cy, o, F)
  local wf, eh = o.headW, o.earH
  for sgn = -1, 1, 2 do
    local bx1, by1 = cx + sgn * 22 * wf, cy - 2
    local bx2, by2 = cx + sgn * 6 * wf, cy - 16
    local tx, ty = cx + sgn * 21 * wf, cy - 16 - 18 * eh
    local earBase = (o.pattern == "points") and FUR[o.coat == "gilt" and "ember" or o.coat].stripe or F.base
    poly(F.dark, bx1, by1, bx2, by2, tx, ty)
    poly(earBase, bx1 - sgn * 1.2, by1 - 1, bx2 + sgn * 0.6, by2, tx - sgn * 0.6, ty + 2)
    poly(PINK, bx1 - sgn * 4.5, by1 - 4, bx2 + sgn * 3.5, by2 - 1, tx - sgn * 1.4, ty + 6)
    if o.pattern == "fluff" then
      ln(F.light, 1, tx - sgn * 3, ty + 9, tx - sgn * 5, ty + 15)
      ln(F.light, 1, tx - sgn * 1, ty + 10, tx - sgn * 2, ty + 16)
    end
    if o.torn and sgn == 1 then
      -- a notch bitten out of the right ear
      local mxp, myp = (bx1 + tx) / 2, (by1 + ty) / 2
      lg.setBlendMode("replace")
      lg.setColor(0, 0, 0, 0)
      lg.polygon("fill", mxp + 3, myp - 4, mxp + 3, myp + 3, mxp - 2, myp)
      lg.setBlendMode("alpha")
    end
  end
end

local function pattern(cx, cy, o, F)
  local wf = o.headW
  local p = o.pattern
  if p == "tabby" or p == "patch" then
    -- the "M" on the forehead and cheek stripes
    ln(F.stripe, 2, cx, cy - 18, cx, cy - 10)
    ln(F.stripe, 1.6, cx - 5, cy - 17, cx - 4, cy - 10)
    ln(F.stripe, 1.6, cx + 5, cy - 17, cx + 4, cy - 10)
    for sgn = -1, 1, 2 do
      ln(F.stripe, 1.5, cx + sgn * 24 * wf, cy + 3, cx + sgn * 16 * wf, cy + 4.5)
      ln(F.stripe, 1.5, cx + sgn * 24 * wf, cy + 8, cx + sgn * 17 * wf, cy + 9)
    end
    if p == "patch" then
      ell(cx - 11, cy - 8, 8, 6, FUR.shadow.base, -0.3)
      ell(cx + 14, cy + 6, 6, 5, FUR.cream.base, 0.4)
    end
  elseif p == "smoke" then
    ell(cx - 2, cy - 12, 7, 4, F.light, -0.2)
  elseif p == "points" then
    -- a darker mask around the eyes and nose
    local P = FUR[o.coat == "gilt" and "ember" or o.coat] or FUR.ember
    ell(cx, cy + 5, 13 * wf, 10, mix(F.base, P.stripe, 0.55))
  elseif p == "fluff" then
    for sgn = -1, 1, 2 do
      for k = 0, 2 do
        poly(F.light, cx + sgn * (17 + k * 2) * wf, cy + 6 + k * 4, cx + sgn * (27 + k) * wf, cy + 10 + k * 5, cx + sgn * (18 + k * 2) * wf, cy + 13 + k * 4)
      end
    end
  end
end

local function eye(x, y, o, sgn, F)
  local ec = EYE[o.eyes] or EYE.gold
  local rx, ry = 6.2, 5.4
  if o.expr == "happy" then
    col(OUTLINE); lg.setLineWidth(2)
    lg.arc("line", "open", x, y + 2.5, 4.6, PI * 1.12, PI * 1.88)
    lg.setLineWidth(1)
    return
  end
  if o.eyepatch and sgn == -1 then
    ell(x, y, rx + 1.2, ry + 1.2, OUTLINE)
    ln(OUTLINE, 1.6, x - 12, y - 10, x + 14, y - 14)
    return
  end
  if o.expr == "wide" then rx, ry = 6.8, 6.4 end
  ell(x, y, rx + 1.1, ry + 1.1, OUTLINE)
  ell(x, y, rx, ry, ec)
  ell(x, y + ry * 0.35, rx * 0.8, ry * 0.5, mix(ec, C.white, 0.35))
  local pw = o.expr == "wide" and 2.8 or (o.menace and 0.9 or 1.5)
  ell(x, y, pw, ry * 0.86, OUTLINE)
  ell(x - 2.2, y - 2.2, 1.4, 1.4, C.white)
  ell(x + 2, y + 2.4, 0.7, 0.7, C.white)
  local lid = F.base
  if o.expr == "smug" then
    poly(lid, x - rx - 2, y - ry - 2, x + rx + 2, y - ry - 2, x + rx + 2, y - 0.4, x - rx - 2, y - 0.4)
    ln(OUTLINE, 1.6, x - rx - 0.5, y - 0.4, x + rx + 0.5, y - 0.4)
  elseif o.expr == "fierce" or o.expr == "yowl" then
    local inner = -sgn
    poly(lid, x - inner * (rx + 2), y - ry - 2.5, x + inner * (rx + 2), y - ry - 2.5, x + inner * (rx + 2), y + 0.8)
    ln(OUTLINE, 1.8, x - inner * (rx + 0.5), y - ry + 0.2, x + inner * (rx + 0.8), y + 0.6)
  end
end

local function face(cx, cy, o, F)
  local muz = F.muzzle
  if o.pattern == "tux" then muz = C.paper end
  if o.pattern == "tux" then
    poly(C.paper, cx - 6, cy - 2, cx + 6, cy - 2, cx + 9, cy + 14, cx - 9, cy + 14)
  end
  ell(cx - 4.8, cy + 9.5, 5.8, 4.6, muz)
  ell(cx + 4.8, cy + 9.5, 5.8, 4.6, muz)
  ell(cx, cy + 13, 4.8, 3.6, muz)
  -- eyes
  for sgn = -1, 1, 2 do eye(cx + sgn * 10 * o.headW, cy + 1, o, sgn, F) end
  -- nose and mouth
  poly(PINK, cx - 2.8, cy + 5.6, cx + 2.8, cy + 5.6, cx, cy + 8.4)
  ell(cx - 0.8, cy + 6, 0.9, 0.5, C.white)
  if o.expr == "yowl" then
    ell(cx, cy + 13.5, 5, 4.6, OUTLINE)
    ell(cx, cy + 15.5, 3, 2, PINK)
    poly(C.white, cx - 4, cy + 10.5, cx - 2, cy + 10.5, cx - 3, cy + 14)
    poly(C.white, cx + 2, cy + 10.5, cx + 4, cy + 10.5, cx + 3, cy + 14)
  else
    col(OUTLINE); lg.setLineWidth(1.1)
    lg.line(cx, cy + 8.4, cx, cy + 10)
    lg.arc("line", "open", cx - 2.3, cy + 9.8, 2.3, 0.1, PI - 0.1)
    lg.arc("line", "open", cx + 2.3, cy + 9.8, 2.3, 0.1, PI - 0.1)
    lg.setLineWidth(1)
    if o.tongue then ell(cx + 1, cy + 13.6, 2.4, 2.8, PINK); ln(PINKD, 0.8, cx + 1, cy + 12, cx + 1, cy + 15) end
  end
  -- scars
  local scars = o.scars or 0
  if scars > 0 then ln(C.paper, 1.2, cx - 14, cy - 8, cx - 6, cy + 7) end
  if scars > 1 then ln(PINKD, 1.2, cx + 6, cy - 12, cx + 14, cy - 4) end
end

-- Headwear that sits behind the head (drawn before the ears).
local function hatBack(cx, cy, o, F)
  local hat = o.hat
  if hat == "hood" or hat == "hoodCirclet" or hat == "veil" then
    local R = hat == "veil" and hex("#9fd8ff") or o.robe
    local a = hat == "veil" and 0.85 or 1
    col(mix(R, C.black, 0.4), a); lg.ellipse("fill", cx, cy + 2, 31, 30, 32)
    col(R, a); lg.ellipse("fill", cx - 1, cy + 1, 29.5, 29, 32)
    col(R, a); lg.polygon("fill", cx - 14, cy - 22, cx + 14, cy - 22, cx + 4, cy - 40)
  elseif hat == "coif" then
    local S = steelOf(o)
    ell(cx, cy + 4, 30, 29, S.deep); ell(cx - 1, cy + 3, 28.5, 27.5, S.dark)
    for yy = cy - 22, cy + 30, 3 do
      for xx = cx - 28, cx + 28, 3 do
        if ((xx - cx) / 29) ^ 2 + ((yy - cy - 4) / 28) ^ 2 < 1 then rect(S.base, xx + (yy % 2) * 1.5, yy, 1, 1) end
      end
    end
  end
end

-- Headwear on top of the head. Returns true if the ears should be drawn over it.
local function hatFront(cx, cy, o, F)
  local hat = o.hat
  local top = cy - 18.5
  local wf = o.headW
  if hat == "helm" or hat == "bighelm" or hat == "hornhelm" then
    local S = hat == "hornhelm" and steelOf({ steel = "dark" }) or steelOf(o)
    local big = hat == "bighelm" and 1.18 or 1
    local hy = cy - 8 + (big > 1 and 4 or 0)
    local r = 23.5 * wf * big
    if hat == "hornhelm" then
      for sgn = -1, 1, 2 do
        poly(C.paper, cx + sgn * 16, hy - 12, cx + sgn * 24, hy - 8, cx + sgn * 30, hy - 30)
        poly(hex("#d8d3c2"), cx + sgn * 20, hy - 10, cx + sgn * 24, hy - 8, cx + sgn * 30, hy - 30)
      end
    end
    col(S.dark); lg.arc("fill", cx, hy, r + 1, PI, 2 * PI, 28)
    col(S.base); lg.arc("fill", cx - 0.8, hy - 0.8, r, PI, 2 * PI, 28)
    ell(cx - 8, hy - r * 0.6, 6, 3, S.light, -0.3)
    rect(S.dark, cx - r - 1, hy - 1, 2 * r + 2, 4)
    for k = -3, 3 do rect(S.light, cx + k * 6 - 0.5, hy, 1, 1) end
    rect(S.dark, cx - 2, hy - 2, 4, 12)
    rect(S.base, cx - 1.2, hy - 2, 2.4, 11)
    if hat == "bighelm" then
      poly(C.red, cx - 3, hy - r, cx + 3, hy - r, cx + 9, hy - r - 12) -- a plume
    end
    return hat ~= "hornhelm"
  elseif hat == "crown" or hat == "crownTilt" then
    lg.push()
    if hat == "crownTilt" then lg.translate(cx, top); lg.rotate(0.28); lg.translate(-cx, -top) end
    rect(GOLD.dark, cx - 13, top - 1, 26, 6)
    rect(GOLD.base, cx - 12, top, 24, 4)
    for k = -2, 2 do poly(GOLD.base, cx + k * 5.5 - 3, top, cx + k * 5.5 + 3, top, cx + k * 5.5, top - 8 + math.abs(k)) end
    ell(cx, top + 2, 1.8, 1.8, C.red); ell(cx - 7, top + 2, 1.3, 1.3, EYE.blue); ell(cx + 7, top + 2, 1.3, 1.3, EYE.blue)
    rect(GOLD.light, cx - 11, top, 22, 1)
    lg.pop()
  elseif hat == "circlet" or hat == "hoodCirclet" then
    ln(GOLD.base, 1.6, cx - 19 * wf, top + 8, cx, top + 4, cx + 19 * wf, top + 8)
    ell(cx, top + 4.5, 2.4, 2.4, GOLD.dark); ell(cx, top + 4.5, 1.6, 1.6, EYE.cyan)
    if hat == "hoodCirclet" then
      col(o.robe); lg.setLineWidth(3); lg.arc("line", "open", cx, cy + 2, 27, PI * 1.05, PI * 1.95); lg.setLineWidth(1)
    end
  elseif hat == "hood" or hat == "veil" then
    local R = hat == "veil" and hex("#9fd8ff") or o.robe
    col(mix(R, C.black, 0.2), hat == "veil" and 0.85 or 1); lg.setLineWidth(3.5)
    lg.arc("line", "open", cx, cy + 3, 26.5, PI * 1.02, PI * 1.98)
    lg.setLineWidth(1)
    return true
  elseif hat == "wizard" or hat == "bigwizard" or hat == "witch" then
    local R = hat == "witch" and hex("#16352a") or o.robe
    local big = hat == "bigwizard" and 1.25 or 1
    local by = top + 4 + (big > 1 and 4 or 0)
    local brim = hat == "witch" and 30 or 24
    ell(cx + 1, by + 1, brim * big, 4.5 * big, mix(R, C.black, 0.45))
    ell(cx, by, brim * big, 4 * big, R)
    poly(mix(R, C.black, 0.25), cx - 14 * big, by, cx + 15 * big, by, cx + 6 * big, by - 22 * big)
    poly(R, cx - 13 * big, by - 0.5, cx + 13 * big, by - 0.5, cx + 5 * big, by - 21 * big)
    poly(R, cx + 4 * big, by - 19 * big, cx + 7 * big, by - 21 * big, cx + 16 * big, by - 32 * big)
    if hat == "witch" then
      rect(hex("#0a1a12"), cx - 12, by - 5, 25, 4)
      rect(GOLD.base, cx - 2, by - 5.5, 5, 5)
    else
      ln(GOLD.base, 1.6, cx - 13 * big, by - 1, cx + 13 * big, by - 1)
      sparkle(cx - 2 * big, by - 10 * big, 1.6, GOLD.light, 1)
      ell(cx + 5 * big, by - 4 * big, 1, 1, GOLD.light)
    end
  elseif hat == "beret" then
    ell(cx - 2, top + 2, 20, 6, hex("#7a2016"), -0.15)
    ell(cx - 3, top + 1, 19, 5.5, C.red, -0.15)
    ell(cx + 14, top - 6, 2.2, 11, C.paper, 0.6)
    ln(hex("#d8d3c2"), 0.8, cx + 9, top + 1, cx + 19, top - 13)
  elseif hat == "leaves" then
    for k = -3, 3 do
      local a = k * 0.3
      ell(cx + math.sin(a) * 20, top + 5 - math.cos(a) * 3, 3.2, 5.5, k % 2 == 0 and hex("#5fd38d") or hex("#2f8a52"), a)
    end
    ell(cx, top + 1, 2, 2, C.red)
  elseif hat == "bandana" or hat == "bandage" then
    local B = hat == "bandana" and C.red or C.paper
    rect(mix(B, C.black, 0.3), cx - 22 * wf, top + 3, 44 * wf, 7)
    rect(B, cx - 21 * wf, top + 3, 42 * wf, 5.5)
    if hat == "bandana" then
      poly(B, cx + 20 * wf, top + 4, cx + 30 * wf, top + 2, cx + 28 * wf, top + 12)
      for k = -2, 2 do rect(C.paper, cx + k * 8, top + 5, 1.5, 1.5) end
    else
      ln(PINKD, 1, cx + 5, top + 4, cx + 9, top + 8)
    end
    return true
  end
  return false
end

local function kitten(x, y, s, o, F)
  ell(x, y + 2, 8 * s, 6 * s, F.dark)
  for sgn = -1, 1, 2 do
    poly(F.dark, x + sgn * 7 * s, y - 1 * s, x + sgn * 1.5 * s, y - 5 * s, x + sgn * 7 * s, y - 11 * s)
    poly(PINK, x + sgn * 5.5 * s, y - 2 * s, x + sgn * 3 * s, y - 4.5 * s, x + sgn * 6 * s, y - 8 * s)
  end
  ell(x - 0.6, y - 0.4, 7.6 * s, 6.6 * s, F.base)
  ell(x, y + 3 * s, 4 * s, 2.6 * s, F.muzzle)
  for sgn = -1, 1, 2 do
    ell(x + sgn * 3.4 * s, y, 2.3 * s, 2.3 * s, OUTLINE)
    ell(x + sgn * 3.4 * s, y, 1.6 * s, 1.8 * s, EYE[o.eyes] or EYE.gold)
    ell(x + sgn * 3.4 * s - 0.6, y - 0.7, 0.6, 0.6, C.white)
  end
  poly(PINK, x - 1, y + 2 * s, x + 1, y + 2 * s, x, y + 3 * s)
end

-- Props held in front of (or behind) the cat. back = true for the ones behind the body.
local function prop(w, h, o, cx, cy, F, back)
  local p = o.prop
  local S = steelOf(o)
  if back then
    if p == "banner" then
      local px = cx - 34
      rect(WOODD, px - 1.5, 4, 3, h)
      ell(px, 4, 2.4, 2.4, GOLD.base)
      rect(mix(o.cloth, C.black, 0.3), px + 1, 8, 24, 24)
      rect(o.cloth, px + 1, 8, 23, 22)
      poly(o.cloth, px + 1, 30, px + 12, 30, px + 1, 38)
      poly(o.cloth, px + 12, 30, px + 24, 30, px + 24, 38)
      emblem(o.coat, px + 12, 19, 1.4, o.coat == "gilt" and C.paper or GOLD.light)
    elseif p == "spear" then
      local px = cx + 34
      rect(WOODD, px - 1.2, 10, 2.4, h)
      poly(S.base, px - 3.5, 12, px + 3.5, 12, px, -2)
      ln(S.light, 0.8, px, 0, px, 11)
      poly(C.red, px + 1, 14, px + 12, 17, px + 1, 21)
    elseif p == "staff" then
      local px = cx - 34
      rect(WOOD, px - 1.6, 14, 3.2, h)
      poly(hex("#2f8a52"), px - 6, 16, px, 14, px - 3, 8)
      poly(EYE.cyan, px - 4, 10, px + 4, 10, px, 2)
      poly(hex("#2bb0d0"), px - 4, 10, px + 4, 10, px, 16)
    elseif p == "axe" then
      local px = cx + 33
      rect(WOODD, px - 1.4, 8, 2.8, h)
      col(STEEL.dark); lg.arc("fill", px + 1, 18, 13, -PI / 2, PI / 2, 20)
      col(STEEL.base); lg.arc("fill", px + 1, 18, 11.5, -PI / 2, PI / 2, 20)
      ln(STEEL.light, 1, px + 10, 10, px + 12, 18)
    elseif p == "excalibur" then
      local px = cx + 30
      poly(S.light, px - 2, 60, px + 2, 60, px + 2, 8, px, 2, px - 2, 8)
      ln(S.dark, 0.8, px, 6, px, 58)
      rect(GOLD.base, px - 8, 58, 16, 3.5)
      rect(WOODD, px - 1.5, 61, 3, 9)
    end
    return
  end
  if p == "sword" then
    local px = cx + 31
    poly(S.light, px - 2, h - 18, px + 2, h - 18, px + 2, h - 62, px, h - 67, px - 2, h - 62)
    ln(S.dark, 0.8, px, h - 64, px, h - 20)
    rect(GOLD.dark, px - 8, h - 19, 16, 4)
    rect(GOLD.base, px - 7.5, h - 19, 15, 2.6)
    rect(WOODD, px - 1.6, h - 15, 3.2, 10)
    ell(px, h - 4, 2.6, 2.6, GOLD.base)
    ell(px - 10, h - 6, 6, 5, F.base) -- a paw on the grip
    ell(px - 10, h - 7, 4.5, 3, F.light)
  elseif p == "hammer" then
    local px, py = cx + 30, h - 40
    lg.push(); lg.translate(px, py); lg.rotate(0.35)
    rect(WOODD, -1.8, -6, 3.6, 52)
    rect(S.dark, -11, -16, 22, 14)
    rect(S.base, -10, -15, 20, 12)
    rect(S.light, -10, -15, 20, 2)
    rect(GOLD.base, -11, -9, 22, 2)
    lg.pop()
    ell(cx + 25, h - 12, 6, 5, F.base)
  elseif p == "shield" then
    local sx, sy = cx - 24, h - 16
    poly(S.dark, sx - 14, sy - 16, sx + 14, sy - 16, sx + 14, sy + 2, sx, sy + 16, sx - 14, sy + 2)
    poly(o.cloth, sx - 12, sy - 14, sx + 12, sy - 14, sx + 12, sy + 1, sx, sy + 13, sx - 12, sy + 1)
    rect(mix(o.cloth, C.white, 0.3), sx - 12, sy - 14, 24, 2)
    emblem(o.coat, sx, sy - 3, 1.6, o.coat == "gilt" and C.paper or GOLD.light)
  elseif p == "claws" then
    local px, py = cx + 24, h - 18
    ell(px, py, 9, 8, F.dark); ell(px - 0.8, py - 0.8, 8, 7, F.base)
    for k = -1, 1 do
      poly(C.white, px + k * 4 - 1.4, py - 6, px + k * 4 + 1.4, py - 6, px + k * 4 + 0.5, py - 13)
      ell(px + k * 4, py - 3, 1.6, 1.4, PINK)
    end
    ell(px, py + 2.5, 3.4, 2.6, PINK)
  elseif p == "lute" then
    local lx, ly = cx + 22, h - 12
    lg.push(); lg.translate(lx, ly); lg.rotate(0.55)
    rect(WOODD, -1.8, -30, 3.6, 24)
    rect(WOODD, -3, -34, 6, 5)
    lg.pop()
    ell(lx, ly, 11, 9, WOODD); ell(lx - 0.6, ly - 0.6, 10, 8, WOOD)
    ell(lx, ly, 3, 3, hex("#2a1a0c"))
    ell(lx - 10, ly + 3, 5, 4.5, F.base)
  elseif p == "orb" or p == "crystal" or p == "fireball" then
    if p == "crystal" then
      rect(GOLD.dark, cx - 9, h - 8, 18, 5); rect(GOLD.base, cx - 7, h - 10, 14, 3)
    end
    for sgn = -1, 1, 2 do ell(cx + sgn * 10, h - 14, 6, 5, F.base) end
  elseif p == "wand" then
    lg.push(); lg.translate(cx + 22, h - 22); lg.rotate(0.6)
    rect(WOODD, -1.2, -16, 2.4, 22)
    lg.pop()
    ell(cx + 24, h - 12, 5.5, 4.5, F.base)
  elseif p == "book" then
    rect(hex("#4a1a12"), cx - 34, h - 26, 22, 26)
    rect(hex("#7a2016"), cx - 33, h - 25, 20, 24)
    rect(C.paper, cx - 31, h - 24, 2, 22)
    emblem("gilt", cx - 23, h - 14, 1, GOLD.base)
    ell(cx - 13, h - 10, 5.5, 4.5, F.base)
  elseif p == "goblet" or p == "grail" then
    local gx, gy = cx + 25, h - 22
    poly(GOLD.dark, gx - 8, gy - 8, gx + 8, gy - 8, gx + 4, gy + 4, gx - 4, gy + 4)
    poly(GOLD.base, gx - 7, gy - 7, gx + 7, gy - 7, gx + 3.5, gy + 3, gx - 3.5, gy + 3)
    rect(GOLD.light, gx - 6, gy - 7, 12, 1.2)
    rect(GOLD.dark, gx - 1.5, gy + 3, 3, 10)
    rect(GOLD.base, gx - 6, gy + 12, 12, 3)
    if p == "grail" then ell(gx, gy - 1, 1.6, 1.6, C.red) end
    ell(gx - 10, gy + 6, 5.5, 4.5, F.base)
  elseif p == "fishbone" then
    local fx, fy = cx + 22, h - 16
    ln(C.paper, 1.4, fx - 10, fy, fx + 8, fy)
    for k = 0, 3 do ln(C.paper, 1, fx - 6 + k * 4, fy - 4, fx - 6 + k * 4, fy + 4) end
    poly(C.paper, fx + 8, fy, fx + 14, fy - 5, fx + 14, fy + 5)
    ell(fx - 12, fy, 3.5, 3, C.paper)
    ell(fx - 13, fy - 0.5, 0.8, 0.8, OUTLINE)
  elseif p == "mouse" then
    local mx, my = cx - 26, h - 10
    ell(mx, my, 8, 6, hex("#9aa0a8")); ell(mx - 6, my - 4, 3.2, 3.2, hex("#9aa0a8")); ell(mx - 6, my - 4, 1.8, 1.8, PINK)
    ell(mx - 7, my + 1, 1, 1, OUTLINE)
    ln(PINK, 1, mx + 7, my + 2, mx + 14, my - 4)
  elseif p == "ladle" then
    lg.push(); lg.translate(cx + 26, h - 30); lg.rotate(0.25)
    rect(S.base, -1.2, -10, 2.4, 30)
    lg.pop()
    ell(cx + 23, h - 41, 6, 4.5, S.dark); ell(cx + 23, h - 42, 5, 3, S.light)
    ell(cx + 28, h - 10, 5.5, 4.5, F.base)
  elseif p == "candle" then
    local x0 = cx + 26
    rect(GOLD.dark, x0 - 8, h - 8, 16, 3)
    rect(C.paper, x0 - 3, h - 30, 6, 22)
    rect(hex("#d8d3c2"), x0 + 1.5, h - 30, 1.5, 22)
    ln(OUTLINE, 0.8, x0, h - 30, x0, h - 33)
    ell(x0 - 9, h - 10, 5.5, 4.5, F.base)
  elseif p == "needle" then
    rect(C.paper, cx - 34, h - 24, 24, 22)
    for k = 0, 3 do rect(k % 2 == 0 and C.red or C.blue, cx - 32, h - 22 + k * 5, 20, 2) end
    ln(S.light, 0.8, cx - 10, h - 30, cx - 18, h - 14)
  end
end

local function fx(w, h, o, cx, cy, F)
  local r = rngm.new((o.seed or 1) + 501)
  local function nx() return rngm.next(r) end
  -- whiskers
  local wc = o.coat == "shadow" and hex("#a9bfb3") or C.paper
  for sgn = -1, 1, 2 do
    for i = 0, 2 do
      col(wc, 0.75); lg.setLineWidth(0.8)
      lg.line(cx + sgn * 9, cy + 9 + i * 1.6, cx + sgn * 26, cy + 6 + i * 3.6)
    end
  end
  lg.setLineWidth(1)
  local p = o.prop
  if p == "orb" or p == "crystal" or p == "fireball" then
    local c = p == "fireball" and hex("#ff8a3a") or (o.ability == "hex" and hex("#c18cff") or EYE.cyan)
    local ox, oy = cx, h - 22
    glow(ox, oy, 20, c, 0.7)
    ell(ox, oy, 7, 7, mix(c, C.white, 0.2))
    ell(ox - 2, oy - 2, 2.4, 2.4, C.white)
    if p == "fireball" then
      poly(GOLD.light, ox - 4, oy - 3, ox + 4, oy - 3, ox, oy - 14)
    end
  elseif p == "candle" then
    local x0 = cx + 26
    glow(x0, h - 36, 14, hex("#ff8a3a"), 0.7)
    poly(GOLD.light, x0 - 2.4, h - 33, x0 + 2.4, h - 33, x0, h - 41)
    ell(x0, h - 34, 2.4, 2.4, GOLD.light)
  elseif p == "wand" then
    sparkle(cx + 31, h - 36, 2.6, o.ability == "hex" and hex("#c18cff") or GOLD.light, 1)
  elseif p == "staff" then
    glow(cx - 34, 9, 10, EYE.cyan, 0.6)
  elseif p == "excalibur" then
    glow(cx + 30, 30, 14, EYE.cyan, 0.35)
    sparkle(cx + 30, 12, 2.4, C.white, 1)
  end
  if o.halo then
    local hc = o.halo == "gold" and GOLD.light or EYE.cyan
    col(hc, 0.85); lg.setLineWidth(2)
    lg.ellipse("line", cx, cy - 32, 14, 3.6, 24)
    lg.setLineWidth(1)
  end
  if o.runes then
    local rc = hex("#c18cff")
    for i = 1, 4 do
      local rx, ry = 8 + nx() * (w - 16), 8 + nx() * 40
      if math.abs(rx - cx) > 22 then
        col(rc, 0.8); lg.setLineWidth(1)
        lg.line(rx - 2, ry - 3, rx + 2, ry - 3, rx, ry + 3, rx - 2, ry - 3)
      end
    end
  end
  if o.notes then
    for i = 1, 3 do
      local nxp, nyp = cx + 24 + i * 5, cy - 14 - i * 7
      ell(nxp, nyp + 4, 2.2, 1.6, GOLD.light, -0.4)
      ln(GOLD.light, 1, nxp + 2, nyp + 4, nxp + 2, nyp - 3)
    end
  end
  if o.sparkles then
    for i = 1, 4 do
      local sx, sy = 6 + nx() * (w - 12), 6 + nx() * (h * 0.55)
      if math.abs(sx - cx) > 24 then sparkle(sx, sy, 1.2 + nx(), GOLD.light, 0.9) end
    end
  end
  if o.menace then
    for sgn = -1, 1, 2 do glow(cx + sgn * 10 * o.headW, cy + 1, 8, EYE.red, 0.45) end
  end
end

-- The figure layer (outlined).
local function figure(w, h, o)
  local cx, cy = w / 2 + o.jx, h - 52
  local F = FUR[o.fur] or FUR.shadow
  prop(w, h, o, cx, cy, F, true)
  body(w, h, o, cx)
  -- the neck ruff, so the head sits on the collar
  ell(cx, h - 30, 16, 9, F.dark); ell(cx, h - 31, 14.5, 8, F.base)
  hatBack(cx, cy, o, F)
  local helmLike = o.hat == "helm" or o.hat == "bighelm" or o.hat == "hood" or o.hat == "veil" or o.hat == "bandana" or o.hat == "bandage"
  if not helmLike then ears(cx, cy, o, F) end
  headShape(cx, cy, o, F.dark, 0, 0, 0)
  headShape(cx, cy, o, F.base, -1.2, -1.4, 0.8)
  ell(cx - 8, cy - 10, 8, 4.5, F.light, -0.35)
  pattern(cx, cy, o, F)
  face(cx, cy, o, F)
  local earsOver = hatFront(cx, cy, o, F)
  if helmLike and earsOver then ears(cx, cy, o, F) end
  if o.kittens then
    kitten(cx - 30, h - 10, 1, o, F)
    kitten(cx + 18, h - 7, 0.9, o, F)
  end
  prop(w, h, o, cx, cy, F, false)
end

-- ---------------------------------------------------------------- tricks

local TRICK_BG = {
  downpour = { top = hex("#16263a"), bottom = hex("#05090f") },
  moonfog = { top = hex("#16352a"), bottom = hex("#030605") },
  sunbeam = { top = hex("#2a1e0a"), bottom = hex("#0c0904") },
  warhorn = { top = hex("#5a1d12"), bottom = hex("#160806") },
  box = { top = hex("#24503c"), bottom = hex("#08140f") },
  hairball = { top = hex("#2a3a14"), bottom = hex("#0a1004") },
}

local function trickBg(w, h, o)
  local B = TRICK_BG[o.ability] or TRICK_BG.box
  vgrad(0, 0, w, h, B.top, B.bottom)
  local cx, cy = w / 2, h / 2
  local ab = o.ability
  if ab == "downpour" then
    for i = 1, 40 do
      local x, y = (i * 37) % w, (i * 53) % h
      ln(hex("#5cb8ff"), 0.9, x, y, x - 4, y + 9)
    end
  elseif ab == "moonfog" then
    glow(cx + 16, 26, 34, EYE.cyan, 0.2)
    ell(cx + 16, 26, 16, 16, C.paper)
  elseif ab == "sunbeam" then
    -- a window
    rect(hex("#3a2a10"), 10, 8, 28, 30)
    rect(GOLD.light, 12, 10, 11, 12); rect(GOLD.light, 25, 10, 11, 12); rect(GOLD.light, 12, 24, 11, 12); rect(GOLD.light, 25, 24, 11, 12)
    col(GOLD.light, 0.22)
    lg.polygon("fill", 12, 10, 36, 10, w, h, w - 58, h)
    for i = 1, 10 do rect(GOLD.light, 30 + (i * 19) % 50, 30 + (i * 23) % 50, 1, 1, 0.7) end
  elseif ab == "warhorn" then
    glow(cx, cy, 50, hex("#ff8a3a"), 0.4)
    for i = 1, 3 do
      col(GOLD.light, 0.5 - i * 0.1); lg.setLineWidth(2)
      lg.arc("line", "open", cx + 18, cy - 8, 10 + i * 8, -0.9, 0.9)
    end
    lg.setLineWidth(1)
  elseif ab == "box" then
    glow(cx, cy + 6, 46, GOLD.base, 0.25)
  elseif ab == "hairball" then
    glow(cx, cy, 44, hex("#a8d14f"), 0.3)
  end
end

local function trickFig(w, h, o)
  local cx, cy = w / 2, h / 2
  local ab = o.ability
  if ab == "downpour" then
    for _, c in ipairs({ { cx - 18, 24, 16, 11 }, { cx + 2, 18, 20, 14 }, { cx + 22, 26, 14, 10 }, { cx, 30, 28, 8 } }) do
      ell(c[1], c[2], c[3], c[4], hex("#56677c"))
      ell(c[1] - 2, c[2] - 2, c[3] - 2, c[4] - 2, hex("#8a96a8"))
    end
    -- a soaked cat under it, ears flat
    local F = FUR.tide
    ell(cx, h - 6, 22, 12, F.dark); ell(cx - 1, h - 7, 20, 11, F.base)
    poly(F.dark, cx - 20, h - 12, cx - 8, h - 16, cx - 26, h - 20)
    poly(F.dark, cx + 20, h - 12, cx + 8, h - 16, cx + 26, h - 20)
    ell(cx - 7, h - 9, 3.4, 2.4, OUTLINE); ell(cx + 7, h - 9, 3.4, 2.4, OUTLINE)
    ell(cx - 7, h - 9.4, 2.4, 1.4, EYE.gold); ell(cx + 7, h - 9.4, 2.4, 1.4, EYE.gold)
  elseif ab == "moonfog" then
    for k = 0, 3 do
      local y = 44 + k * 11
      col(C.paper, 0.18 + k * 0.08)
      lg.ellipse("fill", cx + (k % 2 == 0 and -10 or 12), y, 48, 6, 28)
    end
    -- eyes in the fog
    for sgn = -1, 1, 2 do ell(cx - 14 + sgn * 6, 62, 3, 2, EYE.gold) end
  elseif ab == "sunbeam" then
    -- a cat asleep on a cushion in the light
    ell(cx + 10, h - 14, 30, 9, hex("#7a2016")); ell(cx + 9, h - 15, 28, 7.5, C.red)
    local F = FUR.gilt
    ell(cx + 10, h - 25, 22, 11, F.dark); ell(cx + 9, h - 26, 20.5, 10, F.base)
    ell(cx - 6, h - 29, 11, 9, F.dark); ell(cx - 7, h - 30, 10, 8, F.base)
    poly(F.dark, cx - 15, h - 34, cx - 9, h - 37, cx - 15, h - 44)
    poly(F.dark, cx + 1, h - 34, cx - 5, h - 37, cx + 1, h - 44)
    ln(OUTLINE, 1.2, cx - 12, h - 30, cx - 9, h - 30)
    ln(OUTLINE, 1.2, cx - 5, h - 30, cx - 2, h - 30)
    col(F.dark); lg.setLineWidth(3); lg.arc("line", "open", cx + 30, h - 26, 8, -PI / 2, PI / 2); lg.setLineWidth(1)
  elseif ab == "warhorn" then
    lg.push(); lg.translate(cx - 4, cy + 6); lg.rotate(-0.35)
    poly(GOLD.dark, -26, -4, -26, 4, 10, 10, 10, -10)
    poly(GOLD.base, -25, -3, -25, 3, 9, 8.5, 9, -8.5)
    rect(GOLD.light, -25, -3, 34, 1.5)
    ell(12, 0, 5, 12, GOLD.dark); ell(12, 0, 3.5, 10, hex("#2a1e00"))
    rect(C.red, -18, -5, 4, 10); rect(C.red, -4, -7, 4, 14)
    lg.pop()
  elseif ab == "box" then
    local bx, by = cx - 26, cy - 4
    poly(hex("#8c5a24"), bx, by, bx + 52, by, bx + 52, by + 36, bx, by + 36)
    poly(hex("#b07a3a"), bx + 1, by + 1, bx + 51, by + 1, bx + 51, by + 35, bx + 1, by + 35)
    rect(hex("#d9a35a"), bx + 22, by + 1, 8, 34)
    poly(hex("#9a6a2c"), bx, by, bx + 26, by, bx + 18, by - 10, bx - 8, by - 10)
    poly(hex("#c08844"), bx + 26, by, bx + 52, by, bx + 60, by - 10, bx + 34, by - 10)
    -- ears and eyes peeking out of the dark gap
    rect(hex("#120a04"), bx + 4, by - 2, 44, 6)
    local F = FUR.shadow
    poly(F.base, bx + 12, by + 1, bx + 20, by + 1, bx + 14, by - 9)
    poly(F.base, bx + 28, by + 1, bx + 36, by + 1, bx + 34, by - 9)
  elseif ab == "hairball" then
    local hx, hy = cx, cy + 6
    ell(hx, hy, 17, 15, hex("#5c3a1f"))
    ell(hx - 1, hy - 1, 15.5, 13.5, hex("#8c6a2c"))
    for i = 0, 17 do
      local a = i / 18 * 2 * PI
      ln(i % 2 == 0 and hex("#d0602a") or hex("#3a2412"), 1.3, hx + math.cos(a) * 6, hy + math.sin(a) * 5, hx + math.cos(a + 0.6) * 18, hy + math.sin(a + 0.6) * 16)
    end
  end
end

local function trickFx(w, h, o)
  local cx, cy = w / 2, h / 2
  local ab = o.ability
  if ab == "box" then
    local bx, by = cx - 26, cy - 4
    for _, ex in ipairs({ bx + 18, bx + 30 }) do ell(ex, by + 1, 2.4, 1.6, EYE.gold) end
  elseif ab == "hairball" then
    for k = -1, 1 do
      col(hex("#a8d14f"), 0.8); lg.setLineWidth(1.4)
      local x = cx + k * 12
      lg.line(x, cy - 12, x + 3, cy - 18, x - 1, cy - 24, x + 2, cy - 30)
    end
    lg.setLineWidth(1)
  elseif ab == "sunbeam" then
    for k = 0, 2 do
      local zx, zy = cx + 4 + k * 8, h - 50 - k * 9
      ln(C.paper, 1.2, zx, zy, zx + 4, zy, zx, zy + 4, zx + 4, zy + 4)
    end
  elseif ab == "moonfog" then
    for sgn = -1, 1, 2 do glow(cx - 14 + sgn * 6, 62, 6, EYE.gold, 0.5) end
  elseif ab == "warhorn" then
    sparkle(cx + 24, cy - 16, 2, GOLD.light, 1)
  end
end

-- ---------------------------------------------------------------- compositing

local cache = {}
local SS = 2 -- supersampling

local function begin(cv, transparent)
  lg.push("all")
  lg.origin()
  lg.setScissor() -- baking happens mid-frame, maybe inside a clipped overlay
  lg.setShader()
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, transparent and 0 or 1)
end

local RIM = { shadow = hex("#62c49a"), menace = hex("#c8382c") }
local OFFSETS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }

-- Paint bg / fig / fx into an outW x outH picture. Logical space is 100 units wide.
local function compose(key, outW, outH, layers, o, transparent)
  if cache[key] then return cache[key] end
  local plates = require("src.ui.plates")
  local cw, ch = outW * SS, outH * SS
  local k = cw / 100
  local lw, lh = 100, ch / k
  local fig = lg.newCanvas(cw, ch)
  begin(fig, true)
  lg.scale(k)
  layers.fig(lw, lh, o)
  lg.pop()
  local comp = lg.newCanvas(cw, ch)
  begin(comp, transparent)
  if not transparent then
    lg.push(); lg.scale(k); layers.bg(lw, lh, o); lg.pop()
  end
  if o.ghost then
    lg.setBlendMode("alpha", "premultiplied")
    lg.setColor(0.18 * 0.35, 0.55 * 0.35, 0.6 * 0.35, 0.35)
    lg.draw(fig, -10 * SS, 0)
  end
  lg.setBlendMode("alpha", "alphamultiply")
  local rim = o.menace and RIM.menace or (o.coat == "shadow" and RIM.shadow) or nil
  if rim then -- dark figures get a second, coloured line outside the outline, like moonlight
    lg.setColor(rim[1], rim[2], rim[3], 1)
    for _, d in ipairs(OFFSETS) do lg.draw(fig, d[1] * SS * 2, d[2] * SS * 2) end
  end
  lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
  for _, d in ipairs(OFFSETS) do lg.draw(fig, d[1] * SS, d[2] * SS) end
  lg.setBlendMode("alpha", "premultiplied")
  lg.setColor(1, 1, 1, 1)
  lg.draw(fig, 0, 0)
  lg.setBlendMode("alpha", "alphamultiply")
  lg.push(); lg.scale(k); layers.fx(lw, lh, o); lg.pop()
  lg.pop()
  fig:release()
  -- box-filter down to the output size
  comp:setFilter("linear", "linear")
  local out = lg.newCanvas(outW, outH)
  out:setFilter("nearest", "nearest")
  begin(out, true)
  lg.setBlendMode("alpha", "premultiplied")
  lg.setColor(1, 1, 1, 1)
  lg.draw(comp, 0, 0, 0, 1 / SS, 1 / SS)
  lg.pop()
  comp:release()
  local d = plates.dither(out, outW, outH, transparent)
  if d ~= out then out:release() end -- without the shader the raw canvas is the result
  cache[key] = d
  return d
end

local CAT = {
  bg = bgPaint,
  fig = figure,
  fx = function(w, h, o)
    local cx, cy = w / 2 + o.jx, h - 52
    fx(w, h, o, cx, cy, FUR[o.fur] or FUR.shadow)
  end,
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

-- The picture on a card face (50x48), or larger for the inspect panel and the Cattery
-- (scale 2 gives 100x96).
function M.card(def, scale)
  scale = scale or 1
  local w, h = M.CARD_W * scale, M.CARD_H * scale
  local key = ("card:%s:%d:%d"):format(def.id, def.scars or 0, scale)
  if cache[key] then return cache[key] end
  if def.kind == "special" then
    return compose(key, w, h, TRICK, { ability = def.ability, seed = rngm.hash(def.id) }, false)
  end
  return compose(key, w, h, CAT, cardSpec(def), false)
end
function M.illustration(def) return M.card(def, 2) end

-- Square portraits (any size). Returns the image and the eye positions {x1, y1, x2, y2, colour}.
local eyes = {}
function M.portrait(o, size)
  size = size or 48
  local key = ("p:%d:%s:%s:%s:%s:%d:%s:%s:%d:%s"):format(o.seed or 0, o.coat, tostring(o.magic), tostring(o.ability), tostring(o.legendary), o.scars or 0,
    tostring(o.crown), tostring(o.menace), size, tostring(o.cutout))
  if not cache[key] then
    derive(o)
    compose(key, size, size, CAT, o, o.cutout)
    local k = size / 100
    local cx, cy = 50 + o.jx, 100 - 52 + 1
    eyes[key] = { (cx - 10 * o.headW) * k, cy * k, (cx + 10 * o.headW) * k, cy * k, EYE[o.eyes] or EYE.gold }
  end
  return cache[key], eyes[key]
end

function M.nemesis(n, rank, size, cutout)
  return M.portrait({ seed = n.seed, coat = n.coat, magic = n.style == "hex" or n.style == "inspire" or n.style == "groom",
    ability = n.style, legendary = false, crown = rank == 1, scars = n.scars, menace = true, cutout = cutout,
    rarity = "epic" }, size)
end

function M.player(name, size, cutout)
  return M.portrait({ seed = rngm.hash(name), coat = "gilt", magic = false, ability = "smite", legendary = false, cutout = cutout,
    rarity = "rare", prop = "sword", hat = "none", outfit = "plate", expr = "calm", eyes = "green" }, size)
end

function M.stray(foe, size, cutout)
  return M.portrait({ seed = foe.seed, coat = foe.coat, magic = false, ability = "none", legendary = false, menace = foe.elite, cutout = cutout,
    rarity = "common" }, size)
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

-- Turn a smooth image (Figma export) into dithered pixels at the given width.
function M.bake(img, w)
  return require("src.ui.plates").image(img, w)
end

return M
