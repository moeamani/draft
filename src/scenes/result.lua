-- After a match: verdict, festival consequence, a Hand's fate, then card and charm rewards.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local charms = require("src.core.charms")
local festival = require("src.core.festival")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local nemesis = require("src.core.nemesis")
local overlays = require("src.ui.overlays")
local picker = require("src.ui.picker")
local plates = require("src.ui.plates")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c
local T = theme.T

local function consequence(out, f)
  if out.champion then return "FESTIVAL CHAMPION!" end
  if out.eliminated then
    return out.stage == "group" and "Out in the group stage." or ("Knocked out in the " .. festival.STAGE_NAMES[out.stage]:lower() .. ".")
  end
  if f.stage == "qf" and out.stage == "group" then return "Through to the knockouts!" end
  if out.stage == "group" then return out.won and "Three points in the group table." or "No points this round. Keep fighting." end
  return out.won and ("Through to the " .. festival.STAGE_NAMES[f.stage] .. "!") or ""
end

function S:enter(p)
  self.ctx, self.out = p.ctx, p.out
  self.t = 0
  self.n = self.ctx.nemesis
  local won = self.out.won
  S.bg = { preset = "menu", ramp = won and "felt" or "blood" }
  self.step = won and (self.n and "fate" or "cards") or "loss"
  if self.step == "cards" then self:makeCards() end
  self.portrait = art.entrant(G.save, self.ctx.opp, 48)
  if won then sfx.play("cheer") end
end

function S:makeCards()
  local items = {}
  for i, id in ipairs(self.out.cardChoices) do items[i] = { id = id } end
  self.picker = picker.new(items, { x = 320, y = 244, scale = 1, gap = 30, dealFrom = { 320, 420 } })
end

function S:update(dt)
  self.t = self.t + dt
  if self.picker then self.picker:update(dt) end
end

function S:continue()
  game.afterMatch(G.save)
  G.persist()
  if G.save.run.phase == "over" then G.go("summary")
  else G.go("hub", { notes = self.out.notes }) end
end

function S:nextAfterCards()
  if #self.out.charmChoices > 0 and #G.save.run.charms < charms.MAX then
    self.step = "charms"
    self.picker = nil
  else
    self:continue()
  end
end

