-- Immediate-mode pixel widgets with springy hover/press.
local gfx = require("src.ui.gfx")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {
  mx = 0, my = 0, pressed = false, released = false, down = false,
  layer = "scene", top = "scene", state = {}, tooltipFn = nil, pressId = nil,
}
local C = theme.c

function M.beginFrame(mx, my)
  M.mx, M.my = mx, my
  M.tooltipFn = nil
end

function M.endFrame()
  M.pressed, M.released = false, false
end

function M.inside(x, y, w, h)
  return M.layer == M.top and M.mx >= x and M.mx < x + w and M.my >= y and M.my < y + h
end

function M.click(id, x, y, w, h)
  local over = M.inside(x, y, w, h)
  if over and M.pressed then M.pressId = id end
  local clicked = over and M.released and M.pressId == id
  if clicked then M.pressId = nil end
  return clicked, over
end

local function st(id)
  local s = M.state[id]
  if not s then
    s = { hover = 0, press = 0, wasOver = false }
    M.state[id] = s
  end
  return s
end

function M.updateStates(dt)
  for _, s in pairs(M.state) do
    s.hover = s.hover + ((s.over and 1 or 0) - s.hover) * math.min(1, dt * 18)
    s.press = s.press + ((s.down and 1 or 0) - s.press) * math.min(1, dt * 30)
    s.over, s.down = false, false
  end
end

-- The one button style. opts: color, sub, disabled, font, icon
function M.button(id, x, y, w, h, label, opts)
  opts = opts or {}
  local s = st(id)
  local clicked, over = M.click(id, x, y, w, h)
  if opts.disabled then clicked = false end
  s.over = over and not opts.disabled
  s.down = s.over and M.down
  if s.over and not s.wasOver then sfx.play("hover", 1, 0.4) end
  s.wasOver = s.over
  if clicked then sfx.play("click") end
  local col = opts.color or C.ink3
  if opts.disabled then col = theme.mix(col, C.ink, 0.6) end
  local press = math.floor(s.press * 2 + 0.5)
  local lift = math.floor(s.hover + 0.5)
  local bx, by = math.floor(x), math.floor(y) - lift + press
  -- base (the "depth" of the button)
  gfx.box(x, y + 3, w, h, C.black, 0.6)
  gfx.box(x, y + 2, w, h, C.black)
  gfx.box(x + 1, y + 2, w - 2, h - 1, theme.darken(col, 0.55))
  -- face
  gfx.box(bx, by, w, h, C.black)
  gfx.box(bx + 1, by + 1, w - 2, h - 2, s.hover > 0.5 and theme.mix(col, C.paper, 0.12) or col)
  theme.set(theme.mix(col, C.paper, 0.3))
  lg.rectangle("fill", bx + 2, by + 1, w - 4, 1)
  local tc = opts.disabled and C.muted or (opts.textColor or C.paper)
  local font = opts.font or theme.T.big()
  if opts.sub then
    local fh = font:getHeight()
    local sf = theme.T.small()
    local total = fh + sf:getHeight() + 1
    local ty = by + math.floor((h - total) / 2)
    gfx.text(label, font, bx + w / 2, ty, tc, { align = "center" })
    gfx.text(opts.sub, sf, bx + w / 2, ty + fh + 1, opts.disabled and C.muted or theme.mix(tc, col, 0.25), { align = "center" })
  else
    local ty = by + math.floor((h - font:getHeight()) / 2)
    local tx = bx + w / 2
    if opts.icon then
      local tw = font:getWidth(label) + 12
      tx = tx + 6
      require("src.ui.icons").draw(opts.icon, bx + w / 2 - tw / 2 + 4, by + h / 2, opts.iconColor or C.paper)
    end
    gfx.text(label, font, tx, ty, tc, { align = "center" })
  end
  return clicked
end

-- A clickable choice card: a title and a wrapped, readable description.
-- opts: color, icon, iconColor, disabled, border, titleColor
function M.choice(id, x, y, w, h, title, desc, opts)
  opts = opts or {}
  local s = st(id)
  local clicked, over = M.click(id, x, y, w, h)
  if opts.disabled then clicked = false end
  s.over = over and not opts.disabled
  if s.over and not s.wasOver then sfx.play("hover", 1, 0.4) end
  s.wasOver = s.over
  if clicked then sfx.play("click") end
  local lift = math.floor(s.hover * 2 + 0.5)
  local col = opts.color or C.ink2
  if opts.disabled then col = C.deep elseif s.hover > 0.5 then col = theme.mix(col, C.paper, 0.1) end
  local by = y - lift
  gfx.panel(x, by, w, h, col, { border = opts.disabled and C.ink3 or (opts.border or C.goldDark) })
  local tx = x + 9
  if opts.icon then
    require("src.ui.icons").draw(opts.icon, x + 16, by + 17, opts.disabled and C.muted or (opts.iconColor or C.gold), 2)
    tx = x + 32
  end
  gfx.text(title, theme.T.big(), tx, by + 5, opts.disabled and C.muted or (opts.titleColor or C.paper))
  if desc then gfx.textf(desc, theme.T.body(), x + 9, by + 30, w - 18, "left", opts.disabled and C.muted or C.paper2) end
  return clicked
end

function M.tooltip(fn) M.tooltipFn = fn end
function M.drawTooltip() if M.tooltipFn then M.tooltipFn() end end

-- lines: { {text=, font=, color=, gap=} ... }
function M.infoBox(x, y, w, lines)
  local pad = 6
  local h = pad
  local hs = {}
  for i, l in ipairs(lines) do
    local font = l.font or theme.T.body()
    hs[i] = gfx.wrapHeight(l.text, font, w - pad * 2) + (l.gap or 2)
    h = h + hs[i]
  end
  h = h + pad - 2
  x = math.floor(math.max(2, math.min(theme.W - w - 2, x)))
  y = math.floor(math.max(2, math.min(theme.H - h - 2, y)))
  gfx.panel(x, y, w, h, C.deep, { border = lines.border or C.goldDark })
  local cy = y + pad
  for i, l in ipairs(lines) do
    gfx.textf(l.text, l.font or theme.T.body(), x + pad, cy, w - pad * 2, l.align or "left", l.color or C.paper, { shadow = l.shadow })
    cy = cy + hs[i]
  end
  return x, y, w, h
end

return M
