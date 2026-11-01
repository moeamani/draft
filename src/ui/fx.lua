-- Juice: particles, floating numbers, banners, toasts, screen shake, flashes.
local gfx = require("src.ui.gfx")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = { particles = {}, floats = {}, banners = {}, toasts = {}, shake = 0, flash = 0, time = 0 }

function M.reset()
  M.particles, M.floats, M.banners, M.toasts = {}, {}, {}, {}
  M.shake, M.flash = 0, 0
end

function M.burst(x, y, color, n, speed, size)
  for _ = 1, n or 14 do
    local a = love.math.random() * math.pi * 2
    local v = (speed or 260) * (0.3 + love.math.random() * 0.9)
    M.particles[#M.particles + 1] = {
      x = x, y = y, vx = math.cos(a) * v, vy = math.sin(a) * v - 80, life = 0.6 + love.math.random() * 0.5, age = 0,
      size = (size or 6) * (0.5 + love.math.random()), color = color, rot = love.math.random() * 6, vr = (love.math.random() - 0.5) * 12,
    }
  end
end

function M.float(x, y, text, color, size)
  M.floats[#M.floats + 1] = { x = x, y = y, text = text, color = color or theme.c.paper, age = 0, life = 1.3, size = size or 30 }
end

function M.banner(text, sub, color, delay)
  M.banners[#M.banners + 1] = { text = text, sub = sub, color = color or theme.c.paper, age = -(delay or 0), life = 1.6 }
end

function M.toast(text, kind)
  M.toasts[#M.toasts + 1] = { text = text, kind = kind or "info", age = 0, life = 3.0 }
end

function M.addShake(a) M.shake = math.max(M.shake, a) end

function M.update(dt)
  M.time = M.time + dt
  M.shake = math.max(0, M.shake - dt * 30)
  M.flash = math.max(0, M.flash - dt * 2.5)
  for i = #M.particles, 1, -1 do
    local p = M.particles[i]
    p.age = p.age + dt
    p.vy = p.vy + 700 * dt
    p.vx = p.vx * (1 - dt * 1.5)
    p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
    p.rot = p.rot + p.vr * dt
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
  if M.shake <= 0 then return 0, 0 end
  return (love.math.random() - 0.5) * M.shake * 2, (love.math.random() - 0.5) * M.shake * 2
end

local function easeOutBack(t)
  local c1, c3 = 1.70158, 2.70158
  return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

function M.draw()
  for _, p in ipairs(M.particles) do
    local a = 1 - p.age / p.life
    lg.setColor(p.color[1], p.color[2], p.color[3], a)
    lg.push()
    lg.translate(p.x, p.y)
    lg.rotate(p.rot)
    lg.rectangle("fill", -p.size / 2, -p.size / 2, p.size, p.size)
    lg.pop()
  end
  for _, f in ipairs(M.floats) do
    local t = f.age / f.life
    local s = t < 0.25 and easeOutBack(t / 0.25) or 1
    local font = theme.font("bold", f.size)
    lg.push()
    lg.translate(f.x, f.y - t * 70)
    lg.scale(s, s)
    gfx.text(f.text, font, 0, -font:getHeight() / 2, f.color, { align = "center", alpha = 1 - math.max(0, t - 0.6) / 0.4, shadow = 3 })
    lg.pop()
  end
  for _, b in ipairs(M.banners) do
    if b.age >= 0 then
      local t = b.age / b.life
      local open = math.min(1, b.age / 0.18)
      local alpha = t > 0.8 and (1 - (t - 0.8) / 0.2) or 1
      local h = 150 * open
      lg.setColor(0.02, 0.03, 0.03, 0.85 * alpha)
      lg.rectangle("fill", 0, 375 - h / 2, theme.W, h)
      theme.set(b.color, alpha)
      lg.rectangle("fill", 0, 375 - h / 2, theme.W, 4)
      lg.rectangle("fill", 0, 375 + h / 2 - 4, theme.W, 4)
      if open >= 1 then
        local slide = (1 - math.min(1, (b.age - 0.18) / 0.25)) ^ 3 * 300
        gfx.wavy(b.text, theme.font("bold", 76), theme.W / 2 + slide, 318, b.color, M.time, 3, { alpha = alpha })
        if b.sub then gfx.text(b.sub:upper(), theme.font("monoBold", 18), theme.W / 2 - slide, 410, theme.c.gold, { align = "center", alpha = alpha, shadow = 0 }) end
      end
    end
  end
  local y = 90
  for _, t in ipairs(M.toasts) do
    local a = math.min(1, t.age / 0.15) * (t.age > t.life - 0.4 and (t.life - t.age) / 0.4 or 1)
    local font = theme.font("serif", 22)
    local w = font:getWidth(t.text) + 44
    local col = t.kind == "good" and theme.c.gold or t.kind == "bad" and theme.c.red or theme.c.paper
    local fg = t.kind == "bad" and theme.c.paper or theme.c.ink
    local dy = (1 - math.min(1, t.age / 0.2)) * -20
    gfx.panel(theme.W / 2 - w / 2, y + dy, w, 44, col, { r = 22, alpha = a, depth = 4, sheen = false })
    gfx.text(t.text, font, theme.W / 2, y + dy + 9, fg, { align = "center", alpha = a, shadow = 0 })
    y = y + 54
  end
end

return M
