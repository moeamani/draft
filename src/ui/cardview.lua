-- Pixel cards in the Figma title-card style: a 56x78 face built from dithered palette plates,
-- baked once. At rest a card is drawn 1:1 on whole pixels (no wobble, no tilt, no resampling),
-- so its pixels never shimmer. Only transient motion (dealing, flipping, a lean while moving)
-- goes through the projected mesh.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local plates = require("src.ui.plates")
local shaders = require("src.ui.shaders")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
M.W, M.H = 56, 78

local C = theme.c
local faceCache = {}

local function rarityCol(d) return cards.RARITY_COLOR[d.rarity] end

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

-- Face layout: rarity frame, art window, then three plates: name (ink), ability (blue), coat.
local function renderFace(def, level)
  local key = def.id .. ":" .. level .. ":" .. (def.scars or 0) .. ":" .. def.power
  if faceCache[key] then return faceCache[key] end
  local W, H = M.W, M.H
  -- build the plates before switching canvases (they bake into their own canvases)
  local namePlate = plates.plate(W - 6, 12, C.ink, { outline = false, light = 0.1 })
  local abilCol = def.kind == "special" and C.ink3 or (def.ability == "none" and theme.hex("#3b4a5e") or C.blue)
  local abilPlate = plates.plate(W - 6, 11, abilCol, { outline = false, light = 0.14 })
  local coatCol = def.kind == "unit" and cards.COATS[def.coat].color or C.ink2
  local coatPlate = plates.plate(W - 6, 11, coatCol, { outline = false, light = 0.14 })
  local frame = plates.plate(W, H, rarityCol(def), { outline = C.black, light = 0.25 })
  local cv = lg.newCanvas(W, H)
  cv:setFilter("nearest", "nearest")
  begin(cv)
  lg.setColor(1, 1, 1)
  lg.draw(frame, 0, 0)
  theme.set(C.black)
  lg.rectangle("fill", 2, 2, W - 4, H - 4)
  lg.setColor(1, 1, 1)
  lg.draw(art.card(def), 3, 3)
  lg.draw(namePlate, 3, 40)
  lg.draw(abilPlate, 3, 53)
  lg.draw(coatPlate, 3, 65)
  local f10 = theme.T.small()
  gfx.text(fit(f10, cards.shortName(def), W - 8), f10, W / 2, 40, C.paper, { align = "center", shadow = false })
  local label = M.SHORT[def.ability] or ""
  local lw = f10:getWidth(label) + 11
  local lx = math.floor(W / 2 - lw / 2)
  icons.draw(icons.ABILITY_ICON[def.ability] or "paw", lx + 4, 58, C.white)
  gfx.text(label, f10, lx + 10, 53, C.white, { shadow = false })
  if def.kind == "unit" then
    local coat = cards.COATS[def.coat]
    local dark = def.coat == "gilt"
    icons.draw(def.type == "magic" and "orb" or "sword", 10, 70, C.white)
    gfx.text(coat.name:upper(), f10, W / 2 + 4, 65, dark and C.black or C.white, { align = "center", shadow = false })
  else
    gfx.text("TRICK", f10, W / 2, 65, C.cyan, { align = "center", shadow = false })
  end
  if level > 1 then
    for i = 1, level - 1 do icons.draw("star", W - 9 - (i - 1) * 8, 9, C.gold) end
  end
  lg.pop()
  faceCache[key] = cv
  return cv
end
M.face = renderFace

-- Card backs are little title cards: the coat's plate with the smeared mascot. Shadow cats and
-- tricks share the black "Power" plate with its full spectrum smear.
M.BACKS = {
  ember = { plate = C.red, streak = 0.43, icon = "paw" },
  tide = { plate = theme.hex("#2471fc"), streak = 0.43, icon = "paw" },
  gilt = { plate = C.gold, streak = 0.43, icon = "paw" },
  dark = { plate = C.night, streak = 1.0, icon = "moon" },
  plain = { plate = C.ink3, streak = 0.43, icon = "paw" },
}
local backs = {}
function M.back(kind)
  kind = kind or "plain"
  if backs[kind] then return backs[kind] end
  local spec = M.BACKS[kind] or M.BACKS.plain
  local W, H = M.W, M.H
  local inner = plates.titleCard(W - 4, H - 4, spec.plate, { streak = spec.streak })
  local cv = lg.newCanvas(W, H)
  cv:setFilter("nearest", "nearest")
  begin(cv)
  theme.set(C.black)
  lg.rectangle("fill", 0, 0, W, H)
  theme.set(C.paper)
  lg.rectangle("fill", 1, 1, W - 2, H - 2)
  lg.setColor(1, 1, 1)
  lg.draw(inner, 2, 2)
  lg.pop()
  backs[kind] = cv
  return cv
end

-- A small draw-pile sprite (three stacked backs), drawn 1:1.
local pile
function M.pile()
  if pile then return pile end
  local w, h = 24, 32
  local inner = plates.titleCard(w - 4, h - 4, C.ink3, { streak = 0.43 })
  pile = lg.newCanvas(w + 4, h + 4)
  pile:setFilter("nearest", "nearest")
  begin(pile)
  for k = 2, 0, -1 do
    theme.set(C.black)
    lg.rectangle("fill", k * 2, 4 - k * 2, w, h)
    theme.set(C.paper)
    lg.rectangle("fill", k * 2 + 1, 5 - k * 2, w - 2, h - 2)
  end
  lg.setColor(1, 1, 1)
  lg.draw(inner, 2, 4)
  lg.pop()
  return pile
