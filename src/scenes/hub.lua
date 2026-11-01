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
S.bg = { C.ink, C.ink3, C.gold, spin = 0.8 }

function S:enter(p)
  self.t = 0
  local run = G.save.run
  if not run or run.phase == "over" then return G.go("summary") end
  if not run.stallEvent then run.stallEvent = rng.pick(run.rng, game.EVENT_IDS) end
  if p and p.fresh then
    fx.toast("Welcome to " .. run.festival.name .. "! You've been dealt " .. #run.deck .. " cats.", "good")
    sfx.play("cheer")
  end
  local f = run.festival
  S.bg = f.stage == "group" and { C.ink, C.ink3, C.gold, spin = 0.8 } or { C.ink, { 0.3, 0.06, 0.05 }, C.red, spin = 1.4 }
  self.notes = (p and p.notes) or {}
end

function S:update(dt) self.t = self.t + dt end

local function stall(id, x, y, w, h, icon, title, desc, used)
  local clicked, over = widgets.click(id, x, y, w, h)
  local lift = (over and not used) and -2 or 0
  gfx.panel(x, y + lift, w, h, used and C.deep or (over and C.ink3 or C.ink2), { border = used and nil or C.goldDark })
  icons.draw(icon, x + 16, y + 16 + lift, used and C.muted or C.gold, 2)
  gfx.text(title, theme.T.headS(), x + 30, y + 8 + lift, used and C.muted or C.paper)
  gfx.textf(desc, theme.T.tiny(), x + 8, y + 32 + lift, w - 16, "left", used and C.muted or C.paper2)
  return clicked and not used
end

function S:draw()
  local save = G.save
  local run = save.run
  if not run or run.phase == "over" then return end
  local f = run.festival
  hud.draw(run)

  -- left: standings
  if f.stage == "group" then
    gfx.label("Standings", 10, 34)
    for gi = 1, 4 do overlays.groupTable(f, gi, 8 + ((gi - 1) % 2) * 150, 44 + math.floor((gi - 1) / 2) * 66, 146) end
  else
    gfx.label("Knockouts", 10, 34)
    overlays.bracket(f, 8, 44, 296, 128)
  end
  if widgets.button("h_stand", 8, 180, 296, 16, "Full standings & bracket", { font = theme.T.num() }) then overlays.standings(f) end
  -- news ticker
  gfx.panel(8, 202, 296, 34, C.deep)
  gfx.label("Around the festival", 14, 205, C.muted)
  local note = self.notes[1 + math.floor(self.t / 3) % math.max(1, #self.notes)] or "The crowd is restless. Fish sellers shout. Somewhere, a bard tunes a sardine tin."
  gfx.textf(note, theme.T.tiny(), 14, 216, 284, "left", C.paper)

  -- right: next match
  local opp = game.nextOpponent(save)
  gfx.panel(312, 34, 320, 202, C.deep, { border = C.redDark })
  gfx.label("Next match  -  " .. festival.stageLabel(f), 320, 38, C.red)
  if opp then
    local p = art.entrant(save, opp, 64)
    gfx.box(319, 51, 66, 66, C.black)
    lg.setColor(1, 1, 1)
    lg.draw(p, 320, 52)
    local n = opp.kind == "hand" and game.findNemesis(save, opp.id)
    gfx.text(opp.name, theme.T.head(), 392, 48, C.paper)
    local sub = n and n.epithet or ("the " .. (opp.title or "Stray"))
    gfx.text(sub, theme.T.body(), 393, 74, C.muted)
    local tag = n and nemesis.RANK_TITLES[game.rankOf(save, n)] or (opp.foe and opp.foe.elite and "VETERAN STRAY" or "STRAY")
    gfx.chip(tag:upper(), 393, 86, n and "strength" or "hidden")
    local coat = cards.COATS[opp.coat]
    gfx.text(coat.name:upper() .. " COAT", theme.T.tiny(), 393, 100, coat.color)
    local w, l = 0, 0
    for _, m in ipairs(f.results) do
      if m.a == opp.id or m.b == opp.id then if m.winner == opp.id then w = w + 1 else l = l + 1 end end
    end
    gfx.text(("FESTIVAL RECORD %d-%d"):format(w, l), theme.T.tiny(), 624, 52, C.paper, { align = "right" })
    local stars = math.max(1, math.min(5, math.floor((opp.rating - 6) / 4) + 1))
    gfx.text("THREAT", theme.T.tiny(), 624 - stars * 9 - 4, 64, C.muted, { align = "right" })
    for i = 1, stars do icons.draw("skull", 624 - (i - 1) * 9 - 4, 68, C.red) end
    if n then
      overlays.traitChips(n, 320, 124, 304)
      local last = n.history[#n.history]
      if last then gfx.textf(last.text, theme.T.tiny(), 320, 168, 304, "left", C.muted) end
    else
      gfx.textf("Beat a stray and they'll squeal one of the Hands' secrets.", theme.T.tiny(), 320, 124, 304, "left", C.muted)
    end
    if widgets.button("h_fight", 470, 196, 154, 30, "To the Arena!", { color = C.red }) then
      G.go("vs")
    end
  end

  -- bottom: stalls
  gfx.label(run.stallUsed and "Stalls: visit again after your next match" or "Visit one stall before your match", 10, 242, run.stallUsed and C.muted or C.gold)
  local ev = game.EVENTS[run.stallEvent]
  if stall("st_market", 8, 254, 204, 96, "fish", "Mews Market", "Buy cats and charms, or send a cat home.", run.stallUsed) then
    run.stallUsed = true
    G.persist()
    G.go("market")
  end
  if stall("st_fortune", 218, 254, 204, 96, "star", "Fortune Teller", "\"" .. ev.title .. "\" ... the cards are hazy.", run.stallUsed) then
    run.stallUsed = true
    G.persist()
    G.go("event", { event = run.stallEvent })
  end
  if stall("st_train", 428, 254, 204, 96, "shield", "Training Yard", "One cat of your choice gains a level (+2 Paws).", run.stallUsed) then
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
