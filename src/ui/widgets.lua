-- Immediate-mode widgets, all cut from plates: buttons that press like keys, tabs, sliders,
-- choice cards, tooltips. One style each, used on every screen.
local audio = require("src.audio")
local gfx = require("src.ui.gfx")
local plates = require("src.ui.plates")
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

-- The largest of the allowed bold sizes (from size down) at which str fits in width.
local BOLD_STEPS = { 13, 12, 10, 8.5 }
local function fitBold(str, size, width)
  for _, s in ipairs(BOLD_STEPS) do
    if s <= size and theme.font("bold", s):getWidth(str) <= width then return s end
  end
  return 8.5
end
M.fitBold = fitBold

M.LIP = 3 -- every button's lip, in pixels

local KINDS = { primary = C.red, secondary = C.ink3, info = C.blue, reward = C.goldDark, danger = C.redDark }

-- The one button: a plate with a three-pixel lip that sinks when pressed.
-- opts: kind ("primary" | "secondary" | "info" | "reward" | "danger") or color, sub (a second
--       line), disabled, icon, iconColor, textColor, focused (keyboard or controller selection),
--       arrow (a drawn arrow after the label), size (a bold size to start from)
function M.button(id, x, y, w, h, label, opts)
  opts = opts or {}
  local s = st(id)
  local clicked, over = M.click(id, x, y, w, h)
  if opts.disabled then clicked = false end
  s.over = (over or opts.focused) and not opts.disabled
  s.down = s.over and over and M.down
  if s.over and not s.wasOver and over then audio.play("hover", 1, 0.5) end
  s.wasOver = s.over
  if clicked then audio.play("click") end
  local col = opts.color or KINDS[opts.kind or "secondary"] or C.ink3
  if opts.disabled then col = C.ink2 elseif s.hover > 0.5 then col = theme.shade(col, 0.14) end
  x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
  local lip = h >= 16 and M.LIP or 2
  local sink = s.down and (lip - 1) or 0
  -- the shadow stays put; the face sinks into its lip
  theme.set(C.black, 0.4)
  plates.rounded(x, y + 2, w, h, 2)
  plates.draw(plates.plate(w, h - sink, col, { lip = lip - sink }), x, y + sink)
  local by, bh = y + sink, h - lip
  if opts.focused and not opts.disabled then
    theme.set(C.goldText)
    lg.rectangle("line", x - 1.5, y - 1.5, w + 3, h + 3)
  end
  local tc = opts.disabled and C.muted or (opts.textColor or (theme.luminance(col) > 0.3 and C.black or C.white))
  local extra = (opts.icon and 14 or 0) + (opts.arrow and 12 or 0)
  local want = opts.size or ((opts.sub and bh >= 26 or bh >= 26) and 13 or 10)
  if opts.sub and bh < 30 then want = 10 end
  local font = theme.font("bold", fitBold(label, want, w - 10 - extra))
  local fh = font:getHeight()
  if opts.sub then
    local sf = theme.T.small()
    local total = fh + sf:getHeight() - 2
    local ty = by + (bh - total) / 2
    gfx.text(label, font, x + w / 2, ty, tc, { align = "center", bg = col })
    gfx.text(gfx.fitText(opts.sub, sf, w - 8), sf, x + w / 2, ty + fh - 2, opts.disabled and C.muted or C.paper2, { align = "center", bg = col })
  else
    local ty = by + (bh - fh) / 2
    local tx = x + w / 2
    local lw = font:getWidth(label)
    if opts.arrow then
      -- a drawn arrow after the label, like the poster's call to action
      tx = tx - 6
      local ax, ay = math.floor(tx + lw / 2 + 6), math.floor(by + bh / 2)
      theme.set(tc)
      lg.rectangle("fill", ax, ay, 7, 1)
      lg.rectangle("fill", ax + 4, ay - 2, 1, 5)
      lg.rectangle("fill", ax + 5, ay - 1, 1, 3)
    end
    if opts.icon then
      tx = tx + 7
      require("src.ui.icons").draw(opts.icon, math.floor(x + w / 2 - (lw + 14) / 2 + 4), math.floor(by + bh / 2), opts.iconColor or C.paper)
    end
    gfx.text(label, font, tx, ty, tc, { align = "center", bg = col })
  end
  return clicked
