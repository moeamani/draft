-- The backdrop as data and plain maths, shared by the live shader (src/ui/shaders.lua), the
-- still bake in src/ui/print.lua and tools/switch/bake_assets.py, which runs this very file to
-- print PNG fallbacks. Nothing here touches love.*, so the three can't drift apart.
local M = {}

-- Backdrop presets: where the light falls, and (horizon > 0) where a table starts, as a
-- fraction of the screen's height.
M.STAGES = {
  menu = { horizon = 0, light = { 0.5, 0.4 }, radius = 0.95, power = 0.95 },
  vs = { horizon = 0, light = { 0.3, 0.45 }, radius = 0.8, power = 1.0 },
  match = { horizon = 100 / 360, light = { 0.5, 0.62 }, radius = 0.72, power = 1.0 },
  table = { horizon = 0, light = { 0.5, 0.45 }, radius = 0.85, power = 1.0 },
}

-- Paper stocks: ink green for the room, blood red for the Hands, the Overseer and defeats.
-- Three flat inks each: the paper, the halftone, and the brightest dots.
M.PAPER = {
  felt = { dark = "#0b2218", mid = "#123a28", dot = "#1a4d35" },
  blood = { dark = "#1e0a09", mid = "#3a1210", dot = "#571a15" },
}
M.TABLE = { base = "#c9a43a", dark = "#b08a29", light = "#dcbd58", edge = "#5e4410" }
M.CELL = 6 -- the screen's period along its diagonals; dots are about 4 pixels apart

function M.stageFile(preset, ramp) return ("assets/switch/stage-%s-%s.png"):format(preset, ramp) end

local function rgb(h)
  return { tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255 }
end
M.rgb = rgb

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

-- The colour of one virtual pixel at time 0: the shader's maths, in Lua. Returns a function
-- (vx, vy) -> r, g, b, a. layer "table" paints only the table and leaves the rest clear.
function M.painter(preset, stock, layer)
  local S = M.PAPER[stock] or M.PAPER.felt
  local P = { dark = rgb(S.dark), mid = rgb(S.mid), dot = rgb(S.dot) }
  local T = { base = rgb(M.TABLE.base), dark = rgb(M.TABLE.dark), light = rgb(M.TABLE.light), edge = rgb(M.TABLE.edge) }
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

return M
