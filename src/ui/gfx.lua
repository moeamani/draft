-- Drawing helpers: chunky panels, text effects, gradients.
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}

function M.panel(x, y, w, h, col, opts)
  opts = opts or {}
  local r = opts.r or 14
  local depth = opts.depth or 6
  if depth > 0 then
    lg.setColor(0, 0, 0, 0.35 * (opts.alpha or 1))
    lg.rectangle("fill", x, y + depth, w, h, r, r)
  end
  theme.set(col, opts.alpha)
  lg.rectangle("fill", x, y, w, h, r, r)
  if opts.border then
    theme.set(opts.border, opts.alpha)
    lg.setLineWidth(opts.lw or 3)
    lg.rectangle("line", x, y, w, h, r, r)
    lg.setLineWidth(1)
  end
  if opts.sheen ~= false then
    lg.setColor(1, 1, 1, 0.05 * (opts.alpha or 1))
    lg.rectangle("fill", x + 4, y + 3, w - 8, math.min(h * 0.35, 30), r - 2, r - 2)
  end
end

-- Text with a hard drop shadow.
function M.text(str, font, x, y, col, opts)
  opts = opts or {}
  lg.setFont(font)
  local w = font:getWidth(str)
  local ox = 0
  if opts.align == "center" then ox = -w / 2 elseif opts.align == "right" then ox = -w end
  local sd = opts.shadow == nil and math.max(2, math.floor(font:getHeight() / 14)) or opts.shadow
  if sd > 0 then
    lg.setColor(0, 0, 0, 0.55 * (opts.alpha or 1))
    lg.print(str, math.floor(x + ox + sd * 0.6), math.floor(y + sd))
  end
  theme.set(col, opts.alpha)
  lg.print(str, math.floor(x + ox), math.floor(y))
  return w
end

function M.textf(str, font, x, y, w, align, col, opts)
  opts = opts or {}
  lg.setFont(font)
  if opts.shadow ~= false then
    lg.setColor(0, 0, 0, 0.5 * (opts.alpha or 1))
    lg.printf(str, math.floor(x + 1), math.floor(y + 2), w, align)
  end
  theme.set(col, opts.alpha)
  lg.printf(str, math.floor(x), math.floor(y), w, align)
  local _, lines = font:getWrap(str, w)
  return #lines * font:getHeight() * font:getLineHeight()
end

-- Per-letter bobbing text, for titles.
function M.wavy(str, font, cx, y, col, t, amp, opts)
  opts = opts or {}
  lg.setFont(font)
  local total = font:getWidth(str)
  local x = cx - total / 2
  amp = amp or 4
  for i = 1, #str do
    local ch = str:sub(i, i)
    local dy = math.sin(t * 2.2 + i * 0.45) * amp
    local rot = math.sin(t * 1.7 + i * 0.6) * 0.03
    lg.setColor(0, 0, 0, 0.5)
    lg.print(ch, x + 3, y + dy + 5, rot)
    theme.set(col, opts.alpha)
    lg.print(ch, x, y + dy, rot)
    x = x + font:getWidth(ch)
  end
end

function M.vgradient(x, y, w, h, c1, c2)
  local mesh = lg.newMesh({
    { x, y, 0, 0, c1[1], c1[2], c1[3], c1[4] or 1 },
    { x + w, y, 1, 0, c1[1], c1[2], c1[3], c1[4] or 1 },
    { x + w, y + h, 1, 1, c2[1], c2[2], c2[3], c2[4] or 1 },
    { x, y + h, 0, 1, c2[1], c2[2], c2[3], c2[4] or 1 },
  }, "fan", "static")
  lg.setColor(1, 1, 1, 1)
  lg.draw(mesh)
  mesh:release()
end

function M.radial(cx, cy, r, inner, outer, segs)
  segs = segs or 32
  local verts = { { cx, cy, 0.5, 0.5, inner[1], inner[2], inner[3], inner[4] or 1 } }
  for i = 0, segs do
    local a = i / segs * math.pi * 2
    verts[#verts + 1] = { cx + math.cos(a) * r, cy + math.sin(a) * r, 0, 0, outer[1], outer[2], outer[3], outer[4] or 0 }
  end
  local mesh = lg.newMesh(verts, "fan", "static")
  lg.setColor(1, 1, 1, 1)
  lg.draw(mesh)
  mesh:release()
end

-- A pill-shaped chip; returns its width.
function M.chip(str, x, y, kind, font)
  font = font or theme.font("mono", 13)
  local w = font:getWidth(str) + 18
  local h = font:getHeight() + 6
  local c = theme.c
  local bg, fg, br
  if kind == "strength" then bg, fg, br = { 0.91, 0.28, 0.23, 0.18 }, { 1, 0.72, 0.68 }, c.red
  elseif kind == "weakness" then bg, fg, br = { 0.25, 0.81, 0.56, 0.15 }, { 0.66, 1, 0.82 }, c.green
  else bg, fg, br = { 0, 0, 0, 0.25 }, { 0.55, 0.6, 0.63 }, { 0.3, 0.35, 0.39 } end
  theme.set(bg)
  lg.rectangle("fill", x, y, w, h, h / 2, h / 2)
  theme.set(br)
  lg.setLineWidth(1.5)
  lg.rectangle("line", x, y, w, h, h / 2, h / 2)
  lg.setLineWidth(1)
  theme.set(fg)
  lg.setFont(font)
  lg.print(str, x + 9, y + 3)
  return w, h
end

function M.label(str, x, y, col, align)
  M.text(str:upper(), theme.font("monoBold", 14), x, y, col or theme.c.pale, { align = align, shadow = 0 })
end

return M
