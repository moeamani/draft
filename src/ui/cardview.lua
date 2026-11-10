-- Pixel playing cards: a 56x78 face printed on worn cream paper, with a rarity-framed
-- illustration and coat-coloured plates, baked once. At rest a card is drawn 1:1 on whole pixels (no wobble, no tilt, no resampling),
-- so its pixels never shimmer. Only transient motion (dealing, flipping, a lean while moving)
-- is drawn scaled and rotated.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local plates = require("src.ui.plates")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
M.W, M.H = 56, 78
local HOT = require("src.core.match").HOT
local warmthBadge

local C = theme.c
local faceCache = {}


M.SHORT = {
  none = "STEADY", smite = "HAMMER", inspire = "ORB", hex = "HEX", litter = "LITTER", pounce = "POUNCE",
  ninelives = "9 LIVES", stray = "STRAY", groom = "GROOM", purr = "PURR", yowl = "YOWL", muster = "RALLY",
  downpour = "RAIN", moonfog = "FOG", sunbeam = "NAP", warhorn = "RALLY", box = "BOX", hairball = "HRRK",
}

local function fit(font, str, w)
  while font:getWidth(str) > w and #str > 3 do str = str:sub(1, -2) end
  return str
end

local function begin(cv)
  lg.push("all")
  lg.origin()
  lg.setScissor() -- baking happens mid-frame, maybe inside a clipped overlay
  lg.setShader()
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, 0)
end

-- Face layout: a paper margin, the illustration in a rarity-coloured window, then two plates:
-- the name on its coat's colour (so the coat reads at a glance) and the ability. The text on a
-- card (name, ability, Paws, lives) is drawn live by View:draw, never baked.
M.NAME_PLATE = { 3, 52, 50, 12 }
M.ABIL_PLATE = { 3, 65, 50, 11 }
local function nameColor(def)
  if def.kind ~= "unit" then return C.ink3 end
  return ({ ember = C.red, tide = C.blue, gilt = C.gold, shadow = C.slate })[def.coat] or C.slate
end
M.nameColor = nameColor
local function abilColor(def)
  if def.kind ~= "unit" then return C.ink2 end
  return def.ability == "none" and C.slate or C.blueDark
end

-- Cards are printed on cream paper: worn specks, a darker edge, a 2px margin. The illustration
-- sits in a window framed in the rarity's colour (brown, blue, red, gold). A badge in the top
-- right corner shows the coat as a shape (flame, drop, crown, moon), so coats read without
-- colour. A copy's printing is drawn into it: a Proof has blue registration corners, Gold Leaf
-- has a gilt edge, and a Misprint's art is printed out of register in red and cyan.
local PAPER = { theme.hex("#ebe2c6"), theme.hex("#d6c8a3"), theme.hex("#bba882") }
local GILT = { theme.hex("#f2c84b"), theme.hex("#d3a200"), theme.hex("#8a6a00") }
local INK = theme.hex("#3a2a1c")
local RARITY_FRAME = { common = INK, rare = theme.hex("#2471fc"), epic = theme.hex("#c8382c"), legendary = theme.hex("#d3a200") }
local PROOF_BLUE = theme.hex("#2471fc")

local function hash(x, y, s)
  local n = math.sin(x * 12.9898 + y * 78.233 + (s or 0) * 3.7) * 43758.5453
  return n - math.floor(n)
end

-- Paper over the whole card: outline with rounded corners, specks, a worn edge.
local function paper(W, H, seed, stock)
  stock = stock or PAPER
  theme.set(C.black)
  plates.rounded(0, 0, W, H, 2)
  theme.set(stock[1])
  plates.rounded(1, 1, W - 2, H - 2, 1)
  for y = 1, H - 2 do
    for x = 1, W - 2 do
      local edge = x == 1 or y == 1 or x == W - 2 or y == H - 2
      local corner = (x == 1 or x == W - 2) and (y == 1 or y == H - 2)
      local r = hash(x, y, seed)
      local c
      if corner then c = nil
      elseif edge then c = r < 0.25 and stock[3] or stock[2]
      elseif r < 0.05 then c = stock[2]
      elseif r < 0.065 then c = stock[3] end
      if c then theme.set(c); lg.rectangle("fill", x, y, 1, 1) end
    end
  end
end