end

-- A tab: a small button that stays lit while its page is shown.
function M.tab(id, x, y, w, label, active, focused)
  return M.button(id, x, y, w, 20, label, { kind = active and "primary" or "secondary", focused = focused })
end

-- A slider from 0 to 1 in tenths. Returns the new value (or the old one).
function M.slider(id, x, y, w, value, focused)
  local s = st(id)
  local h = 14
  local over = M.inside(x - 4, y - 3, w + 8, h + 6)
  s.over = over or focused
  if over and M.pressed then M.pressId = id end
  local v = value
  if M.pressId == id and M.down then
    v = math.floor(math.max(0, math.min(1, (M.mx - x - 4) / (w - 8))) * 10 + 0.5) / 10
    if v ~= value then audio.play("tick", 0.8 + v * 0.6, 0.7) end
  end
  if M.pressId == id and M.released then M.pressId = nil end
  x, y, w = math.floor(x), math.floor(y), math.floor(w)
  gfx.meter(x, y + 4, w, 6, v, C.gold)
  local kx = x + math.floor((w - 8) * v)
  theme.set(C.black, 0.4)
  plates.rounded(kx, y + 2, 8, h, 1)
  plates.draw(plates.plate(8, h, (s.hover > 0.5 or M.pressId == id) and C.white or C.paper, { lip = 2, radius = 1 }), kx, y)
  if focused then
    theme.set(C.goldText)
    lg.rectangle("line", x - 2.5, y - 1.5, w + 5, h + 3)
  end
  return v
end

-- A clickable choice card: a title and a wrapped description.
-- opts: color, icon, iconColor, disabled, titleColor, focused
function M.choice(id, x, y, w, h, title, desc, opts)
  opts = opts or {}
  local s = st(id)
  local clicked, over = M.click(id, x, y, w, h)
  if opts.disabled then clicked = false end
  s.over = (over or opts.focused) and not opts.disabled
  if s.over and not s.wasOver and over then audio.play("hover", 1, 0.5) end
  s.wasOver = s.over
  if clicked then audio.play("click") end
  local lift = s.hover > 0.5 and 2 or 0
  local col = opts.color or C.ink2
  if opts.disabled then col = C.deep elseif s.hover > 0.5 then col = theme.shade(col, 0.1) end
  local by = y - lift
  x, by, w, h = math.floor(x), math.floor(by), math.floor(w), math.floor(h)
  theme.set(C.black, 0.4)
  plates.rounded(x, y + 2, w, h, 2)
  plates.draw(plates.plate(w, h, col, { lip = 2 }), x, by)
  if opts.focused and not opts.disabled then
    theme.set(C.goldText)
    lg.rectangle("line", x - 1.5, by - 1.5, w + 3, h + 3)
  end
  local tx = x + 8
  if opts.icon then
    require("src.ui.icons").draw(opts.icon, x + 15, by + 14, opts.disabled and C.muted or (opts.iconColor or C.gold), 2)
    tx = x + 28
  end
  local tf = theme.font("bold", fitBold(title, 12, w - (tx - x) - 8))
  gfx.text(title, tf, tx, by + 6, opts.disabled and C.muted or (opts.titleColor or C.white), { bg = col })
  if desc then gfx.textf(desc, theme.T.body(), x + 8, by + 24, w - 16, "left", opts.disabled and C.muted or C.paper2, { bg = col }) end
  return clicked
end

function M.tooltip(fn) M.tooltipFn = fn end
function M.drawTooltip() if M.tooltipFn then M.tooltipFn() end end

-- A floating box of lines: { {text=, font=, color=, gap=} ... }; img: a picture shown above.
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
  gfx.panel(x, y, w, h, C.deep, { outline = C.ink4 })
  local cy = y + pad
  if img then
    local ix = math.floor(x + (w - iw) / 2)
    gfx.box(ix - 1, cy - 1, iw + 2, ih + 2, C.black)
    plates.draw(img, ix, cy)
    cy = cy + ih + 4
  end
  for i, l in ipairs(lines) do
    gfx.textf(l.text, l.font or theme.T.body(), x + pad, cy, w - pad * 2, l.align or "left", l.color or C.paper, { bg = C.deep })
    cy = cy + hs[i]
  end
  return x, y, w, h
end

return M
