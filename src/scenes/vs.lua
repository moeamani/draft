-- VS screen: split diagonal, both champions slide in, "VS" slams, the rival taunts.
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
S.bg = { C.black, { 0.3, 0.05, 0.04 }, C.red, spin = 3.0 }

function S:enter()
  local save = G.save
  self.t = 0
  self.opp = game.nextOpponent(save)
  self.n = self.opp.kind == "hand" and game.findNemesis(save, self.opp.id) or nil
  self.rank = self.n and game.rankOf(save, self.n) or 0
  local r = { s = math.floor(love.math.random() * 2 ^ 30) + 1 }
  if self.n then
    self.line = nemesis.speak(r, self.n, nemesis.situation(self.n), save.playerName, self.rank)
  else
    local lines = { "Out of my way, house cat.", "My whiskers are sharper than yours.", "I didn't come all this way to lose to you.", "The crowd came to see me. Not you.", "Fish says I win this one." }
    self.line = lines[math.random(#lines)]
  end
  self.me = art.player(save.playerName, 96)
  self.them = art.entrant(save, self.opp, 96)
  self.slammed = false
  self.shown = 0
  sfx.play("whoosh")
end

function S:update(dt)
  self.t = self.t + dt
  if self.t > 0.55 and not self.slammed then
    self.slammed = true
    fx.addShake(6)
    fx.flash = 0.8
    sfx.play("slam")
    fx.burst(320, 150, C.gold, 30, 160)
    fx.burst(320, 150, C.red, 20, 120)
  end
  if self.t > 0.9 then self.shown = math.min(#self.line, self.shown + dt * 50) end
end

local function ease(t) t = math.max(0, math.min(1, t)); return 1 - (1 - t) ^ 3 end

function S:draw()
  local save = G.save
  local f = save.run.festival
  local t = self.t
  local e = ease(t / 0.45)
  -- split panels
  local off = math.floor((1 - e) * 400)
  theme.set(C.ink2)
  lg.polygon("fill", -off, 0, 360 - off, 0, 280 - off, 360, -off, 360)
  theme.set(C.redDark)
  lg.polygon("fill", 360 + off, 0, 640 + off, 0, 640 + off, 360, 280 + off, 360)
  theme.set(C.gold)
  lg.polygon("fill", 357 - off, 0, 361 - off, 0, 281 - off, 360, 277 - off, 360)
  -- speed lines
  for i = 0, 11 do
    local yy = (i * 31 + math.floor(t * 300)) % 360
    lg.setColor(1, 1, 1, 0.06)
    lg.rectangle("fill", 0, yy, 260 - off, 1)
    lg.rectangle("fill", 380 + off, (yy + 15) % 360, 260, 1)
  end
  gfx.text(festival.stageLabel(f):upper(), theme.T.tiny(), 320, 10, C.gold, { align = "center" })
  gfx.text(f.name, theme.T.headS(), 320, 20, C.paper, { align = "center" })
  -- portraits
  local lx = math.floor(60 - (1 - e) * 220)
  local rx = math.floor(484 + (1 - e) * 220)
  gfx.box(lx - 2, 78, 100, 100, C.black)
  gfx.box(lx - 1, 79, 98, 98, C.gold)
  lg.setColor(1, 1, 1)
  lg.draw(self.me, lx, 80)
  gfx.box(rx - 2, 78, 100, 100, C.black)
  gfx.box(rx - 1, 79, 98, 98, C.red)
  lg.setColor(1, 1, 1)
  lg.draw(self.them, rx, 80)
  gfx.text(save.playerName, theme.T.head(), lx + 48, 184, C.paper, { align = "center" })
  gfx.text("CHAMPION", theme.T.tiny(), lx + 48, 210, C.gold, { align = "center" })
  gfx.text(self.opp.name, theme.T.head(), rx + 48, 184, C.paper, { align = "center" })
  local sub = self.n and (self.rank > 0 and nemesis.RANK_TITLES[self.rank]:upper() or "WARLORD") or ("THE " .. (self.opp.title or "STRAY"):upper())
  gfx.text(sub, theme.T.tiny(), rx + 48, 210, C.red, { align = "center" })
  local coat = cards.COATS[self.opp.coat]
  gfx.text(coat.name:upper() .. " COAT", theme.T.tiny(), rx + 48, 220, coat.color, { align = "center" })
  -- VS slam
  if t > 0.45 then
    local k = math.min(1, (t - 0.45) / 0.12)
    local sc = 4 - 2.4 * k
    lg.push()
    lg.translate(320, 128)
    lg.scale(sc, sc)
    gfx.outlined("VS", theme.T.headL(), 0, -22, C.gold, { align = "center" })
    lg.pop()
  end
  -- taunt
  if t > 0.9 then
    gfx.panel(150, 240, 340, 40, C.paper)
    gfx.textf('"' .. self.line:sub(1, math.floor(self.shown)) .. '"', theme.T.body(), 158, 246, 324, "center", C.ink, { shadow = false })
  end
  if self.n and t > 0.9 then overlays.traitChips(self.n, 484, 232, 150) end
  if t > 1.1 then
    if widgets.button("vs_go", 250, 296, 140, 34, "Fight!", { color = C.red }) then G.go("match") end
  end
end

function S:keypressed(k)
  if (k == "return" or k == "space") and self.t > 1.1 then G.go("match") end
end

return S
