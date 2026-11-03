-- Procedural cat portraits: drawn with primitives at low resolution, then quantised with the
-- Figma dither (Bayer 16x16, 8 levels) on the GPU. Results are cached per seed.
local rngm = require("src.core.rng")
local shaders = require("src.ui.shaders")
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
local hex = theme.hex

local FUR = {
  ember = { hex("#d0602a"), hex("#f39a4a"), hex("#7a2c12") },
  tide = { hex("#647a93"), hex("#a7bccf"), hex("#36465a") },
  gilt = { hex("#d9b56a"), hex("#f3deaa"), hex("#8c6a2c") },
  shadow = { hex("#1a1d22"), hex("#343a42"), hex("#050807") },
}
local function col(c, a) lg.setColor(c[1], c[2], c[3], a or c[4] or 1) end
local function tri(pts, c) col(c); lg.polygon("fill", pts) end
local function ell(x, y, rx, ry, c, rot)
  col(c)
  lg.push(); lg.translate(x, y); if rot then lg.rotate(rot) end
  lg.ellipse("fill", 0, 0, math.max(0.1, rx), math.max(0.1, ry), 24)
  lg.pop()
end
local function line(pts, c, w) col(c); lg.setLineWidth(w or 1); lg.line(pts); lg.setLineWidth(1) end

local function vgrad(w, h, c1, c2)
  local mesh = lg.newMesh({ { 0, 0, 0, 0, c1[1], c1[2], c1[3], 1 }, { w, 0, 1, 0, c1[1], c1[2], c1[3], 1 },
    { w, h, 1, 1, c2[1], c2[2], c2[3], 1 }, { 0, h, 0, 1, c2[1], c2[2], c2[3], 1 } }, "fan", "static")
  lg.setColor(1, 1, 1); lg.draw(mesh); mesh:release()
