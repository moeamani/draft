-- Top bar shown during a run, plus shared run-level overlays.
local charms = require("src.core.charms")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local M = {}
local C = theme.c

local function roman(n) return ({ "I", "II", "III", "IV", "V" })[n] or tostring(n) end
M.roman = roman

function M.draw(run, opts)
  opts = opts or {}
  local overlays = require("src.ui.overlays")
  gfx.panel(14, 12, theme.W - 28, 62, { 0.02, 0.05, 0.04, 0.82 }, { r = 16, depth = 5, border = { 1, 1, 1, 0.08 }, lw = 2 })
  gfx.label("Ring " .. roman(math.min(run.ring, 4)), 36, 22)
  gfx.text(game.RING_NAMES[math.min(run.ring, 4)], theme.font("bold", 24), 36, 38, C.paper, { shadow = 2 })
  -- step pips
  local px = 300
  for i = 0, game.STEPS - 1 do
    local done, now = i < run.step, i == run.step
    local boss = i == game.STEPS - 1
    lg.push()
    lg.translate(px + i * 28, 43)
    if boss then lg.rotate(math.pi / 4) end
    theme.set(done and C.muted or now and C.gold or { 0.3, 0.38, 0.34 })
    if done or now then lg.rectangle("fill", -8, -8, 16, 16, boss and 2 or 8) else lg.setLineWidth(2); lg.rectangle("line", -8, -8, 16, 16, boss and 2 or 8); lg.setLineWidth(1) end
    lg.pop()
  end
  -- lives
  local lx = 420
  for i = 1, game.START_LIVES do
    local on = i <= run.lives
    local bob = on and math.sin(G.time * 3 + i) * 1.5 or 0
    icons.draw("heart", lx + (i - 1) * 26, 43 + bob, 24, on and C.red or { 0.2, 0.26, 0.23 })
  end
  -- fish
  icons.draw("fish", 680, 43, 30, C.gold)
  gfx.text(tostring(run.fish), theme.font("bold", 30), 700, 25, C.gold, { shadow = 2 })
  -- charms
  local cx = 800
  for i, id in ipairs(run.charms) do
    local x = cx + (i - 1) * 48
    local over = widgets.inside(x - 20, 22, 40, 40)
    gfx.panel(x - 20, 22, 40, 40, over and C.ink3 or C.ink2, { r = 10, depth = 3, border = C.gold, lw = 2, sheen = false })
    local info = charms.CHARMS[id]
    local col = info.color and require("src.core.cards").COATS[info.color].color or C.gold
    icons.draw(info.icon, x, 42, 26, col)
    if over then
      widgets.tooltip(function() widgets.infoBox(x - 150, 80, 320, { { text = info.name, font = theme.font("bold", 22), color = C.gold }, { text = info.desc } }) end)
    end
  end
  if not opts.noButtons then
    if widgets.button("hud_deck", 1136, 22, 140, 42, "Deck " .. #run.deck, { size = 20, color = C.ink3 }) then overlays.deck(run.deck) end
    if widgets.button("hud_hands", 1290, 22, 190, 42, "The Four Hands", { size = 20, color = C.ink3 }) then overlays.hands() end
    if widgets.button("hud_menu", 1494, 22, 80, 42, "Menu", { size = 20, color = C.ink3 }) then overlays.pause() end
  end
end

return M
