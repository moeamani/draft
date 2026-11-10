-- Print backdrops, after the Overseer's poster: dark green (or blood red) paper with film grain,
-- one pool of light screened in halftone dots, darker corners, and for matches a mustard table
-- in perspective, screened the same way. Baked once per backdrop, colour ramp and window shape,
-- at twice the virtual resolution so the dots and grain stay fine, then drawn smoothly scaled.
-- No shader needed, so the Switch gets the same backdrops.
local bakes = require("src.ui.bakes")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
local hex = theme.hex
M.SCALE = 2 -- baked pixels per virtual pixel

local PAPER = {
  felt = { dark = hex("#0c2417"), mid = hex("#1b4a2f"), dot = hex("#2c6a45") },
  blood = { dark = hex("#1f0a08"), mid = hex("#471611"), dot = hex("#6e231a") },
}
local TABLE = { base = hex("#c9a43a"), dark = hex("#8c6b1c"), light = hex("#f2d877"), edge = hex("#5e4410") }

local function smooth(a, b, x)
  local t = math.max(0, math.min(1, (x - a) / (b - a)))
  return t * t * (3 - 2 * t)
end

local function hash(x, y)
  local n = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
  return n - math.floor(n)
end

-- Is (x, y) inside a halftone dot of the given amount (0..1)? cell in baked pixels.
local cos45, sin45 = math.cos(math.rad(45)), math.sin(math.rad(45))
local cos15, sin15 = math.cos(math.rad(15)), math.sin(math.rad(15))
local function dot(x, y, amount, cell, c, s)
  if amount <= 0 then return false end
  local u = (x * c + y * s) / cell
  local v = (-x * s + y * c) / cell
  local du, dv = u - math.floor(u + 0.5), v - math.floor(v + 0.5)
  local r = math.sqrt(math.min(1, amount)) * 0.62
  return du * du + dv * dv < r * r
end

local function mixc(a, b, t) return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t end

-- The colour of one baked pixel. Returns r, g, b, a.
local function painter(preset, rampName, ox, oy, layer)
  local P = PAPER[rampName] or PAPER.felt
  local light, radius, power = preset.light, preset.radius, preset.power
  local horizon = preset.horizon or 0
  local S = M.SCALE
  return function(bx, by)
    local vx, vy = bx / S - ox, by / S - oy
    local ux, uy = vx / 640, vy / 360
    local dx, dy = (ux - light[1]) * (640 / 360), uy - light[2]
    local L = math.max(0, math.min(1, power * (1 - smooth(0, radius, math.sqrt(dx * dx + dy * dy)))))
    local ex = math.min(ux, 1 - ux) * 640 / 360
    local vig = smooth(-0.2, 0.25, math.min(ex, math.min(uy, 1 - uy)))
    local grain = (hash(bx, by) - 0.5) * 0.07
    local r, g, b, a
    local onTable = false
    if horizon > 0 and uy >= horizon then
      local t = (uy - horizon) / (1 - horizon)
      local halfw = 0.36 + (0.8 - 0.36) * t
      local u = (ux - 0.5) / halfw
      if math.abs(u) <= 1 then
        onTable = true
        local depth = (uy - horizon) * 360
        local edge = depth < 2 or math.abs(u) > 1 - 2 / (halfw * 640)
        if edge then
          r, g, b = TABLE.edge[1], TABLE.edge[2], TABLE.edge[3]
        else
          r, g, b = TABLE.base[1], TABLE.base[2], TABLE.base[3]
          local shade = (1 - L) * 0.55 + (1 - t) * 0.25
          if dot(bx, by, shade, 3, cos45, sin45) then r, g, b = TABLE.dark[1], TABLE.dark[2], TABLE.dark[3] end
          if dot(bx + 1, by, L * 0.45, 3, cos15, sin15) then r, g, b = TABLE.light[1], TABLE.light[2], TABLE.light[3] end
        end
      end
    end
    if not onTable then
      if layer == "table" then return 0, 0, 0, 0 end
      local t = math.max(0, math.min(1, 0.25 + 0.75 * L * vig))
      r, g, b = mixc(P.dark, P.mid, t)
      if dot(bx, by, L * vig * 0.5, 3, cos45, sin45) then r, g, b = P.dot[1], P.dot[2], P.dot[3] end
      if vig < 1 then r, g, b = r * (0.55 + 0.45 * vig), g * (0.55 + 0.45 * vig), b * (0.55 + 0.45 * vig) end
    end
    a = 1
    return math.max(0, math.min(1, r + grain)), math.max(0, math.min(1, g + grain)), math.max(0, math.min(1, b + grain)), a
  end
end

local cache, order = {}, {}

local function bake(key, w, h, paint)
  if cache[key] ~= nil then return cache[key] or nil end
  local ok, img = pcall(function()
    local data = love.image.newImageData(w, h)
    if data.mapPixel then
      data:mapPixel(function(x, y) return paint(x, y) end)
    else
      for y = 0, h - 1 do
        for x = 0, w - 1 do data:setPixel(x, y, paint(x, y)) end
      end
    end
    local im = lg.newImage(data)
    im:setFilter("linear", "linear")
    return im
  end)
  cache[key] = ok and img or false
  order[#order + 1] = key
  while #order > 8 do
    local old = table.remove(order, 1)
    if cache[old] and cache[old].release then cache[old]:release() end
    cache[old] = nil
  end
  return ok and img or nil
end

-- The backdrop image for a scene's bg, covering the visible area (vw x vh virtual pixels), or nil
-- where images can't be built from pixels (the caller then uses the baked PNGs).
function M.image(bg, vw, vh, ox, oy)
  local presetName = bakes.STAGES[bg.preset or "menu"] and (bg.preset or "menu") or "menu"
  local rampName = PAPER[bg.ramp or "felt"] and (bg.ramp or "felt") or "felt"
  local w, h = math.ceil(vw * M.SCALE), math.ceil(vh * M.SCALE)
  local key = ("%s:%s:%d:%d:%d:%d"):format(presetName, rampName, w, h, ox, oy)
  return bake(key, w, h, painter(bakes.STAGES[presetName], rampName, ox, oy))
end

-- Just a table, on a transparent ground: for scenes that put something behind it (the menu's
-- Overseer). horizon is in virtual pixels from the top of the safe area.
function M.tableLayer(horizon, vw, vh, ox, oy)
  local w, h = math.ceil(vw * M.SCALE), math.ceil(vh * M.SCALE)
  local preset = { light = { 0.5, 0.85 }, radius = 0.9, power = 1.0, horizon = horizon / 360 }
  local key = ("table:%d:%d:%d:%d:%d"):format(horizon, w, h, ox, oy)
  return bake(key, w, h, painter(preset, "felt", ox, oy, "table"))
end

return M
