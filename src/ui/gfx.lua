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

-- The one panel style: a dithered palette plate (Figma texture) with a 1px outline and a drop
-- shadow. opts.accent (or the older opts.border) adds a 2px coloured strip along the top.
function M.panel(x, y, w, h, col, opts)
  opts = opts or {}
  local a = opts.alpha or 1
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  if opts.shadow ~= false then
    theme.set(C.black, 0.5 * a)
    lg.rectangle("fill", x + 1, y + 2, w, h)
  end
  local plates = require("src.ui.plates")
  plates.draw(plates.plate(w, h, col, { outline = opts.outline }), x, y, a)
  local accent = opts.accent or opts.border
  if accent then
    theme.set(accent, a)
    lg.rectangle("fill", x + 1, y + 1, w - 2, 2)
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

-- Short all-caps label (section headings, small tags).
function M.label(str, x, y, col, align)
  return M.text(str:upper(), theme.T.label(), x, y, col or C.pale, { align = align })
end

M.CHIP_H = 13
function M.chip(str, x, y, kind)
  local font = theme.T.small()
  local w = font:getWidth(str) + 8
  local bg, fg
  if kind == "strength" then bg, fg = C.redDark, C.paper
  elseif kind == "weakness" then bg, fg = theme.hex("#1f6b45"), C.paper
  elseif kind == "gold" then bg, fg = C.goldDark, C.paper
  else bg, fg = C.ink2, C.paper2 end
  M.box(x, y, w, M.CHIP_H, C.black)
  M.box(x + 1, y + 1, w - 2, M.CHIP_H - 2, bg)
  M.text(str, font, x + 4, y + 1, fg, { shadow = false })
  return w
end

function M.dim(a)
  lg.setColor(0.01, 0.03, 0.02, a or 0.75)
  lg.rectangle("fill", -10, -10, theme.W + 20, theme.H + 20)
end

return M
