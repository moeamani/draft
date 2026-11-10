-- The room around the game, painted as pixel art: a felt card table with a paw-print weave and a
-- worn wooden rail, panelled walls and a plank floor, lit by one pool of lamplight and darkened
-- towards the corners. Baked once per backdrop, colour ramp and window shape into an image at
-- virtual-pixel resolution, then drawn K times larger with no filtering, so its pixels are the
-- same size as the cats'. Works without shaders (LÖVE Potion) wherever ImageData exists.
local bakes = require("src.ui.bakes")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
local hex = theme.hex

-- dark to light; the lamp moves a pixel up and down these, dithered
local WOOD = { hex("#120b07"), hex("#1f130c"), hex("#2f1d12"), hex("#432a19"), hex("#5c3a22"), hex("#764c2c") }
local WALL = { hex("#0b0806"), hex("#140d09"), hex("#1e140d"), hex("#2a1c12"), hex("#382518") }
local FLOOR = { hex("#070504"), hex("#0e0907"), hex("#160f0b"), hex("#1f150f") }

local BAYER = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } }
local function pick(list, t, x, y)
  local n = #list
  local f = math.max(0, math.min(1, t)) * (n - 1)
  local i = math.floor(f)
  if f - i > (BAYER[y % 4 + 1][x % 4 + 1] + 0.5) / 16 then i = i + 1 end
  return list[math.min(n, i + 1)]
end

local function smooth(a, b, x)
  local t = math.max(0, math.min(1, (x - a) / (b - a)))
  return t * t * (3 - 2 * t)
end

-- a tiny deterministic hash for grain and wear
local function hash(x, y)
  local n = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
  return n - math.floor(n)
end

-- A paw print, woven into the felt every 20 pixels (alternate rows shifted by 10).
local PAW = { ".x.x.", "x...x", ".xxx.", "xxxxx", ".xxx." }
local function pawAt(x, y)
  local row = math.floor(y / 20)
  local px = (x + (row % 2) * 10) % 20 - 7
  local py = y % 20 - 7
  if px < 0 or py < 0 or px > 4 or py > 4 then return false end
  return PAW[py + 1]:sub(px + 1, px + 1) == "x"
end

local function feltRamp(r)
  local A, B, E, V = hex(r.baseA), hex(r.baseB), hex(r.edge), hex(r.voidc)
  return { theme.mix(V, A, 0.5), A, theme.mix(A, B, 0.5), B, theme.mix(B, E, 0.5), E, theme.shade(E, 0.18) }
end

