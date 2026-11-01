-- Pixel drawing helpers. Everything is drawn in virtual pixels on integer coordinates.
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
local C = theme.c
local floor = math.floor

-- Filled box with 1px notched corners.
function M.box(x, y, w, h, col, a)
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  theme.set(col, a)
  lg.rectangle("fill", x + 1, y, w - 2, h)
  lg.rectangle("fill", x, y + 1, 1, h - 2)
  lg.rectangle("fill", x + w - 1, y + 1, 1, h - 2)
end

-- The one panel style: drop shadow, black outline, fill, 1px top highlight.
function M.panel(x, y, w, h, col, opts)
  opts = opts or {}
  local a = opts.alpha or 1
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  if opts.shadow ~= false then M.box(x + 1, y + 2, w, h, C.black, 0.55 * a) end
  M.box(x, y, w, h, opts.outline or C.black, a)
  M.box(x + 1, y + 1, w - 2, h - 2, col, a)
  if opts.border then
    theme.set(opts.border, a)
    lg.rectangle("fill", x + 2, y + 1, w - 4, 1)
    lg.rectangle("fill", x + 2, y + h - 2, w - 4, 1)
    lg.rectangle("fill", x + 1, y + 2, 1, h - 4)
    lg.rectangle("fill", x + w - 2, y + 2, 1, h - 4)
  elseif opts.highlight ~= false then
    local hl = theme.mix(col, C.paper, 0.18)
    theme.set(hl, a)
    lg.rectangle("fill", x + 2, y + 1, w - 4, 1)
  end
end

function M.text(str, font, x, y, col, opts)
  opts = opts or {}
  lg.setFont(font)
  local w = font:getWidth(str)
  local ox = 0
  if opts.align == "center" then ox = -floor(w / 2) elseif opts.align == "right" then ox = -w end
  x, y = floor(x + ox), floor(y)
  if opts.shadow ~= false then
    theme.set(opts.shadowCol or C.black, (opts.alpha or 1) * 0.85)
    lg.print(str, x + (opts.sx or 0), y + (opts.sy or 1))
  end
  theme.set(col, opts.alpha)
  lg.print(str, x, y)
  return w
end

-- Text with a full 1px outline (for numbers over art).
function M.outlined(str, font, x, y, col, opts)
  opts = opts or {}
  lg.setFont(font)
  local w = font:getWidth(str)
  if opts.align == "center" then x = x - floor(w / 2) elseif opts.align == "right" then x = x - w end
  x, y = floor(x), floor(y)
  theme.set(opts.outline or C.black, opts.alpha)
  for dx = -1, 1 do for dy = -1, 1 do if dx ~= 0 or dy ~= 0 then lg.print(str, x + dx, y + dy) end end end
  lg.print(str, x, y + 2)
  theme.set(col, opts.alpha)
  lg.print(str, x, y)
  return w
end

function M.textf(str, font, x, y, w, align, col, opts)
  opts = opts or {}
  lg.setFont(font)
  x, y = floor(x), floor(y)
  if opts.shadow ~= false then
    theme.set(C.black, (opts.alpha or 1) * 0.85)
    lg.printf(str, x, y + 1, w, align)
  end
  theme.set(col, opts.alpha)
  lg.printf(str, x, y, w, align)
  local _, lines = font:getWrap(str, w)
  return #lines * font:getHeight()
end

function M.wrapHeight(str, font, w)
  local _, lines = font:getWrap(str, w)
  return #lines * font:getHeight()
end

-- Title text with per-letter bobbing.
function M.wavy(str, font, cx, y, col, t, amp, opts)
  opts = opts or {}
  lg.setFont(font)
  local x = floor(cx - font:getWidth(str) / 2)
  amp = amp or 2
  for i = 1, #str do
    local ch = str:sub(i, i)
    local dy = floor(math.sin(t * 2.4 + i * 0.5) * amp + 0.5)
    theme.set(C.black, opts.alpha)
    lg.print(ch, x + 1, y + dy + 2)
    theme.set(col, opts.alpha)
    lg.print(ch, x, y + dy)
    x = x + font:getWidth(ch)
  end
end

function M.label(str, x, y, col, align)
  return M.text(str:upper(), theme.T.tiny(), x, y, col or C.pale, { align = align })
end

-- Horizontal bar (Pride, progress).
function M.bar(x, y, w, h, frac, col, back)
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  M.box(x, y, w, h, C.black)
  theme.set(back or C.deep)
  lg.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
  local fw = floor((w - 2) * math.max(0, math.min(1, frac)) + 0.5)
  if fw > 0 then
    theme.set(col)
    lg.rectangle("fill", x + 1, y + 1, fw, h - 2)
    theme.set(theme.mix(col, C.paper, 0.35))
    lg.rectangle("fill", x + 1, y + 1, fw, 1)
  end
end

function M.chip(str, x, y, kind)
  local font = theme.T.tiny()
  local w = font:getWidth(str) + 6
  local bg, fg
  if kind == "strength" then bg, fg = C.redDark, C.paper
  elseif kind == "weakness" then bg, fg = theme.hex("#1f6b45"), C.paper
  else bg, fg = C.deep, C.muted end
  M.box(x, y, w, 10, C.black)
  M.box(x + 1, y + 1, w - 2, 8, bg)
  M.text(str, font, x + 3, y + 1, fg, { shadow = false })
  return w
end

function M.dim(a)
  lg.setColor(0.01, 0.03, 0.02, a or 0.75)
  lg.rectangle("fill", -10, -10, theme.W + 20, theme.H + 20)
end

return M
