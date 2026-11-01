local cards = require("src.core.cards")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local picker = require("src.ui.picker")
local theme = require("src.ui.theme")
local lg = love.graphics

local S = {}
local C = theme.c
S.bg = { C.ink, C.ink3, C.blue, spin = 0.9 }

function S:enter()
  self.t = 0
  self:deal()
end

function S:deal()
  local run = G.save.run
  local items = {}
  for i, id in ipairs(run.draftOptions) do items[i] = { id = id } end
  self.picker = picker.new(items, { x = 800, y = 410, scale = 1.12, gap = 60, dealFrom = { 800, 1200 } })
  local deckItems = {}
  for i, c in ipairs(run.deck) do deckItems[i] = c end
  self.deckRow = picker.new(deckItems, { x = 800, y = 800, scale = 0.34, gap = 6, noTooltip = false })
end

function S:update(dt)
  self.t = self.t + dt
  self.picker:update(dt)
  self.deckRow:update(dt)
end

function S:draw()
  local run = G.save.run
  gfx.wavy("Draft your Pride", theme.font("bold", 64), 800, 40, C.paper, self.t, 4)
  gfx.text(("Pick 1 of 3  -  %d / %d"):format(run.draftPicks + 1, game.DRAFT_PICKS), theme.font("monoBold", 18), 800, 126, C.gold, { align = "center", shadow = 0 })
  gfx.text("Physical cats fight in the Vanguard row, Magic cats in the Arcane row.", theme.font("serif", 19), 800, 154, C.muted, { align = "center", shadow = 0 })
  local i = self.picker:draw()
  gfx.label("Your pride so far (" .. #run.deck .. ")", 800, 700, C.pale, "center")
  self.deckRow:draw()
  if i then
    local v = self.picker.views[i]
    fx.burst(v.x, v.y, cards.RARITY_COLOR[v.def.rarity], 26, 420, 8)
    fx.addShake(4)
    local done, sibling = game.draftPick(G.save, run.draftOptions[i])
    if sibling then fx.toast(v.def.name .. " brought a sibling!", "good") end
    G.persist()
    if done then G.go("map") else self:deal() end
  end
end

return S
