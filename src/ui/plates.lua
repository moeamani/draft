-- Baked surfaces in the style of the Figma title cards.
--   * plate:     a flat palette colour with a soft top light and a 1px outline
--   * titleCard: a plate with the mascot silhouette smeared by the chromatic lens, and a serif label
--   * text:      serif type on its own (names, headings drawn straight onto other surfaces)
-- Everything is composed smooth (antialiased type, gradients, the smear) and then quantised once
-- with the Figma dither (Bayer 16x16, 8 levels per channel), so every surface shares one texture.
-- Results are cached; the cache is trimmed when it grows.
local shaders = require("src.ui.shaders")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
local C = theme.c
local cache, order = {}, {}
local LIMIT = 400

local function remember(key, value)
  cache[key] = value
  order[#order + 1] = key
  if #order > LIMIT then
    local old = table.remove(order, 1)
    local v = cache[old]
    if v and v.canvas then v.canvas:release() end
    cache[old] = nil
  end
  return value
end

local function newCanvas(w, h)
  local c = lg.newCanvas(math.max(1, w), math.max(1, h))
  c:setFilter("nearest", "nearest")
  return c
end

local function colKey(c) return ("%.3f,%.3f,%.3f"):format(c[1], c[2], c[3]) end

-- Quantise a canvas with the Figma dither into a fresh canvas (straight alpha).
local function dither(src, w, h, alphaCut)
  local out = newCanvas(w, h)
  lg.push("all")
  lg.origin()
  lg.setScissor()
  lg.setCanvas(out)
  lg.clear(0, 0, 0, 0)
  lg.setBlendMode("replace", "premultiplied")
  if shaders.fdither then
    lg.setShader(shaders.fdither)
    shaders.fdither:send("alphaCut", alphaCut and 1 or 0)
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(src, 0, 0)
  lg.pop()
  return out
end
M.dither = dither

local function begin(canvas, r, g, b, a)
  lg.push("all")
  lg.origin()
  lg.setScissor()
  lg.setShader()
  lg.setCanvas(canvas)
  lg.clear(r or 0, g or 0, b or 0, a or 0)
end

local function vgrad(x, y, w, h, top, bottom)
  local mesh = lg.newMesh({
    { x, y, 0, 0, top[1], top[2], top[3], 1 }, { x + w, y, 1, 0, top[1], top[2], top[3], 1 },
    { x + w, y + h, 1, 1, bottom[1], bottom[2], bottom[3], 1 }, { x, y + h, 0, 1, bottom[1], bottom[2], bottom[3], 1 },
  }, "fan", "static")
  lg.setColor(1, 1, 1)
  lg.draw(mesh)
  mesh:release()
end

-- The mascot silhouette in `tint`, smeared sideways by the chromatic lens, premultiplied.
-- The effect is worked out on a square frame (as in Figma) but only the middle `band` rows that a
-- title card shows are rendered.
local function smear(side, tint, aberration, band)
  band = math.min(side, band or side)
  local key = ("smear:%d:%d:%s:%.2f"):format(side, band, colKey(tint), aberration)
  if cache[key] then return cache[key].canvas end
  local sil = newCanvas(side, side)
  sil:setFilter("linear", "linear")
  local img = G.images["mascot-silhouette"]
  begin(sil)
  lg.setColor(tint[1], tint[2], tint[3], 1)
  if img then lg.draw(img, 0, 0, 0, side / img:getWidth(), side / img:getHeight()) end
  lg.pop()
  local out = newCanvas(side, band)
  begin(out)
  lg.setBlendMode("replace", "premultiplied")
  if shaders.smear then
    lg.setShader(shaders.smear)
    shaders.smear:send("size", { side, side })
    shaders.smear:send("amount", 1.0)
    shaders.smear:send("aberration", aberration)
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(sil, 0, -math.floor((side - band) / 2))
  lg.pop()
  sil:release()
  remember(key, { canvas = out })
  return out
end

-- A plain plate. opts: outline (colour or false), light (0..1 top highlight), shade (0..1 bottom shade)
function M.plate(w, h, color, opts)
  w, h = math.floor(w), math.floor(h)
  opts = opts or {}
  local outline = opts.outline == nil and C.black or opts.outline
  local key = ("plate:%d:%d:%s:%s:%.2f:%.2f"):format(w, h, colKey(color), outline and colKey(outline) or "-", opts.light or 0.08, opts.shade or 0.12)
  if cache[key] then return cache[key].canvas end
  local raw = newCanvas(w, h)
  begin(raw)
  local inset = outline and 1 or 0
  if outline then
    theme.set(outline)
    lg.rectangle("fill", 0, 0, w, h)
  end
  vgrad(inset, inset, w - inset * 2, h - inset * 2, theme.mix(color, C.paper, opts.light or 0.08), theme.darken(color, 1 - (opts.shade or 0.12)))
  lg.pop()
  local out = dither(raw, w, h, false)
  raw:release()
  remember(key, { canvas = out })
  return out
end

-- A Figma title card. opts: label, size (serif px), italic, labelColor, streak (aberration 0..1, nil
-- for none), streakTint, align ("center" | "left"), pad, outline, light
function M.titleCard(w, h, color, opts)
  w, h = math.floor(w), math.floor(h)
  opts = opts or {}
  local size = opts.size or math.max(12, math.floor(h * 0.62))
  if opts.label and opts.label ~= "" then size = M.fit(opts.label, size, w - 2 * (opts.pad or 8), opts.italic) end
  local labelColor = opts.labelColor or C.white
  local key = ("title:%d:%d:%s:%s:%d:%s:%s:%s:%s:%s"):format(w, h, colKey(color), opts.label or "", size, tostring(opts.italic),
    colKey(labelColor), tostring(opts.streak), opts.align or "center", tostring(opts.outline))
  if cache[key] then return cache[key].canvas end
  local raw = newCanvas(w, h)
  begin(raw, color[1], color[2], color[3], 1)
  if opts.light ~= false then
    vgrad(0, 0, w, h, theme.mix(color, C.paper, 0.05), theme.darken(color, 0.9))
  end
  if opts.streak then
    local sm = smear(w, opts.streakTint or color, opts.streak, h)
    lg.setBlendMode("alpha", "premultiplied")
    lg.setColor(1, 1, 1, 1)
    lg.draw(sm, 0, 0)
    lg.setBlendMode("alpha", "alphamultiply")
  end
  if opts.label and opts.label ~= "" then
    local f = theme.serif(size, opts.italic)
    lg.setFont(f)
    local tw = f:getWidth(opts.label)
    local tx = opts.align == "left" and (opts.pad or 8) or math.floor((w - tw) / 2)
    local ty = math.floor((h - f:getHeight()) / 2)
    theme.set(labelColor)
    lg.print(opts.label, tx, ty)
  end
  if opts.outline then
    theme.set(opts.outline)
    lg.rectangle("fill", 0, 0, w, 1)
    lg.rectangle("fill", 0, h - 1, w, 1)
    lg.rectangle("fill", 0, 0, 1, h)
    lg.rectangle("fill", w - 1, 0, 1, h)
  end
  lg.pop()
  local out = dither(raw, w, h, false)
  raw:release()
  remember(key, { canvas = out })
  return out
end

-- Serif text on a transparent background, dithered. Returns canvas, width, height.
-- opts: italic, shadow (colour for a 1px drop shadow)
function M.text(str, size, color, opts)
  opts = opts or {}
  str = tostring(str)
  local key = ("text:%s:%d:%s:%s:%s"):format(str, size, colKey(color), tostring(opts.italic), opts.shadow and colKey(opts.shadow) or "-")
  local hit = cache[key]
  if hit then return hit.canvas, hit.w, hit.h end
  local f = theme.serif(size, opts.italic)
  local w, h = f:getWidth(str) + 3, f:getHeight() + 2
  local raw = newCanvas(w, h)
  begin(raw)
  lg.setFont(f)
  if opts.shadow then
    theme.set(opts.shadow)
    lg.print(str, 1, 1)
  end
  theme.set(color)
  lg.print(str, 0, 0)
  lg.pop()
  local out = dither(raw, w, h, false)
  raw:release()
  remember(key, { canvas = out, w = w, h = h })
  return out, w, h
end

function M.textWidth(str, size, italic) return theme.serif(size, italic):getWidth(tostring(str)) end

-- The largest size (down to 10px) at which str fits in width.
function M.fit(str, size, width, italic)
  while size > 10 and M.textWidth(str, size, italic) > width do size = size - 1 end
  return size
end

-- Bake any smooth image (Figma art) to a given width with the same dither.
function M.image(img, w, alphaCut)
  local key = ("image:%s:%d:%s"):format(tostring(img), w, tostring(alphaCut))
  if cache[key] then return cache[key].canvas end
  local h = math.floor(img:getHeight() * w / img:getWidth() + 0.5)
  local raw = newCanvas(w, h)
  begin(raw)
  lg.setColor(1, 1, 1, 1)
  lg.draw(img, 0, 0, 0, w / img:getWidth(), h / img:getHeight())
  lg.pop()
  local out = dither(raw, w, h, alphaCut ~= false)
  raw:release()
  remember(key, { canvas = out })
  return out
end

-- Smeared silhouette of any image (used for portraits on the VS screen).
function M.smearImage(img, side, aberration)
  local key = ("smearimg:%s:%d:%.2f"):format(tostring(img), side, aberration)
  if cache[key] then return cache[key].canvas end
  local src = newCanvas(side, side)
  src:setFilter("linear", "linear")
  begin(src)
  lg.setColor(1, 1, 1, 1)
  lg.draw(img, 0, 0, 0, side / img:getWidth(), side / img:getHeight())
  lg.pop()
  local out = newCanvas(side, side)
  begin(out)
  lg.setBlendMode("replace", "premultiplied")
  if shaders.smear then
    lg.setShader(shaders.smear)
    shaders.smear:send("size", { side, side })
    shaders.smear:send("amount", 1.0)
    shaders.smear:send("aberration", aberration)
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(src, 0, 0)
  lg.pop()
  src:release()
  local d = dither(out, side, side, false)
  out:release()
  remember(key, { canvas = d })
  return d
end

-- Draw helpers -----------------------------------------------------------------

function M.draw(canvas, x, y, alpha)
  lg.setColor(1, 1, 1, alpha or 1)
  lg.draw(canvas, math.floor(x), math.floor(y))
end

-- A title-card strip used as a heading. opts as titleCard, plus align defaults to "left".
function M.header(x, y, w, h, color, label, opts)
  opts = opts or {}
  local o = { label = label, align = opts.align or "left", pad = opts.pad or 8, size = opts.size or math.max(12, math.floor(h * 0.7)),
    streak = opts.streak, italic = opts.italic, labelColor = opts.labelColor, outline = opts.outline == nil and C.black or opts.outline }
  theme.set(C.black, 0.5)
  lg.rectangle("fill", math.floor(x) + 1, math.floor(y) + 2, w, h)
  M.draw(M.titleCard(w, h, color, o), x, y)
end

-- Serif text drawn straight onto the frame. align: "left" | "center" | "right"
function M.print(str, size, x, y, color, opts)
  opts = opts or {}
  local c, w = M.text(str, size, color, opts)
  local ox = 0
  if opts.align == "center" then ox = -math.floor(w / 2) elseif opts.align == "right" then ox = -w end
  M.draw(c, x + ox, y, opts.alpha)
  return w
end

return M
