-- Pixel cards: a 52x72 face baked once, drawn through a projected mesh for tilt,
-- with spring motion, hover lift, legendary foil, play flash and dissolve.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local shaders = require("src.ui.shaders")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
M.W, M.H = 52, 72

local C = theme.c
local faceCache = {}

local function rarityCol(d) return cards.RARITY_COLOR[d.rarity] end

M.SHORT = {
  none = "STEADY", smite = "HAMMER", inspire = "ORB", hex = "HEX", litter = "LITTER", pounce = "POUNCE",
  ninelives = "9 LIVES", stray = "STRAY", groom = "GROOM", purr = "PURR", yowl = "YOWL", muster = "RALLY",
}

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
  lg.draw(art.card(def), 4, 4)
  -- name
  local f = theme.T.tiny()
  local name = cards.shortName(def)
  while f:getWidth(name) > W - 8 and #name > 3 do name = name:sub(1, -2) end
  gfx.text(name, f, W / 2, 37, C.ink, { align = "center", shadow = false })
  -- ability: icon + short label
  local label = def.kind == "special" and "TRICK" or (M.SHORT[def.ability] or "")
  local iconCol = def.kind == "special" and C.cyan or (def.ability == "none" and C.steel or C.blue)
  local lw = f:getWidth(label) + 11
  local lx = math.floor(W / 2 - lw / 2)
  icons.draw(icons.ABILITY_ICON[def.ability] or "paw", lx + 4, 51, iconCol)
  gfx.text(label, f, lx + 10, 47, C.blueDark, { shadow = false })
  -- footer: coat bar with class icon
  if def.kind == "unit" then
    local coat = cards.COATS[def.coat]
    gfx.box(3, H - 13, W - 6, 10, C.black)
    gfx.box(4, H - 12, W - 8, 8, coat.color)
    theme.set(theme.mix(coat.color, C.paper, 0.35))
    lg.rectangle("fill", 5, H - 12, W - 10, 1)
    local dark = def.coat == "gilt" or def.coat == "shadow"
    icons.draw(def.type == "magic" and "orb" or "sword", 9, H - 8, C.paper)
    gfx.text(coat.name:upper(), f, W / 2 + 4, H - 13, dark and C.black or C.paper, { align = "center", shadow = false })
  else
    gfx.box(3, H - 13, W - 6, 10, C.black)
    gfx.box(4, H - 12, W - 8, 8, C.ink3)
    gfx.text("TRICK", f, W / 2, H - 13, C.cyan, { align = "center", shadow = false })
  end
  if level > 1 then
    for i = 1, level - 1 do icons.draw("star", W - 9 - (i - 1) * 8, 9, C.gold) end
  end
  lg.pop()
  faceCache[key] = cv
  return cv
end
M.face = renderFace

local back
function M.back()
  if back then return back end
  local W, H = M.W, M.H
  back = lg.newCanvas(W, H)
  back:setFilter("nearest", "nearest")
  lg.push("all")
  lg.origin()
  lg.setCanvas(back)
  lg.clear(0, 0, 0, 0)
  gfx.box(0, 0, W, H, C.black)
  gfx.box(1, 1, W - 2, H - 2, C.paper)
  gfx.box(3, 3, W - 6, H - 6, C.red)
  theme.set(C.redDark)
  for y = 3, H - 4 do
    for x = 3, W - 4 do
      if (x + y) % 6 < 2 then lg.rectangle("fill", x, y, 1, 1) end
    end
  end
  gfx.box(12, 22, W - 24, 28, C.black)
  gfx.box(13, 23, W - 26, 26, C.red)
  icons.draw("paw", W / 2, H / 2, C.paper, 2)
  lg.pop()
  return back
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
    hovered = false, faceDown = false, flip = 1, tflip = 1, selected = false, bounce = 0,
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
  local tex = showBack and M.back() or renderFace(def, self.inst.level or 1)
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
      verts[#verts + 1] = { px, py, u, v, 1, 1, 1, alpha }
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
  if showBack or self.dying or def.kind ~= "unit" then return end
  -- paws badge (dynamic, so buffs can show)
  local bx, by = self:project(-0.5 + 9 / M.W, -0.5 + 9 / M.H)
  local p = opts.paws or cards.paws(self.inst)
  local font = theme.T.num()
  local str = tostring(p)
  local bw = math.max(11, font:getWidth(str) + 4)
  local bxl, byt = math.floor(bx - bw / 2), math.floor(by - 6)
  gfx.box(bxl, byt, bw, 12, C.black, alpha)
  gfx.box(bxl + 1, byt + 1, bw - 2, 10, def.rarity == "legendary" and C.gold or C.ink, alpha)
  gfx.text(str, font, bxl + bw / 2, byt, def.rarity == "legendary" and C.black or C.paper, { align = "center", shadow = false, alpha = alpha })
end

return M
