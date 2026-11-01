-- Cards on screen: cached faces, spring motion, pseudo-3D tilt via a projected mesh,
-- legendary foil, play flashes and dissolve-on-death.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local shaders = require("src.ui.shaders")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
M.W, M.H = 200, 280

local C = theme.c
local faceCache = {}

local function rarityCol(d) return cards.RARITY_COLOR[d.rarity] end

local function drawBadge(x, y, r, iconName, bg)
  lg.setColor(0, 0, 0, 0.5)
  lg.circle("fill", x + 1, y + 2, r)
  theme.set(bg or C.black, 0.9)
  lg.circle("fill", x, y, r)
  icons.draw(iconName, x, y, r * 1.5, C.paper)
end

local function renderFace(def, level, style)
  local key = def.id .. ":" .. level .. ":" .. style .. ":" .. (def.scars or 0) .. ":" .. def.power
  if faceCache[key] then return faceCache[key] end
  local W, H = M.W, M.H
  local cv = lg.newCanvas(W, H, { msaa = 0 })
  cv:setFilter("linear", "linear")
  local portrait = art.card(def)
  lg.push("all")
  lg.origin()
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, 0)
  local rc = rarityCol(def)
  theme.set(rc)
  lg.rectangle("fill", 0, 0, W, H, 18, 18)
  theme.set(C.paper)
  lg.rectangle("fill", 7, 7, W - 14, H - 14, 13, 13)

  if style == "compact" then
    lg.setColor(1, 1, 1)
    lg.draw(portrait, 10, 10, 0, (W - 20) / 64, (H - 60) / 52)
    gfx.vgradient(10, H - 120, W - 20, 70, { 0, 0, 0, 0 }, { 0, 0, 0, 0.55 })
    local f = theme.font("bold", 30)
    local name = def.name
    while f:getWidth(name) > W - 26 and #name > 4 do name = name:sub(1, -2) end
    gfx.textf(name, f, 10, H - 48, W - 20, "center", C.ink, { shadow = false })
  else
    lg.setColor(1, 1, 1)
    lg.draw(portrait, 12, 12, 0, (W - 24) / 64, 140 / 52)
    lg.setColor(0, 0, 0, 0.25)
    lg.rectangle("fill", 12, 150, W - 24, 3)
    local size = 24
    local f = theme.font("bold", size)
    while f:getWidth(def.name) > W - 28 and size > 14 do size = size - 1; f = theme.font("bold", size) end
    gfx.textf(def.name, f, 10, 158, W - 20, "center", C.ink, { shadow = false })
    local ab = cards.ABILITIES[def.ability]
    gfx.textf(ab.name:upper(), theme.font("monoBold", 12), 10, 190, W - 20, "center", C.blue, { shadow = false })
    if def.ability ~= "none" then
      gfx.textf(ab.desc, theme.font("serif", 13), 16, 207, W - 32, "center", { 0.2, 0.25, 0.22 }, { shadow = false })
    else
      gfx.textf('"' .. def.flavor .. '"', theme.font("italic", 13), 16, 207, W - 32, "center", { 0.35, 0.4, 0.37 }, { shadow = false })
    end
    local meta = def.kind == "unit" and (def.type == "magic" and "MAGIC" or "PHYSICAL") or "SPECIAL"
    gfx.textf(meta .. " - " .. def.rarity:upper(), theme.font("mono", 10), 10, H - 24, W - 20, "center", { 0.4, 0.45, 0.42 }, { shadow = false })
  end

  if def.kind == "unit" then
    drawBadge(W - 28, 30, 16, def.type == "magic" and "orb" or "sword", C.black)
    if def.ability ~= "none" then drawBadge(W - 28, 66, 16, icons.ABILITY_ICON[def.ability], C.blueDark) end
    if def.coat ~= "none" then
      theme.set(C.paper); lg.circle("fill", 26, 76, 10)
      theme.set(cards.COATS[def.coat].color); lg.circle("fill", 26, 76, 7)
    end
  else
    drawBadge(30, 30, 20, icons.ABILITY_ICON[def.ability] or "star", C.blue)
  end
  if level > 1 then
    for i = 1, level - 1 do icons.draw("star", W - 26 - (i - 1) * 22, style == "compact" and H - 70 or 160, 22, C.gold) end
  end
  lg.pop()
  faceCache[key] = cv
  return cv
