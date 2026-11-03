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
  icons.draw("fish", 302, 19, C.gold)
  gfx.text(tostring(run.fish), T.big(), 310, 7, C.gold)
  M.charmRow(run, 352, 11)
  if not opts.noButtons then
    if widgets.button("hud_deck", 440, 8, 66, 20, "Pride " .. #run.deck) then overlays.deck(run.deck) end
    if widgets.button("hud_hands", 510, 8, 76, 20, "Four Hands") then overlays.hands() end
    if widgets.button("hud_menu", 590, 8, 42, 20, "Menu") then overlays.pause() end
  end
end

return M
