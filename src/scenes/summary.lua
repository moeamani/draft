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

function S:enter()
  self.t = 0
  self.news = nil
  local run = G.save.run
  self.victory = run and run.outcome == "victory"
  S.bg = self.victory and { C.ink, { 0.32, 0.25, 0.02 }, C.gold, spin = 2 } or { C.black, { 0.25, 0.04, 0.03 }, C.red, spin = 1 }
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
  lg.setColor(1, 1, 1)
  if self.victory then lg.draw(self.logo, 220, 14)
  else
    lg.setColor(1, 1, 1, 0.7)
    lg.draw(self.flames, 80, 360 - self.flames:getHeight() + math.floor(math.sin(self.t * 5) * 2))
  end
  local placing = festival.PLACING_NAMES[f.placing or "group"]
  gfx.wavy(self.victory and "Champion of the Festival" or placing, theme.T.headL(), 320, 132, self.victory and C.gold or C.paper, self.t, 2)
  local champ = f.champion and f.entrants[f.champion]
  local sub = self.victory and ("The crowd chants " .. save.playerName .. "'s name.") or (champ and (champ.name .. " won " .. f.name .. ".") or "The festival ends.")
  gfx.text(sub, theme.T.big(), 320, 178, C.paper2, { align = "center" })
  local stats = { { run.stats.won, "wins" }, { run.stats.lost, "losses" }, { run.stats.slain, "slain" }, { run.stats.recruited, "recruited" }, { run.stats.branded, "branded" } }
  for i, st in ipairs(stats) do
    local x = 320 + (i - 3) * 74
    gfx.panel(x - 34, 204, 68, 44, C.deep)
    gfx.text(tostring(st[1]), theme.T.numL(), x, 206, C.paper, { align = "center" })
    gfx.text(st[2]:upper(), theme.T.tiny(), x, 234, C.muted, { align = "center" })
  end
  if widgets.button("s_br", 196, 262, 120, 22, "Final bracket", { font = theme.T.num() }) then overlays.standings(f) end
  if widgets.button("s_go", 324, 262, 140, 22, "The Arena moves on", { color = C.red, font = theme.T.num() }) then
    self.news = game.arenaMovesOn(save)
    if #self.news == 0 then self.news = { "The Hands lick their wounds and wait." } end
    G.persist()
    sfx.play("burn", 0.8)
  end
end

function S:drawNews()
  local save = G.save
  gfx.wavy("The Arena Moves On", theme.T.head(), 320, 8, C.paper, self.t, 1)
  local y = 40
  for _, t in ipairs(self.news) do
    y = y + gfx.textf(t, theme.T.body(), 60, y, 520, "center", C.paper2) + 4
    if y > 120 then break end
  end
  for i, h in ipairs(save.hands) do overlays.nemesisCard(h, i, 14 + (i - 1) * 154, 128, 150, 180) end
  if widgets.button("n_again", 180, 318, 136, 28, "Next festival", { color = C.red }) then
    game.startRun(save)
    G.persist()
    G.go("hub", { fresh = true })
  end
  if widgets.button("n_title", 324, 318, 136, 28, "Title") then G.go("title") end
end

return S
