-- The Fortune Teller's tent: one strange encounter per visit.
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local hud = require("src.ui.hud")
local icons = require("src.ui.icons")
local rng = require("src.core.rng")
local plates = require("src.ui.plates")
local audio = require("src.audio")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local S = {}
local C = theme.c
local T = theme.T
S.bg = { preset = "table" }

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
  gfx.text("The Fortune Teller sees...", T.body(), 320, 46, C.paper2, { align = "center" })
  local tsize = plates.textWidth(self.ev.title, 28) <= 380 and 28 or 22
  plates.header(110, 66, 420, 44, theme.hex("#2471fc"), self.ev.title, { size = tsize, streak = 0.43, align = "center" })
  gfx.panel(110, 118, 420, 98, C.ink2)
  gfx.textf(self.result or self.text, T.body(), 122, 126, 396, "center", C.paper)
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
      audio.play("reveal")
      fx.burst(320, 175, C.cyan, 24, 120)
      G.persist()
    end
  end
end

return S
