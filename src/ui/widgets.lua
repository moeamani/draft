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

local function labelSize(h, hint)
  if hint == "huge" then return 16 end
  if h >= 34 then return 14 elseif h >= 28 then return 12.5 elseif h >= 22 then return 11 end
  return 10
end

-- The largest Atkinson Bold size (down to 8) at which str fits in width.
local function fitBold(str, size, width)
  while size > 8 and theme.font("bold", size):getWidth(str) > width do size = size - 0.5 end
  return size
end
M.fitBold = fitBold

-- The one button style: a flat plate on a darker lip with a bold, high-contrast label.
-- opts: color, sub, disabled, size ("huge" for the big call-to-action), icon, iconColor,
--       textColor, focused (keyboard / controller selection)
function M.button(id, x, y, w, h, label, opts)
  opts = opts or {}
  local plates = require("src.ui.plates")
  local s = st(id)
  local clicked, over = M.click(id, x, y, w, h)
  if opts.disabled then clicked = false end
  s.over = (over or opts.focused) and not opts.disabled
  s.down = s.over and over and M.down
  if s.over and not s.wasOver and over then sfx.play("hover", 1, 0.4) end
  s.wasOver = s.over
  if clicked then sfx.play("click") end
  local col = opts.color or C.ink3
  if opts.disabled then col = C.ink2 elseif s.hover > 0.5 then col = theme.shade(col, 0.12) end
  x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
  local press = s.down and 2 or 0
  theme.set(C.black, 0.5)
  lg.rectangle("fill", x + 1, y + 3, w, h)
  plates.draw(plates.plate(w, h, theme.shade(col, -0.45)), x, y + 2)
  local by = y + press
  plates.draw(plates.plate(w, h, col), x, by)
  if opts.focused and not opts.disabled then
    theme.set(C.goldText)
    lg.rectangle("line", x - 1.5, by - 1.5, w + 3, h + 3)
  end
  local tc = opts.disabled and C.muted or (opts.textColor or C.white)
  local font = theme.font("bold", fitBold(label, labelSize(opts.sub and h - 10 or h, opts.size), w - 10 - (opts.icon and 14 or 0)))
  local fh = font:getHeight()
  if opts.sub then
    local sf = theme.T.small()
    local total = fh + sf:getHeight() - 1
    local ty = by + (h - total) / 2
    gfx.text(label, font, x + w / 2, ty, tc, { align = "center", bg = col })
    gfx.text(opts.sub, sf, x + w / 2, ty + fh - 1, opts.disabled and C.muted or C.paper2, { align = "center", bg = col })
  else
    local ty = by + (h - fh) / 2
    local tx = x + w / 2
    if opts.icon then
      local tw = font:getWidth(label) + 14
      tx = tx + 7
      require("src.ui.icons").draw(opts.icon, math.floor(x + w / 2 - tw / 2 + 4), math.floor(by + h / 2), opts.iconColor or C.paper)
    end
    gfx.text(label, font, tx, ty, tc, { align = "center", bg = col })
  end
  return clicked
end

-- A clickable choice card: a title and a wrapped, readable description.
-- opts: color, icon, iconColor, disabled, titleColor, focused
function M.choice(id, x, y, w, h, title, desc, opts)
  opts = opts or {}
  local s = st(id)
  local clicked, over = M.click(id, x, y, w, h)
  if opts.disabled then clicked = false end
  s.over = (over or opts.focused) and not opts.disabled
  if s.over and not s.wasOver and over then sfx.play("hover", 1, 0.4) end
  s.wasOver = s.over
  if clicked then sfx.play("click") end
  local lift = s.hover > 0.5 and 2 or 0
  local col = opts.color or C.ink2
  if opts.disabled then col = C.deep elseif s.hover > 0.5 then col = theme.shade(col, 0.08) end
  local by = y - lift
  gfx.panel(x, by, w, h, col)
  if opts.focused and not opts.disabled then
    theme.set(C.goldText)
    lg.rectangle("line", x - 1.5, by - 1.5, w + 3, h + 3)
  end
  local tx = x + 8
  if opts.icon then
    require("src.ui.icons").draw(opts.icon, x + 15, by + 13, opts.disabled and C.muted or (opts.iconColor or C.gold), 2)
    tx = x + 28
  end
  local tf = theme.font("bold", fitBold(title, 12, w - (tx - x) - 8))
  gfx.text(title, tf, tx, by + 5, opts.disabled and C.muted or (opts.titleColor or C.white), { bg = col })
  if desc then gfx.textf(desc, theme.T.body(), x + 8, by + 22, w - 16, "left", opts.disabled and C.muted or C.paper2, { bg = col }) end
  return clicked
end

function M.tooltip(fn) M.tooltipFn = fn end
function M.drawTooltip() if M.tooltipFn then M.tooltipFn() end end

-- lines: { {text=, font=, color=, gap=} ... }; img (optional): a picture shown above the text
function M.infoBox(x, y, w, lines, img)
  local pad = 6
  local h = pad
  local iw, ih = 0, 0
  if img then iw, ih = img:getDimensions(); h = h + ih + 4 end
  local hs = {}
  for i, l in ipairs(lines) do
    local font = l.font or theme.T.body()
    hs[i] = gfx.wrapHeight(l.text, font, w - pad * 2) + (l.gap or 2)
    h = h + hs[i]
  end
  h = h + pad - 2
  x = math.floor(math.max(2, math.min(theme.W - w - 2, x)))
  y = math.floor(math.max(2, math.min(theme.H - h - 2, y)))
  gfx.panel(x, y, w, h, C.deep)
  local cy = y + pad
  if img then
    local ix = math.floor(x + (w - iw) / 2)
    gfx.box(ix - 1, cy - 1, iw + 2, ih + 2, C.black)
    require("src.ui.plates").draw(img, ix, cy)
    cy = cy + ih + 4
  end
  for i, l in ipairs(lines) do
    gfx.textf(l.text, l.font or theme.T.body(), x + pad, cy, w - pad * 2, l.align or "left", l.color or C.paper, { bg = C.deep })
    cy = cy + hs[i]
  end
  return x, y, w, h
end

return M