local function seedOf(str)
  local n = 0
  for i = 1, #str do n = (n * 31 + str:byte(i)) % 997 end
  return n
end

local function renderFace(def, level, print)
  local key = def.id .. ":" .. level .. ":" .. (def.scars or 0) .. ":" .. def.power .. ":" .. (print or "")
  if faceCache[key] then return faceCache[key] end
  local W, H = M.W, M.H
  local unit = def.kind == "unit"
  -- build the plates before switching canvases (they bake into their own canvases)
  local namePlate = plates.plate(50, 12, nameColor(def), { outline = false, radius = 1, hi = false })
  local abilPlate = plates.plate(50, 11, abilColor(def), { outline = false, radius = 1, hi = false })
  local pic = art.card(def)
  local cv = lg.newCanvas(W, H)
  cv:setFilter("nearest", "nearest")
  begin(cv)
  paper(W, H, seedOf(def.id), print == "gold" and GILT or PAPER)
  -- the illustration window: rarity frame, then the art (trimmed by a pixel all round)
  theme.set(RARITY_FRAME[def.rarity] or INK)
  lg.rectangle("fill", 3, 3, 50, 48)
  lg.setScissor(4, 4, 48, 46)
  if print == "misprint" then
    -- out of register: the red plate two pixels left, the cyan plate two pixels right, and
    -- the picture printed thin over both
    lg.setColor(1, 0.32, 0.26, 1)
    lg.draw(pic, 1, 3)
    lg.setColor(0.25, 0.9, 1, 0.6)
    lg.draw(pic, 5, 4)
    lg.setColor(1, 1, 1, 0.7)
    lg.draw(pic, 3, 3)
  else
    lg.setColor(1, 1, 1)
    lg.draw(pic, 3, 3)
  end
  lg.setScissor()
  if print == "proof" then
    -- a printer's proof: blue registration corners on the art
    theme.set(PROOF_BLUE)
    for _, c in ipairs({ { 4, 4, 1, 1 }, { 51, 4, -1, 1 }, { 4, 49, 1, -1 }, { 51, 49, -1, -1 } }) do
      lg.rectangle("fill", math.min(c[1], c[1] + c[3] * 5), c[2], 6, 1)
      lg.rectangle("fill", c[1], math.min(c[2], c[2] + c[4] * 5), 1, 6)
    end
  end
  if def.rarity == "legendary" then
    -- gilt corners on the paper
    theme.set(C.gold)
    for _, p in ipairs({ { 2, 2 }, { W - 3, 2 }, { 2, H - 3 }, { W - 3, H - 3 } }) do lg.rectangle("fill", p[1], p[2], 1, 1) end
  end
  lg.setColor(1, 1, 1)
  lg.draw(namePlate, 3, 52)
  lg.draw(abilPlate, 3, 65)
  if unit then
    -- the coat badge: its shape in its colour, on black
    theme.set(C.black)
    lg.rectangle("fill", W - 15, 3, 12, 12)
    theme.set(C.night)
    lg.rectangle("fill", W - 14, 4, 10, 10)
    icons.draw(icons.COAT_ICON[def.coat] or "moon", W - 9, 9, cards.COATS[def.coat] and cards.COATS[def.coat].color or C.steel)
    -- its type, small, at the end of the ability plate: sword for Physical, orb for Magic
    icons.draw(def.type == "magic" and "orb" or "sword", W - 9, 70, def.type == "magic" and C.cyan or C.paper2)
  end
  icons.draw(icons.ABILITY_ICON[def.ability] or "paw", 9, 70, C.white)
  lg.pop()
  faceCache[key] = cv
  return cv
end
M.face = renderFace

-- Card backs: the same paper, and a field in the coat's colour printed in halftone (dots grow
-- towards the edges, a ruled frame) with the coat's shape large in the middle and the Overseer's
-- mark, a black cat's head with two red eyes, below it: every deck in the Arena is the
-- Overseer's. Shadow cats and tricks share the dark back. "plain" (the draw piles) has only
-- the mark.
M.BACKS = {
  ember = { field = C.red },
  tide = { field = theme.hex("#2471fc") },
  gilt = { field = C.gold },
  dark = { field = theme.hex("#171a26"), light = C.slate },
  plain = { field = C.ink3 },
}

