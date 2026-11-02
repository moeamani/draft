-- End of a festival: your placing, the champion, then the Arena moves on.
local art = require("src.ui.art")
local festival = require("src.core.festival")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local overlays = require("src.ui.overlays")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c
local T = theme.T

function S:enter()
  self.t = 0
  self.news = nil
  local run = G.save.run
  self.victory = run and run.outcome == "victory"
  S.bg = { horizon = 0, light = { 0.5, 0.35 }, radius = 0.9, power = 1.0, ramp = self.victory and "felt" or "blood" }
  self.logo = art.bake(G.images["logo-lockup"], 200)
  self.flames = art.bake(G.images.shadow, 480)
  sfx.play(self.victory and "win" or "lose")
end

function S:update(dt)
  self.t = self.t + dt
  if self.victory and love.math.random() < dt * 3 then fx.burst(love.math.random(60, 580), love.math.random(30, 140), C.gold, 12, 120) end
end

function S:draw()
  local save = G.save
  if self.news then return self:drawNews() end
  local run = save.run
  if not run then return end
  local f = run.festival
  if self.victory then
    lg.setColor(1, 1, 1)
    lg.draw(self.logo, 220, 10)
  else
    lg.setColor(0.55, 0.55, 0.6)
    lg.draw(self.flames, 80, 360 - self.flames:getHeight() + 40 + math.floor(math.sin(self.t * 5) * 2))
  end
  local ty = self.victory and 124 or 40
  local placing = festival.PLACING_NAMES[f.placing or "group"]
  gfx.wavy(self.victory and "Champion of the Festival" or placing, T.title(), 320, ty, self.victory and C.gold or C.paper, self.t, 2)
  local champ = f.champion and f.entrants[f.champion]
  local sub = self.victory and ("The crowd chants " .. save.playerName .. "'s name.") or (champ and (champ.name .. " won " .. f.name .. ".") or "The festival ends.")
  gfx.text(sub, T.big(), 320, ty + 32, C.paper2, { align = "center" })
  local stats = { { run.stats.won, "Wins" }, { run.stats.lost, "Losses" }, { run.stats.slain, "Slain" }, { run.stats.recruited, "Recruited" }, { run.stats.branded, "Branded" } }
  local sy = ty + 64
  for i, st in ipairs(stats) do
    local x = 320 + (i - 3) * 78
    gfx.panel(x - 36, sy, 72, 52, C.deep, { border = C.goldDark })
    gfx.text(tostring(st[1]), T.huge(), x, sy + 2, C.paper, { align = "center" })
    gfx.text(st[2], T.body(), x, sy + 31, C.paper2, { align = "center" })
  end
  if widgets.button("s_br", 180, sy + 66, 132, 28, "Final bracket", { font = T.body() }) then overlays.standings(f) end
  if widgets.button("s_go", 320, sy + 66, 160, 28, "The Arena moves on", { color = C.red, font = T.body() }) then
    self.news = game.arenaMovesOn(save)
    if #self.news == 0 then self.news = { "The Hands lick their wounds and wait." } end
    G.persist()
    sfx.play("burn", 0.8)
  end
end

function S:drawNews()
  local save = G.save
  gfx.wavy("The Arena Moves On", T.title(), 320, 8, C.gold, self.t, 1)
  local y = 40
  for _, t in ipairs(self.news) do
    local h = gfx.wrapHeight(t, T.body(), 560)
    if y + h > 122 then break end
    gfx.textf(t, T.body(), 40, y, 560, "center", C.paper)
    y = y + h + 2
  end
  for i, h in ipairs(save.hands) do overlays.nemesisCard(h, i, 14 + (i - 1) * 154, 126, 150, 182) end
  if widgets.button("n_again", 180, 318, 136, 30, "Next festival", { color = C.red }) then
    game.startRun(save)
    G.persist()
    G.go("hub", { fresh = true })
  end
  if widgets.button("n_title", 324, 318, 136, 30, "Title") then G.go("title") end
end

return S
