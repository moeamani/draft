local cards = require("src.core.cards")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local hud = require("src.ui.hud")
local icons = require("src.ui.icons")
local overlays = require("src.ui.overlays")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local S = {}
local C = theme.c

function S:enter(p)
  self.t = 0
  self.tavern = p.tavern
  self.result = nil
  if self.tavern then
    self.title = "The Sleeping Fox"
    self.text = "A warm inn that smells of fish pie. The fox behind the bar is, as promised, asleep."
    S.bg = { C.ink, { 0.3, 0.18, 0.05 }, C.gold, spin = 0.6 }
  else
    self.ev = game.EVENTS[p.event]
    self.title = self.ev.title
    self.text = self.ev.text(G.save)
    S.bg = { C.ink, C.ink2, C.cyan, spin = 1.3 }
  end
end

function S:update(dt) self.t = self.t + dt end

local function finish()
  local save = G.save
  if save.run.lives <= 0 then
    game.finishRun(save, "defeat")
    G.persist()
    return G.go("summary")
  end
  game.advance(save)
  G.persist()
  G.go(save.run.phase == "over" and "summary" or "map")
end

function S:draw()
  local run = G.save.run
  hud.draw(run)
  icons.draw(self.tavern and "cup" or "star", 800, 190, 100, self.tavern and C.gold or C.cyan, math.sin(self.t * 1.5) * 0.15)
  gfx.wavy(self.title, theme.font("bold", 64), 800, 260, C.paper, self.t, 3)
  gfx.panel(300, 360, 1000, 170, { 0.03, 0.06, 0.05, 0.88 }, { r = 18, border = { 1, 1, 1, 0.1 }, lw = 2 })
  gfx.textf(self.result or self.text, theme.font("serif", 27), 340, 390, 920, "center", self.result and C.paper or C.paper2)
  if self.result then
    if widgets.button("ev_go", 640, 600, 320, 72, "Continue", { color = C.red }) then finish() end
    return
  end
  if self.tavern then
    if widgets.button("tv_rest", 380, 580, 400, 120, "Rest by the fire", { sub = "Recover 3 lives", disabled = run.lives >= game.START_LIVES, color = C.red }) then
      run.lives = math.min(game.START_LIVES, run.lives + 3)
      sfx.play("reveal")
      self.result = "You wake up feeling three lives better."
    end
    if widgets.button("tv_train", 820, 580, 400, 120, "Spar in the cellar", { sub = "A cat of your choice gains a level", color = C.blue }) then
      overlays.chooseCard("Who trains tonight?", run.deck, function(c) return cards.getDef(c).kind == "unit" and c.level < 3 end, function(c)
        game.upgradeCard(run, c.uid)
        sfx.play("reveal")
        self.result = cards.getDef(c).name .. " trains all night and reaches level " .. c.level .. "."
      end)
    end
    return
  end
  local n = #self.ev.choices
  for i, ch in ipairs(self.ev.choices) do
    local x = 800 - (n * 440) / 2 + (i - 1) * 440 + 20
    local ok = ch.enabled(G.save)
    if widgets.button("ev" .. i, x, 580, 400, 120, ch.label, { sub = ch.hint, disabled = not ok, color = i == 1 and C.red or C.ink3 }) then
      self.result = ch.apply(G.save)
      sfx.play("reveal")
      fx.burst(800, 440, C.cyan, 30, 400, 7)
      G.persist()
    end
  end
end

return S
