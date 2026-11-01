-- Immediate-mode widgets with springy hover/press states.
local gfx = require("src.ui.gfx")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {
  mx = 0, my = 0, pressed = false, released = false, down = false,
  layer = "scene", top = "scene", state = {}, tooltipFn = nil, hot = nil, pressId = nil,
}

function M.beginFrame(mx, my)
  M.mx, M.my = mx, my
  M.hot = nil
  M.tooltipFn = nil
end

function M.endFrame()
  M.pressed, M.released = false, false
end

function M.inside(x, y, w, h)
  return M.layer == M.top and M.mx >= x and M.mx <= x + w and M.my >= y and M.my <= y + h
end

function M.click(id, x, y, w, h)
  local over = M.inside(x, y, w, h)
  if over then M.hot = id end
  if over and M.pressed then M.pressId = id end
  local clicked = over and M.released and M.pressId == id
  if clicked then M.pressId = nil end
  return clicked, over
end

local function st(id)
  local s = M.state[id]
  if not s then
    s = { hover = 0, wasOver = false, press = 0 }
    M.state[id] = s
  end
  return s
end

function M.updateStates(dt)
  for _, s in pairs(M.state) do
    s.hover = s.hover + ((s.over and 1 or 0) - s.hover) * math.min(1, dt * 14)
    s.press = s.press + ((s.down and 1 or 0) - s.press) * math.min(1, dt * 25)
    s.over, s.down = false, false
  end
end

-- opts: color, size, sub, disabled, font
function M.button(id, x, y, w, h, label, opts)
  opts = opts or {}
  local s = st(id)
  local clicked, over = M.click(id, x, y, w, h)
  if opts.disabled then clicked = false end
  s.over = over and not opts.disabled
  s.down = s.over and M.down
  if s.over and not s.wasOver then sfx.play("hover", 1, 0.5) end
  s.wasOver = s.over
  if clicked then sfx.play("click") end

  local col = opts.color or theme.c.ink3
  local depth = 7
  local press = s.press * 5
  local hs = 1 + s.hover * 0.04
  local wob = s.hover * math.sin(love.timer.getTime() * 9) * 0.012
  local cx, cy = x + w / 2, y + h / 2
  lg.push()
  lg.translate(cx, cy + press)
  lg.rotate(wob)
  lg.scale(hs, hs)
  local a = opts.disabled and 0.4 or 1
  lg.setColor(0, 0, 0, 0.45 * a)
  lg.rectangle("fill", -w / 2, -h / 2 + depth - press, w, h, 12, 12)
  local dark = { col[1] * 0.62, col[2] * 0.62, col[3] * 0.62 }
  theme.set(dark, a)
  lg.rectangle("fill", -w / 2, -h / 2 + depth - press - 2, w, h, 12, 12)
  theme.set(theme.mix(col, theme.c.paper, s.hover * 0.12), a)
  lg.rectangle("fill", -w / 2, -h / 2, w, h, 12, 12)
  lg.setColor(1, 1, 1, 0.09 * a)
  lg.rectangle("fill", -w / 2 + 5, -h / 2 + 4, w - 10, h * 0.32, 8, 8)
  local font = opts.font or theme.font("bold", opts.size or 26)
  if opts.sub then
    local sf = theme.font("serif", 16)
    gfx.text(label, font, 0, -h / 2 + h * 0.18, opts.textColor or theme.c.paper, { align = "center", alpha = a })
    gfx.textf(opts.sub, sf, -w / 2 + 10, -h / 2 + h * 0.18 + font:getHeight() + 2, w - 20, "center", { 1, 1, 1, 0.75 }, { alpha = a, shadow = false })
  else
    gfx.text(label, font, 0, -font:getHeight() / 2 - 2, opts.textColor or theme.c.paper, { align = "center", alpha = a })
  end
  lg.pop()
  return clicked
end

function M.tooltip(fn) M.tooltipFn = fn end

function M.drawTooltip()
  if M.tooltipFn then M.tooltipFn() end
end

-- A rounded info box near (x, y) that stays on screen.
function M.infoBox(x, y, w, lines)
  local pad = 16
  local h = pad
  local measured = {}
  for _, l in ipairs(lines) do
    local font = l.font or theme.font("serif", 18)
    local _, wrapped = font:getWrap(l.text, w - pad * 2)
    local lh = #wrapped * font:getHeight() * font:getLineHeight() + (l.gap or 6)
    measured[#measured + 1] = lh
    h = h + lh
  end
  h = h + pad - 6
  x = math.max(10, math.min(theme.W - w - 10, x))
  y = math.max(10, math.min(theme.H - h - 10, y))
  gfx.panel(x, y, w, h, { 0.03, 0.06, 0.05, 0.96 }, { border = lines.border or theme.c.paper2, lw = 2, r = 12, depth = 6 })
  local cy = y + pad
  for i, l in ipairs(lines) do
    gfx.textf(l.text, l.font or theme.font("serif", 18), x + pad, cy, w - pad * 2, l.align or "left", l.color or theme.c.paper, { shadow = false })
    cy = cy + measured[i]
  end
  return x, y, w, h
end

return M
