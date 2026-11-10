-- Juice, in virtual pixels: particles, popping numbers and tags, banners, toasts, the ledger's
-- stamps, screen shake, the colour-fringe punch and the pulse that swells the backdrop's dots.
local audio = require("src.audio")
local gfx = require("src.ui.gfx")
local plates = require("src.ui.plates")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {
  particles = {}, floats = {}, tags = {}, banners = {}, toasts = {}, stamps = {},
  shake = 0, punch = 0, time = 0, pulse = nil,
}
local C = theme.c

-- Scene changes clear the table's effects; the stamp queue survives them.
function M.reset()
  M.particles, M.floats, M.tags, M.banners, M.toasts = {}, {}, {}, {}, {}
  M.shake, M.punch, M.pulse = 0, 0, nil
end

function M.burst(x, y, color, n, speed)
  for _ = 1, n or 12 do
    local a = love.math.random() * math.pi * 2
    local v = (speed or 90) * (0.3 + love.math.random() * 0.9)
    M.particles[#M.particles + 1] = {
      x = x, y = y, vx = math.cos(a) * v, vy = math.sin(a) * v - 30, life = 0.5 + love.math.random() * 0.5, age = 0,
      size = love.math.random() < 0.3 and 2 or 1, color = color,
    }
  end
end

