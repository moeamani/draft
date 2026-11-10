-- Top bar shown during a festival.
local cards = require("src.core.cards")
local charms = require("src.core.charms")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local plates = require("src.ui.plates")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local M = {}
local C = theme.c
local T = theme.T

function M.roman(n) return ({ "I", "II", "III", "IV", "V", "VI" })[n] or tostring(n) end

function M.charmRow(run, x, y)
  for i, id in ipairs(run.charms) do
    local cx = x + (i - 1) * 17
    local info = charms.CHARMS[id]
    local over = widgets.inside(cx, y, 15, 15)
    gfx.panel(cx, y, 15, 15, over and C.ink3 or C.ink2, { border = C.goldDark })
    icons.draw(info.icon, cx + 7, y + 7, info.color and cards.COATS[info.color].color or C.gold)
    if over then
      widgets.tooltip(function() widgets.infoBox(cx - 70, y + 18, 180, { { text = info.name, color = C.gold, font = T.big() }, { text = info.desc } }) end)
    end
  end
end

function M.draw(run, opts)
  opts = opts or {}
  local overlays = require("src.ui.overlays")
  local f = run.festival
  -- the festival's title card, as in the Figma "Card Name" plate
  local size = plates.textWidth(f.name, 20) <= 270 and 20 or 16
  plates.header(4, 4, theme.W - 8, 30, C.ink, f.name, { size = size, pad = 10 })
  -- the stake this festival is played at, if it's above Paper
  local stake = require("src.core.renown").STAKES[run.stake or 1]
  if (run.stake or 1) > 1 and stake then
    local nw = plates.textWidth(f.name, size)
    local cw = T.small():getWidth(stake.name) + 8
    if 14 + nw + 8 + cw < 292 then gfx.chip(stake.name, 14 + nw + 8, 11, "gold") end
  end
  icons.draw("fish", 302, 19, C.gold)
  gfx.text(tostring(run.fish), T.big(), 310, 7, C.gold)
  M.charmRow(run, 352, 11)
  if not opts.noButtons then
    if widgets.button("hud_deck", 440, 8, 66, 20, "Pride " .. #run.deck) then overlays.deck(run.deck) end
    if widgets.button("hud_hands", 510, 8, 76, 20, "Four Hands") then overlays.hands() end
    if widgets.button("hud_menu", 590, 8, 42, 20, "Menu") then overlays.pause() end
  end
end

-- ---------------------------------------------------------------- Renown

local CREST_LOOK = {
  stray = { "steel", "paw" }, ember = { "ember", "burst" }, tide = { "tide", "orb" }, gilt = { "gilt", "diamond" },
  moon = { "slate", "moon" }, velvet = { "velvet", "heart" }, merchant = { "goldDark", "fish" },
  lion = { "red", "sword" }, royal = { "gold", "crown" },
}

local function crestColor(key)
  if cards.COATS[key] then return cards.COATS[key].color end
  if key == "velvet" then return theme.CUSHION.velvet.col end
  return C[key] or C.steel
end

-- A heraldic shield for a Crest, centred on (x, y); about 20x24 at scale 1.
function M.crest(id, x, y, scale, locked)
  local love_ = love.graphics
  scale = scale or 1
  local look = CREST_LOOK[id] or CREST_LOOK.stray
  local col = locked and C.ink3 or crestColor(look[1])
  local function shield(w, h, c)
    theme.set(c)
    love_.polygon("fill", x - w, y - h, x + w, y - h, x + w, y + h * 0.3, x, y + h, x - w, y + h * 0.3)
  end
  shield(11 * scale, 13 * scale, C.black)
  shield(10 * scale, 12 * scale, locked and C.ink2 or theme.darken(col, 0.55))
  shield(8 * scale, 10 * scale, col)
  -- a pale chief across the top
  theme.set(C.white, locked and 0.08 or 0.22)
  love_.rectangle("fill", x - 8 * scale, y - 10 * scale, 16 * scale, 4 * scale)
  icons.draw(locked and "cross" or look[2], x, y + scale, locked and C.ink4 or C.paper, scale)
end

-- Renown bar: level badge, a bar from `from` to `to` (animated by t in 0..1) and the gain.
function M.renownBar(x, y, w, from, to, t)
  local renown = require("src.core.renown")
  local love_ = love.graphics
  local cur = from + (to - from) * math.min(1, math.max(0, t or 1))
  local L, into, need = renown.level(math.floor(cur))
  gfx.panel(x, y, w, 22, C.night, { border = C.goldDark })
  icons.draw("star", x + 10, y + 11, C.gold)
  gfx.text("Lv " .. L, T.bold(), x + 20, y + 4, C.goldText)
  local bx = x + 52
  local bw = w - 52 - (to > from and 40 or 6)
  theme.set(C.black)
  love_.rectangle("fill", bx, y + 7, bw, 8)
  theme.set(C.ink2)
  love_.rectangle("fill", bx + 1, y + 8, bw - 2, 6)
  local fill = math.floor((bw - 2) * (into / math.max(1, need)))
  theme.set(C.gold)
  love_.rectangle("fill", bx + 1, y + 8, fill, 6)
  theme.set(C.white, 0.35)
  love_.rectangle("fill", bx + 1, y + 8, fill, 2)
  if to > from then gfx.text("+" .. math.floor(to - from + 0.5), T.bold(), x + w - 6, y + 4, C.goldText, { align = "right" }) end
  return L
end

return M