end
local function halo(x, y, r, c, a)
  local verts = { { x, y, 0, 0, c[1], c[2], c[3], a } }
  for i = 0, 24 do
    local t = i / 24 * math.pi * 2
    verts[#verts + 1] = { x + math.cos(t) * r, y + math.sin(t) * r, 0, 0, c[1], c[2], c[3], 0 }
  end
  local mesh = lg.newMesh(verts, "fan", "static")
  lg.setColor(1, 1, 1); lg.draw(mesh); mesh:release()
end

local C = theme.c

local function drawCat(W, H, o)
  local r = rngm.new(o.seed)
  local nx = function() return rngm.next(r) end
  local fur, furLight, furDark = FUR[o.coat][1], FUR[o.coat][2], FUR[o.coat][3]
  if not o.cutout then
    vgrad(W, H, o.menace and C.black or C.ink3, C.ink)
    local hc = o.menace and C.red or o.legendary and C.gold or (o.coat == "tide" and C.blue or o.coat == "ember" and C.red or o.coat == "gilt" and C.gold or C.cyan)
    halo(W / 2, H * 0.45, W * 0.55, hc, 0.55)
  end

  local cx = W / 2 + (nx() - 0.5) * 4
  local cy = H * 0.5 + (nx() - 0.5) * 3
  local rx, ry = 14 + nx() * 3, 12 + nx() * 2.5

  local garments = o.magic and { C.blue, C.red, C.ink2, C.gold } or (o.legendary and { C.gold } or { C.steel, hex("#4a5563"), C.red })
  local garment = garments[math.floor(nx() * #garments) + 1]
  ell(W / 2, H + 8, 25, 22, garment)
  if o.magic then line({ W / 2, H - 14, W / 2, H }, C.gold, 1.5) else line({ W / 2 - 18, H - 6, W / 2 + 18, H - 6 }, C.paper, 1) end

  if o.ability == "hex" and not o.legendary and not o.crown then
    col(C.black)
    lg.arc("fill", cx, cy - 1, rx + 6, math.pi, math.pi * 2)
    lg.polygon("fill", cx - rx - 6, cy - 1, cx + rx + 6, cy - 1, cx + rx + 8, H, cx - rx - 8, H)
  end

  local es = 0.85 + nx() * 0.2
  local L = { cx - rx * es, cy - ry * 0.35, cx - rx * 0.95, cy - ry - 9 - nx() * 3, cx - rx * 0.2, cy - ry * 0.85 }
  local R = { cx + rx * es, cy - ry * 0.35, cx + rx * 0.95, cy - ry - 9 - nx() * 3, cx + rx * 0.2, cy - ry * 0.85 }
  local earCol = o.coat == "gilt" and furDark or fur
  tri(L, earCol); tri(R, earCol)
  local function inner(a)
    return { a[1] * 0.7 + a[3] * 0.15 + a[5] * 0.15, a[2] * 0.7 + a[4] * 0.15 + a[6] * 0.15, a[3], a[4] + 3,
      a[5] * 0.7 + a[1] * 0.15 + a[3] * 0.15, a[6] * 0.7 + a[2] * 0.15 + a[4] * 0.15 }
  end
  tri(inner(L), C.red); tri(inner(R), C.red)

  ell(cx, cy, rx, ry, fur)
  if o.coat == "ember" then
    for i = -1, 1 do line({ cx + i * 4, cy - ry + 1, cx + i * 3, cy - ry + 6 }, furDark, 1.6) end
  elseif o.coat == "tide" then ell(cx, cy + 5, 8, 5, furLight)
  elseif o.coat == "gilt" then ell(cx, cy + 4, 9, 6, furLight)
  else ell(cx - 4, cy - 4, 5, 3, furLight, -0.4) end
  if o.coat ~= "shadow" then ell(cx, cy + 5, 6, 4, furLight) end

  local eyeCol = (o.menace or o.coat == "shadow") and C.red or (nx() < 0.5 and C.gold or C.cyan)
  local ey, ex = cy + 0.5, 6 + nx() * 1.2
  o.eyes = { cx - ex, ey, cx + ex, ey, eyeCol }
  local sq = o.menace and 1.5 or 2.6
  ell(cx - ex, ey, 3.4, sq, eyeCol, o.menace and 0.35 or 0)
  ell(cx + ex, ey, 3.4, sq, eyeCol, o.menace and -0.35 or 0)
  ell(cx - ex, ey, 0.9, sq * 0.85, C.black)
  ell(cx + ex, ey, 0.9, sq * 0.85, C.black)
  if o.menace then
    line({ cx - ex - 4, ey - 5, cx - ex + 3, ey - 2.5 }, C.black, 1.6)
    line({ cx + ex + 4, ey - 5, cx + ex - 3, ey - 2.5 }, C.black, 1.6)
  end
  tri({ cx - 1.8, cy + 4.5, cx + 1.8, cy + 4.5, cx, cy + 6.5 }, C.red)
  line({ cx - 3, cy + 8.5, cx, cy + 7, cx + 3, cy + 8.5 }, o.coat == "shadow" and hex("#4a5563") or furDark, 0.8)
  for i = 0, 2 do
    local wy = cy + 5 + i * 1.6
    line({ cx - 6, wy, cx - 17, wy - 2 + i * 2 }, C.paper, 0.6)
    line({ cx + 6, wy, cx + 17, wy - 2 + i * 2 }, C.paper, 0.6)
  end

  local top = cy - ry
  if o.crown or o.legendary then
    col(C.gold)
    lg.polygon("fill", cx - 9, top + 3, cx - 9, top - 4, cx - 5, top, cx, top - 6, cx + 5, top, cx + 9, top - 4, cx + 9, top + 3)
    ell(cx, top - 1, 1.2, 1.2, C.red)
  elseif o.ability == "hex" then
    col(C.black); lg.setLineWidth(3); lg.arc("line", "open", cx, cy - 1, rx + 2, math.pi * 1.08, math.pi * 1.92); lg.setLineWidth(1)
  elseif o.magic then
    local hats = { C.blue, C.red, C.ink2 }
    tri({ cx - 12, top + 4, cx + 12, top + 4, cx + 4 + nx() * 4, top - 16 }, hats[math.floor(nx() * 3) + 1])
    line({ cx - 13, top + 4, cx + 13, top + 4 }, C.gold, 1.6)
    ell(cx + 2, top - 5, 1, 1, C.paper)
  elseif nx() < 0.55 then
    col(C.steel)
    lg.arc("fill", cx, top + 5, rx * 0.95, math.pi, math.pi * 2)
    lg.rectangle("fill", cx - 1, top + 4, 2, 7)
    line({ cx - rx * 0.9, top + 5, cx + rx * 0.9, top + 5 }, hex("#4a5563"), 1)
  end
  if o.ability == "stray" then
    line({ cx - rx, cy - 5, cx + rx, cy - 1 }, C.black, 1.2)
    ell(cx - ex, ey, 3.8, 3, C.black)
  end
  if o.magic then
    local orb = o.ability == "hex" and C.red or C.cyan
    halo(W - 12, H - 12, 9, orb, 0.9)
    ell(W - 12, H - 12, 3.5, 3.5, orb)
    ell(W - 13, H - 13, 1, 1, C.paper)
  else
    line({ W - 9, H - 2, W - 9, H - 30 }, C.paper, 2)
    line({ W - 13, H - 10, W - 5, H - 10 }, C.gold, 2)
    if o.ability == "smite" then col(C.steel); lg.rectangle("fill", W - 14, H - 36, 10, 6) end
  end
  local scars = o.scars or 0
  if scars > 0 then line({ cx - ex - 4, ey - 6, cx - ex + 3, ey + 6 }, C.paper, 1.2) end
  if scars > 1 then line({ cx + 4, cy + 3, cx + 12, cy + 8 }, C.red, 1.2) end
  if scars > 2 then tri({ R[3] - 3, R[4] + 2, R[3] + 3, R[4] + 2, R[3], R[4] + 7 }, C.ink) end
end

local function drawSpecial(W, H, ability)
  vgrad(W, H, C.ink3, C.ink)
  local cx, cy = W / 2, H / 2
  if ability == "downpour" then
    ell(cx - 10, cy - 10, 12, 8, C.steel); ell(cx + 6, cy - 12, 14, 10, hex("#a7bccf")); ell(cx + 14, cy - 6, 9, 6, C.steel)
    for i = 0, 8 do line({ cx - 20 + i * 5, cy + 2 + (i % 3) * 3, cx - 24 + i * 5, cy + 14 + (i % 3) * 3 }, C.blue, 1.4) end
  elseif ability == "moonfog" then
    ell(cx + 8, cy - 10, 10, 10, hex("#f3deaa")); ell(cx + 13, cy - 13, 9, 9, C.ink2)
    for i = 0, 3 do lg.setColor(0.8, 0.83, 0.86, 0.35 + i * 0.1); lg.rectangle("fill", 4 + i * 3, cy + i * 6, W - 8 - i * 6, 3) end
  elseif ability == "sunbeam" then
    halo(cx, cy, W * 0.6, C.gold, 0.9)
    for i = 0, 11 do
      local a = i / 12 * math.pi * 2
      line({ cx + math.cos(a) * 12, cy + math.sin(a) * 12, cx + math.cos(a) * 26, cy + math.sin(a) * 26 }, C.gold, 1.5)
    end
    ell(cx, cy, 9, 9, C.paper)
  elseif ability == "warhorn" then
    col(C.gold)
    lg.polygon("fill", cx - 18, cy + 4, cx - 4, cy + 10, cx + 10, cy - 2, cx + 14, cy - 14, cx + 20, cy + 4, cx + 12, cy + 4, cx - 4, cy + 16, cx - 18, cy + 8)
    for i = 1, 3 do col(C.paper); lg.arc("line", "open", cx + 16, cy - 6, 4 + i * 4, -1.2, 0.6) end
  elseif ability == "box" then
    col(hex("#b07a3a")); lg.rectangle("fill", cx - 18, cy - 4, 36, 22)
    col(hex("#8c6a2c")); lg.rectangle("fill", cx - 18, cy - 4, 36, 4)
    tri({ cx - 12, cy - 4, cx - 8, cy - 14, cx - 4, cy - 4 }, hex("#1a1d22"))
    tri({ cx + 4, cy - 4, cx + 8, cy - 14, cx + 12, cy - 4 }, hex("#1a1d22"))
    ell(cx - 4, cy + 1, 1.6, 1.6, C.gold); ell(cx + 4, cy + 1, 1.6, 1.6, C.gold)
  elseif ability == "hairball" then
    for i = 0, 39 do
      local a = i / 40 * math.pi * 2
      local rr = 10 + (i % 4) * 2
      line({ cx, cy, cx + math.cos(a) * rr, cy + math.sin(a) * rr }, i % 2 == 1 and hex("#7a2c12") or hex("#d0602a"), 1.4)
    end
    ell(cx, cy, 8, 8, hex("#8c6a2c"))
  end
end

local cache = {}

-- Paint at a logical size (lw x lh), output at W x H real pixels, then dither 1:1.
-- Paint at a logical size (lw x lh), output at W x H real pixels, then quantise with the same
-- Figma dither as every other surface.
local function render(key, W, H, painter, lw, lh, transparent)
  if cache[key] then return cache[key] end
  local plates = require("src.ui.plates")
  local raw = lg.newCanvas(W, H)
  raw:setFilter("nearest", "nearest")
  lg.push("all")
  lg.origin()
  lg.setScissor() -- baking happens mid-frame, maybe inside a clipped overlay
  lg.setShader()
  lg.setCanvas(raw)
  lg.clear(0, 0, 0, transparent and 0 or 1)
  lg.scale(W / (lw or W), H / (lh or H))
  painter()
  lg.pop()
  local out = plates.dither(raw, W, H, transparent)
  raw:release()
  cache[key] = out
  return out
end

M.CARD_W, M.CARD_H = 50, 36

function M.card(def)
  local key = "card:" .. def.id .. ":" .. (def.scars or 0)
  return render(key, M.CARD_W, M.CARD_H, function()
    if def.kind == "special" then drawSpecial(64, 46, def.ability)
    else
      drawCat(64, 46, {
        seed = def.artSeed or rngm.hash(def.id), coat = def.coat == "none" and "shadow" or def.coat,
        magic = def.type == "magic", ability = def.ability, legendary = def.rarity == "legendary", scars = def.scars,
      })
    end
  end, 64, 46)
end

-- size: output pixels (32, 48, 96...). The cat is always painted on a 64x64 logical grid.
local eyes = {}
function M.portrait(o, size)
  size = size or 48
  local key = ("p:%d:%s:%s:%s:%s:%d:%s:%s:%d:%s"):format(o.seed, o.coat, tostring(o.magic), o.ability, tostring(o.legendary), o.scars or 0, tostring(o.crown), tostring(o.menace), size, tostring(o.cutout))
  local img = render(key, size, size, function()
    drawCat(64, 64, o)
    local e, k = o.eyes, size / 64
    eyes[key] = { e[1] * k, e[2] * k, e[3] * k, e[4] * k, e[5] }
  end, 64, 64, o.cutout)
  return img, eyes[key]
end

function M.nemesis(n, rank, size, cutout)
  return M.portrait({ seed = n.seed, coat = n.coat, magic = n.style == "hex" or n.style == "inspire" or n.style == "groom",
    ability = n.style, legendary = false, crown = rank == 1, scars = n.scars, menace = true, cutout = cutout }, size)
end

function M.player(name, size, cutout)
  return M.portrait({ seed = rngm.hash(name), coat = "gilt", magic = false, ability = "smite", legendary = false, cutout = cutout }, size)
end

function M.stray(foe, size, cutout)
  return M.portrait({ seed = foe.seed, coat = foe.coat, magic = false, ability = "none", legendary = false, menace = foe.elite, cutout = cutout }, size)
end

-- Portrait for any festival entrant. cutout: no backdrop, just the cat (for looming over the table).
function M.entrant(save, e, size, cutout)
  if e.kind == "player" then return M.player(save.playerName, size, cutout) end
  if e.kind == "hand" then
    local game = require("src.core.game")
    local n = game.findNemesis(save, e.id)
    if n then return M.nemesis(n, game.rankOf(save, n), size, cutout) end
  end
  return M.stray(e.foe or { seed = e.seed or 1, coat = e.coat or "shadow" }, size, cutout)
end

-- Turn a smooth image (Figma export) into dithered pixels at the given width.
function M.bake(img, w)
  return require("src.ui.plates").image(img, w)
end

return M
