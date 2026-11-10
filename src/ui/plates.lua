-- Plates: the one shape everything in the interface is cut from.
--
-- A plate is a flat fill with pixel-rounded corners (two pixels cut from each), a one-pixel edge
-- a shade darker than the fill, a one-pixel highlight along the top, and optionally a "lip": a
-- darker band along the bottom that makes it look like a pressed key. Panels, buttons, signs,
-- chips, cushions and card plates are all plates, so they all share the same corners and edges.
-- Plates are baked once per size and colour and drawn on whole pixels.
local gfx -- required lazily: gfx draws panels with plates
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
local C = theme.c

-- small cache of baked canvases
local cache, order = {}, {}
local LIMIT = 500
local function remember(key, v)
  cache[key] = v
  order[#order + 1] = key
  if #order > LIMIT then
    local old = table.remove(order, 1)
    local o = cache[old]
    if o and o.release then o:release() end
    cache[old] = nil
  end
end

local function colKey(c) return ("%.3f,%.3f,%.3f"):format(c[1], c[2], c[3]) end

local function begin(cv)
  lg.push("all")
  lg.origin()
  lg.setScissor() -- baking happens mid-frame, maybe inside a clipped overlay
  lg.setShader()
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, 0)
end
M.begin = begin

-- Fill a w x h rounded rectangle at (x, y) in the current colour. r: 0, 1 or 2 pixels.
local function rounded(x, y, w, h, r)
  if r <= 0 or w < 4 or h < 4 then
    lg.rectangle("fill", x, y, w, h)
  elseif r == 1 or w < 8 or h < 8 then
    lg.rectangle("fill", x + 1, y, w - 2, h)
    lg.rectangle("fill", x, y + 1, w, h - 2)
  else
    lg.rectangle("fill", x + 2, y, w - 4, h)
    lg.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
    lg.rectangle("fill", x, y + 2, w, h - 4)
  end
end
M.rounded = rounded

-- opts: outline (a colour, or false for none; default a darker shade of the fill),
--       radius (0, 1 or 2; default 2), lip (pixels of darker band along the bottom; default 0),
--       hi (false to skip the top highlight)
function M.plate(w, h, color, opts)
  w, h = math.max(1, math.floor(w)), math.max(1, math.floor(h))
  opts = opts or {}
  local outline = opts.outline
  if outline == nil then outline = theme.shade(color, -0.55) end
  local r = opts.radius or 2
  local lip = math.min(opts.lip or 0, h - 4)
  if lip < 0 then lip = 0 end
  local hi = opts.hi ~= false and opts.bevel ~= false
  local key = ("p:%d:%d:%s:%s:%d:%d:%s"):format(w, h, colKey(color), outline and colKey(outline) or "-", r, lip, tostring(hi))
  if cache[key] then return cache[key] end
  local cv = lg.newCanvas(w, h)
  cv:setFilter("nearest", "nearest")
  begin(cv)
  local i = outline and 1 or 0
  if outline then
    theme.set(outline)
    rounded(0, 0, w, h, r)
  end
  if lip > 0 then
    theme.set(theme.shade(color, -0.42))
    rounded(i, i, w - 2 * i, h - 2 * i, math.max(0, r - i))
  end
  theme.set(color)
  rounded(i, i, w - 2 * i, h - 2 * i - lip, math.max(0, r - i))
  if hi and h - lip > 5 and w > 6 then
    theme.set(theme.shade(color, 0.2))
    lg.rectangle("fill", i + math.max(1, r - i), i, w - 2 * i - 2 * math.max(1, r - i), 1)
  end
  lg.pop()
  remember(key, cv)
  return cv
end

-- ---------------------------------------------------------------- signs

local Sign = {}
Sign.__index = Sign
function Sign:getDimensions() return self.w, self.h end
function Sign:getWidth() return self.w end
function Sign:getHeight() return self.h end

