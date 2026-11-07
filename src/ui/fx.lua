-- Juice in virtual pixels: particles, popping numbers, banners, toasts, shake, flash.
local gfx = require("src.ui.gfx")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = { particles = {}, floats = {}, banners = {}, toasts = {}, medals = {}, shake = 0, flash = 0, time = 0 }
local C = theme.c

function M.reset()
  M.particles, M.floats, M.banners, M.toasts = {}, {}, {}, {}
  M.shake, M.flash = 0, 0
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

function M.float(x, y, text, color, big)
  M.floats[#M.floats + 1] = { x = x, y = y, text = text, color = color or C.paper, age = 0, life = 1.1, big = big }
end

-- color picks the plate: red, gold, blue or the black Power plate (default)
function M.banner(text, sub, color, delay, y)
  local plate = C.night
  if color == C.red then plate = C.red elseif color == C.gold then plate = C.goldDark elseif color == C.blue then plate = C.blue end
  M.banners[#M.banners + 1] = { text = text, sub = sub, plate = plate, age = -(delay or 0), life = 1.6, y = y }
end

function M.toast(text, kind)
  M.toasts[#M.toasts + 1] = { text = text, kind = kind or "info", age = 0, life = 3.2 }
  if #M.toasts > 3 then table.remove(M.toasts, 1) end
end

-- Feats and Renown levels: a medal slides in at the top right, one at a time. The queue
-- survives scene changes (M.reset leaves it alone).
function M.medal(title, desc, kind)
  M.medals[#M.medals + 1] = { title = title, desc = desc, kind = kind or "feat", age = 0, life = 3.4 }
  while #M.medals > 6 do table.remove(M.medals, 2) end
end

function M.addShake(a) M.shake = math.max(M.shake, a) end

function M.update(dt)
  M.time = M.time + dt
  M.shake = math.max(0, M.shake - dt * 14)
  M.flash = math.max(0, M.flash - dt * 2.5)
  for i = #M.particles, 1, -1 do
    local p = M.particles[i]
    p.age = p.age + dt
    p.vy = p.vy + 260 * dt
    p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
    if p.age > p.life then table.remove(M.particles, i) end
  end
  local m = M.medals[1]
  if m then
    m.age = m.age + dt
    if m.age > m.life then table.remove(M.medals, 1) end
  end
  for _, list in ipairs({ M.floats, M.banners, M.toasts }) do
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

function M.draw()
  for _, p in ipairs(M.particles) do
    local a = 1 - p.age / p.life
    lg.setColor(p.color[1], p.color[2], p.color[3], a)
    lg.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size)
  end
  for _, f in ipairs(M.floats) do
    local t = f.age / f.life
    -- numbers punch in: a size up for the first beat, then settle
    local font = f.big and theme.T.huge() or theme.T.body()
    if f.age < 0.07 then font = theme.font("bold", f.big and 27 or 14)
    elseif f.age < 0.14 then font = theme.font("bold", f.big and 22 or 12) end
    local pop = t < 0.12 and -3 or 0
    local a = t > 0.7 and (1 - (t - 0.7) / 0.3) or 1
    gfx.outlined(f.text, font, f.x, f.y - math.floor(t * 22) + pop, f.color, { align = "center", alpha = a })
  end
  for _, b in ipairs(M.banners) do
    if b.age >= 0 then
      -- a Figma title card slides across the screen
      local plates = require("src.ui.plates")
      local t = b.age / b.life
      local a = t > 0.8 and (1 - (t - 0.8) / 0.2) or 1
      local w, h = 360, 40
      local enter = math.min(1, b.age / 0.18)
      local slide = math.floor((1 - enter) ^ 3 * 420)
      local cy = b.y or 150
      local card = plates.titleCard(w, h, b.plate or C.night, { label = b.text, size = 28, streak = b.streak or 0.6, outline = C.black })
      theme.set(C.black, 0.5 * a)
      lg.rectangle("fill", theme.W / 2 - w / 2 + slide + 2, cy - h / 2 + 3, w, h)
      plates.draw(card, theme.W / 2 - w / 2 + slide, cy - h / 2, a)
      if b.sub then
        local sw = math.min(440, theme.T.body():getWidth(b.sub) + 16)
        gfx.panel(theme.W / 2 - sw / 2 - slide, cy + h / 2 + 4, sw, 20, C.deep, { alpha = a })
        gfx.text(b.sub, theme.T.body(), theme.W / 2 - slide, cy + h / 2 + 5, C.paper, { align = "center", alpha = a })
      end
    end
  end
  M.drawMedal()
  local y = 34
  for _, t in ipairs(M.toasts) do
    local a = math.min(1, t.age / 0.1) * (t.age > t.life - 0.3 and (t.life - t.age) / 0.3 or 1)
    local font = theme.T.body()
    local w = math.min(420, font:getWidth(t.text) + 16)
    local h = gfx.wrapHeight(t.text, font, w - 12) + 6
    local col = t.kind == "good" and C.goldDark or t.kind == "bad" and C.redDark or C.ink3
    local fg = C.paper
    local dy = math.floor((1 - math.min(1, t.age / 0.15)) * -8)
    gfx.panel(theme.W / 2 - w / 2, y + dy, w, h, col, { alpha = a })
    gfx.textf(t.text, font, theme.W / 2 - w / 2 + 6, y + dy + 2, w - 12, "center", fg, { alpha = a, shadow = false })
    y = y + h + 4
  end
end

function M.drawMedal()
  local m = M.medals[1]
  if not m then return end
  local icons = require("src.ui.icons")
  local level = m.kind == "level"
  local w = 214
  local font, small = theme.T.bold(), theme.T.small()
  local dh = gfx.wrapHeight(m.desc or "", small, w - 44)
  local h = math.max(34, 18 + dh + 4)
  local enter = math.min(1, m.age / 0.25)
  local leave = m.age > m.life - 0.3 and (m.life - m.age) / 0.3 or 1
  local slide = math.floor((1 - enter) ^ 3 * (w + 20) + (1 - leave) * (w + 20))
  local x, y = theme.W - w - 6 + slide, 6
  local edge = level and C.cyan or C.gold
  theme.set(C.black, 0.55)
  lg.rectangle("fill", x + 2, y + 3, w, h)
  theme.set(C.black)
  lg.rectangle("fill", x - 1, y - 1, w + 2, h + 2)
  theme.set(edge)
  lg.rectangle("fill", x, y, w, h)
  theme.set(level and C.blueDark or C.night)
  lg.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
  -- the medal, swinging in
  local swing = math.sin(m.age * 9) * math.max(0, 1 - m.age * 1.4) * 0.5
  icons.draw(level and "star" or "medal", x + 18, y + h / 2, edge, 2, swing)
  local label = level and "RENOWN" or "FEAT"
  gfx.text(label, theme.T.label(), x + 36, y + 3, level and C.cyan or C.goldText)
  local lw = theme.T.label():getWidth(label)
  gfx.text(m.title, font, x + 40 + lw, y + 1, C.white)
  gfx.textf(m.desc or "", small, x + 36, y + 16, w - 44, "left", C.paper2, { shadow = false })
  -- a shine sweeps across as it lands
  local sh = (m.age - 0.2) / 0.5
  if sh > 0 and sh < 1 then
    local sx = x + 8 + math.floor(sh * (w - 24))
    lg.setColor(1, 1, 1, 0.22)
    lg.polygon("fill", sx, y + 1, sx + 10, y + 1, sx + 4, y + h - 1, sx - 6, y + h - 1)
  end
end

return M
