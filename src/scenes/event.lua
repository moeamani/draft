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
S.bg = { C.ink, C.ink2, C.cyan, spin = 1.3 }

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
  icons.draw("star", 320, 62, C.cyan, 4, math.sin(self.t * 1.5) * 0.15)
  gfx.text("THE FORTUNE TELLER SEES...", theme.T.tiny(), 320, 86, C.muted, { align = "center" })
  gfx.wavy(self.ev.title, theme.T.head(), 320, 96, C.paper, self.t, 1)
  gfx.panel(120, 130, 400, 70, C.deep, { border = C.ink3 })
  gfx.textf(self.result or self.text, theme.T.body(), 132, 140, 376, "center", self.result and C.paper or C.paper2)
  if self.result then
    if widgets.button("ev_go", 240, 226, 160, 28, "Back to the grounds", { color = C.red, font = theme.T.num() }) then back() end
    return
  end
  local n = #self.ev.choices
  for i, ch in ipairs(self.ev.choices) do
    local x = 320 - (n * 196) / 2 + (i - 1) * 196 + 6
    local ok = ch.enabled(G.save)
    if widgets.button("ev" .. i, x, 220, 184, 44, ch.label, { sub = ch.hint, disabled = not ok, color = i == 1 and C.red or C.ink3 }) then
      self.result = ch.apply(G.save)
      sfx.play("reveal")
      fx.burst(320, 165, C.cyan, 24, 120)
      G.persist()
    end
  end
end

return S