end
M.face = renderFace

local back
function M.back()
  if back then return back end
  back = lg.newCanvas(M.W, M.H)
  lg.push("all")
  lg.origin()
  lg.setCanvas(back)
  lg.clear(0, 0, 0, 0)
  theme.set(C.paper); lg.rectangle("fill", 0, 0, M.W, M.H, 18, 18)
  theme.set(C.red); lg.rectangle("fill", 8, 8, M.W - 16, M.H - 16, 13, 13)
  theme.set(C.redDark)
  for i = -12, 20 do lg.polygon("fill", 8 + i * 18, 8, 8 + i * 18 + 9, 8, 8 + i * 18 + 9 - 260, M.H - 8, 8 + i * 18 - 260, M.H - 8) end
  lg.setColor(1, 1, 1)
  local img = M.images and M.images.mascot
  if img then lg.draw(img, M.W / 2, M.H / 2, 0, 120 / img:getWidth(), 120 / img:getHeight(), img:getWidth() / 2, img:getHeight() / 2) end
  theme.set(C.paper); lg.setLineWidth(3); lg.rectangle("line", 16, 16, M.W - 32, M.H - 32, 10, 10); lg.setLineWidth(1)
  lg.pop()
  return back
end

-- ---------------------------------------------------------------- view objects

local View = {}
View.__index = View

local GRID = 4