function S:header()
  local out = self.out
  local f = G.save.run.festival
  local title = out.won and "Victory" or "Defeat"
  plates.header(170, 8, 300, 40, out.won and C.goldDark or C.night, title, { size = 30, streak = out.won and 0.43 or 1.0, align = "center" })
  local cons = consequence(out, f)
  gfx.text(cons, T.big(), 320, 52, out.champion and C.gold or C.paper, { align = "center" })
  gfx.text(out.won and ("+" .. out.fish .. " fish" .. (out.flawless and ", never lost a bout!" or "")) or "+5 fish for showing up", T.body(), 320, 74, C.gold, { align = "center" })
  local y = 94
  if out.line ~= "" then
    gfx.box(125, y, 34, 34, C.black)
    lg.setColor(1, 1, 1)
    lg.draw(self.portrait, 126, y + 1, 0, 32 / 48, 32 / 48)
    local h = gfx.textf(self.ctx.opp.name .. ': "' .. out.line .. '"', T.body(), 166, y + 1, 350, "left", C.paper)
    y = y + math.max(38, h + 6)
  end
  for _, l in ipairs(out.levelUps) do
    gfx.text(l.name .. " reached level " .. l.level .. "!", T.body(), 320, y, C.gold, { align = "center" })
    y = y + 17
  end
  for _, t in ipairs(out.intel) do
    y = y + gfx.textf(t, T.body(), 110, y, 420, "center", C.green) + 3
  end
  -- Stolen Lives: what changed hands
  local lost = {}
  for _, c in ipairs(out.captured or {}) do lost[#lost + 1] = cards.CARDS[c.id] and cards.CARDS[c.id].name or c.id end
  if #lost > 0 then
    local where = self.n and (self.n.name .. " keeps them. Beat " .. self.n.name .. " to bring them home.") or "The stray will pawn them at the Mews Market."
    y = y + gfx.textf("Captured: " .. table.concat(lost, ", ") .. ". " .. where, T.body(), 90, y + 2, 460, "center", C.redText) + 5
  end
  local back = {}
  for _, id in ipairs(out.rescued or {}) do back[#back + 1] = cards.CARDS[id] and cards.CARDS[id].name or id end
  if #back > 0 then
    y = y + gfx.textf("Rescued: " .. table.concat(back, ", ") .. " came home!", T.body(), 90, y + 2, 460, "center", C.goldText) + 5
  end
  if (out.guards or 0) > 0 then
    y = y + gfx.textf("Your pride is thin: the Arena lends you " .. out.guards .. " guard" .. (out.guards > 1 and "s" or "") .. ".", T.body(), 90, y + 2, 460, "center", C.muted) + 5
  end
  return y
end

function S:draw()
  local run = G.save.run
  local y = self:header()
  if self.step == "loss" then
    if self.n then gfx.text(self.n.name .. " will remember this, and grow stronger.", T.body(), 320, y + 8, C.paper2, { align = "center" }) end
    if widgets.button("r_go", 240, 300, 160, 32, "Continue", { color = C.red }) then self:continue() end
  elseif self.step == "fate" then
    local n = self.n
    local ty = math.max(y + 6, 150)
    plates.print(n.name .. " is at your mercy.", 24, 320, ty, C.white, { align = "center" })
    local opts = {
      { "slay", "Slay", "They forfeit the festival. They might not stay dead.", C.redDark, false },
      { "recruit", "Recruit", self.out.flawless and "They join your pride as a Legendary card." or "Only if you never lost a bout.", C.blueDark, not self.out.flawless },
      { "brand", "Brand", "Spare them, but leave a weakness and a grudge.", C.ink2, false },
    }
    for i, o in ipairs(opts) do
      if widgets.choice("fate_" .. o[1], 24 + (i - 1) * 200, ty + 36, 192, 84, o[2], o[3], { color = o[4], disabled = o[5] }) then
        local txt = game.decideFate(G.save, n, o[1])
        local sit = o[1] == "slay" and "slain" or o[1] == "recruit" and "recruit" or "brand"
        local line = nemesis.speak({ s = math.floor(love.math.random() * 2 ^ 30) + 1 }, n, sit, G.save.playerName)
        G.persist()
        fx.addShake(o[1] == "slay" and 8 or 4)
        if o[1] == "slay" then sfx.play("burn"); fx.burst(320, 180, C.red, 40, 160) else sfx.play("reveal") end
        overlays.message(n.name, '"' .. line .. '"\n\n' .. txt, function() self.step = "cards"; self:makeCards() end, art.nemesis(n, 0, 96))
      end
    end
  elseif self.step == "cards" then
    local spoils = self.out.spoils and next(self.out.spoils) ~= nil
    plates.print(spoils and "Spoils: choose a cat to join your pride" or "Choose a cat to join your pride", 20, 320, math.max(y + 2, 168), C.white, { align = "center" })
    local i = self.picker and self.picker:draw()
    if self.picker and self.out.spoils then
      for k, v in ipairs(self.picker.views) do
        if self.out.spoils[self.out.cardChoices[k]] then
          gfx.chip("captured", math.floor(v.x - 20), math.floor(v.y - 52), "gold")
        end
      end
    end
    if i then
      local v = self.picker.views[i]
      game.addCard(run, self.out.cardChoices[i])
      fx.burst(v.x, v.y, cards.RARITY_COLOR[v.def.rarity], 24, 140)
      G.persist()
      self:nextAfterCards()
    end
    if widgets.button("r_skip", 250, 322, 140, 26, "Skip (+10 fish)", { font = T.body() }) then
      run.fish = run.fish + 10
      sfx.play("coin")
      self:nextAfterCards()
    end
  elseif self.step == "charms" then
    plates.print("A charm from the festival judges", 20, 320, math.max(y + 2, 150), C.white, { align = "center" })
    for i, id in ipairs(self.out.charmChoices) do
      local info = charms.CHARMS[id]
      local x = 320 - (#self.out.charmChoices * 220) / 2 + (i - 1) * 220 + 10
      if widgets.choice("rc" .. i, x, 184, 200, 90, info.name, info.desc, { icon = info.icon, iconColor = info.color and cards.COATS[info.color].color or C.gold }) then
        game.addCharm(run, id)
        sfx.play("coin")
        fx.burst(x + 100, 220, C.gold, 24, 140)
        G.persist()
        self:continue()
      end
    end
    if widgets.button("r_leave", 250, 300, 140, 26, "Leave it", { font = T.body() }) then self:continue() end
  end
end

return S
