-- Plates and title cards: the building blocks of every panel, button, heading and card face.
--
-- A plate is clean pixel art: a flat palette fill, a 1px dark outline with notched corners and a
-- 1px bevel (light along the top, dark along the bottom). No dither, no gradients.
-- Title cards (the "Card Name / Ability / Power" plates) are flat plates with a darker edge, like
-- the poster's flat red buttons. Their labels are live text (smooth or pixel, per Settings).
local gfx = require("src.ui.gfx")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
local C = theme.c

-- small LRU-ish cache of baked canvases
local cache, order = {}, {}
local LIMIT = 400
local function remember(key, v)
  cache[key] = v
  order[#order + 1] = key
  if #order > LIMIT then
    local old = table.remove(order, 1)
    local o = cache[old]
    if o and o.canvas then o.canvas:release() end
    cache[old] = nil
  end
end

local function colKey(c) return ("%.3f,%.3f,%.3f"):format(c[1], c[2], c[3]) end

local function newCanvas(w, h)
  local cv = lg.newCanvas(math.max(1, w), math.max(1, h))
  cv:setFilter("nearest", "nearest")
  return cv
end

local function begin(cv)
  lg.push("all")
  lg.origin()
  lg.setScissor() -- baking happens mid-frame, maybe inside a clipped overlay
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, 0)
end
M.begin = begin

-- ---------------------------------------------------------------- plates

-- opts: outline (colour or false), bevel (false to skip), notch (false for square corners)
function M.plate(w, h, color, opts)
  w, h = math.floor(w), math.floor(h)
  opts = opts or {}
  local outline = opts.outline == nil and C.black or opts.outline
  local key = ("plate:%d:%d:%s:%s:%s:%s"):format(w, h, colKey(color), outline and colKey(outline) or "-", tostring(opts.bevel), tostring(opts.notch))
  if cache[key] then return cache[key].canvas end
  local cv = newCanvas(w, h)
  begin(cv)
  local i = outline and 1 or 0
  if outline then
    theme.set(outline)
    lg.rectangle("fill", 1, 0, w - 2, h)
    lg.rectangle("fill", 0, 1, w, h - 2)
    if opts.notch == false then lg.rectangle("fill", 0, 0, w, h) end
  end
  theme.set(color)
  lg.rectangle("fill", i, i, w - 2 * i, h - 2 * i)
  if opts.bevel ~= false and h > 4 and w > 4 then
    theme.set(theme.shade(color, 0.22))
    lg.rectangle("fill", i, i, w - 2 * i, 1)
    theme.set(theme.shade(color, -0.32))
    lg.rectangle("fill", i, h - i - 1, w - 2 * i, 1)
  end
  lg.pop()
  remember(key, { canvas = cv })
  return cv
end

-- ---------------------------------------------------------------- title cards

local Card = {}
Card.__index = Card
function Card:getDimensions() return self.w, self.h end
function Card:getWidth() return self.w end
function Card:getHeight() return self.h end

-- A title card: a flat plate with an edge a shade darker than itself (like the poster's flat
-- red buttons) and an optional live label.
-- opts: label, size, align ("center" | "left"), pad, labelColor, italic, outline (false: none)
function M.titleCard(w, h, color, opts)
  w, h = math.floor(w), math.floor(h)
  opts = opts or {}
  local edge = opts.outline ~= false and theme.shade(color, -0.5) or false
  local key = ("title:%d:%d:%s:%s"):format(w, h, colKey(color), edge and "e" or "-")
  local canvas
  if cache[key] then canvas = cache[key].canvas
  else
    canvas = M.plate(w, h, color, { outline = edge, bevel = false })
    remember(key, { canvas = canvas })
  end
  local card = setmetatable({ canvas = canvas, w = w, h = h, color = color }, Card)
  if opts.label and opts.label ~= "" then
    card.label = opts.label
    card.size = M.fit(opts.label, opts.size or math.max(12, math.floor(h * 0.62)), w - 2 * (opts.pad or 11), opts.italic)
    card.align, card.pad, card.italic = opts.align or "center", opts.pad or 11, opts.italic
    card.labelColor = opts.labelColor or (theme.luminance(color) > 0.3 and C.black or C.white)
  end
  return card