function M.new(inst, x, y, scale)
  local def = cards.getDef(inst)
  local v = setmetatable({
    inst = inst, def = def, x = x, y = y, vx = 0, vy = 0, tx = x, ty = y, s = scale or 0.6, ts = scale or 0.6,
    rot = 0, trot = 0, tiltX = 0, tiltY = 0, flash = 0, alpha = 1, dying = nil, phase = love.math.random() * 6.28,
    style = "full", hovered = false, faceDown = false, z = 0,
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
  local k, damp = 170, 17
  local ax = (self.tx - self.x) * k - self.vx * damp
  local ay = (self.ty - self.y) * k - self.vy * damp
  self.vx, self.vy = self.vx + ax * dt, self.vy + ay * dt
  self.x, self.y = self.x + self.vx * dt, self.y + self.vy * dt
  self.s = self.s + (self.ts - self.s) * math.min(1, dt * 14)
  local lean = math.max(-0.25, math.min(0.25, self.vx / 4000))
  self.rot = self.rot + (self.trot + lean - self.rot) * math.min(1, dt * 12)
  self.flash = math.max(0, self.flash - dt * 2.2)
  if self.dying then self.dying = self.dying + dt * 1.3 end
  local tX, tY = 0, 0
  if self.hovered then
    local w, h = M.W * self.s, M.H * self.s
    local widgets = require("src.ui.widgets")
    tX = math.max(-1, math.min(1, (widgets.mx - self.x) / (w / 2)))
    tY = math.max(-1, math.min(1, (widgets.my - self.y) / (h / 2)))
  end
  self.tiltX = self.tiltX + (tX - self.tiltX) * math.min(1, dt * 10)
  self.tiltY = self.tiltY + (tY - self.tiltY) * math.min(1, dt * 10)
end

function View:contains(px, py)
  local w, h = M.W * self.s, M.H * self.s
  return px >= self.x - w / 2 and px <= self.x + w / 2 and py >= self.y - h / 2 and py <= self.y + h / 2
end

-- Project a point on the card (u, v in -0.5..0.5) through the tilt.
function View:project(u, v)
  local w, h = M.W * self.s, M.H * self.s
  local ay = self.tiltX * 0.35 + math.sin(love.timer.getTime() * 1.3 + self.phase) * 0.03
  local ax = -self.tiltY * 0.3 + math.cos(love.timer.getTime() * 1.1 + self.phase) * 0.025
  local x, y, z = u * w, v * h, 0
  local cy, sy = math.cos(ay), math.sin(ay)
  x, z = x * cy + z * sy, -x * sy + z * cy
  local cx, sx = math.cos(ax), math.sin(ax)
  y, z = y * cx - z * sx, y * sx + z * cx
  local f = 900
  local p = f / (f + z)
  x, y = x * p, y * p
  local cr, sr = math.cos(self.rot), math.sin(self.rot)
  return self.x + x * cr - y * sr, self.y + x * sr + y * cr
end

function View:draw(opts)
  opts = opts or {}
  local def = self.def
  local tex = self.faceDown and M.back() or renderFace(def, self.inst.level or 1, self.style)
  local alpha = self.alpha * (self.dying and 1 or 1)
  if self.dying and self.dying >= 1 then return end

  -- shadow
  local lift = (self.hovered and 1 or 0) * 10 + 6
  lg.setColor(0, 0, 0, 0.35 * alpha)
  lg.push()
  lg.translate(self.x + lift * 0.6, self.y + lift)
  lg.rotate(self.rot)
  lg.rectangle("fill", -M.W * self.s / 2, -M.H * self.s / 2, M.W * self.s, M.H * self.s, 16 * self.s, 16 * self.s)
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
    sh:send("t", math.min(1, self.dying))
    sh:send("edge", { 1.0, 0.55, 0.1 })
  elseif self.flash > 0 and shaders.flash then
    sh = shaders.flash
    sh:send("amount", self.flash)
  elseif def.rarity == "legendary" and not self.faceDown and shaders.foil then
    sh = shaders.foil
    sh:send("time", love.timer.getTime())
    sh:send("tilt", { self.tiltX, self.tiltY })
  end
  lg.setShader(sh)
  lg.setColor(1, 1, 1, alpha)
  lg.draw(self.mesh)
  lg.setShader()

  if self.faceDown or self.dying then return end
  -- dynamic power badge
  if def.kind == "unit" then
    local bx, by = self:project(-0.5 + 30 / M.W, -0.5 + 30 / M.H)
    local r = 24 * self.s / 0.6 * 0.62
    if self.style == "compact" then r = r * 1.25 end
    local p = opts.power or (def.power + cards.levelBonus(self.inst.level or 1))
    local base = def.power + cards.levelBonus(self.inst.level or 1)
    local bg = def.rarity == "legendary" and C.gold or C.black
    lg.setColor(0, 0, 0, 0.5 * alpha)
    lg.circle("fill", bx + 2, by + 3, r + 2)
    theme.set(C.paper, alpha)
    lg.circle("fill", bx, by, r + 2)
    theme.set(bg, alpha)
    lg.circle("fill", bx, by, r)
    local col = p > base and { 0.5, 1, 0.6 } or p < base and C.red or (def.rarity == "legendary" and C.black or C.paper)
    local pop = 1 + (self.powerPop or 0) * 0.5
    local font = theme.font("bold", math.max(12, math.floor(r * 1.25 * pop)))
    gfx.text(tostring(p), font, bx, by - font:getHeight() / 2 - 1, col, { align = "center", shadow = def.rarity == "legendary" and 0 or 2, alpha = alpha })
    if opts.advantage then
      local ax2, ay2 = self:project(-0.5 + 30 / M.W, -0.5 + 92 / M.H)
      icons.draw("up", ax2 + r * 0.9, ay2, r * 0.9, { 0.5, 1, 0.6, alpha })
    end
  end
  if opts.strayMark then
    local x1, y1 = self:project(0, 0.5)
    icons.draw("eye", x1, y1 - 10, 22, C.cyan)
  end
end

function View:updatePowerPop(p, dt)
  if self.lastPower and self.lastPower ~= p then self.powerPop = 1 end
  self.lastPower = p
  self.powerPop = math.max(0, (self.powerPop or 0) - dt * 3)
end

return M