-- A sign: a coloured plate with a two-pixel lip and a serif label (names, stalls, banners).
-- opts: label, size, align ("center" | "left"), pad, labelColor, italic, lip
function M.titleCard(w, h, color, opts)
  w, h = math.floor(w), math.floor(h)
  opts = opts or {}
  local lip = opts.lip or (h >= 16 and 2 or 0)
  local sign = setmetatable({ canvas = M.plate(w, h, color, { lip = lip }), w = w, h = h, color = color, lip = lip }, Sign)
  if opts.label and opts.label ~= "" then
    sign.label = opts.label
    sign.pad = opts.pad or 8
    sign.size = M.fit(opts.label, opts.size or math.max(12, math.floor((h - lip) * 0.66)), w - 2 * sign.pad, opts.italic)
    sign.align, sign.italic = opts.align or "center", opts.italic
    sign.labelColor = opts.labelColor or (theme.luminance(color) > 0.3 and C.black or C.white)
  end
  return sign
end

-- ---------------------------------------------------------------- serif text

function M.textWidth(str, size, italic) return theme.serif(size, italic):getWidth(tostring(str)) end

-- The largest step of the serif scale (from size down to 12) at which str fits in width.
function M.fit(str, size, width, italic)
  while size > 12 and M.textWidth(str, size, italic) > width do size = size - 1 end
  return size
end

-- Serif text drawn straight onto the frame. align: "left" | "center" | "right". opts.bg: ground.
function M.print(str, size, x, y, color, opts)
  gfx = gfx or require("src.ui.gfx")
  opts = opts or {}
  return gfx.text(str, theme.serif(size, opts.italic), x, y, color, { align = opts.align, alpha = opts.alpha, bg = opts.bg, shadow = opts.shadow })
end

-- ---------------------------------------------------------------- images

local Pic = {}
Pic.__index = Pic
function Pic:getDimensions() return self.w, self.h end
function Pic:getWidth() return self.w end
function Pic:getHeight() return self.h end

-- A smooth image (the logo) shown at a given width.
function M.image(img, w)
  local h = math.floor(img:getHeight() * w / img:getWidth() + 0.5)
  return setmetatable({ img = img, w = w, h = h }, Pic)
end

-- ---------------------------------------------------------------- drawing

function M.draw(obj, x, y, alpha)
  if not obj then return end
  gfx = gfx or require("src.ui.gfx")
  local a = alpha or 1
  x, y = math.floor(x), math.floor(y)
  local mt = getmetatable(obj)
  if mt == Pic then
    lg.setColor(1, 1, 1, a)
    lg.draw(obj.img, x, y, 0, obj.w / obj.img:getWidth(), obj.h / obj.img:getHeight())
    return
  end
  if mt == Sign then
    lg.setColor(1, 1, 1, a)
    lg.draw(obj.canvas, x, y)
    if obj.label then
      local f = theme.serif(obj.size, obj.italic)
      local ty = y + (obj.h - obj.lip - f:getHeight()) / 2
      local tx = obj.align == "left" and x + obj.pad or x + obj.w / 2
      gfx.text(obj.label, f, tx, ty, obj.labelColor, { align = obj.align == "left" and "left" or "center", alpha = a, bg = obj.color })
    end
    return
  end
  lg.setColor(1, 1, 1, a)
  lg.draw(obj, x, y)
end

-- Draw a baked canvas multiplied by a colour. blend "add" glows.
function M.drawTint(canvas, x, y, color, alpha, blend)
  if not canvas then return end
  local a = alpha or 1
  local mode, am = lg.getBlendMode()
  lg.setBlendMode(blend or "alpha")
  lg.setColor(color[1], color[2], color[3], a)
  lg.draw(canvas, math.floor(x), math.floor(y))
  lg.setBlendMode(mode, am)
end

-- A sign with its shadow, used as a heading. opts as titleCard; align defaults to "left".
function M.header(x, y, w, h, color, label, opts)
  opts = opts or {}
  x, y = math.floor(x), math.floor(y)
  theme.set(C.black, 0.4)
  rounded(x, y + 2, w, h, 2)
  M.draw(M.titleCard(w, h, color, { label = label, align = opts.align or "left", pad = opts.pad, size = opts.size,
    italic = opts.italic, labelColor = opts.labelColor }), x, y)
end

return M