-- A number or word that pops and drifts up. big uses the headline size.
function M.float(x, y, text, color, big)
  M.floats[#M.floats + 1] = { x = x, y = y, text = text, color = color or C.paper, age = 0, life = 1.1, big = big }
end

-- A tag: a small coloured plate that pops in, tilted, and drifts up ("+3 Coat edge").
function M.tag(x, y, text, color, delay)
  M.tags[#M.tags + 1] = { x = x, y = y, text = text, color = color or C.ink3, age = -(delay or 0), life = 1.25,
    rot = (love.math.random() - 0.5) * 0.16 }
end

-- A sign that slides across the screen. color picks the plate: red, gold, blue, or black.
function M.banner(text, sub, color, delay, y)
  local plate = C.night
  if color == C.red then plate = C.red elseif color == C.gold then plate = C.goldDark elseif color == C.blue then plate = C.blue end
  M.banners[#M.banners + 1] = { text = text, sub = sub, plate = plate, age = -(delay or 0), life = 1.7, y = y }
end

function M.toast(text, kind)
  M.toasts[#M.toasts + 1] = { text = text, kind = kind or "info", age = 0, life = 3.2 }
  if #M.toasts > 3 then table.remove(M.toasts, 1) end
end

-- The Overseer stamps the ledger: a feat (red ink) or a Renown level (blue ink). One at a time.
function M.stamp(title, desc, kind)
  M.stamps[#M.stamps + 1] = { title = title, desc = desc, kind = kind or "feat", age = 0, life = 3.6 }
  while #M.stamps > 6 do table.remove(M.stamps, 2) end
end
M.medal = M.stamp

function M.addShake(a) M.shake = math.max(M.shake, a) end

-- A burst of colour fringe through the CRT (0..1), for the biggest hits.
function M.addPunch(a) M.punch = math.max(M.punch, a) end
function M.punchAmount() return M.punch end

-- A ring that travels out from (x, y) through the backdrop's halftone, swelling its dots.
function M.addPulse(x, y, strength)
  M.pulse = { x = x, y = y, age = 0, strength = strength or 0.5 }
end
function M.pulseUniform()
  local p = M.pulse
  if not p then return nil end
  local t = p.age / 0.8
  return { p.x, p.y, 10 + t * 300, p.strength * (1 - t) ^ 1.5 }
end

function M.update(dt)
  M.time = M.time + dt
  M.shake = math.max(0, M.shake - dt * 14)
  M.punch = math.max(0, M.punch - dt * 3.2)
  if M.pulse then
    M.pulse.age = M.pulse.age + dt
    if M.pulse.age >= 0.8 then M.pulse = nil end
  end
  for i = #M.particles, 1, -1 do
    local p = M.particles[i]
    p.age = p.age + dt
    p.vy = p.vy + 260 * dt
    p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
    if p.age > p.life then table.remove(M.particles, i) end
  end
  local s = M.stamps[1]
  if s then
    local before = s.age
    s.age = s.age + dt
    if before < 0.3 and s.age >= 0.3 then -- the stamp lands
      audio.play("stamp")
      M.addShake(3)
    end
    if s.age > s.life then table.remove(M.stamps, 1) end
  end
  for _, list in ipairs({ M.floats, M.tags, M.banners, M.toasts }) do
    for i = #list, 1, -1 do
      list[i].age = list[i].age + dt
      if list[i].age > list[i].life then table.remove(list, i) end
    end
  end
end

function M.shakeOffset()
  if M.shake <= 0.3 then return 0, 0 end
  return math.floor((love.math.random() - 0.5) * M.shake * 2 + 0.5), math.floor((love.math.random() - 0.5) * M.shake * 2 + 0.5)
end

local function outBack(t)
  local c = 1.70158
  t = t - 1
  return 1 + (c + 1) * t * t * t + c * t * t
end

local function drawTags()
  local font = theme.T.bold()
  for _, g in ipairs(M.tags) do
    if g.age >= 0 then
      local t = g.age / g.life
      local pop = g.age < 0.14 and outBack(g.age / 0.14) or 1
      local a = t > 0.75 and (1 - (t - 0.75) / 0.25) or 1
      local w = math.ceil(font:getWidth(g.text)) + 10
      local y = g.y - t * 14
      lg.push()
      lg.translate(math.floor(g.x), math.floor(y))
      lg.rotate(g.rot)
      lg.scale(pop, pop)
      theme.set(C.black, 0.4 * a)
      plates.rounded(-w / 2, -7 + 2, w, 15, 2)
      plates.draw(plates.plate(w, 15, g.color, { lip = 2 }), -w / 2, -7, a)
      gfx.text(g.text, font, 0, -7, theme.luminance(g.color) > 0.3 and C.black or C.white, { align = "center", alpha = a, raw = true })
      lg.pop()
    end
  end
end

local function drawStamp()
  local s = M.stamps[1]
  if not s then return end
  local level = s.kind == "level"
  local ink = level and C.stampBlue or C.stamp
  local w = 196
  local small = theme.T.small()
  local dh = gfx.wrapHeight(s.desc or "", small, w - 50)
  local h = math.max(46, 30 + dh + 5)
  local enter = math.min(1, s.age / 0.22)
  local leave = s.age > s.life - 0.3 and (s.life - s.age) / 0.3 or 1
  local slide = math.floor((1 - outBack(enter)) * (w + 20) + (1 - leave) * (w + 20))
  local x, y = theme.W - w - 6 + slide, 6
  -- the slip: a page torn from the ledger
  theme.set(C.black, 0.45)
  plates.rounded(x + 1, y + 3, w, h, 2)
  plates.draw(plates.plate(w, h, C.cream, { outline = C.cream3 }), x, y)
  theme.set(C.cream2)
  for ry = y + 12, y + h - 4, 9 do lg.rectangle("fill", x + 4, ry, w - 8, 1) end
  -- the Overseer, who keeps the ledger, looks up from the corner
  require("src.ui.overseer").face(x + 3, y + 3, 34, h - 6, M.time)
  gfx.text(level and "THE OVERSEER IS AMUSED" or "THE OVERSEER NOTES", theme.T.label(), x + 42, y + 3, C.inkMuted, { bg = C.cream })
  gfx.textf(s.desc or "", small, x + 42, y + 27, w - 48, "left", C.inkText, { bg = C.cream })
  -- the stamp: slams down a moment after the slip arrives
  if s.age >= 0.3 then
    local k = math.min(1, (s.age - 0.3) / 0.09)
    local scale = 1.9 - 0.9 * k
    local font = theme.T.big()
    local name = s.title:upper()
    if font:getWidth(name) > w - 58 then font = theme.T.bold() end
    local tw = math.ceil(font:getWidth(name)) + 12
    lg.push()
    lg.translate(x + 42 + tw / 2, y + 19)
    lg.rotate(-0.05)
    lg.scale(scale, scale)
    theme.set(ink, 0.9 * k)
    lg.setLineWidth(2)
    lg.rectangle("line", -tw / 2, -8, tw, 17)
    lg.setLineWidth(1)
    gfx.text(name, font, 0, -8 + (17 - font:getHeight()) / 2, ink, { align = "center", alpha = k, raw = true })
    lg.pop()
  end
end
M.drawStamp = drawStamp

function M.draw()
  for _, p in ipairs(M.particles) do
    local a = 1 - p.age / p.life
    lg.setColor(p.color[1], p.color[2], p.color[3], a)
    lg.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size)
  end
  drawTags()
  for _, f in ipairs(M.floats) do
    local t = f.age / f.life
    -- numbers punch in: a size up for the first beat, then settle
    local font = f.big and theme.T.huge() or theme.T.bold()
    if f.age < 0.07 then font = theme.font("bold", f.big and 27 or 13)
    elseif f.age < 0.14 then font = theme.font("bold", f.big and 22 or 12) end
    local a = t > 0.7 and (1 - (t - 0.7) / 0.3) or 1
    gfx.outlined(f.text, font, f.x, f.y - math.floor(t * 22) - (t < 0.12 and 3 or 0), f.color, { align = "center", alpha = a })
  end
  for _, b in ipairs(M.banners) do
    if b.age >= 0 then
      local t = b.age / b.life
      local a = t > 0.85 and (1 - (t - 0.85) / 0.15) or 1
      local w, h = 340, 44
      local slide = math.floor((1 - outBack(math.min(1, b.age / 0.22))) * 420)
      local cy = b.y or 150
      local sign = plates.titleCard(w, h, b.plate or C.night, { label = b.text, size = 30 })
      theme.set(C.black, 0.45 * a)
      plates.rounded(theme.W / 2 - w / 2 + slide, cy - h / 2 + 3, w, h, 2)
      plates.draw(sign, theme.W / 2 - w / 2 + slide, cy - h / 2, a)
      if b.sub then
        local sw = math.min(440, theme.T.body():getWidth(b.sub) + 20)
        gfx.panel(theme.W / 2 - sw / 2 - slide, cy + h / 2 + 5, sw, 20, C.deep, { alpha = a })
        gfx.text(b.sub, theme.T.body(), theme.W / 2 - slide, cy + h / 2 + 9, C.paper, { align = "center", alpha = a, bg = C.deep })
      end
    end
  end
  drawStamp()
  local y = 34
  for _, t in ipairs(M.toasts) do
    local a = math.min(1, t.age / 0.1) * (t.age > t.life - 0.3 and (t.life - t.age) / 0.3 or 1)
    local font = theme.T.body()
    local w = math.min(420, font:getWidth(t.text) + 20)
    local h = gfx.wrapHeight(t.text, font, w - 16) + 9
    local col = t.kind == "good" and C.goldDark or t.kind == "bad" and C.redDark or C.ink3
    local dy = math.floor((1 - math.min(1, t.age / 0.15)) * -8)
    gfx.panel(theme.W / 2 - w / 2, y + dy, w, h, col, { alpha = a })
    gfx.textf(t.text, font, theme.W / 2 - w / 2 + 8, y + dy + 4, w - 16, "center", C.paper, { alpha = a, bg = col })
    y = y + h + 5
  end
end

return M
