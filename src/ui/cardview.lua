-- Pixel cards: a 56x78 face baked once, drawn through a projected mesh for tilt,
-- with spring motion, hover lift, legendary foil, play flash and dissolve.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
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

local function renderFace(def, level)
  local key = def.id .. ":" .. level .. ":" .. (def.scars or 0) .. ":" .. def.power
  if faceCache[key] then return faceCache[key] end
  local W, H = M.W, M.H
  local cv = lg.newCanvas(W, H)
  cv:setFilter("nearest", "nearest")
  lg.push("all")
  lg.origin()
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, 0)
  local rc = rarityCol(def)
  gfx.box(0, 0, W, H, C.black)
  gfx.box(1, 1, W - 2, H - 2, rc)
  theme.set(theme.mix(rc, C.paper, 0.45))
  lg.rectangle("fill", 2, 1, W - 4, 1)
  gfx.box(3, 3, W - 6, H - 6, C.paper)
  -- art window
  theme.set(C.black)
  lg.rectangle("fill", 3, 3, W - 6, art.CARD_H + 2)
  lg.setColor(1, 1, 1)
  lg.draw(art.card(def), 3, 4)
  -- name
  local f10 = theme.T.small()
  local name = fit(f10, cards.shortName(def), W - 6)
  gfx.text(name, f10, W / 2, 40, C.ink, { align = "center", shadow = false })
  -- ability: icon + short label
  local f8 = theme.T.label()
  local label = M.SHORT[def.ability] or ""
  local iconCol = def.kind == "special" and C.cyan or (def.ability == "none" and C.steel or C.blue)
  local lw = f8:getWidth(label) + 11
  local lx = math.floor(W / 2 - lw / 2)
  icons.draw(icons.ABILITY_ICON[def.ability] or "paw", lx + 4, 57, iconCol)
  gfx.text(label, f8, lx + 10, 53, C.blueDark, { shadow = false })
  -- footer: coat bar with class icon
  gfx.box(3, H - 15, W - 6, 12, C.black)
  if def.kind == "unit" then
    local coat = cards.COATS[def.coat]
    gfx.box(4, H - 14, W - 8, 10, coat.color)
    theme.set(theme.mix(coat.color, C.paper, 0.35))
    lg.rectangle("fill", 5, H - 14, W - 10, 1)
    local dark = def.coat == "gilt" or def.coat == "shadow"
    icons.draw(def.type == "magic" and "orb" or "sword", 10, H - 9, C.paper)
    gfx.text(coat.name:upper(), f8, W / 2 + 4, H - 14, dark and C.black or C.paper, { align = "center", shadow = false })
  else
    gfx.box(4, H - 14, W - 8, 10, C.ink3)
    gfx.text("TRICK", f8, W / 2, H - 14, C.cyan, { align = "center", shadow = false })
  end
  if level > 1 then
    for i = 1, level - 1 do icons.draw("star", W - 9 - (i - 1) * 8, 9, C.gold) end
  end
  lg.pop()
  faceCache[key] = cv
  return cv
end
M.face = renderFace

-- Card backs show the coat: Ember, Tide and Gilt cats have coloured backs, while Shadow cats and
-- tricks share the same dark back.
M.BACKS = {
  ember = { field = C.red, hatch = C.redDark, icon = "paw" },
  tide = { field = C.blue, hatch = C.blueDark, icon = "paw" },
  gilt = { field = C.gold, hatch = C.goldDark, icon = "paw" },
  dark = { field = theme.hex("#1b2420"), hatch = C.black, icon = "moon" },
  plain = { field = C.ink3, hatch = C.ink2, icon = "paw" },
}
local backs = {}
function M.back(kind)
  kind = kind or "plain"
  if backs[kind] then return backs[kind] end
  local spec = M.BACKS[kind] or M.BACKS.plain
  local W, H = M.W, M.H
  local cv = lg.newCanvas(W, H)
  cv:setFilter("nearest", "nearest")
  lg.push("all")
  lg.origin()
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, 0)
  gfx.box(0, 0, W, H, C.black)
  gfx.box(1, 1, W - 2, H - 2, C.paper)
  gfx.box(3, 3, W - 6, H - 6, spec.field)
  theme.set(spec.hatch)
  for y = 3, H - 4 do
    for x = 3, W - 4 do
      if (x + y) % 6 < 2 then lg.rectangle("fill", x, y, 1, 1) end
    end
  end
  gfx.box(13, 24, W - 26, 30, C.black)
  gfx.box(14, 25, W - 28, 28, spec.field)
  icons.draw(spec.icon, W / 2, H / 2 + 1, C.paper, 2)
  lg.pop()
  backs[kind] = cv
  return cv
end

-- ---------------------------------------------------------------- views

local View = {}
View.__index = View
local GRID = 3

