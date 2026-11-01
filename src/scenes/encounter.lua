local art = require("src.ui.art")
local cards = require("src.core.cards")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local nemesis = require("src.core.nemesis")
local overlays = require("src.ui.overlays")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c
S.bg = { C.black, { 0.32, 0.04, 0.03 }, C.red, spin = 2.6 }

function S:enter(p)
  self.node = p.node
  self.t = 0
  local save = G.save
  self.n = game.currentBoss(save)
  self.rank = game.rankOf(save, self.n)
  self.line = nemesis.speak(love.math.newRandomGenerator and { s = math.floor(love.math.random() * 2 ^ 31) } or save.run.rng, self.n, nemesis.situation(self.n), save.playerName, self.rank)
  self.shown = 0
  sfx.play("burn", 0.7)
end

function S:update(dt)
  self.t = self.t + dt
  self.shown = math.min(#self.line, self.shown + dt * 45)
end

function S:draw()
  local n, t = self.n, self.t
  local fl = G.images.shadow
  local flick = 1 + math.sin(t * 7) * 0.015 + math.sin(t * 13) * 0.01
  lg.setColor(1, 1, 1, 0.95)
  lg.draw(fl, 800, 940, 0, 1.0, 1.0 * flick, fl:getWidth() / 2, fl:getHeight())

  local enter = math.min(1, t / 0.5)
  local e = 1 - (1 - enter) ^ 3
  local p = art.nemesis(n, self.rank)
  p:setFilter("nearest", "nearest")
  local px, py = 120 - (1 - e) * 500, 70
  gfx.radial(px + 190, py + 190, 300, { C.red[1], C.red[2], C.red[3], 0.35 }, { C.red[1], C.red[2], C.red[3], 0 })
  lg.setColor(0, 0, 0, 0.6)
  lg.rectangle("fill", px + 10, py + 14, 380, 380, 20)
  theme.set(C.red)
  lg.rectangle("fill", px - 6, py - 6, 392, 392, 22)
  lg.setColor(1, 1, 1)
  lg.draw(p, px, py, math.sin(t * 1.3) * 0.01, 380 / 64, 380 / 64)

  local ix = 570 + (1 - e) * 600
  gfx.panel(ix, 60, 970, 560, { 0.02, 0.03, 0.03, 0.88 }, { r = 22, depth = 10, border = { C.red[1], C.red[2], C.red[3], 0.6 }, lw = 2 })
  local coat = cards.COATS[n.coat]
  gfx.label((self.rank > 0 and nemesis.RANK_TITLES[self.rank] or "Warlord") .. "  -  Level " .. n.level .. "  -  " .. coat.name, ix + 34, 86, C.pale)
  gfx.text(n.name, theme.font("bold", 84), ix + 32, 104, C.paper, { shadow = 5 })
  gfx.text(n.epithet, theme.font("italic", 30), ix + 36, 196, C.muted)
  -- speech bubble with typewriter
  gfx.panel(ix + 34, 250, 900, 96, C.paper, { r = 18, depth = 6, sheen = false })
  lg.polygon("fill", ix + 34, 280, ix + 10, 296, ix + 34, 306)
  gfx.textf('"' .. self.line:sub(1, math.floor(self.shown)) .. '"', theme.font("italic", 27), ix + 60, 268, 850, "left", C.ink, { shadow = false })
  gfx.label("What you know", ix + 34, 372)
  overlays.traitChips(n, ix + 34, 398, 900, theme.font("monoBold", 16))
  gfx.label("Their story", ix + 34, 460)
  local y = 486
  for i = #n.history, math.max(1, #n.history - 3), -1 do
    y = y + gfx.textf(n.history[i].text, theme.font("serif", 18), ix + 34, y, 900, "left", C.muted, { shadow = false }) + 2
  end
  if widgets.button("fight", 640, 650, 320, 80, "Fight", { color = C.red, size = 40 }) then
    G.go("duel", { node = self.node })
  end
end

return S
