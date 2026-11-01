-- Top bar shown during a festival.
local cards = require("src.core.cards")
local charms = require("src.core.charms")
local festival = require("src.core.festival")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local M = {}
local C = theme.c

function M.roman(n) return ({ "I", "II", "III", "IV", "V", "VI" })[n] or tostring(n) end

function M.charmRow(run, x, y)
  for i, id in ipairs(run.charms) do
    local cx = x + (i - 1) * 16
    local info = charms.CHARMS[id]
    local over = widgets.inside(cx, y, 15, 15)
    gfx.panel(cx, y, 15, 15, over and C.ink3 or C.ink2, { border = C.goldDark })
    icons.draw(info.icon, cx + 7, y + 7, info.color and cards.COATS[info.color].color or C.gold)
    if over then
      widgets.tooltip(function() widgets.infoBox(cx - 60, y + 18, 140, { { text = info.name, color = C.gold }, { text = info.desc } }) end)
    end
  end
end

function M.draw(run, opts)
  opts = opts or {}
  local overlays = require("src.ui.overlays")
  local f = run.festival
  gfx.panel(4, 4, theme.W - 8, 24, C.deep)
  gfx.text(f.name, theme.T.headS(), 10, 6, C.gold)
  gfx.text(festival.stageLabel(f):upper(), theme.T.tiny(), 10, 18, C.muted)
  icons.draw("fish", 228, 16, C.gold)
  gfx.text(tostring(run.fish), theme.T.numL(), 236, 4, C.gold)
  M.charmRow(run, 280, 9)
  if not opts.noButtons then
    if widgets.button("hud_deck", 420, 8, 64, 16, "Deck " .. #run.deck, { font = theme.T.num() }) then overlays.deck(run.deck) end
    if widgets.button("hud_hands", 488, 8, 92, 16, "The Four Hands", { font = theme.T.num() }) then overlays.hands() end
    if widgets.button("hud_menu", 584, 8, 48, 16, "Menu", { font = theme.T.num() }) then overlays.pause() end
  end
end

return M