function M.new(inst, x, y, scale)
  local def = cards.getDef(inst)
  local v = setmetatable({
    inst = inst, def = def, x = x, y = y, vx = 0, vy = 0, tx = x, ty = y, s = scale or 1, ts = scale or 1,
    rot = 0, trot = 0, tiltX = 0, tiltY = 0, flash = 0, alpha = 1, dying = nil, phase = love.math.random() * 6.28,
    hovered = false, faceDown = false, flip = 1, tflip = 1, selected = false, bounce = 0, dim = 0,
    backKind = "plain", lunge = 0,
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
  local lean = math.max(-0.3, math.min(0.3, self.vx / 1400))
  self.rot = self.rot + (self.trot + lean - self.rot) * math.min(1, dt * 14)
  self.flash = math.max(0, self.flash - dt * 3)
  self.bounce = math.max(0, self.bounce - dt * 4)
  self.flip = self.flip + (self.tflip - self.flip) * math.min(1, dt * 12)
  if self.dying then self.dying = self.dying + dt * 1.4 end
  local tX, tY = 0, 0
  if self.hovered then
    local widgets = require("src.ui.widgets")
    local w, h = M.W * self.s, M.H * self.s
    tX = math.max(-1, math.min(1, (widgets.mx - self.x) / (w / 2)))
    tY = math.max(-1, math.min(1, (widgets.my - self.y) / (h / 2)))
  end
  self.tiltX = self.tiltX + (tX - self.tiltX) * math.min(1, dt * 12)
  self.tiltY = self.tiltY + (tY - self.tiltY) * math.min(1, dt * 12)
end

function View:contains(px, py)
  local w, h = M.W * self.s, M.H * self.s
  return px >= self.x - w / 2 and px <= self.x + w / 2 and py >= self.y - h / 2 and py <= self.y + h / 2
end

function View:project(u, v)
  local s = self.s * (1 + self.bounce * 0.25)
  local w, h = M.W * s * math.abs(self.flip), M.H * s
  local t = love.timer.getTime()
  local ay = self.tiltX * 0.4 + math.sin(t * 1.3 + self.phase) * 0.04
  local ax = -self.tiltY * 0.35 + math.cos(t * 1.1 + self.phase) * 0.03
  local x, y, z = u * w, v * h, 0
  local cy, sy = math.cos(ay), math.sin(ay)
  x, z = x * cy + z * sy, -x * sy + z * cy
  local cx, sx = math.cos(ax), math.sin(ax)
  y, z = y * cx - z * sx, y * sx + z * cx
  local p = 300 / (300 + z)
  x, y = x * p, y * p
  local cr, sr = math.cos(self.rot), math.sin(self.rot)
  return self.x + x * cr - y * sr, self.y + x * sr + y * cr
end

function View:draw(opts)
  opts = opts or {}
  if self.dying and self.dying >= 1 then return end
  local def = self.def
  local showBack = self.faceDown or self.flip < 0
  local tex = showBack and M.back(self.backKind) or renderFace(def, self.inst.level or 1)
  local alpha = self.alpha
  local s = self.s * (1 + self.bounce * 0.25)
  -- shadow
  local lift = (self.hovered or self.selected) and 4 or 2
  lg.setColor(0, 0, 0, 0.45 * alpha)
  lg.push()
  lg.translate(math.floor(self.x + lift * 0.5), math.floor(self.y + lift))
  lg.rotate(self.rot)
  lg.rectangle("fill", -M.W * s * math.abs(self.flip) / 2, -M.H * s / 2, M.W * s * math.abs(self.flip), M.H * s)
  lg.pop()
  local verts = {}
  for j = 0, GRID do
    for i = 0, GRID do
      local u, v = i / GRID, j / GRID
      local px, py = self:project(u - 0.5, v - 0.5)
      local k = 1 - self.dim * 0.6
      verts[#verts + 1] = { px, py, u, v, k, k, k, alpha }
    end
  end
  self.mesh:setVertices(verts)
  self.mesh:setTexture(tex)
  local sh
  if self.dying and shaders.dissolve then
    sh = shaders.dissolve
    sh:send("t", math.max(0, math.min(1, self.dying)))
    sh:send("edge", { 1.0, 0.55, 0.1 })
  elseif self.flash > 0 and shaders.flash then
    sh = shaders.flash
    sh:send("amount", self.flash)
  elseif def.rarity == "legendary" and not showBack and shaders.foil then
    sh = shaders.foil
    sh:send("time", love.timer.getTime())
    sh:send("tilt", { self.tiltX, self.tiltY })
  end
  lg.setShader(sh)
  lg.setColor(1, 1, 1, alpha)
  lg.draw(self.mesh)
  lg.setShader()
  if self.selected and not self.dying then
    local x1, y1 = self:project(-0.5, -0.5)
    local x2, y2 = self:project(0.5, 0.5)
    theme.set(C.gold, alpha)
    lg.setLineWidth(1)
    lg.rectangle("line", math.floor(math.min(x1, x2)) - 1.5, math.floor(math.min(y1, y2)) - 1.5, math.floor(math.abs(x2 - x1)) + 3, math.floor(math.abs(y2 - y1)) + 3)
  end
  if showBack or self.dying or (def.kind ~= "unit" and not self.paws) then return end
  -- paws badge (dynamic, so buffs and hexes can show)
  local bx, by = self:project(-0.5 + 9 / M.W, -0.5 + 9 / M.H)
  local base = def.ability == "box" and 4 or cards.paws(self.inst)
  local p = opts.paws or self.paws or base
  local font = theme.T.body()
  local str = tostring(p)
  local bw = math.max(14, font:getWidth(str) + 5)
  local bxl, byt = math.floor(bx - bw / 2), math.floor(by - 7)
  local bg = def.rarity == "legendary" and C.gold or C.ink
  if p > base then bg = theme.hex("#1f6b45") elseif p < base then bg = C.redDark end
  gfx.box(bxl, byt, bw, 14, C.black, alpha)
  gfx.box(bxl + 1, byt + 1, bw - 2, 12, bg, alpha)
  gfx.text(str, font, bxl + bw / 2, byt - 2, (bg == C.gold) and C.black or C.paper, { align = "center", shadow = false, alpha = alpha })
end

return M
