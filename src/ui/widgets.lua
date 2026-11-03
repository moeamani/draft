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

local function serifSize(h, font)
  if font == theme.T.huge() then return 24 end
  if h >= 34 then return 22 elseif h >= 28 then return 19 elseif h >= 22 then return 16 end
  return 14
end

-- The one button style: a dithered plate on a darker lip, with a serif label (Figma title cards).
-- opts: color, sub, disabled, font (size hint), icon, textColor
function M.button(id, x, y, w, h, label, opts)
  opts = opts or {}
  local plates = require("src.ui.plates")
  local s = st(id)
  local clicked, over = M.click(id, x, y, w, h)
  if opts.disabled then clicked = false end
  s.over = over and not opts.disabled
  s.down = s.over and M.down
  if s.over and not s.wasOver then sfx.play("hover", 1, 0.4) end
  s.wasOver = s.over
  if clicked then sfx.play("click") end
  local col = opts.color or C.ink3
  if opts.disabled then col = C.ink2 elseif s.hover > 0.5 then col = theme.mix(col, C.paper, 0.12) end
  x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
  local press = s.down and 2 or 0
  theme.set(C.black, 0.55)
  lg.rectangle("fill", x + 1, y + 3, w, h)
  plates.draw(plates.plate(w, h, theme.darken(col, 0.55)), x, y + 2)
  local by = y + press
  plates.draw(plates.plate(w, h, col, { light = 0.14 }), x, by)
  local tc = opts.disabled and C.muted or (opts.textColor or C.white)
  local size = plates.fit(label, serifSize(opts.sub and h - 12 or h, opts.font), w - 10 - (opts.icon and 12 or 0))
  local fh = theme.serif(size):getHeight()
  if opts.sub then
    local sf = theme.T.small()
    local total = fh + sf:getHeight() - 2
    local ty = by + math.floor((h - total) / 2)
    plates.print(label, size, x + w / 2, ty, tc, { align = "center" })
    gfx.text(opts.sub, sf, x + w / 2, ty + fh - 2, opts.disabled and C.muted or theme.mix(tc, col, 0.2), { align = "center", shadow = false })
  else
    local ty = by + math.floor((h - fh) / 2)
    local tx = x + w / 2
    if opts.icon then
      local tw = plates.textWidth(label, size) + 12
      tx = tx + 6
      require("src.ui.icons").draw(opts.icon, x + w / 2 - tw / 2 + 4, by + h / 2, opts.iconColor or C.paper)
    end
    plates.print(label, size, tx, ty, tc, { align = "center" })
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
  local plates = require("src.ui.plates")
  local lift = s.hover > 0.5 and 2 or 0
  local col = opts.color or C.ink2
  if opts.disabled then col = C.deep elseif s.hover > 0.5 then col = theme.mix(col, C.paper, 0.08) end
  local by = y - lift
  gfx.panel(x, by, w, h, col)
  local tx = x + 9
  if opts.icon then
    require("src.ui.icons").draw(opts.icon, x + 16, by + 15, opts.disabled and C.muted or (opts.iconColor or C.gold), 2)
    tx = x + 30
  end
  plates.print(title, plates.fit(title, 20, w - (tx - x) - 8), tx, by + 3, opts.disabled and C.muted or (opts.titleColor or C.white))
  if desc then gfx.textf(desc, theme.T.body(), x + 9, by + 29, w - 18, "left", opts.disabled and C.muted or C.paper2) end
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
    gfx.textf(l.text, l.font or theme.T.body(), x + pad, cy, w - pad * 2, l.align or "left", l.color or C.paper, { shadow = l.shadow })
    cy = cy + hs[i]
  end
  return x, y, w, h
end

return M