-- Paint one backdrop. kind: "table3d" (the match: a table in perspective), "felt" (a table seen
-- from above, with an oval rail) or "wall" (a panelled room).
local function painter(kind, preset, ramp, ox, oy)
  local felt = feltRamp(ramp)
  local V = { 640, 360 }
  local light, radius, power = preset.light, preset.radius, preset.power
  local horizon = preset.horizon or 0
  return function(x, y)
    local vx, vy = x - ox, y - oy
    local ux, uy = (vx + 0.5) / V[1], (vy + 0.5) / V[2]
    local dx, dy = (ux - light[1]) * (V[1] / V[2]), uy - light[2]
    local L = math.max(0, math.min(1, power * (1 - smooth(0, radius, math.sqrt(dx * dx + dy * dy)))))
    -- vignette: the corners of the room fall into shadow
    local ex = math.min(ux, 1 - ux) * V[1] / V[2]
    local ey = math.min(uy, 1 - uy)
    local vig = smooth(-0.15, 0.22, math.min(ex, ey))
    local function wall()
      local plank = math.floor((vx + 4) / 22)
      local seam = (vx + 4) % 22 == 0
      local grain = hash(plank, math.floor(vy / 3)) < 0.18 and -0.12 or 0
      local t = 0.3 + 0.75 * L * vig + grain + (hash(plank, 7) - 0.5) * 0.14
      if seam then t = t - 0.45 end
      return pick(WALL, t, x, y)
    end
    local function floor()
      local board = math.floor(vy / 9)
      local seam = vy % 9 == 0 or (vx + board * 37) % 61 == 0
      local t = 0.3 + 0.7 * L * vig + (hash(board, math.floor((vx + board * 37) / 61)) - 0.5) * 0.15
      if seam then t = t - 0.5 end
      return pick(FLOOR, t, x, y)
    end
    local function wood(t, u) -- a rail, lit from above: t 0..1 across its width
      local tone = 0.4 + 0.6 * L * vig
      if t < 0.2 then tone = 0.05 elseif t < 0.4 then tone = tone + 0.3 elseif t > 0.85 then tone = tone - 0.25 end
      if hash(math.floor(u * 40), math.floor(t * 4)) < 0.12 then tone = tone - 0.15 end -- worn spots
      return pick(WOOD, tone, x, y)
    end
    local function cloth()
      local t = 0.32 + 0.68 * L * vig
      if pawAt(vx, vy) then t = t - 0.2 end
      if hash(vx, vy) < 0.06 then t = t - 0.1 end -- the nap of the felt
      return pick(felt, t, x, y)
    end
    if kind == "wall" then return wall() end
    if kind == "felt" then
      -- an oval table with a wooden rail; the floor beyond it
      local ax, ay = (ux - 0.5) / 0.53, (uy - 0.5) / 0.56
      local r = math.sqrt(ax * ax + ay * ay)
      local rail = 9 / (0.56 * V[2])
      if r > 1 + rail then return floor() end
      if r > 1 then return wood((r - 1) / rail, math.atan2(ay, ax) / math.pi) end
      return cloth()
    end
    -- table3d: wall above the horizon, then the table narrowing into the distance
    if uy < horizon then
      local t = wall()
      if (horizon - uy) * V[2] < 7 then -- the table's shadow on the wainscot
        return pick(WALL, 0.05, x, y)
      end
      return t
    end
    local t = (uy - horizon) / (1 - horizon)
    local halfw = 0.36 + (0.8 - 0.36) * t
    local u = (ux - 0.5) / halfw
    local railU = 9 / (halfw * V[1])
    local depth = (uy - horizon) * V[2]
    if math.abs(u) > 1 then return floor() end
    if depth < 6 then return wood(depth / 6, ux) end -- the far rail
    if math.abs(u) > 1 - railU then return wood((math.abs(u) - (1 - railU)) / railU, uy) end
    return cloth()
  end
end

local cache = {}
local order = {}

-- The baked backdrop image for a scene's bg, sized to the visible area. nil when this platform
-- can't build images from pixels (the caller falls back to the baked PNGs).
function M.image(bg, vw, vh, ox, oy)
  local presetName = bg.preset or "menu"
  local preset = bakes.STAGES[presetName]
  if not preset or not preset.room then return nil end
  local rampName = bakes.RAMPS[bg.ramp or "felt"] and (bg.ramp or "felt") or "felt"
  local w, h = math.ceil(vw), math.ceil(vh)
  local key = ("%s:%s:%d:%d:%d:%d"):format(presetName, rampName, w, h, ox, oy)
  if cache[key] ~= nil then return cache[key] or nil end
  local paint = painter(preset.room, preset, bakes.RAMPS[rampName], ox, oy)
  local ok, img = pcall(function()
    local data = love.image.newImageData(w, h)
    if data.mapPixel then
      data:mapPixel(function(x, y)
        local c = paint(x, y)
        return c[1], c[2], c[3], 1
      end)
    else
      for y = 0, h - 1 do
        for x = 0, w - 1 do
          local c = paint(x, y)
          data:setPixel(x, y, c[1], c[2], c[3], 1)
        end
      end
    end
    local im = lg.newImage(data)
    im:setFilter("nearest", "nearest")
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

return M