end

-- ---------------------------------------------------------------- views

local View = {}
View.__index = View
local GRID = 3

function M.new(inst, x, y, scale)
  local def = cards.getDef(inst)
  local v = setmetatable({
    inst = inst, def = def, x = x, y = y, vx = 0, vy = 0, tx = x, ty = y, s = scale or 1, ts = scale or 1,
    rot = 0, trot = 0, flash = 0, alpha = 1, dying = nil,
    hovered = false, faceDown = false, flip = 1, tflip = 1, selected = false, bounce = 0, dim = 0,
    backKind = "plain",
  }, View)
  v.mesh = lg.newMesh((GRID + 1) * (GRID + 1), "triangles", "stream")
  local map = {}
  for j = 0, GRID - 1 do
    for i = 0, GRID - 1 do
      local a = j * (GRID + 1) + i + 1
      local b, c, d = a + 1, a + GRID + 1, a + GRID + 2
      for _, k in ipairs({ a, b, c, b, d, c }) do map[#map + 1] = k end
    end
  end
  v.mesh:setVertexMap(map)
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

function View:draw(opts)
  opts = opts or {}
  if self.dying and self.dying >= 1 then return end
  local def = self.def
  local showBack = self.faceDown or self.flip < 0
  local tex = showBack and M.back(self.backKind) or renderFace(def, self.inst.level or 1)
  local alpha = self.alpha
  local k = 1 - self.dim * 0.6
  local lift = (self.hovered or self.selected) and 3 or 2
  local rest = self:atRest()
  local x0, y0 = math.floor(self.x - M.W / 2 + 0.5), math.floor(self.y - M.H / 2 + 0.5)
  -- shadow
  lg.setColor(0, 0, 0, 0.45 * alpha)
  if rest then
    lg.rectangle("fill", x0 + 1, y0 + lift, M.W, M.H)
  else
    local s = self.s
    lg.push()
    lg.translate(math.floor(self.x + 1), math.floor(self.y + lift))
    lg.rotate(self.rot)
    lg.rectangle("fill", -M.W * s * math.abs(self.flip) / 2, -M.H * s / 2, M.W * s * math.abs(self.flip), M.H * s)
    lg.pop()
  end
  local sh
  if self.dying and shaders.dissolve then
    sh = shaders.dissolve
    sh:send("t", math.max(0, math.min(1, self.dying)))
    sh:send("edge", { 1.0, 0.55, 0.1 })
  elseif self.flash > 0 and shaders.flash then
    sh = shaders.flash
    sh:send("amount", self.flash)
  end
  lg.setShader(sh)
  if rest then
    lg.setColor(k, k, k, alpha)
    lg.draw(tex, x0, y0)
  else
    local verts = {}
    for j = 0, GRID do
      for i = 0, GRID do
        local u, v = i / GRID, j / GRID
        local px, py = self:project(u - 0.5, v - 0.5)
        verts[#verts + 1] = { px, py, u, v, k, k, k, alpha }
      end
    end
    self.mesh:setVertices(verts)
    self.mesh:setTexture(tex)
    lg.setColor(1, 1, 1, alpha)
    lg.draw(self.mesh)
  end
  lg.setShader()
  if self.selected and not self.dying then
    theme.set(C.gold, alpha)
    if rest then
      lg.rectangle("fill", x0 - 2, y0 - 2, M.W + 4, 1)
      lg.rectangle("fill", x0 - 2, y0 + M.H + 1, M.W + 4, 1)
      lg.rectangle("fill", x0 - 2, y0 - 2, 1, M.H + 4)
      lg.rectangle("fill", x0 + M.W + 1, y0 - 2, 1, M.H + 4)
    end
  end
  if showBack or self.dying or (def.kind ~= "unit" and not self.paws) then return end
  -- Paws badge: a little black "Power" plate (green when buffed, red when hexed)
  local bx, by
  if rest then bx, by = x0 + 9, y0 + 9 else bx, by = self:project(-0.5 + 9 / M.W, -0.5 + 9 / M.H) end
  local base = def.ability == "box" and 4 or cards.paws(self.inst)
  local p = opts.paws or self.paws or base
  local font = theme.T.body()
  local str = tostring(p)
  local bw = math.max(14, font:getWidth(str) + 5)
  local bxl, byt = math.floor(bx - bw / 2), math.floor(by - 7)
  local bg = def.rarity == "legendary" and C.goldDark or C.night
  if p > base then bg = theme.hex("#1f6b45") elseif p < base then bg = C.redDark end
  gfx.box(bxl, byt, bw, 14, C.black, alpha)
  gfx.box(bxl + 1, byt + 1, bw - 2, 12, bg, alpha)
  gfx.text(str, font, bxl + bw / 2, byt - 2, C.white, { align = "center", shadow = false, alpha = alpha })
end

return M
