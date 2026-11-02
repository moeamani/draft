-- One palette (from the Figma file), one set of pixel fonts drawn at their native sizes, one virtual resolution.
local M = {}

local function hex(h, a)
  return { tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255, a or 1 }
end
M.hex = hex

M.c = {
  ink = hex("#0e2119"), ink2 = hex("#16352a"), ink3 = hex("#24503c"), ink4 = hex("#2f6a4f"), deep = hex("#08140f"),
  red = hex("#e8483b"), redDark = hex("#9e2a20"), blue = hex("#2378f7"), blueDark = hex("#164f9e"),
  gold = hex("#d3a200"), goldDark = hex("#8a6a00"), cyan = hex("#47e7fd"), paper = hex("#f4f1e8"),
  paper2 = hex("#d8d3c2"), muted = hex("#a9bfb3"), black = hex("#050807"), steel = hex("#8a96a8"),
  green = hex("#5fd38d"), pale = hex("#9fb8e0"),
  -- the table: walnut rim, candle light
  wood = hex("#3b2a1a"), woodDark = hex("#1f150c"), woodLight = hex("#6b4a2a"), candle = hex("#ffd27a"),
  -- parchment notes
  parch = hex("#efe6cf"), parchDark = hex("#c9b98f"), parchInk = hex("#2a1d10"),
}

-- virtual pixel resolution; the canvas is rendered at SCALE x this and post-processed
M.W, M.H, M.SCALE = 640, 360, 2

local cache = {}
local files = {
  tiny5 = "assets/fonts/Tiny5-Regular.ttf",
  jersey10 = "assets/fonts/Jersey10-Regular.ttf",
  jersey15 = "assets/fonts/Jersey15-Regular.ttf",
  jersey20 = "assets/fonts/Jersey20-Regular.ttf",
  jersey25 = "assets/fonts/Jersey25-Regular.ttf",
  jacquard12 = "assets/fonts/Jacquard12-Regular.ttf",
  jacquard24 = "assets/fonts/Jacquard24-Regular.ttf",
}

function M.font(style, size)
  local key = style .. size
  if not cache[key] then
    local f = love.graphics.newFont(files[style], size, "mono")
    f:setFilter("nearest", "nearest")
    cache[key] = f
  end
  return cache[key]
end

-- The type scale. Every font is used at the size it was drawn for, so text sits on the same
-- pixel grid as the art (no 2x or 3x blown-up letters).
M.T = {
  label = function() return M.font("tiny5", 8) end, -- short ALL-CAPS labels only
  small = function() return M.font("jersey10", 10) end, -- names on cards, chips
  body = function() return M.font("jersey15", 15) end, -- anything you need to read
  big = function() return M.font("jersey20", 20) end, -- buttons, names, numbers
  huge = function() return M.font("jersey25", 25) end, -- headline numbers
  title = function() return M.font("jacquard24", 24) end, -- screen titles, champion names
  deco = function() return M.font("jacquard12", 12) end, -- small decorative captions
}

function M.set(col, a)
  love.graphics.setColor(col[1], col[2], col[3], (a or 1) * (col[4] or 1))
end

function M.mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, 1 }
end

function M.darken(c, k) return { c[1] * k, c[2] * k, c[3] * k, c[4] or 1 } end

return M
