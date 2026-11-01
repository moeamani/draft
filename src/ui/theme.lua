-- One palette (from the Figma file), one set of pixel fonts, one virtual resolution.
local M = {}

local function hex(h, a)
  return { tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255, a or 1 }
end
M.hex = hex

M.c = {
  ink = hex("#0e2119"), ink2 = hex("#16352a"), ink3 = hex("#24503c"), ink4 = hex("#2f6a4f"), deep = hex("#08140f"),
  red = hex("#e8483b"), redDark = hex("#9e2a20"), blue = hex("#2378f7"), blueDark = hex("#164f9e"),
  gold = hex("#d3a200"), goldDark = hex("#8a6a00"), cyan = hex("#47e7fd"), paper = hex("#f4f1e8"),
  paper2 = hex("#cfc9b6"), muted = hex("#8fa79a"), black = hex("#050807"), steel = hex("#8a96a8"),
  green = hex("#5fd38d"), pale = hex("#81a0cf"),
}

-- virtual pixel resolution; the canvas is rendered at SCALE x this and post-processed
M.W, M.H, M.SCALE = 640, 360, 2

local cache = {}
local files = {
  title = "assets/fonts/Jacquard12-Regular.ttf", -- 12, 24, 36
  ui = "assets/fonts/Tiny5-Regular.ttf", -- 8, 16
  num = "assets/fonts/Jersey10-Regular.ttf", -- 10, 20, 30, 40
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

-- named type scale, so every screen uses the same sizes
M.T = {
  tiny = function() return M.font("ui", 8) end,
  body = function() return M.font("ui", 8) end,
  big = function() return M.font("ui", 16) end,
  num = function() return M.font("num", 10) end,
  numL = function() return M.font("num", 20) end,
  numXL = function() return M.font("num", 30) end,
  head = function() return M.font("title", 24) end,
  headS = function() return M.font("title", 12) end,
  headL = function() return M.font("title", 36) end,
}

function M.set(col, a)
  love.graphics.setColor(col[1], col[2], col[3], (a or 1) * (col[4] or 1))
end

function M.mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, 1 }
end

function M.darken(c, k) return { c[1] * k, c[2] * k, c[3] * k, c[4] or 1 } end

return M
