-- Palette (from the Figma file) and fonts.
local M = {}

local function hex(h, a)
  return { tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255, a or 1 }
end
M.hex = hex

M.c = {
  ink = hex("#0e2119"), ink2 = hex("#16352a"), ink3 = hex("#24503c"), ink4 = hex("#2f6a4f"),
  red = hex("#e8483b"), redDark = hex("#a8291f"), blue = hex("#2378f7"), blueDark = hex("#1550a8"),
  gold = hex("#d3a200"), goldDark = hex("#8f6d00"), cyan = hex("#47e7fd"), paper = hex("#f4f1e8"),
  paper2 = hex("#ddd8c8"), muted = hex("#9fb3a6"), black = hex("#050807"), steel = hex("#8a96a8"),
  green = hex("#3fcf8e"), pale = hex("#81a0cf"), shadow = { 0, 0, 0, 0.45 },
}

M.W, M.H = 1600, 900

local cache = {}
local files = {
  serif = "assets/fonts/AncizarSerif-Regular.ttf",
  bold = "assets/fonts/AncizarSerif-Bold.ttf",
  italic = "assets/fonts/AncizarSerif-Italic.ttf",
  mono = "assets/fonts/IBMPlexMono-Regular.ttf",
  monoBold = "assets/fonts/IBMPlexMono-SemiBold.ttf",
}

function M.font(style, size)
  local key = style .. size
  if not cache[key] then
    local f = love.graphics.newFont(files[style], size, "normal", 2)
    f:setFilter("linear", "linear")
    cache[key] = f
  end
  return cache[key]
end

function M.set(col, a)
  love.graphics.setColor(col[1], col[2], col[3], (a or 1) * (col[4] or 1))
end

function M.mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, 1 }
end

return M
