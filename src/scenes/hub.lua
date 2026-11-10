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
local plates = require("src.ui.plates")
local rng = require("src.core.rng")
local audio = require("src.audio")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
S.music = "table"
local C = theme.c
local T = theme.T
S.bg = { preset = "table" }

function S:enter(p)
  self.t = 0
  local run = G.save.run
  if not run or run.phase == "over" then return G.go("summary") end
  if not run.stallEvent then run.stallEvent = rng.pick(run.rng, game.EVENT_IDS) end
  if p and p.fresh then
    fx.toast("Welcome to " .. run.festival.name .. "! You've been dealt " .. #run.deck .. " cats.", "good")
    audio.play("cheer")
  end
  self.notes = (p and p.notes) or {}
end

function S:update(dt) self.t = self.t + dt end

-- A stall: a coloured title card (as in the Figma sheet) over an ink panel.
local function stall(id, x, y, w, h, color, streak, title, desc, used)
  local clicked, over = widgets.click(id, x, y, w, h)
  local lift = (over and not used) and -2 or 0
  gfx.panel(x, y + lift, w, h, used and C.deep or (over and C.ink3 or C.ink2))
  plates.header(x, y + lift, w, 30, used and C.ink3 or color, title, { size = 22, streak = (not used) and streak or nil, pad = 10 })
  gfx.textf(desc, T.body(), x + 9, y + 36 + lift, w - 18, "left", used and C.muted or C.paper2)
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
  gfx.panel(8, ly, 296, 238 - ly, C.deep)
  -- story mode: the chapter's goal
  if run.story then
    local story = require("src.core.story")
    local ch = story.chapter(save)
    if ch then
      local met = story.goalMet(save)
      gfx.text((met and "Goal reached: " or "Goal: ") .. ch.goalText, T.bold(), 14, ly + 3, met and C.green or C.goldText, { bg = C.deep })
      ly = ly + 16
    end
  end
  -- the festival's omen: one rule twist for every match here
  local omen = festival.omen(f)
  if omen then
    plates.header(8, ly, 296, 18, C.goldDark, "Omen: " .. omen.name, { size = 14, streak = 0.43, pad = 6 })
    gfx.text(omen.desc, T.body(), 14, ly + 19, C.gold)
    ly = ly + 36
  end
  if 238 - ly >= 28 then -- the news, when there's room for it
    gfx.label("Around the festival", 14, ly + 2, C.muted)
    local note = self.notes[1 + math.floor(self.t / 4) % math.max(1, #self.notes)] or "The crowd is restless. Fish sellers shout. Somewhere, a bard tunes a sardine tin."
    lg.setScissor(G.scissor(8, ly, 296, 237 - ly))
    gfx.textf(note, T.body(), 14, ly + 11, 284, "left", C.paper)
    lg.setScissor()
  end

  -- right: the next match
  local opp = game.nextOpponent(save)
  gfx.panel(312, 40, 320, 194, C.deep)
  plates.header(312, 40, 320, 22, C.red, "Next match: " .. festival.stageLabel(f), { size = 16, streak = 0.43 })
  if opp then
    local p = art.entrant(save, opp, 64)
    gfx.box(319, 69, 66, 66, C.black)
    lg.setColor(1, 1, 1)
    lg.draw(p, 320, 70)
    local n = opp.kind == "hand" and game.findNemesis(save, opp.id)
    plates.print(opp.name, 26, 392, 64, C.white)
    local sub = n and n.epithet or ("the " .. (opp.title or "Stray"))
    gfx.text(sub, T.body(), 393, 94, C.paper2)
    local tag = n and nemesis.RANK_TITLES[game.rankOf(save, n)] or (opp.foe and opp.foe.elite and "Veteran stray" or "Stray")
    local tw = gfx.chip(tag, 393, 113, n and "strength" or "hidden")
    local coat = cards.COATS[opp.coat]
    gfx.text(coat.name .. " coat", T.body(), 399 + tw, 111, coat.color)
    local w, l = 0, 0
    for _, m in ipairs(f.results) do
      if m.a == opp.id or m.b == opp.id then if m.winner == opp.id then w = w + 1 else l = l + 1 end end
    end
    gfx.text(("Record %d-%d"):format(w, l), T.body(), 624, 66, C.paper, { align = "right" })
    local stars = math.max(1, math.min(5, math.floor((opp.rating - 6) / 4) + 1))
    for i = 1, stars do icons.draw("skull", 624 - (i - 1) * 10 - 4, 92, C.red) end
    gfx.text("Threat", T.body(), 624 - stars * 10 - 6, 84, C.muted, { align = "right" })
    if n then
      local cy = overlays.traitChips(n, 320, 142, 304)
      local caps = n.captives or {}
      if #caps > 0 then
        local names = {}
        for i = 1, math.min(3, #caps) do names[i] = cards.shortName(cards.getDef(caps[i])) end
        local more = #caps > 3 and (" and " .. (#caps - 3) .. " more") or ""
        gfx.textf(("Holds your %s%s. Beat them, or beat %s, to bring %s home."):format(table.concat(names, ", "), more, #caps > 1 and "each one" or "it", #caps > 1 and "them" or "it"),
          T.body(), 320, cy + 4, 146, "left", C.redText, { bg = C.deep })
      else
        local last = n.history[#n.history]
        if last and cy < 172 then gfx.textf(last.text, T.body(), 320, cy + 4, 140, "left", C.muted, { bg = C.deep }) end
      end
    else
      gfx.textf("Beat a stray and it will squeal one of the Hands' secrets.", T.body(), 320, 142, 300, "left", C.paper2)
    end
    if widgets.button("h_fight", 470, 194, 154, 32, "To the Arena!", { color = C.red }) then
      G.go("vs")
    end
  end

  -- bottom: stalls
  gfx.label(run.stallUsed and "Stalls: visit again after your next match" or "Visit one stall before your match", 10, 241, run.stallUsed and C.muted or C.gold)
  local ev = game.EVENTS[run.stallEvent]
  if stall("st_market", 8, 252, 204, 100, C.gold, 0.43, "Mews Market", "Buy cats and charms, or send a cat home.", run.stallUsed) then
    run.stallUsed = true
    G.persist()
    G.go("market")
  end
  if stall("st_fortune", 218, 252, 204, 100, theme.hex("#2471fc"), 0.43, "Fortune Teller", "\"" .. ev.title .. "\"... the cards are hazy.", run.stallUsed) then
    run.stallUsed = true
    G.persist()
    G.go("event", { event = run.stallEvent })
  end
  if stall("st_train", 428, 252, 204, 100, C.red, 0.43, "Training Yard", "One cat of your choice gains a level: +2 Paws.", run.stallUsed) then
    overlays.chooseCard("Who trains today?", run.deck, function(c) return cards.getDef(c).kind == "unit" and c.level < 3 end, function(c)
      game.upgradeCard(run, c.uid)
      run.stallUsed = true
      audio.play("reveal")
      fx.toast(cards.getDef(c).name .. " trains hard and reaches level " .. c.level .. "!", "good")
      G.persist()
    end)
  end
end

function S:keypressed(k)
  if k == "escape" then overlays.pause() end
end

return S
