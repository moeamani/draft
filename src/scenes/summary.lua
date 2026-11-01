local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local hud = require("src.ui.hud")
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
  sfx.play(self.victory and "win" or "lose")
end

function S:update(dt)
  self.t = self.t + dt
  if self.victory and math.random() < dt * 3 then fx.burst(math.random(200, 1400), math.random(100, 400), C.gold, 16, 400, 6) end
end

function S:draw()
  local save = G.save
  if self.news then return self:drawNews() end
  local run = save.run
  if not run then return end
  if self.victory then
    local logo = G.images["logo-lockup"]
    lg.setColor(1, 1, 1)
    lg.draw(logo, 800, 190, math.sin(self.t) * 0.02, 0.32, 0.32, logo:getWidth() / 2, logo:getHeight() / 2)
  else
    local fl = G.images.shadow
    lg.setColor(1, 1, 1, 0.5)
    lg.draw(fl, 800, 960, 0, 1, 1 + math.sin(self.t * 6) * 0.02, fl:getWidth() / 2, fl:getHeight())
  end
  gfx.wavy(self.victory and "Champion of the Arena" or "Your ninth life is spent", theme.font("bold", 80), 800, 330, self.victory and C.gold or C.red, self.t, 4)
  local killer = run.killedBy and game.findNemesis(save, run.killedBy)
  local sub = self.victory and ("All Four Hands have faced " .. save.playerName .. ". For now.") or (killer and (killer.name .. " " .. killer.epithet .. " ended your run.") or "The Arena claims another champion.")
  gfx.text(sub, theme.font("italic", 26), 800, 430, C.paper2, { align = "center" })
  local stats = {
    { hud.roman(math.min(4, run.ring)), "ring reached" }, { run.stats.won, "duels won" }, { run.stats.slain, "warlords slain" },
    { run.stats.recruited, "recruited" }, { run.stats.branded, "branded" },
  }
  for i, st in ipairs(stats) do
    local x = 800 + (i - 3) * 210
    gfx.panel(x - 90, 500, 180, 120, C.ink2, { border = { 1, 1, 1, 0.1 }, lw = 2 })
    gfx.text(tostring(st[1]), theme.font("bold", 54), x, 508, C.paper, { align = "center" })
    gfx.text(st[2]:upper(), theme.font("monoBold", 13), x, 584, C.muted, { align = "center", shadow = 0 })
  end
  if widgets.button("s_go", 560, 700, 480, 80, "The Arena moves on...", { color = C.red, size = 32 }) then
    self.news = game.arenaMovesOn(save)
    if #self.news == 0 then self.news = { "The Hands lick their wounds and wait." } end
    G.persist()
    sfx.play("burn", 0.8)
  end
end

function S:drawNews()
  local save = G.save
  gfx.wavy("The Arena Moves On", theme.font("bold", 64), 800, 30, C.paper, self.t, 3)
  local y = 120
  for _, t in ipairs(self.news) do
    y = y + gfx.textf(t, theme.font("serif", 22), 250, y, 1100, "center", C.paper2) + 8
  end
  for i, h in ipairs(save.hands) do
    overlays.nemesisCard(h, i, 50 + (i - 1) * 380, math.max(y + 20, 270), 360, { compact = true, h = 300 })
  end
  if widgets.button("n_again", 470, 800, 320, 70, "Start a new run", { color = C.red }) then
    game.startRun(save)
    G.persist()
    G.go("map", { dealt = true })
  end
  if widgets.button("n_title", 810, 800, 320, 70, "Title") then G.go("title") end
end

return S
