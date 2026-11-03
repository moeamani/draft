-- One palette (from the Figma file), one set of pixel fonts drawn at their native sizes, one virtual resolution.
local M = {}

local function hex(h, a)
  return { tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255, a or 1 }
end
M.hex = hex

M.c = {
  ink = hex("#0e2119"), ink2 = hex("#16352a"), ink3 = hex("#24503c"), ink4 = hex("#2f6a4f"), deep = hex("#08140f"),
  red = hex("#e8483b"), redDark = hex("#9e2a20"), blue = hex("#2378f7"), blueDark = hex("#164f9e"),
  gold = hex("#d3a200"), goldDark = hex("#8a6a00"), cyan = hex("#47e7fd"), paper = hex("#f4f1e8"), white = hex("#ffffff"),
  paper2 = hex("#d8d3c2"), muted = hex("#a9bfb3"), black = hex("#050807"), steel = hex("#8a96a8"),
  green = hex("#5fd38d"), pale = hex("#9fb8e0"),
  -- the Power card plate
  night = hex("#020403"),
}

-- virtual pixel resolution; the canvas is rendered at SCALE x this and post-processed
M.W, M.H, M.SCALE = 640, 360, 2

local cache = {}
local files = {
  jersey10 = "assets/fonts/Jersey10-Regular.ttf",
  jersey15 = "assets/fonts/Jersey15-Regular.ttf",
  jersey20 = "assets/fonts/Jersey20-Regular.ttf",
  jersey25 = "assets/fonts/Jersey25-Regular.ttf",
  serif = "assets/fonts/AncizarSerif-Regular.ttf",
  serifItalic = "assets/fonts/AncizarSerif-Italic.ttf",
}

-- Pixel fonts are crisp ("mono"); the serif is antialiased and only ever drawn into baked,
-- dithered plates (see src/ui/plates.lua), the way the Figma title cards treat their type.
function M.font(style, size)
  local key = style .. size
  if not cache[key] then
    local serif = style == "serif" or style == "serifItalic"
    local f = love.graphics.newFont(files[style], size, serif and "normal" or "mono")
    f:setFilter("nearest", "nearest")
    cache[key] = f
  end
  return cache[key]
end

-- Two families: Ancizar Serif for display type (as in the Figma file), Jersey for everything you
-- read. Each Jersey cut is used at the size it was drawn for.
M.T = {
  label = function() return M.font("jersey10", 10) end, -- short labels (drawn in capitals)
  small = function() return M.font("jersey10", 10) end, -- names on cards, chips
  body = function() return M.font("jersey15", 15) end, -- anything you need to read
  big = function() return M.font("jersey20", 20) end, -- numbers, plaque names
  huge = function() return M.font("jersey25", 25) end, -- headline numbers
}
function M.serif(size, italic) return M.font(italic and "serifItalic" or "serif", size) end

function M.set(col, a)
  love.graphics.setColor(col[1], col[2], col[3], (a or 1) * (col[4] or 1))
end

function M.mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, 1 }
end

function M.darken(c, k) return { c[1] * k, c[2] * k, c[3] * k, c[4] or 1 } end

return M
