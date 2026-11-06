-- One palette, two type families, one virtual resolution.
--
-- Art is pixel art on a 640x360 virtual grid. Text is not: fonts are rasterised at the screen's
-- real resolution (see main.lua), so it stays sharp at any window size and on Retina displays.
-- Titles use Ancizar Serif (the Figma font); everything you read uses Atkinson Hyperlegible,
-- a typeface designed for low-vision readability. Every text colour is checked against its
-- background for WCAG AA contrast (4.5:1) before it is drawn.
local M = {}

local function hex(h, a)
  return { tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255, a or 1 }
end
M.hex = hex

M.c = {
  -- grounds (dark ink greens) and plates
  deep = hex("#08140f"), ink = hex("#0e2119"), ink2 = hex("#16352a"), ink3 = hex("#24503c"), ink4 = hex("#2f6a4f"),
  night = hex("#020403"), black = hex("#050807"),
  -- plate colours: each passes 4.5:1 with white text (gold takes black text)
  red = hex("#b8352a"), redDark = hex("#7e2018"), blue = hex("#1f5fd0"), blueDark = hex("#143f8c"),
  gold = hex("#d3a200"), goldDark = hex("#7a5e00"), slate = hex("#3b4a5e"),
  -- text colours: each passes 4.5:1 on every dark ground, ink3 included
  paper = hex("#f4f1e8"), white = hex("#ffffff"), paper2 = hex("#e2dccb"), muted = hex("#b8cbc0"),
  goldText = hex("#f2c84b"), redText = hex("#ffa094"), blueText = hex("#8cb8ff"), cyan = hex("#6fefff"),
  green = hex("#7ee0a4"), pale = hex("#b4c8ec"), steel = hex("#b4bfcd"),
}
local C = M.c

-- Cushion upholstery: colour and badge icon (the rules are in match.CUSHION_KINDS).
M.CUSHION = {
  velvet = { col = hex("#9e2a20"), icon = "heart" },
  thistle = { col = hex("#3f7a3a"), icon = "leaf" },
  silk = { col = hex("#b9a878"), icon = "diamond" },
}

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
local files = {
  body = "assets/fonts/AtkinsonHyperlegible-Regular.ttf",
  bold = "assets/fonts/AtkinsonHyperlegible-Bold.ttf",
  italic = "assets/fonts/AtkinsonHyperlegible-Italic.ttf",
  serif = "assets/fonts/AncizarSerif-Regular.ttf",
  serifItalic = "assets/fonts/AncizarSerif-Italic.ttf",
}
local real = {}

local function rasterise(style, size)
  local px = math.max(6, math.floor(size * M.K + 0.5))
  local key = style .. ":" .. px
  if not real[key] then
    local ok, f = pcall(love.graphics.newFont, files[style], px, "normal", 1)
    if not ok then f = love.graphics.newFont(files[style], px) end
    f:setFilter("linear", "linear")
    real[key] = f
  end
  return real[key]
end

-- A font handle measured in virtual pixels. The rasterised font behind it follows M.K.
local Font = {}
Font.__index = Font
function Font:real() return rasterise(self.style, self.size) end
function Font:getWidth(s) return self:real():getWidth(s) / M.K end
function Font:getHeight() return self:real():getHeight() / M.K end
function Font:getWrap(s, limit)
  local w, lines = self:real():getWrap(s, limit * M.K)
  return w / M.K, lines
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

-- Type scale, in virtual pixels (a body line is 20px tall at 720p, 30px at 1080p).
M.T = {
  label = function() return M.font("bold", 7.5) end, -- short capital labels
  small = function() return M.font("body", 8.5) end, -- names on cards, chips
  body = function() return M.font("body", 10) end, -- anything you need to read
  bold = function() return M.font("bold", 10) end,
  big = function() return M.font("bold", 13) end, -- numbers, plaque names
  huge = function() return M.font("bold", 18) end, -- headline numbers
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