end

-- ---------------------------------------------------------------- serif text

function M.textWidth(str, size, italic) return theme.serif(size, italic):getWidth(tostring(str)) end

-- The largest size (down to 9px) at which str fits in width.
function M.fit(str, size, width, italic)
  while size > 9 and M.textWidth(str, size, italic) > width do size = size - 1 end
  return size
end

-- Serif text drawn straight onto the frame. align: "left" | "center" | "right". opts.bg: ground.
function M.print(str, size, x, y, color, opts)
  opts = opts or {}
  return gfx.text(str, theme.serif(size, opts.italic), x, y, color, { align = opts.align, alpha = opts.alpha, bg = opts.bg, shadow = opts.shadow })
end

-- ---------------------------------------------------------------- images

local Pic = {}
Pic.__index = Pic
function Pic:getDimensions() return self.w, self.h end
function Pic:getWidth() return self.w end
function Pic:getHeight() return self.h end

-- A smooth image (Figma art) shown at a given width, drawn with smooth filtering at screen resolution.
function M.image(img, w)
  local h = math.floor(img:getHeight() * w / img:getWidth() + 0.5)
  return setmetatable({ img = img, w = w, h = h }, Pic)
end

-- ---------------------------------------------------------------- drawing

function M.draw(obj, x, y, alpha)
  if not obj then return end
  local a = alpha or 1
  x, y = math.floor(x), math.floor(y)
  local mt = getmetatable(obj)
  if mt == Pic then
    lg.setColor(1, 1, 1, a)
    lg.draw(obj.img, x, y, 0, obj.w / obj.img:getWidth(), obj.h / obj.img:getHeight())
    return
  end
  if mt == Card then
    lg.setColor(1, 1, 1, a)
    lg.draw(obj.canvas, x, y)
    if obj.label then
      local f = theme.serif(obj.size, obj.italic)
      local ty = y + (obj.h - f:getHeight()) / 2 - 0.5
      local tx = obj.align == "left" and x + obj.pad or x + obj.w / 2
      gfx.text(obj.label, f, tx, ty, obj.labelColor, { align = obj.align == "left" and "left" or "center", alpha = a, bg = obj.color })
    end
    return
  end
  lg.setColor(1, 1, 1, a)
  lg.draw(obj, x, y)
end

-- Draw a baked canvas multiplied by a colour (the VS screen's colour ghosts). blend "add" glows.
function M.drawTint(canvas, x, y, color, alpha, blend)
  if not canvas then return end
  local a = alpha or 1
  local mode, am = lg.getBlendMode()
  lg.setBlendMode(blend or "alpha")
  lg.setColor(color[1], color[2], color[3], a)
  lg.draw(canvas, math.floor(x), math.floor(y))
  lg.setBlendMode(mode, am)
end

-- A title-card strip used as a heading. opts as titleCard, plus align defaults to "left".
function M.header(x, y, w, h, color, label, opts)
  opts = opts or {}
  local o = { label = label, align = opts.align or "left", pad = opts.pad or 11, size = opts.size or math.max(12, math.floor(h * 0.7)),
    streak = opts.streak, italic = opts.italic, labelColor = opts.labelColor, outline = opts.outline == nil and C.black or opts.outline }
  theme.set(C.black, 0.45)
  lg.rectangle("fill", math.floor(x) + 1, math.floor(y) + 2, w, h)
  M.draw(M.titleCard(w, h, color, o), x, y)
end

-- Kept for older callers: there is no dither pass any more.
function M.dither(src) return src end
function M.smearImage() return nil end

return M
