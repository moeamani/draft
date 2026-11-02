-- VS screen: the rival sits down across the table, a wax seal stamps "VS", and they taunt you.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local festival = require("src.core.festival")
local fx = require("src.ui.fx")
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
local T = theme.T
local HORIZON = 100
S.bg = { horizon = HORIZON / 360, light = { 0.5, 0.55 }, radius = 0.7, power = 1.0 }

function S:enter()
  local save = G.save
  self.t = 0
  self.opp = game.nextOpponent(save)
  self.n = self.opp.kind == "hand" and game.findNemesis(save, self.opp.id) or nil
  self.rank = self.n and game.rankOf(save, self.n) or 0
  S.bg = { horizon = HORIZON / 360, light = { 0.5, 0.55 }, radius = 0.7, power = 1.0, ramp = self.n and "blood" or "felt" }
  local r = { s = math.floor(love.math.random() * 2 ^ 30) + 1 }
  if self.n then
    self.line = nemesis.speak(r, self.n, nemesis.situation(self.n), save.playerName, self.rank)
  else
    local lines = { "Out of my way, house cat.", "My whiskers are sharper than yours.", "I didn't come all this way to lose to you.", "The crowd came to see me. Not you.", "Fish says I win this one." }
    self.line = lines[math.random(#lines)]
  end
  self.me = art.player(save.playerName, 48)
  self.them, self.eyes = art.entrant(save, self.opp, 128, true)
  self.slammed = false
  self.shown = 0
  sfx.play("whoosh")
end

function S:update(dt)
  self.t = self.t + dt
  if self.t > 0.7 and not self.slammed then
    self.slammed = true
    fx.addShake(6)
    fx.flash = 0.6
    sfx.play("slam")
    fx.burst(320, 170, C.red, 24, 120)
  end
  if self.t > 1.0 then self.shown = math.min(#self.line, self.shown + dt * 50) end
end

local function ease(t) t = math.max(0, math.min(1, t)); return 1 - (1 - t) ^ 3 end

local function seal(x, y, scale)
  lg.push()
  lg.translate(x, y)
  lg.scale(scale, scale)
  local r = 17
  lg.setColor(0, 0, 0, 0.5)
  lg.ellipse("fill", 1, 2, r + 1, r + 1, 20)
  theme.set(C.redDark)
  lg.ellipse("fill", 0, 0, r + 1, r + 1, 20)
  theme.set(C.red)
  lg.ellipse("fill", 0, 0, r - 2, r - 2, 20)
  theme.set(C.redDark)
  lg.ellipse("fill", 0, 0, r - 5, r - 5, 20)
  gfx.text("VS", T.big(), 0, -11, C.paper, { align = "center" })
  lg.pop()
end

function S:draw()
  local save = G.save
  local f = save.run.festival
  local t = self.t
  gfx.text(f.name, T.body(), 10, 8, C.paper2)
  gfx.text(festival.stageLabel(f), T.body(), 10, 24, C.gold)
  -- the rival rises out of the dark
  local rise = math.floor((1 - ease(t / 0.6)) * 50)
  lg.setScissor(G.scissor(0, 0, theme.W, HORIZON + 1))
  lg.setColor(0.45, 0.45, 0.5)
  lg.draw(self.them, 320 - 64, HORIZON - 106 + rise)
  if self.eyes and t > 0.5 then
    local e = self.eyes
    for j = 0, 1 do
      local ex, ey = 256 + math.floor(e[1 + j * 2]), HORIZON - 106 + rise + math.floor(e[2 + j * 2])
      theme.set(e[5], 0.35)
      lg.rectangle("fill", ex - 3, ey - 2, 6, 4)
      theme.set(e[5])
      lg.rectangle("fill", ex - 2, ey - 1, 4, 2)
    end
  end
  lg.setScissor()
  -- their name on the table edge
  if t > 0.3 then
    gfx.text(self.opp.name, T.title(), 320, 108, C.paper, { align = "center" })
    local sub = self.n and (self.rank > 0 and nemesis.RANK_TITLES[self.rank] or self.n.epithet) or ("the " .. (self.opp.title or "Stray"))
    gfx.text(sub, T.body(), 320, 134, self.n and C.red or C.paper2, { align = "center" })
    local coat = cards.COATS[self.opp.coat]
    gfx.text(coat.name .. " coat", T.body(), 320, 150, coat.color, { align = "center" })
  end
  if t > 0.55 then
    local k = math.min(1, (t - 0.55) / 0.15)
    seal(320, 184, 3 - 2 * k)
  end
  -- the taunt, on a note
  if t > 1.0 then
    gfx.paper(160, 210, 320, 44, { pin = C.red })
    gfx.textf('"' .. self.line:sub(1, math.floor(self.shown)) .. '"', T.body(), 170, 216, 300, "center", C.parchInk, { shadow = false })
  end
  if self.n and t > 1.0 then overlays.traitChips(self.n, 164, 262, 312) end
  -- you
  gfx.panel(8, 296, 176, 56, C.deep, { border = C.goldDark })
  gfx.box(13, 301, 46, 46, C.black)
  lg.setColor(1, 1, 1)
  lg.draw(self.me, 12, 300, 0, 46 / 48, 46 / 48)
  gfx.text(save.playerName, T.big(), 66, 300, C.gold)
  gfx.text("Champion", T.body(), 66, 322, C.paper2)
  if t > 1.2 then
    if widgets.button("vs_go", 250, 302, 140, 36, "Fight!", { color = C.red, font = T.huge() }) then G.go("match") end
  end
end

function S:keypressed(k)
  if (k == "return" or k == "space") and self.t > 1.2 then G.go("match") end
end

return S
