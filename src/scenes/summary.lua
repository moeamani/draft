-- End of a festival: your placing, the champion, then the Arena moves on.
local art = require("src.ui.art")
local festival = require("src.core.festival")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local overlays = require("src.ui.overlays")
local plates = require("src.ui.plates")
local audio = require("src.audio")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
S.music = "menu"
local C = theme.c
local T = theme.T

function S:enter()
  self.t = 0
  self.news = nil
  local run = G.save.run
  self.victory = run and run.outcome == "victory"
  S.bg = { preset = "menu", ramp = self.victory and "felt" or "blood" }
  self.logo = plates.image(G.images.logo, 220)
  audio.play(self.victory and "win" or "lose")
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
    plates.draw(self.logo, 320 - self.logo:getWidth() / 2, 8)
  else
    -- the Overseer watches you leave
    require("src.ui.overseer").draw(320, 372, 640, self.t, 0.8)
  end
  local ty = self.victory and 136 or 40
  local placing = festival.PLACING_NAMES[f.placing or "group"]
  plates.header(140, ty - 4, 360, 40, self.victory and C.goldDark or C.night, self.victory and "Champion of the Festival" or placing,
    { size = 28, streak = self.victory and 0.43 or 1.0, align = "center" })
  local champ = f.champion and f.entrants[f.champion]
  local sub = self.victory and ("The crowd chants " .. save.playerName .. "'s name.") or (champ and (champ.name .. " won " .. f.name .. ".") or "The festival ends.")
  gfx.text(sub, T.big(), 320, ty + 42, C.paper2, { align = "center" })
  local stats = { { run.stats.won, "Wins" }, { run.stats.lost, "Losses" }, { run.stats.slain, "Slain" }, { run.stats.recruited, "Recruited" }, { run.stats.branded, "Branded" } }
  local sy = ty + 72
  for i, st in ipairs(stats) do
    local x = 320 + (i - 3) * 78
    gfx.panel(x - 36, sy, 72, 52, C.ink2)
    gfx.text(tostring(st[1]), T.huge(), x, sy + 2, C.paper, { align = "center" })
    gfx.text(st[2], T.body(), x, sy + 31, C.paper2, { align = "center" })
  end
  if widgets.button("s_br", 180, sy + 66, 132, 28, "Final bracket", { font = T.body() }) then overlays.standings(f) end
  if run.story then
    -- story mode: the chapter's verdict comes next
    if widgets.button("s_go", 320, sy + 66, 160, 28, "Continue the story", { color = C.red }) then G.scenes.story.endChapter() end
    return
  end
  if widgets.button("s_go", 320, sy + 66, 160, 28, "The Arena moves on", { color = C.red, font = T.body() }) then
    self.news = game.arenaMovesOn(save)
    if #self.news == 0 then self.news = { "The Hands lick their wounds and wait." } end
    G.persist()
    audio.play("burn", 0.8)
  end
end

function S:drawNews()
  local save = G.save
  plates.header(150, 6, 340, 36, C.night, "The Arena Moves On", { size = 26, streak = 1.0, align = "center" })
  local y = 48
  for _, t in ipairs(self.news) do
    local h = gfx.wrapHeight(t, T.body(), 560)
    if y + h > 124 then break end
    gfx.textf(t, T.body(), 40, y, 560, "center", C.paper)
    y = y + h + 2
  end
  for i, h in ipairs(save.hands) do overlays.nemesisCard(h, i, 14 + (i - 1) * 154, 126, 150, 182) end
  if widgets.button("n_again", 180, 318, 136, 30, "Next festival", { color = C.red }) then
    G.scenes.menu.pickCrest(function(crest, stake)
      game.startRun(save, crest, stake)
      G.persist()
      G.go("hub", { fresh = true })
    end)
  end
  if widgets.button("n_title", 324, 318, 136, 30, "Main menu") then G.go("menu") end
end

return S