local EYE_RED, EYE_HOT = theme.hex("#ff3a26"), theme.hex("#ffb08a")
-- the mark: ears, head and eyes (k = black, r = eye, h = hot pixel of the eye)
local MARK = {
  "k.........k",
  "kk.......kk",
  "kkk.....kkk",
  "kkkkkkkkkkk",
  "kkkkkkkkkkk",
  "khrrkkkrrhk",
  "kkrrkkkrrkk",
  "kkkkkkkkkkk",
  ".kkkkkkkkk.",
}

local function mark(cx, cy, spec)
  local mw, mh = #MARK[1], #MARK
  local mx, my = math.floor(cx - mw / 2), math.floor(cy - mh / 2)
  theme.set(spec.light and C.slate or C.black)
  lg.rectangle("fill", mx - 2, my - 2, mw + 4, mh + 4)
  theme.set(theme.shade(spec.field, -0.6))
  lg.rectangle("fill", mx - 1, my - 1, mw + 2, mh + 2)
  for j, row in ipairs(MARK) do
    for i = 1, mw do
      local ch = row:sub(i, i)
      local c = (ch == "k" and C.black) or (ch == "r" and EYE_RED) or (ch == "h" and EYE_HOT) or nil
      if c then theme.set(c); lg.rectangle("fill", mx + i - 1, my + j - 1, 1, 1) end
    end
  end
end

local function ornament(x0, y0, w, h, spec, kind, small)
  local field = spec.field
  local light = spec.light or theme.shade(field, 0.38)
  local dark = theme.shade(field, -0.42)
  theme.set(field)
  lg.rectangle("fill", x0, y0, w, h)
  local cx, cy = x0 + w / 2, y0 + h / 2
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local px, py = x0 + x, y0 + y
      local col
      if x == 1 or y == 1 or x == w - 2 or y == h - 2 then
        if x >= 1 and y >= 1 and x <= w - 2 and y <= h - 2 then col = light end -- the ruled frame
      else
        -- halftone: dots grow towards the edges on a 3px diagonal screen
        local d = math.max(math.abs(px - cx) / (w / 2), math.abs(py - cy) / (h / 2))
        local onDot = (x + y) % 3 == 0 and (x - y) % 3 == 0
        local nearDot = ((x + y) % 3 == 0 or (x - y) % 3 == 0) and d > 0.75
        if (onDot and d > 0.35) or nearDot then col = dark
        elseif onDot and d < 0.3 then col = light end
      end
      if col then theme.set(col); lg.rectangle("fill", px, py, 1, 1) end
    end
  end
  if small then return end
  local glyph = icons.COAT_ICON[kind]
  if glyph then
    -- the coat's shape on a clear disc, and the mark below it
    theme.set(theme.shade(field, -0.5))
    lg.rectangle("fill", math.floor(cx) - 12, math.floor(cy) - 18, 24, 24)
    theme.set(field)
    lg.rectangle("fill", math.floor(cx) - 11, math.floor(cy) - 17, 22, 22)
    icons.draw(glyph, math.floor(cx), math.floor(cy) - 6, spec.light and C.steel or C.paper, 2)
    mark(cx, cy + 20, spec)
  else
    mark(cx, cy, spec)
  end
end

