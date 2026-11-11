-- VS screen: the rival's portrait sits crisp over a red and cyan ghost of itself, with their
-- name on a sign and a taunt.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local festival = require("src.core.festival")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local nemesis = require("src.core.nemesis")
local overlays = require("src.ui.overlays")
local plates = require("src.ui.plates")
local audio = require("src.audio")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
S.music = "table"
local C = theme.c
local T = theme.T
S.bg = { preset = "vs" }

function S:enter()
  local save = G.save
  self.t = 0
  self.opp = game.nextOpponent(save)
  self.n = self.opp.kind == "hand" and game.findNemesis(save, self.opp.id) or nil
  self.rank = self.n and game.rankOf(save, self.n) or 0
  S.bg = { preset = "vs", ramp = self.n and "blood" or "felt" }
  local r = { s = math.floor(love.math.random() * 2 ^ 30) + 1 }
  if self.n then
    self.line = nemesis.speak(r, self.n, nemesis.situation(self.n), save.playerName, self.rank)
  else
    local lines = { "Out of my way, house cat.", "My whiskers are sharper than yours.", "I didn't come all this way to lose to you.", "The crowd came to see me. Not you.", "Fish says I win this one." }
    self.line = lines[math.random(#lines)]
  end
  self.me = art.player(save.playerName, 48)
  self.them = art.entrant(save, self.opp, 160, true)
  self.slammed = false
  self.shown = 0
  audio.play("whoosh")
end

function S:update(dt)
  self.t = self.t + dt
  if self.t > 0.55 and not self.slammed then
    self.slammed = true
    fx.addShake(5)
    fx.flash = 0.5
    audio.play("slam")
  end
  if self.t > 0.8 then self.shown = math.min(#self.line, self.shown + dt * 50) end
end

local function ease(t) t = math.max(0, math.min(1, t)); return 1 - (1 - t) ^ 3 end

function S:draw()
  local save = G.save
  local f = save.run.festival
  local t = self.t
  gfx.text(f.name, T.body(), 12, 8, C.paper2)
  gfx.text(festival.stageLabel(f), T.body(), 12, 24, C.gold)
  local omen = festival.omen(f)
  if omen then gfx.text("Omen: " .. omen.name .. ". " .. omen.desc, T.body(), 12, 40, C.muted) end
  -- the rival, Figma-mascot style
  local e = ease(t / 0.5)
  local px = math.floor(60 - (1 - e) * 220)
  -- a red and a cyan ghost trail it in, like plates sliding into register
  local off = math.floor((1 - e) * 26)
  if off > 0 then
    plates.drawTint(self.them, px + off, 66, C.red, 0.5)
    plates.drawTint(self.them, px - off, 66, C.cyan, 0.5)
  end
  plates.draw(self.them, px, 66)
  if t > 0.35 then
    local k = ease((t - 0.35) / 0.3)
    local cx = math.floor(330 + (1 - k) * 320)
    plates.draw(plates.titleCard(56, 26, C.red, { label = "VS", size = 20, outline = C.black }), cx, 52)
    local name = self.opp.name
    local size = plates.textWidth(name, 34) <= 270 and 34 or 26
    plates.header(cx, 82, 296, 46, C.night, name, { size = size, streak = 1.0, pad = 12 })
    local sub = self.n and (self.rank > 0 and nemesis.RANK_TITLES[self.rank] or self.n.epithet) or ("the " .. (self.opp.title or "Stray"))
    gfx.text(sub, T.big(), cx + 2, 134, self.n and C.red or C.paper)
    local coat = cards.COATS[self.opp.coat]
    gfx.text(coat.name .. " coat", T.body(), cx + 2, 156, coat.color)
    if self.n then overlays.traitChips(self.n, cx + 2, 176, 292) end
  end
  if t > 0.8 then
    local th = gfx.wrapHeight('"' .. self.line .. '"', T.body(), 276)
    gfx.panel(330, 212, 296, th + 12, C.ink2)
    gfx.textf('"' .. self.line:sub(1, math.floor(self.shown)) .. '"', T.body(), 340, 217, 276, "left", C.paper)
  end
  -- you
  gfx.panel(8, 296, 180, 56, C.ink2)
  gfx.box(13, 301, 46, 46, C.black)
  lg.setColor(1, 1, 1)
  lg.draw(self.me, 12, 300, 0, 46 / 48, 46 / 48)
  plates.print(save.playerName, 20, 66, 300, C.white)
  gfx.text("Champion", T.body(), 66, 326, C.gold)
  if t > 1.0 then
    if widgets.button("vs_go", 404, 300, 222, 40, "Fight!", { color = C.red, font = T.huge() }) then G.go("match") end
  end
end

function S:keypressed(k)
  if (k == "return" or k == "space") and self.t > 1.0 then G.go("match") end
end

return S
