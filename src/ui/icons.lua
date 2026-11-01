-- Small vector icons drawn with primitives (the fonts don't carry symbol glyphs).
local lg = love.graphics

local M = {}

local function poly(...) lg.polygon("fill", ...) end

local draw = {}

draw.sword = function(s)
  poly(-0.08 * s, 0.25 * s, 0.08 * s, 0.25 * s, 0.08 * s, -0.4 * s, 0, -0.5 * s, -0.08 * s, -0.4 * s)
  lg.rectangle("fill", -0.28 * s, 0.22 * s, 0.56 * s, 0.1 * s)
  lg.rectangle("fill", -0.06 * s, 0.3 * s, 0.12 * s, 0.2 * s)
end
draw.orb = function(s)
  lg.circle("fill", 0, 0, 0.36 * s)
  lg.setColor(1, 1, 1, 0.55)
  lg.circle("fill", -0.12 * s, -0.12 * s, 0.1 * s)
end
draw.moon = function(s)
  -- crescent: outer arc on the left, inner arc back up the right
  local pts = {}
  for i = 0, 16 do
    local a = math.pi * 0.3 + i / 16 * math.pi * 1.4
    pts[#pts + 1] = math.cos(a) * 0.42 * s
    pts[#pts + 1] = math.sin(a) * 0.42 * s
  end
  for i = 16, 0, -1 do
    local a = math.pi * 0.42 + i / 16 * math.pi * 1.16
    pts[#pts + 1] = 0.16 * s + math.cos(a) * 0.3 * s
    pts[#pts + 1] = -0.02 * s + math.sin(a) * 0.36 * s
  end
  local ok, tris = pcall(love.math.triangulate, pts)
  if ok then for _, t in ipairs(tris) do lg.polygon("fill", t) end else lg.circle("fill", 0, 0, 0.35 * s) end
end
draw.flower = function(s)
  for i = 0, 4 do
    local a = i / 5 * math.pi * 2
    lg.circle("fill", math.cos(a) * 0.22 * s, math.sin(a) * 0.22 * s, 0.17 * s)
  end
  lg.setColor(1, 0.9, 0.5)
  lg.circle("fill", 0, 0, 0.12 * s)
end
draw.arrow = function(s)
  lg.setLineWidth(0.12 * s)
  lg.line(-0.35 * s, 0.35 * s, 0.25 * s, -0.25 * s)
  lg.setLineWidth(1)
  poly(0.4 * s, -0.4 * s, 0.05 * s, -0.32 * s, 0.32 * s, -0.05 * s)
end
draw.nine = function(s)
  lg.setLineWidth(0.12 * s)
  lg.circle("line", 0, -0.12 * s, 0.2 * s)
  lg.line(0.2 * s, -0.12 * s, 0.16 * s, 0.4 * s)
  lg.setLineWidth(1)
end
draw.eye = function(s)
  poly(-0.45 * s, 0, -0.2 * s, -0.22 * s, 0.2 * s, -0.22 * s, 0.45 * s, 0, 0.2 * s, 0.22 * s, -0.2 * s, 0.22 * s)
  lg.setColor(0, 0, 0)
  lg.circle("fill", 0, 0, 0.13 * s)
end
draw.cross = function(s)
  lg.rectangle("fill", -0.1 * s, -0.38 * s, 0.2 * s, 0.76 * s)
  lg.rectangle("fill", -0.38 * s, -0.1 * s, 0.76 * s, 0.2 * s)
end
draw.note = function(s)
  lg.ellipse("fill", -0.12 * s, 0.25 * s, 0.17 * s, 0.13 * s)
  lg.rectangle("fill", 0.0 * s, -0.4 * s, 0.07 * s, 0.65 * s)
  poly(0.05 * s, -0.4 * s, 0.32 * s, -0.25 * s, 0.05 * s, -0.18 * s)
end
draw.notes = function(s)
  lg.ellipse("fill", -0.25 * s, 0.25 * s, 0.14 * s, 0.11 * s)
  lg.ellipse("fill", 0.2 * s, 0.18 * s, 0.14 * s, 0.11 * s)
  lg.rectangle("fill", -0.15 * s, -0.35 * s, 0.07 * s, 0.6 * s)
  lg.rectangle("fill", 0.3 * s, -0.42 * s, 0.07 * s, 0.6 * s)
  poly(-0.15 * s, -0.35 * s, 0.37 * s, -0.42 * s, 0.37 * s, -0.28 * s, -0.15 * s, -0.21 * s)
end
draw.up = function(s)
  for i = 0, 1 do
    local y = (i * 0.3 - 0.1) * s
    poly(-0.32 * s, y + 0.18 * s, 0, y - 0.15 * s, 0.32 * s, y + 0.18 * s, 0.2 * s, y + 0.18 * s, 0, y - 0.02 * s, -0.2 * s, y + 0.18 * s)
  end
end
draw.umbrella = function(s)
  lg.arc("fill", 0, 0, 0.42 * s, math.pi, math.pi * 2)
  lg.rectangle("fill", -0.04 * s, 0, 0.08 * s, 0.4 * s)
  lg.setLineWidth(0.08 * s)
  lg.arc("line", "open", -0.12 * s, 0.4 * s, 0.12 * s, 0, math.pi)
  lg.setLineWidth(1)
end
draw.cloud = function(s)
  lg.circle("fill", -0.18 * s, 0.05 * s, 0.2 * s)
  lg.circle("fill", 0.08 * s, -0.08 * s, 0.26 * s)
  lg.circle("fill", 0.28 * s, 0.08 * s, 0.17 * s)
  lg.rectangle("fill", -0.18 * s, 0.05 * s, 0.46 * s, 0.2 * s)
end
draw.sun = function(s)
  lg.circle("fill", 0, 0, 0.22 * s)
  lg.setLineWidth(0.08 * s)
  for i = 0, 7 do
    local a = i / 8 * math.pi * 2
    lg.line(math.cos(a) * 0.3 * s, math.sin(a) * 0.3 * s, math.cos(a) * 0.45 * s, math.sin(a) * 0.45 * s)
  end
  lg.setLineWidth(1)
end
draw.box = function(s)
  lg.rectangle("fill", -0.38 * s, -0.12 * s, 0.76 * s, 0.5 * s)
  poly(-0.3 * s, -0.12 * s, -0.2 * s, -0.42 * s, -0.08 * s, -0.12 * s)
  poly(0.08 * s, -0.12 * s, 0.2 * s, -0.42 * s, 0.3 * s, -0.12 * s)
end
draw.burst = function(s)
  local pts = {}
  for i = 0, 15 do
    local a = i / 16 * math.pi * 2
    local r = (i % 2 == 0 and 0.45 or 0.22) * s
    pts[#pts + 1] = math.cos(a) * r
    pts[#pts + 1] = math.sin(a) * r
  end
  local tris = love.math.triangulate(pts)
  for _, t in ipairs(tris) do lg.polygon("fill", t) end
end
draw.heart = function(s)
  lg.circle("fill", -0.18 * s, -0.08 * s, 0.22 * s)
  lg.circle("fill", 0.18 * s, -0.08 * s, 0.22 * s)
  poly(-0.39 * s, 0, 0.39 * s, 0, 0, 0.42 * s)
end
draw.fish = function(s)
  lg.ellipse("fill", -0.05 * s, 0, 0.32 * s, 0.18 * s)
  poly(0.2 * s, 0, 0.45 * s, -0.22 * s, 0.45 * s, 0.22 * s)
  lg.setColor(0, 0, 0, 0.8)
  lg.circle("fill", -0.2 * s, -0.04 * s, 0.04 * s)
end
draw.gem = function(s)
  poly(0, -0.45 * s, 0.32 * s, 0, 0, 0.45 * s, -0.32 * s, 0)
  lg.setColor(1, 1, 1, 0.4)
  poly(0, -0.45 * s, 0.32 * s, 0, 0, 0)
end
draw.crown = function(s)
  poly(-0.4 * s, 0.3 * s, -0.4 * s, -0.25 * s, -0.2 * s, 0.02 * s, 0, -0.35 * s, 0.2 * s, 0.02 * s, 0.4 * s, -0.25 * s, 0.4 * s, 0.3 * s)
end
draw.skull = function(s)
  lg.circle("fill", 0, -0.08 * s, 0.32 * s)
  lg.rectangle("fill", -0.18 * s, 0.1 * s, 0.36 * s, 0.25 * s)
  lg.setColor(0, 0, 0, 0.9)
  lg.circle("fill", -0.12 * s, -0.08 * s, 0.08 * s)
  lg.circle("fill", 0.12 * s, -0.08 * s, 0.08 * s)
end
draw.cup = function(s)
  poly(-0.3 * s, -0.25 * s, 0.25 * s, -0.25 * s, 0.18 * s, 0.3 * s, -0.23 * s, 0.3 * s)
  lg.setLineWidth(0.08 * s)
  lg.arc("line", "open", 0.27 * s, 0, 0.13 * s, -math.pi / 2, math.pi / 2)
  lg.line(-0.1 * s, -0.35 * s, -0.05 * s, -0.48 * s)
  lg.line(0.08 * s, -0.35 * s, 0.13 * s, -0.48 * s)
  lg.setLineWidth(1)
end
draw.star = function(s)
  local pts = {}
  for i = 0, 9 do
    local a = i / 10 * math.pi * 2 - math.pi / 2
    local r = (i % 2 == 0 and 0.45 or 0.2) * s
    pts[#pts + 1] = math.cos(a) * r
    pts[#pts + 1] = math.sin(a) * r
  end
  for _, t in ipairs(love.math.triangulate(pts)) do lg.polygon("fill", t) end
end
draw.bell = function(s)
  poly(-0.32 * s, 0.25 * s, -0.22 * s, -0.2 * s, 0, -0.38 * s, 0.22 * s, -0.2 * s, 0.32 * s, 0.25 * s)
  lg.circle("fill", 0, 0.32 * s, 0.09 * s)
end
draw.diamond = function(s) poly(0, -0.4 * s, 0.3 * s, 0, 0, 0.4 * s, -0.3 * s, 0) end
draw.leaf = function(s)
  lg.ellipse("fill", 0, 0, 0.18 * s, 0.4 * s)
end
draw.yarn = function(s)
  lg.circle("fill", 0, 0, 0.36 * s)
  lg.setColor(0, 0, 0, 0.3)
  lg.setLineWidth(0.05 * s)
  lg.arc("line", "open", -0.15 * s, 0, 0.3 * s, -1, 1)
  lg.arc("line", "open", 0.1 * s, 0.1 * s, 0.25 * s, 2, 4)
  lg.setLineWidth(1)
end
draw.banner = function(s)
  lg.rectangle("fill", -0.32 * s, -0.42 * s, 0.06 * s, 0.84 * s)
  poly(-0.26 * s, -0.4 * s, 0.38 * s, -0.4 * s, 0.25 * s, -0.18 * s, 0.38 * s, 0.04 * s, -0.26 * s, 0.04 * s)
end
draw.cream = function(s)
  lg.ellipse("fill", 0, 0.12 * s, 0.42 * s, 0.16 * s)
  lg.setColor(1, 1, 1)
  lg.ellipse("fill", 0, 0.06 * s, 0.3 * s, 0.09 * s)
end
draw.market = draw.fish
draw.shrine = function(s)
  draw.star(s * 0.9)
end

M.ABILITY_ICON = {
  smite = "sword", inspire = "orb", hex = "moon", litter = "flower", pounce = "arrow", ninelives = "nine",
  stray = "eye", groom = "cross", purr = "note", yowl = "notes", muster = "up", downpour = "umbrella",
  moonfog = "cloud", sunbeam = "sun", warhorn = "notes", box = "box", hairball = "burst",
}

function M.draw(name, x, y, size, col, rot)
  local f = draw[name]
  if not f then return end
  lg.push()
  lg.translate(x, y)
  if rot then lg.rotate(rot) end
  if col then lg.setColor(col[1], col[2], col[3], col[4] or 1) end
  f(size)
  lg.pop()
end

return M
