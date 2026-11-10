-- The design system's tokens: one palette, one type scale, one virtual resolution.
--
-- Draft looks like a deck printed on the Overseer's press and seen through a CRT: dark ink-green
-- paper, halftone light, a mustard table, flat red and blue plates, cream card stock. Art is
-- pixel art on a 640x360 virtual grid and never scaled by fractions. Text is not pixel art by
-- default: fonts are rasterised at the screen's real resolution (see main.lua). Headings use
-- Ancizar Serif (the logo's family); everything else uses Atkinson Hyperlegible. Every text
-- colour is checked against its ground for WCAG AA contrast (4.5:1) before it is drawn.
local M = {}

local function hex(h, a)
  return { tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255, a or 1 }
end
M.hex = hex

M.c = {
  -- grounds: the ink greens, darkest first. Panels are `ink`, wells and rows `ink2`,
  -- secondary buttons `ink3`, borders and highlights `ink4`.
  deep = hex("#07130d"), ink = hex("#0c1d15"), ink2 = hex("#143225"), ink3 = hex("#1f4a36"), ink4 = hex("#2e6b4d"),
  night = hex("#030605"), black = hex("#050807"),
  -- plates: each passes 4.5:1 with white text (gold takes black text)
  red = hex("#c7392c"), redDark = hex("#7e2018"), blue = hex("#1f66e8"), blueDark = hex("#143f8c"),
  gold = hex("#d3a200"), goldDark = hex("#7a5e00"), slate = hex("#3b4a5e"),
  -- text: each passes 4.5:1 on every ground above
  paper = hex("#f4f1e8"), white = hex("#ffffff"), paper2 = hex("#e2dccb"), muted = hex("#b8cbc0"),
  goldText = hex("#f2c84b"), redText = hex("#ffa094"), blueText = hex("#8cb8ff"), cyan = hex("#6fefff"),
  green = hex("#7ee0a4"), pale = hex("#b4c8ec"), steel = hex("#b4bfcd"),
  -- card stock and the ledger's pages: dark ink on cream
  cream = hex("#efe6cc"), cream2 = hex("#ddd1ae"), cream3 = hex("#bfae84"), inkText = hex("#2b2118"),
  inkMuted = hex("#5c4c38"), stamp = hex("#b3261a"), stampBlue = hex("#1d4fb0"),
  -- the print's highlights (the Overseer's fire, the teaser's fringe)
  pink = hex("#ff9fb4"), flame = hex("#ff6a2a"),
}
local C = M.c

-- What each colour is for. Scenes ask for roles, so a button is the same red everywhere.
M.role = {
  primary = C.red,        -- the one action that moves the game on
  secondary = C.ink3,     -- every other button
  info = C.blue,          -- your side, information
  reward = C.goldDark,    -- Renown, fish, prizes
  danger = C.redDark,     -- destructive choices
  panel = C.ink, well = C.ink2,
}

-- The coats, as plate colours (see cards.COATS for the rules).
M.COAT = { ember = C.red, tide = C.blue, gilt = C.gold, shadow = C.slate, none = C.ink3 }

-- Cushion upholstery: colour and badge icon (the rules are in match.CUSHION_KINDS).
M.CUSHION = {
  velvet = { col = hex("#9e2a20"), icon = "heart" },
  thistle = { col = hex("#3f7a3a"), icon = "leaf" },
  silk = { col = hex("#b9a878"), icon = "diamond" },
}

-- Spacing: everything sits on a 4px grid; panels pad 8, the screen's gutter is 8.
M.PAD, M.GUTTER = 8, 8

-- virtual pixel resolution of the safe area (the window can show more around it)
M.W, M.H = 640, 360

-- ---------------------------------------------------------------- contrast (WCAG 2.x)

local function channel(c) return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
function M.luminance(c) return 0.2126 * channel(c[1]) + 0.7152 * channel(c[2]) + 0.0722 * channel(c[3]) end
function M.contrast(a, b)
  local la, lb = M.luminance(a), M.luminance(b)
  if la < lb then la, lb = lb, la end
  return (la + 0.05) / (lb + 0.05)
end

-- The colour to actually draw `fg` text in over `bg`: unchanged if it already reaches `ratio`
-- (4.5 by default), otherwise lightened (on dark grounds) or darkened (on light ones) until it does.
local readableCache = {}
function M.readable(fg, bg, ratio)
  bg = bg or C.ink2
  ratio = ratio or 4.5
  local key = ("%.3f%.3f%.3f|%.3f%.3f%.3f|%.1f"):format(fg[1], fg[2], fg[3], bg[1], bg[2], bg[3], ratio)
  local hit = readableCache[key]
  if hit then return hit end
  local out = fg
  if M.contrast(fg, bg) < ratio then
    local toward = M.luminance(bg) < 0.18 and C.white or C.black
    for t = 0.05, 1.0001, 0.05 do
      out = M.mix(fg, toward, t)
      if M.contrast(out, bg) >= ratio then break end
    end
  end
  out = { out[1], out[2], out[3], fg[4] or 1 }
  readableCache[key] = out
  return out
end

-- ---------------------------------------------------------------- fonts

-- K: canvas pixels per virtual pixel (set by main.lua whenever the window changes).
M.K = 2

-- Two text styles. "smooth" (the default) rasterises Ancizar Serif (headings) and Atkinson
-- Hyperlegible (everything else) at the screen's real resolution, like the poster. "pixel" draws
-- pixel fonts on the art's own grid, one font pixel per virtual pixel.
M.textStyle = "smooth"

local files = {
  body = "assets/fonts/AtkinsonHyperlegible-Regular.ttf",
  bold = "assets/fonts/AtkinsonHyperlegible-Bold.ttf",
  italic = "assets/fonts/AtkinsonHyperlegible-Italic.ttf",
  serif = "assets/fonts/AncizarSerif-Regular.ttf",
  serifItalic = "assets/fonts/AncizarSerif-Italic.ttf",
}

-- Pixel faces: em size, cap height and descender depth in font pixels (all on a whole-pixel grid).
local FACES = {
  pix10 = { file = "assets/fonts/DraftPixel10.ttf", em = 10, cap = 7, desc = 2 }, -- body text
  pix12 = { file = "assets/fonts/DraftPixel12.ttf", em = 12, cap = 9, desc = 2 }, -- larger body
  coral = { file = "assets/fonts/CoralPixels-Regular.ttf", em = 13, cap = 9, desc = 3 }, -- bold
  jacquard = { file = "assets/fonts/Jacquard12-Regular.ttf", em = 21, cap = 12, desc = 3 }, -- titles
  jersey = { file = "assets/fonts/Jersey15-Regular.ttf", em = 27, cap = 15, desc = 4 }, -- big numbers
  micro = { file = "assets/fonts/Micro5-Regular.ttf", em = 11, cap = 5, desc = 1 }, -- tiny labels
}
M.FACES = FACES

-- Which pixel face (and whole-number scale) stands in for a style at a size. `faux` adds a
-- second pass one pixel to the right: the classic pixel-font bold.
local function pixelFace(style, size)
  if style == "body" or style == "italic" then
    if size < 8 then return "micro", 1 end
    if size < 11 then return "pix10", 1 end
    if size < 20 then return "pix12", 1 end
    return "pix10", 2
  elseif style == "bold" then
    if size < 9.5 then return "micro", 1 end
    if size < 12 then return "pix10", 1, true end
    if size < 16 then return "coral", 1 end
    if size < 26 then return "jersey", 1 end
    return "jersey", 2
  end
  -- serif, serifItalic: titles and headings (a fitting loop can step down to the small bold)
  if size < 11 then return "pix10", 1, true end
  if size < 16 then return "coral", 1 end
  if size < 30 then return "jacquard", 1 end
  return "jacquard", 2
end

local real = {}

local function load(file, px, hinting)
  local ok, f = pcall(love.graphics.newFont, file, px, hinting, 1)
  if not ok then ok, f = pcall(love.graphics.newFont, file, px, hinting) end
  if not ok then f = love.graphics.newFont(file, px) end
  return f
end

local function rasterise(style, size)
  local px = math.max(6, math.floor(size * M.K + 0.5))
  local key = style .. ":" .. px
  if not real[key] then
    local f = load(files[style], px, "normal")
    f:setFilter("linear", "linear")
    real[key] = f
  end
  return real[key]
end

local function rasteriseFace(face, n)
  local spec = FACES[face]
  local px = spec.em * n * M.K
  local key = face .. "@" .. px
  if not real[key] then
    local f = load(spec.file, px, "mono")
    f:setFilter("nearest", "nearest")
    -- anything outside the pixel faces' Latin set falls back to Atkinson
    if f.setFallbacks then pcall(f.setFallbacks, f, load(files.body, px, "normal")) end
    real[key] = f
  end
  return real[key]
end

-- A font handle measured in virtual pixels. The rasterised font behind it follows M.K and the
-- text style.
local Font = {}
Font.__index = Font

-- The pixel layout of this handle, or nil in smooth mode.
function Font:pixel()
  if M.textStyle ~= "pixel" then return nil end
  local p = self._pix
  if not p then
    local face, n, faux = pixelFace(self.style, self.size)
    local spec = FACES[face]
    local cap, desc = spec.cap * n, spec.desc * n
    local lineH = cap + desc + math.max(3, math.floor(0.3 * cap + 0.5))
    -- capitals sit in the middle of the line box (as with the smooth fonts), descenders below
    p = { face = face, n = n, faux = faux, cap = cap, lineH = lineH,
      top = math.floor((lineH - cap) / 2 + 0.5) }
    self._pix = p
  end
  return p
end

function Font:real()
  local p = self:pixel()
  if p then return rasteriseFace(p.face, p.n) end
  return rasterise(self.style, self.size)
end

function Font:getWidth(s)
  local p = self:pixel()
  local w = self:real():getWidth(s) / M.K
  if p and p.faux and s ~= "" then w = w + 1 end
  return w
end

function Font:getHeight()
  local p = self:pixel()
  if p then return p.lineH end
  return self:real():getHeight() / M.K
end

function Font:getWrap(s, limit)
  local p = self:pixel()
  local w, lines = self:real():getWrap(s, (limit - ((p and p.faux) and 1 or 0)) * M.K)
  return w / M.K, lines
end

-- Where to put the draw origin so the baseline lands on a whole virtual pixel, for a line box
-- whose top is at y (pixel mode only).
function Font:drawY(y)
  local p = self:pixel()
  local f = self:real()
  return math.floor(y + 0.5) + p.top + p.cap - f:getAscent() / M.K
end

local handles = {}
function M.font(style, size)
  local key = style .. size
  if not handles[key] then handles[key] = setmetatable({ style = style, size = size }, Font) end
  return handles[key]
end
function M.isFont(f) return getmetatable(f) == Font end

function M.setScale(k)
  if k ~= M.K then
    M.K = k
    real = {}
  end
end

function M.setTextStyle(style)
  style = style == "smooth" and "smooth" or "pixel"
  if style ~= M.textStyle then
    M.textStyle = style
    for _, h in pairs(handles) do h._pix = nil end
  end
end

-- The type scale, in virtual pixels. Nothing else is allowed: sizes asked for in between snap to
-- the nearest step, so every screen shares the same six sizes of each family.
local SERIF_STEPS = { 12, 14, 16, 20, 24, 30 }
local SANS_STEPS = { 5.5, 7.5, 8.5, 10, 12, 13, 18, 22, 27 }
local function snapTo(steps, size)
  local best, bd = steps[1], math.huge
  for _, v in ipairs(steps) do
    local d = math.abs(v - size)
    if d < bd then best, bd = v, d end
  end
  return best
end
local rawFont = M.font
function M.font(style, size)
  local serif = style == "serif" or style == "serifItalic"
  return rawFont(style, snapTo(serif and SERIF_STEPS or SANS_STEPS, size))
end

M.T = {
  label = function() return M.font("bold", 7.5) end,   -- short capital labels
  small = function() return M.font("body", 8.5) end,   -- secondary lines, names on cards
  body = function() return M.font("body", 10) end,     -- anything you read
  bold = function() return M.font("bold", 10) end,     -- buttons, emphasis
  big = function() return M.font("bold", 13) end,      -- numbers, large buttons
  huge = function() return M.font("bold", 18) end,     -- headline numbers
  heading = function() return M.font("serif", 14) end, -- names, panel titles
  title = function() return M.font("serif", 20) end,   -- screen titles
  display = function() return M.font("serif", 30) end, -- banners
}
function M.serif(size, italic) return M.font(italic and "serifItalic" or "serif", size) end

-- ---------------------------------------------------------------- colour helpers

function M.set(col, a)
  love.graphics.setColor(col[1], col[2], col[3], (a or 1) * (col[4] or 1))
end

function M.mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, 1 }
end

function M.darken(c, k) return { c[1] * k, c[2] * k, c[3] * k, c[4] or 1 } end

-- Hue-shifted shade ramps for pixel art: shadows lean cool, highlights lean warm.
function M.shade(c, t)
  if t < 0 then
    local k = -t
    return { c[1] * (1 - k * 0.55), c[2] * (1 - k * 0.5), math.min(1, c[3] * (1 - k * 0.3) + k * 0.06), 1 }
  end
  return { math.min(1, c[1] + (1 - c[1]) * t * 0.9 + t * 0.03), math.min(1, c[2] + (1 - c[2]) * t * 0.8), c[3] + (1 - c[3]) * t * 0.55, 1 }
end

return M
