-- The backdrop: a halftone print on the art's own pixel grid.
--
-- Dark ink-green paper (blood red for the Hands and the Overseer), one pool of light screened in
-- halftone dots, darker corners, film grain, and for matches a mustard table in perspective,
-- screened the same way. The dots sit on a 45 degree lattice of virtual pixels and never move:
-- only their size changes, so the light can drift slowly and swell where something hits the
-- table without the print ever shimmering.
--
-- With shaders it is drawn live (shaders.paper). Without them (LÖVE Potion) the same picture is
-- baked once per backdrop and window shape from the same maths in Lua, and stands still.
local bakes = require("src.ui.bakes")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
local hex = theme.hex

M.PAPER = {
  felt = { dark = hex("#0a2016"), mid = hex("#174a30"), dot = hex("#27663f") },
  blood = { dark = hex("#1c0908"), mid = hex("#4a1611"), dot = hex("#742419") },
}
M.TABLE = { base = hex("#c9a43a"), dark = hex("#96741f"), light = hex("#edd277"), edge = hex("#5e4410") }
M.CELL = 6 -- the screen's period along its diagonals; dots are about 4 pixels apart

local function smooth(a, b, x)
  local t = math.max(0, math.min(1, (x - a) / (b - a)))
  return t * t * (3 - 2 * t)
end

local function hash(x, y)
  local n = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
  return n - math.floor(n)
end

-- Is virtual pixel (x, y) inside a dot of this amount (0..1)? phase shifts the lattice.
local function dot(x, y, amount, phase)
  if amount <= 0 then return false end
  local P = M.CELL
  local u, v = (x + y + phase) % P - P / 2, (x - y) % P - P / 2
  local r = 0.72 * P * math.sqrt(math.min(1, amount))
  return u * u + v * v < r * r
end

