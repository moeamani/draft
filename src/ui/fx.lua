-- Juice in virtual pixels: particles, popping numbers, banners, toasts, shake, flash.
local gfx = require("src.ui.gfx")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = { particles = {}, floats = {}, banners = {}, toasts = {}, shake = 0, flash = 0, time = 0 }
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
    local font = f.big and theme.T.huge() or theme.T.body()
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

return M