local backs = {}
function M.back(kind)
  kind = kind or "plain"
  if backs[kind] then return backs[kind] end
  local spec = M.BACKS[kind] or M.BACKS.plain
  local W, H = M.W, M.H
  local cv = lg.newCanvas(W, H)
  cv:setFilter("nearest", "nearest")
  begin(cv)
  paper(W, H, #kind * 17)
  theme.set(theme.shade(spec.field, -0.55))
  lg.rectangle("fill", 3, 3, W - 6, H - 6)
  ornament(4, 4, W - 8, H - 8, spec, kind)
  lg.pop()
  backs[kind] = cv
  return cv
end

-- A small draw-pile sprite (three stacked backs), drawn 1:1.
local pile
function M.pile()
  if pile then return pile end
  local w, h = 24, 32
  pile = lg.newCanvas(w + 4, h + 4)
  pile:setFilter("nearest", "nearest")
  begin(pile)
  for k = 2, 1, -1 do
    theme.set(C.black)
    lg.rectangle("fill", k * 2, 4 - k * 2, w, h)
    theme.set(PAPER[2])
    lg.rectangle("fill", k * 2 + 1, 5 - k * 2, w - 2, h - 2)
  end
  lg.push()
  lg.translate(0, 4)
  paper(w, h, 5)
  lg.pop()
  theme.set(theme.shade(M.BACKS.plain.field, -0.55))
  lg.rectangle("fill", 2, 6, w - 4, h - 4)
  ornament(3, 7, w - 6, h - 6, M.BACKS.plain, "plain", true)
  lg.pop()
  return pile
end

-- ---------------------------------------------------------------- views

local View = {}
View.__index = View

function M.new(inst, x, y, scale)
  local def = cards.getDef(inst)
  local v = setmetatable({
    inst = inst, def = def, x = x, y = y, vx = 0, vy = 0, tx = x, ty = y, s = scale or 1, ts = scale or 1,
    rot = 0, trot = 0, flash = 0, alpha = 1, dying = nil,
    hovered = false, faceDown = false, flip = 1, tflip = 1, selected = false, bounce = 0, dim = 0,
    backKind = "plain",
  }, View)
  return v
end

function View:setTarget(x, y, s, rot)
  self.tx, self.ty = x, y
  if s then self.ts = s end
  self.trot = rot or 0
end

function View:snap()
  self.x, self.y, self.s, self.rot, self.vx, self.vy = self.tx, self.ty, self.ts, self.trot, 0, 0
end

function View:update(dt)
  local k, damp = 210, 19
  local ax = (self.tx - self.x) * k - self.vx * damp
  local ay = (self.ty - self.y) * k - self.vy * damp
  self.vx, self.vy = self.vx + ax * dt, self.vy + ay * dt
  self.x, self.y = self.x + self.vx * dt, self.y + self.vy * dt
  self.s = self.s + (self.ts - self.s) * math.min(1, dt * 16)
  -- lean into fast moves only; slow drifts stay upright so they keep drawing 1:1
  local lean = math.abs(self.vx) > 120 and math.max(-0.3, math.min(0.3, self.vx / 1400)) or 0
  self.rot = self.rot + (self.trot + lean - self.rot) * math.min(1, dt * 14)
  self.flash = math.max(0, self.flash - dt * 3)
  self.bounce = math.max(0, self.bounce - dt * 4)
  self.flip = self.flip + (self.tflip - self.flip) * math.min(1, dt * 12)
  if self.dying then self.dying = self.dying + dt * 1.4 end
  -- a shine sweeps across a card when you first point at it, and it wobbles as it's picked out
  if self.hovered and not self.wasHovered then
    self.shine = 0
    if self.rot == self.trot then self.rot = self.trot + (love.math.random() < 0.5 and -0.05 or 0.05) end
  end
  self.wasHovered = self.hovered
  if self.shine then
    self.shine = self.shine + dt * 2.4
    if self.shine >= 1 then self.shine = nil end
  end
  -- settle exactly, so resting cards land on whole pixels with no rotation
  if math.abs(self.tx - self.x) < 0.3 and math.abs(self.vx) < 2 then self.x, self.vx = self.tx, 0 end
  if math.abs(self.ty - self.y) < 0.3 and math.abs(self.vy) < 2 then self.y, self.vy = self.ty, 0 end
  if math.abs(self.ts - self.s) < 0.01 then self.s = self.ts end
  if math.abs(self.trot - self.rot) < 0.004 then self.rot = self.trot end
  if math.abs(self.tflip - self.flip) < 0.01 then self.flip = self.tflip end
end

function View:contains(px, py)
  local w, h = M.W * self.s, M.H * self.s
  return px >= self.x - w / 2 and px <= self.x + w / 2 and py >= self.y - h / 2 and py <= self.y + h / 2
end

function View:project(u, v)
  local s = self.s * (1 + self.bounce * 0.12)
  local w, h = M.W * s * math.abs(self.flip), M.H * s
  local x, y = u * w, v * h
  local cr, sr = math.cos(self.rot), math.sin(self.rot)
  return self.x + x * cr - y * sr, self.y + x * sr + y * cr
end

-- True when the card can be drawn 1:1 on whole pixels.
function View:atRest()
  return self.rot == 0 and self.s == 1 and math.abs(self.flip) == 1 and self.bounce < 0.02 and not self.dying
end

-- A tiny heart for each life: full for lives left, an empty outline for lives lost.
local HEART = { ".k.k.", "kffff", "kffff", ".kff.", "..k.." }
local HEART_RED, HEART_LOST = theme.hex("#ff5a6e"), theme.hex("#3a3f4c")
local function hearts(x, y, left, max, alpha)
  for i = 1, max do
    local hx = x + (i - 1) * 6
    for j, row in ipairs(HEART) do
      for c = 1, #row do
        local ch = row:sub(c, c)
        if ch == "k" then theme.set(C.black, alpha)
        elseif ch == "f" then theme.set(i <= left and HEART_RED or HEART_LOST, alpha) end
        if ch ~= "." then lg.rectangle("fill", hx + c - 1, y + j - 1, 1, 1) end
      end
    end
  end
end
M.hearts = hearts

-- A seated cat's Warmth: a flame and the number, on the top-right corner.
local FLAME = { "..o..", ".oyo.", "oyyyo", "oyyyo", ".ooo." }
warmthBadge = function(self, alpha)
  local w = self.inst.warmth or 0
  if w <= 0 then return false end
  local hot = w >= HOT
  local x, y = M.W - 21, 2
  gfx.box(x, y, 19, 13, C.black, alpha)
  gfx.box(x + 1, y + 1, 17, 11, hot and theme.hex("#7e2018") or theme.hex("#5a3410"), alpha)
  for j, row in ipairs(FLAME) do
    for c = 1, #row do
      local ch = row:sub(c, c)
      if ch ~= "." then
        theme.set(ch == "y" and C.goldText or theme.hex("#ff6a2a"), alpha)
        lg.rectangle("fill", x + 2 + c - 1, y + 4 + j - 1, 1, 1)
      end
    end
  end
  gfx.text(tostring(w), theme.font("bold", 8.5), x + 13, y + 1.5, C.white, { align = "center", alpha = alpha, bg = C.black })
  return true
end

function View:draw(opts)
  opts = opts or {}
  if self.dying and self.dying >= 1 then return end
  local def = self.def
  local showBack = self.faceDown or self.flip < 0
  local tex = showBack and M.back(self.backKind) or renderFace(def, self.inst.level or 1, self.inst.print)
  local alpha = self.alpha
  if self.dying then alpha = alpha * (1 - self.dying) end
  local k = 1 - self.dim * 0.6
  local lift = (self.hovered or self.selected) and 3 or 2
  local rest = self:atRest()
  local s = self.s * (1 + self.bounce * 0.12)
  local fx_ = math.abs(self.flip)
  -- the card's own frame of reference: (0, 0) is its top-left corner
  lg.push()
  -- cards in a hand float: a slow bob, each on its own phase, in whole screen pixels so the
  -- pixel art stays crisp
  local bob = self.bob and math.sin(love.timer.getTime() * 1.7 + self.bob) * 0.9 or 0
  if rest then
    local K = theme.K
    lg.translate(math.floor((self.x - M.W / 2) * K + 0.5) / K, math.floor((self.y - M.H / 2 + bob) * K + 0.5) / K)
  else
    lg.translate(self.x, self.y + bob)
    lg.rotate(self.rot)
    lg.scale(s * fx_, s)
    lg.translate(-M.W / 2, -M.H / 2)
  end
  lg.setColor(0, 0, 0, 0.45 * alpha)
  lg.rectangle("fill", 1, lift, M.W, M.H)
  lg.setColor(k, k, k, alpha)
  lg.draw(tex, 0, 0)
  if self.shine and not showBack and not self.dying then
    -- a slanted band of light, clipped to the card row by row
    local p = -14 + self.shine * (M.W + 28)
    lg.setColor(1, 1, 1, 0.28 * alpha)
    for y = 0, M.H - 1, 2 do
      local x0 = p + (M.H - y) * 0.35 - M.H * 0.18
      local a, b = math.max(0, math.floor(x0)), math.min(M.W, math.floor(x0 + 7))
      if b > a then lg.rectangle("fill", a, y, b - a, 2) end
    end
  end
  if self.flash > 0 then -- a white wash over the card
    lg.setBlendMode("add")
    lg.setColor(self.flash * alpha, self.flash * alpha, self.flash * alpha, 1)
    lg.rectangle("fill", 0, 0, M.W, M.H)
    lg.setBlendMode("alpha")
  end
  local warm = self.inst.warmth or 0
  if warm >= HOT and not showBack and not self.dying then
    -- the Hot Seat: a flickering ring of fire around the card
    local t = love.timer.getTime()
    for k = 0, 2 do
      local a = (0.55 + 0.45 * math.sin(t * 9 + k * 2.1)) * alpha
      theme.set(k == 1 and C.goldText or theme.hex("#ff6a2a"), a)
      lg.rectangle("line", -1.5 - k, -1.5 - k, M.W + 3 + 2 * k, M.H + 3 + 2 * k)
    end
  elseif self.selected and not self.dying then
    theme.set(C.goldText, alpha)
    lg.rectangle("line", -1.5, -1.5, M.W + 3, M.H + 3)
  end
  if not showBack and not self.dying then self:drawText(opts, alpha, k) end
  lg.pop()
end

-- The live layer of a face: name, ability, Paws badge, lives, and the captive's brand.
function View:drawText(opts, alpha, k)
  local def = self.def
  local unit = def.kind == "unit"
  local f = theme.T.small()
  local np, ap = M.NAME_PLATE, M.ABIL_PLATE
  local ncol = nameColor(def)
  local ink = (unit and def.coat == "gilt") and C.black or C.white
  local name = cards.shortName(def)
  local nf = f
  -- pixel text: every name in the same tiny face, like a printed card
  if theme.textStyle == "pixel" or nf:getWidth(name) > np[3] - 4 then nf = theme.font("body", 7.5) end
  if nf:getWidth(name) > np[3] - 4 then name = name:match("^(%S+)") or name end
  gfx.text(name, nf, np[1] + np[3] / 2, np[2] + (np[4] - nf:getHeight()) / 2, unit and ink or C.cyan,
    { align = "center", alpha = alpha, bg = ncol })
  local label = M.SHORT[def.ability] or ""
  gfx.text(label, theme.font("bold", 7.5), ap[1] + 11, ap[2] + (ap[4] - theme.font("bold", 7.5):getHeight()) / 2, C.white,
    { alpha = alpha, bg = abilColor(def) })
  if not unit and not self.paws then return end
  -- Paws badge (green when buffed, red when hexed)
  local base = def.ability == "box" and 4 or cards.paws(self.inst)
  local p = opts.paws or self.paws or base
  local font = theme.T.bold()
  local str = tostring(p)
  local bw = math.max(14, math.ceil(font:getWidth(str)) + 6)
  local bg = def.rarity == "legendary" and C.goldDark or C.night
  if p > base then bg = theme.hex("#1f6b45") elseif p < base then bg = C.redDark end
  gfx.box(2, 2, bw, 14, C.black, alpha)
  gfx.box(3, 3, bw - 2, 12, bg, alpha)
  gfx.text(str, font, 2 + bw / 2, 3 + (12 - font:getHeight()) / 2, C.white, { align = "center", alpha = alpha, bg = bg })
  -- lives
  if unit then
    local max = cards.livesOf(self.inst)
    local left = self.livesShown or self.inst.lives or max
    if self.inst.captive then max = 1 end
    if max > 0 then
      theme.set(C.black, 0.6 * alpha)
      lg.rectangle("fill", 3, 44, max * 6 + 2, 7)
      hearts(4, 45, left, max, alpha)
    end
    if warmthBadge(self, alpha) then end
    if self.risk then
      -- placed here, it could be captured
      gfx.box(M.W - 15, 16, 12, 12, C.black, alpha)
      gfx.box(M.W - 14, 17, 10, 10, C.red, alpha)
      gfx.text("!", theme.font("bold", 9), M.W - 9, 17, C.white, { align = "center", alpha = alpha, bg = C.red })
    end
    if self.inst.captive then
      -- your cat, held by the rival: a red brand on the art
      theme.set(theme.hex("#ff3b30"), alpha)
      lg.rectangle("line", 3.5, 3.5, 49, 47)
      gfx.box(M.W - 22, 40, 19, 10, C.redDark, alpha)
      gfx.text("YOURS", theme.font("bold", 5.5), M.W - 12.5, 41.5, C.white, { align = "center", alpha = alpha, bg = C.redDark })
    end
  end
end

return M
