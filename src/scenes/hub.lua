-- Festival Grounds: standings or bracket, the next match, and one stall visit between matches.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local festival = require("src.core.festival")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local hud = require("src.ui.hud")
local icons = require("src.ui.icons")
local nemesis = require("src.core.nemesis")
local overlays = require("src.ui.overlays")
local rng = require("src.core.rng")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c
local T = theme.T
S.bg = { horizon = 0, light = { 0.5, 0.4 }, radius = 0.95, power = 0.95 }

function S:enter(p)
  self.t = 0
  local run = G.save.run
  if not run or run.phase == "over" then return G.go("summary") end
  if not run.stallEvent then run.stallEvent = rng.pick(run.rng, game.EVENT_IDS) end
  if p and p.fresh then
    fx.toast("Welcome to " .. run.festival.name .. "! You've been dealt " .. #run.deck .. " cats.", "good")
    sfx.play("cheer")
  end
  self.notes = (p and p.notes) or {}
end

function S:update(dt) self.t = self.t + dt end

local function stall(id, x, y, w, h, icon, title, desc, used)
  local clicked, over = widgets.click(id, x, y, w, h)
  local lift = (over and not used) and -2 or 0
  gfx.panel(x, y + lift, w, h, used and C.deep or (over and C.ink3 or C.ink2), { border = used and C.ink3 or C.goldDark })
  icons.draw(icon, x + 16, y + 17 + lift, used and C.muted or C.gold, 2)
  gfx.text(title, T.big(), x + 32, y + 6 + lift, used and C.muted or C.paper)
  gfx.textf(desc, T.body(), x + 9, y + 32 + lift, w - 18, "left", used and C.muted or C.paper2)
  return clicked and not used
end

function S:draw()
  local save = G.save
  local run = save.run
  if not run or run.phase == "over" then return end
  local f = run.festival
  hud.draw(run)

  -- left: your group (or the bracket), then the news
  local ly
  if f.stage == "group" then
    local gi = festival.groupOf(f, festival.PLAYER)
    overlays.groupTable(f, gi, 8, 40, 296)
    ly = 40 + overlays.GROUP_H + 6
  else
    overlays.bracket(f, 8, 40, 296, 124)
    ly = 168
  end
  if widgets.button("h_stand", 8, ly, 296, 20, f.stage == "group" and "All groups and the bracket" or "Full standings", { font = T.body() }) then overlays.standings(f) end
  ly = ly + 24
  gfx.panel(8, ly, 296, 238 - ly, C.deep, { border = C.ink3 })
  gfx.label("Around the festival", 14, ly + 4, C.gold)
  local note = self.notes[1 + math.floor(self.t / 4) % math.max(1, #self.notes)] or "The crowd is restless. Fish sellers shout. Somewhere, a bard tunes a sardine tin."
  gfx.textf(note, T.body(), 14, ly + 13, 284, "left", C.paper)

  -- right: the next match
  local opp = game.nextOpponent(save)
  gfx.panel(312, 40, 320, 194, C.deep, { border = C.redDark })
  gfx.label("Next match", 320, 45, C.red)
  gfx.text(festival.stageLabel(f), T.body(), 624, 40, C.paper2, { align = "right" })
  if opp then
    local p = art.entrant(save, opp, 64)
    gfx.box(319, 59, 66, 66, C.black)
    lg.setColor(1, 1, 1)
    lg.draw(p, 320, 60)
    local n = opp.kind == "hand" and game.findNemesis(save, opp.id)
    gfx.text(opp.name, T.title(), 392, 56, C.paper)
    local sub = n and n.epithet or ("the " .. (opp.title or "Stray"))
    gfx.text(sub, T.body(), 393, 81, C.paper2)
    local tag = n and nemesis.RANK_TITLES[game.rankOf(save, n)] or (opp.foe and opp.foe.elite and "Veteran stray" or "Stray")
    local tw = gfx.chip(tag, 393, 100, n and "strength" or "hidden")
    local coat = cards.COATS[opp.coat]
    gfx.text(coat.name .. " coat", T.body(), 399 + tw, 98, coat.color)
    local w, l = 0, 0
    for _, m in ipairs(f.results) do
      if m.a == opp.id or m.b == opp.id then if m.winner == opp.id then w = w + 1 else l = l + 1 end end
    end
    gfx.text(("Record %d-%d"):format(w, l), T.body(), 624, 58, C.paper, { align = "right" })
    local stars = math.max(1, math.min(5, math.floor((opp.rating - 6) / 4) + 1))
    for i = 1, stars do icons.draw("skull", 624 - (i - 1) * 10 - 4, 84, C.red) end
    gfx.text("Threat", T.body(), 624 - stars * 10 - 6, 76, C.muted, { align = "right" })
    if n then
      local cy = overlays.traitChips(n, 320, 132, 304)
      local last = n.history[#n.history]
      if last and cy < 170 then gfx.textf(last.text, T.body(), 320, cy + 4, 140, "left", C.muted) end
    else
      gfx.textf("Beat a stray and it will squeal one of the Hands' secrets.", T.body(), 320, 132, 300, "left", C.paper2)
    end
    if widgets.button("h_fight", 470, 194, 154, 32, "To the Arena!", { color = C.red }) then
      G.go("vs")
    end
  end

  -- bottom: stalls
  gfx.label(run.stallUsed and "Stalls: visit again after your next match" or "Visit one stall before your match", 10, 241, run.stallUsed and C.muted or C.gold)
  local ev = game.EVENTS[run.stallEvent]
  if stall("st_market", 8, 252, 204, 100, "fish", "Mews Market", "Buy cats and charms, or send a cat home.", run.stallUsed) then
    run.stallUsed = true
    G.persist()
    G.go("market")
  end
  if stall("st_fortune", 218, 252, 204, 100, "star", "Fortune Teller", "\"" .. ev.title .. "\"... the cards are hazy.", run.stallUsed) then
    run.stallUsed = true
    G.persist()
    G.go("event", { event = run.stallEvent })
  end
  if stall("st_train", 428, 252, 204, 100, "shield", "Training Yard", "One cat of your choice gains a level: +2 Paws.", run.stallUsed) then
    overlays.chooseCard("Who trains today?", run.deck, function(c) return cards.getDef(c).kind == "unit" and c.level < 3 end, function(c)
      game.upgradeCard(run, c.uid)
      run.stallUsed = true
      sfx.play("reveal")
      fx.toast(cards.getDef(c).name .. " trains hard and reaches level " .. c.level .. "!", "good")
      G.persist()
    end)
  end
end

function S:keypressed(k)
  if k == "escape" then overlays.pause() end
end

return S