-- The colour of one virtual pixel at time 0 (the shader's maths, in Lua). layer "table" paints
-- only the table and leaves the rest clear.
local function painter(preset, rampName, layer)
  local P = M.PAPER[rampName] or M.PAPER.felt
  local T = M.TABLE
  local light, radius, power = preset.light, preset.radius, preset.power
  local horizon = preset.horizon or 0
  return function(vx, vy)
    local ux, uy = (vx + 0.5) / 640, (vy + 0.5) / 360
    local dx, dy = (ux - light[1]) * (640 / 360), uy - light[2]
    local L = math.max(0, math.min(1, power * (1 - smooth(0, radius, math.sqrt(dx * dx + dy * dy)))))
    local ex = math.min(ux, 1 - ux) * 640 / 360
    local vig = smooth(-0.2, 0.25, math.min(ex, math.min(uy, 1 - uy)))
    local grain = (hash(vx, vy) - 0.5) * 0.03
    local c
    if horizon > 0 and uy >= horizon then
      local t = (uy - horizon) / (1 - horizon)
      local halfw = 0.36 + (0.8 - 0.36) * t
      local u = (ux - 0.5) / halfw
      if math.abs(u) <= 1 then
        local depth = (uy - horizon) * 360
        if depth < 2 or math.abs(u) > 1 - 2 / (halfw * 640) then c = T.edge
        elseif dot(vx, vy, L * 0.42, 3) then c = T.light
        elseif dot(vx, vy, (1 - L) * 0.5 + (1 - t) * 0.2, 0) then c = T.dark
        else c = T.base end
      end
    end
    if not c then
      if layer == "table" then return 0, 0, 0, 0 end
      local tone = L * vig
      if dot(vx, vy, smooth(0.55, 1.25, tone), 3) then c = P.dot
      elseif dot(vx, vy, smooth(0.0, 0.8, tone), 0) then c = P.mid
      else c = P.dark end
    end
    return math.max(0, math.min(1, c[1] + grain)), math.max(0, math.min(1, c[2] + grain)), math.max(0, math.min(1, c[3] + grain)), 1
  end
end
M.painter = painter

local cache, order = {}, {}
local function bake(key, w, h, ox, oy, paint)
  if cache[key] ~= nil then return cache[key] or nil end
  local ok, img = pcall(function()
    local data = love.image.newImageData(w, h)
    for y = 0, h - 1 do
      for x = 0, w - 1 do data:setPixel(x, y, paint(x - ox, y - oy)) end
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

local function presetOf(bg)
  local name = bakes.STAGES[bg.preset or "menu"] and (bg.preset or "menu") or "menu"
  local ramp = M.PAPER[bg.ramp or "felt"] and (bg.ramp or "felt") or "felt"
  return name, ramp
end

-- The still backdrop for a scene's bg, one image pixel per virtual pixel, covering the visible
-- area. nil where images can't be built from pixels (the caller then uses the baked PNGs).
function M.image(bg, vw, vh, ox, oy)
  local name, ramp = presetOf(bg)
  local w, h = math.ceil(vw), math.ceil(vh)
  return bake(("%s:%s:%d:%d:%d:%d"):format(name, ramp, w, h, ox, oy), w, h, ox, oy, painter(bakes.STAGES[name], ramp))
end

local function send(sh, name, value) pcall(sh.send, sh, name, value) end

-- Point the live shader at a backdrop. view: { k = canvas pixels per virtual pixel }.
-- pulse: { x, y, radius, strength } in virtual pixels, or nil.
local function aim(sh, preset, ramp, k, ox, oy, time, flow, pulse, layer)
  local P = M.PAPER[ramp]
  send(sh, "pix", k)
  send(sh, "origin", { ox, oy })
  send(sh, "horizon", preset.horizon or 0)
  send(sh, "light", preset.light)
  send(sh, "radius", preset.radius)
  send(sh, "power", preset.power)
  send(sh, "dark", { P.dark[1], P.dark[2], P.dark[3] })
  send(sh, "mid", { P.mid[1], P.mid[2], P.mid[3] })
  send(sh, "dotc", { P.dot[1], P.dot[2], P.dot[3] })
  send(sh, "time", time)
  send(sh, "flow", flow)
  send(sh, "pulse", pulse or { 0, 0, 0, 0 })
  send(sh, "layer", layer or 0)
end

-- Draw the backdrop over the whole canvas (cw x ch canvas pixels). Returns false if it couldn't.
-- opts: k, ox, oy, vw, vh, time, flow (0..1), pulse, shader (shaders.paper or nil)
function M.draw(bg, cw, ch, o)
  local name, ramp = presetOf(bg)
  local preset = bakes.STAGES[name]
  if o.shader then
    aim(o.shader, preset, ramp, o.k, o.ox, o.oy, o.time, o.flow, o.pulse, 0)
    lg.setShader(o.shader)
    lg.setColor(1, 1, 1)
    lg.rectangle("fill", 0, 0, cw, ch)
    lg.setShader()
    return true
  end
  local img = M.image(bg, o.vw, o.vh, o.ox, o.oy)
  if not img then return false end
  lg.setColor(1, 1, 1)
  lg.draw(img, 0, 0, 0, o.k, o.k)
  return true
end

-- Just a table, from `horizon` (virtual pixels from the top of the safe area) down, over
-- whatever is already drawn: the menu puts the Overseer behind it. Call from a scene's draw.
function M.tableFront(horizon)
  local preset = { light = { 0.5, 0.85 }, radius = 0.9, power = 1.0, horizon = horizon / 360 }
  local sh = G.paperShader and G.paperShader()
  if sh then
    aim(sh, preset, "felt", G.K, G.OX, G.OY, G.time % 3600, 0, nil, 1)
    lg.setShader(sh)
    lg.setColor(1, 1, 1)
    lg.rectangle("fill", -G.OX, horizon, G.VW, G.VH - horizon - G.OY + 1)
    lg.setShader()
    return
  end
  local w, h = math.ceil(G.VW), math.ceil(G.VH)
  local img = bake(("table:%d:%d:%d:%d:%d"):format(horizon, w, h, G.OX, G.OY), w, h, G.OX, G.OY, painter(preset, "felt", "table"))
  if img then
    lg.setColor(1, 1, 1)
    lg.draw(img, -G.OX, -G.OY)
  end
end

return M
