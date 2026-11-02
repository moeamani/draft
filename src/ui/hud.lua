-- Top bar shown during a festival.
local cards = require("src.core.cards")
local charms = require("src.core.charms")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
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
  gfx.panel(4, 4, theme.W - 8, 28, C.deep, { border = C.goldDark })
  local nameFont = T.big():getWidth(f.name) <= 282 and T.big() or T.body()
  gfx.text(f.name, nameFont, 10, nameFont == T.big() and 6 or 9, C.gold)
  icons.draw("fish", 302, 18, C.gold)
  gfx.text(tostring(run.fish), T.big(), 310, 6, C.gold)
  M.charmRow(run, 352, 10)
  if not opts.noButtons then
    if widgets.button("hud_deck", 444, 9, 62, 18, "Pride " .. #run.deck, { font = T.body() }) then overlays.deck(run.deck) end
    if widgets.button("hud_hands", 510, 9, 76, 18, "Four Hands", { font = T.body() }) then overlays.hands() end
    if widgets.button("hud_menu", 590, 9, 42, 18, "Menu", { font = T.body() }) then overlays.pause() end
  end
end

return M
