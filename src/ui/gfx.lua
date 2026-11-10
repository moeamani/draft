-- Drawing helpers. Shapes are drawn in virtual pixels on integer coordinates; text is drawn with
-- fonts rasterised at the real screen resolution (theme.K canvas pixels per virtual pixel), so it
-- stays sharp. Every text colour goes through theme.readable() against the ground it sits on.
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

-- The one panel style: a flat plate with an edge a shade darker than itself and a drop shadow.
-- opts.accent (or opts.border) adds a 2px coloured strip along the top.
function M.panel(x, y, w, h, col, opts)
  opts = opts or {}
  local a = opts.alpha or 1
  x, y, w, h = floor(x), floor(y), floor(w), floor(h)
  if opts.shadow ~= false then
    theme.set(C.black, 0.45 * a)
    lg.rectangle("fill", x + 1, y + 2, w, h)
  end
  local plates = require("src.ui.plates")
  local edge = opts.outline
  if edge == nil then edge = theme.shade(col, -0.5) end
  plates.draw(plates.plate(w, h, col, { outline = edge, bevel = false }), x, y, a)
  local accent = opts.accent or opts.border
  if accent then
    theme.set(accent, a)
    lg.rectangle("fill", x + 1, y + 1, w - 2, 2)
  end
end

-- ---------------------------------------------------------------- text

local function snap(v) local k = theme.K; return floor(v * k + 0.5) / k end

local function useFont(font)
  local f = font:real()
  lg.setFont(f)
  return f
end

-- Text colour after the WCAG check. Pure black or white with no ground given is taken as a
-- deliberate choice for a known plate (black on gold, white on red) and left alone.
local function inkFor(col, opts)
  if opts.raw then return col end
  if not opts.bg then
    local l = theme.luminance(col)
    if l < 0.01 or l > 0.92 then return col end
  end
  return theme.readable(col, opts.bg or C.ink2, opts.ratio)
end

-- Put one line of text with its line box's top-left at (x, y). Pixel fonts land on whole virtual
-- pixels (baseline included) and get their faux-bold second pass; smooth fonts snap to screen pixels.
local function put(font, f, str, x, y, k)
  local p = font:pixel()
  if p then
    x = floor(x + 0.5)
    local dy = font:drawY(y)
    lg.print(str, x, dy, 0, 1 / k, 1 / k)
    if p.faux then lg.print(str, x + 1, dy, 0, 1 / k, 1 / k) end
  else
    lg.print(str, snap(x), snap(y), 0, 1 / k, 1 / k)
  end
end
M.put = put

-- One line of text. opts: align ("left" | "center" | "right"), bg (the ground, for contrast),
-- shadow (true for a drop shadow over busy art), alpha, raw (skip the contrast check)
function M.text(str, font, x, y, col, opts)
  opts = opts or {}
  str = tostring(str)
  local f = useFont(font)
  local k = theme.K
  local w = font:getWidth(str)
  local ox = 0
  if opts.align == "center" then ox = -w / 2 elseif opts.align == "right" then ox = -w end
  x = x + ox
  if opts.shadow == true then
    theme.set(C.black, (opts.alpha or 1) * 0.8)
    if font:pixel() then put(font, f, str, x + 1, y + 1, k) else put(font, f, str, x + 0.5, y + 0.75, k) end
  end
  theme.set(inkFor(col, opts), opts.alpha)
  put(font, f, str, x, y, k)
  return w
end

-- Text with a dark outline (numbers over art).
function M.outlined(str, font, x, y, col, opts)
  opts = opts or {}
  str = tostring(str)
  local f = useFont(font)
  local k = theme.K
  local w = font:getWidth(str)
  if opts.align == "center" then x = x - w / 2 elseif opts.align == "right" then x = x - w end
  theme.set(opts.outline or C.black, opts.alpha)
  local d = font:pixel() and 1 or 0.75
  if font:pixel() then x, y = floor(x + 0.5), floor(y + 0.5) end
  for dx = -1, 1 do
    for dy = -1, 1 do
      if dx ~= 0 or dy ~= 0 then put(font, f, str, x + dx * d, y + dy * d, k) end
    end
  end
  theme.set(col, opts.alpha)
  put(font, f, str, x, y, k)
  return w
end

-- Wrapped text. Returns its height in virtual pixels.
function M.textf(str, font, x, y, w, align, col, opts)
  opts = opts or {}
  str = tostring(str)
  local f = useFont(font)
  local k = theme.K
  if font:pixel() then
    -- pixel fonts: wrap, then place each line on whole pixels
    local _, lines = font:getWrap(str, w)
    local lh = font:getHeight()
    local function pass(dx, dy)
      for i, line in ipairs(lines) do
        local lw = font:getWidth(line)
        local ox = 0
        if align == "center" then ox = (w - lw) / 2 elseif align == "right" then ox = w - lw end
        put(font, f, line, x + ox + dx, y + (i - 1) * lh + dy, k)
      end
    end
    if opts.shadow == true then
      theme.set(C.black, (opts.alpha or 1) * 0.8)
      pass(1, 1)
    end
    theme.set(inkFor(col, opts), opts.alpha)
    pass(0, 0)
    return #lines * lh
  end
  x, y = snap(x), snap(y)
  if opts.shadow == true then
    theme.set(C.black, (opts.alpha or 1) * 0.8)
    lg.printf(str, x + 0.5, y + 0.75, w * k, align or "left", 0, 1 / k, 1 / k)
  end
  theme.set(inkFor(col, opts), opts.alpha)
  lg.printf(str, x, y, w * k, align or "left", 0, 1 / k, 1 / k)
  local _, lines = f:getWrap(str, w * k)
  return #lines * f:getHeight() / k
end

function M.wrapHeight(str, font, w)
  local _, lines = font:getWrap(tostring(str), w)
  return #lines * font:getHeight()
end

-- Title text with per-letter bobbing.
function M.wavy(str, font, cx, y, col, t, amp, opts)
  opts = opts or {}
  local f = useFont(font)
  local k = theme.K
  local x = cx - font:getWidth(str) / 2
  amp = amp or 2
  theme.set(inkFor(col, opts), opts.alpha)
  for i = 1, #str do
    local ch = str:sub(i, i)
    local dy = math.sin(t * 2.4 + i * 0.5) * amp
    put(font, f, ch, x, y + dy, k)
    x = x + f:getWidth(ch) / k
  end
end

-- Short all-caps label (section headings, small tags).
function M.label(str, x, y, col, align, opts)
  opts = opts or {}
  opts.align = align
  return M.text(str:upper(), theme.T.label(), x, y, col or C.pale, opts)
end

M.CHIP_H = 13
function M.chip(str, x, y, kind)
  local font = theme.T.small()
  local w = math.ceil(font:getWidth(str)) + 8
  local bg
  if kind == "strength" then bg = C.redDark
  elseif kind == "weakness" then bg = theme.hex("#1f6b45")
  elseif kind == "gold" then bg = C.goldDark
  else bg = C.ink2 end
  M.box(x, y, w, M.CHIP_H, C.black)
  M.box(x + 1, y + 1, w - 2, M.CHIP_H - 2, bg)
  M.text(str, font, x + 4, y + 1.5, C.paper, { bg = bg })
  return w
end

-- Darken everything (behind overlays). Covers the whole window, margins included.
function M.dim(a)
  lg.setColor(0.01, 0.03, 0.02, a or 0.78)
  local ox, oy = G and G.OX or 0, G and G.OY or 0
  lg.rectangle("fill", -ox - 2, -oy - 2, (G and G.VW or theme.W) + 4, (G and G.VH or theme.H) + 4)
end

return M
