-- Plates and title cards: the building blocks of every panel, button, heading and card face.
--
-- A plate is clean pixel art: a flat palette fill, a 1px dark outline with notched corners and a
-- 1px bevel (light along the top, dark along the bottom). No dither, no gradients.
-- Title cards (the Figma "Card Name / Ability / Power" plates) add the mascot's chromatic smear
-- along one end as an accent. Their labels are live serif text, drawn sharp at screen resolution.
local bakes = require("src.ui.bakes")
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

-- ---------------------------------------------------------------- the smear accent

local smearImages = {}
local function smearFor(tint, aberration)
  local best, bestD
  for _, sm in ipairs(bakes.SMEARS) do
    local c = theme.hex(sm.tint)
    local d = (c[1] - tint[1]) ^ 2 + (c[2] - tint[2]) ^ 2 + (c[3] - tint[3]) ^ 2
    if ((aberration or 0) >= 0.9) == (sm.aberration >= 0.9) then d = d * 0.5 end
    if not bestD or d < bestD then best, bestD = sm, d end
  end
  local file = bakes.smearFile(best.name)
  if smearImages[file] == nil then
    local ok, img = pcall(lg.newImage, file)
    smearImages[file] = ok and img or false
    if ok then img:setFilter("linear", "linear") end
  end
  return smearImages[file] or nil
end

-- ---------------------------------------------------------------- title cards

local Card = {}
Card.__index = Card
function Card:getDimensions() return self.w, self.h end
function Card:getWidth() return self.w end
function Card:getHeight() return self.h end

-- A title card: plate, smear accent (opts.streak: 0.43 for the colour plates, 1.0 for the
-- black "Power" plate) and an optional live serif label.
-- opts: label, size, align ("center" | "left"), pad, labelColor, italic, streak, outline
function M.titleCard(w, h, color, opts)
  w, h = math.floor(w), math.floor(h)
  opts = opts or {}
  local outline = opts.outline == nil and C.black or opts.outline
  local key = ("title:%d:%d:%s:%s:%s"):format(w, h, colKey(color), tostring(opts.streak), outline and colKey(outline) or "-")
  local canvas
  if cache[key] then canvas = cache[key].canvas
  else
    canvas = newCanvas(w, h)
    local base = M.plate(w, h, color, { outline = outline })
    begin(canvas)
    lg.setColor(1, 1, 1)
    lg.draw(base, 0, 0)
    if opts.streak and w >= 24 and h >= 12 then
      -- an engraved sign: a ruled frame inset two pixels and a stud at each end
      local i = outline and 1 or 0
      local rule = opts.streak >= 0.9 and C.goldDark or theme.shade(color, 0.32)
      local deep = theme.shade(color, -0.38)
      theme.set(deep)
      lg.rectangle("line", i + 2.5, i + 2.5, w - 2 * i - 5, h - 2 * i - 5)
      theme.set(rule)
      lg.rectangle("line", i + 1.5, i + 1.5, w - 2 * i - 3, h - 2 * i - 3)
      local cy = math.floor(h / 2)
      for _, sx in ipairs({ i + 5, w - i - 6 }) do
        theme.set(deep)
        lg.rectangle("fill", sx - 1, cy - 1, 3, 3)
        theme.set(rule)
        lg.rectangle("fill", sx, cy - 1, 1, 3)
        lg.rectangle("fill", sx - 1, cy, 3, 1)
      end
    end
    lg.pop()
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
