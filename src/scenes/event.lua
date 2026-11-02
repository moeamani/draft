-- The Fortune Teller's tent: one strange encounter per visit.
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local hud = require("src.ui.hud")
local icons = require("src.ui.icons")
local rng = require("src.core.rng")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local S = {}
local C = theme.c
local T = theme.T
S.bg = { horizon = 0, light = { 0.5, 0.35 }, radius = 0.75, power = 1.0 }

function S:enter(p)
  self.t = 0
  self.result = nil
  self.ev = game.EVENTS[p.event]
  self.text = self.ev.text(G.save)
end

function S:update(dt) self.t = self.t + dt end

local function back()
  local run = G.save.run
  run.stallEvent = rng.pick(run.rng, game.EVENT_IDS)
  G.persist()
  G.go("hub")
end

function S:draw()
  local run = G.save.run
  hud.draw(run)
  icons.draw("star", 320, 62, C.cyan, 3, math.sin(self.t * 1.5) * 0.15)
  gfx.text("The Fortune Teller sees...", T.body(), 320, 78, C.paper2, { align = "center" })
  gfx.wavy(self.ev.title, T.title(), 320, 96, C.gold, self.t, 1)
  gfx.paper(110, 132, 420, 84, { pin = C.cyan })
  gfx.textf(self.result or self.text, T.body(), 122, 140, 396, "center", C.parchInk, { shadow = false })
  if self.result then
    if widgets.button("ev_go", 230, 236, 180, 32, "Back to the grounds", { color = C.red, font = T.body() }) then back() end
    return
  end
  local n = #self.ev.choices
  for i, ch in ipairs(self.ev.choices) do
    local x = 320 - (n * 208) / 2 + (i - 1) * 208 + 4
    local ok = ch.enabled(G.save)
    if widgets.choice("ev" .. i, x, 232, 200, 84, ch.label, ch.hint, { color = i == 1 and C.redDark or C.ink2, disabled = not ok }) then
      self.result = ch.apply(G.save)
      sfx.play("reveal")
      fx.burst(320, 175, C.cyan, 24, 120)
      G.persist()
    end
  end
end

return S
