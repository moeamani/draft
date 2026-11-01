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

function M.banner(text, sub, color, delay)
  M.banners[#M.banners + 1] = { text = text, sub = sub, color = color or C.paper, age = -(delay or 0), life = 1.5 }
end

function M.toast(text, kind)
  M.toasts[#M.toasts + 1] = { text = text, kind = kind or "info", age = 0, life = 2.8 }
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
    local font = f.big and theme.T.numL() or theme.T.num()
    local pop = t < 0.12 and -3 or 0
    local a = t > 0.7 and (1 - (t - 0.7) / 0.3) or 1
    gfx.outlined(f.text, font, f.x, f.y - math.floor(t * 22) + pop, f.color, { align = "center", alpha = a })
  end
  for _, b in ipairs(M.banners) do
    if b.age >= 0 then
      local t = b.age / b.life
      local open = math.min(1, b.age / 0.12)
      local a = t > 0.8 and (1 - (t - 0.8) / 0.2) or 1
      local h = math.floor(56 * open)
      local cy = 150
      lg.setColor(0.02, 0.03, 0.03, 0.9 * a)
      lg.rectangle("fill", 0, cy - h / 2, theme.W, h)
      theme.set(b.color, a)
      lg.rectangle("fill", 0, cy - h / 2, theme.W, 1)
      lg.rectangle("fill", 0, cy + h / 2 - 1, theme.W, 1)
      if open >= 1 then
        local slide = math.floor((1 - math.min(1, (b.age - 0.12) / 0.2)) ^ 3 * 120)
        gfx.wavy(b.text, theme.T.head(), theme.W / 2 + slide, cy - 20, b.color, M.time, 1, { alpha = a })
        if b.sub then gfx.text(b.sub:upper(), theme.T.tiny(), theme.W / 2 - slide, cy + 12, C.gold, { align = "center", alpha = a }) end
      end
    end
  end
  local y = 30
  for _, t in ipairs(M.toasts) do
    local a = math.min(1, t.age / 0.1) * (t.age > t.life - 0.3 and (t.life - t.age) / 0.3 or 1)
    local font = theme.T.body()
    local w = math.min(420, font:getWidth(t.text) + 14)
    local h = gfx.wrapHeight(t.text, font, w - 10) + 7
    local col = t.kind == "good" and C.gold or t.kind == "bad" and C.red or C.paper
    local fg = t.kind == "bad" and C.paper or C.ink
    local dy = math.floor((1 - math.min(1, t.age / 0.15)) * -8)
    gfx.panel(theme.W / 2 - w / 2, y + dy, w, h, col, { alpha = a })
    gfx.textf(t.text, font, theme.W / 2 - w / 2 + 5, y + dy + 3, w - 10, "center", fg, { alpha = a, shadow = false })
    y = y + h + 4
  end
end

return M
