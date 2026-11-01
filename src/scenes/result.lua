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
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c

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
  S.bg = won and { C.ink, { 0.3, 0.24, 0.02 }, C.gold, spin = 1.6 } or { C.black, { 0.25, 0.05, 0.04 }, C.red, spin = 0.8 }
  self.step = won and (self.n and "fate" or "cards") or "loss"
  if self.step == "cards" then self:makeCards() end
  self.portrait = art.entrant(G.save, self.ctx.opp, 48)
  if won then sfx.play("cheer") end
end

function S:makeCards()
  local items = {}
  for i, id in ipairs(self.out.cardChoices) do items[i] = { id = id } end
  self.picker = picker.new(items, { x = 320, y = 230, scale = 1.3, gap = 22, dealFrom = { 320, 420 } })
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
  gfx.wavy(title, theme.T.headL(), 320, 8, out.won and C.gold or C.red, self.t, 2)
  local cons = consequence(out, f)
  gfx.text(cons, theme.T.big(), 320, 52, out.champion and C.gold or C.paper, { align = "center" })
  gfx.text(out.won and ("+" .. out.fish .. " fish" .. (out.flawless and "   flawless!" or "")) or "+5 fish for showing up", theme.T.body(), 320, 72, C.gold, { align = "center" })
  local y = 86
  if out.line ~= "" then
    gfx.box(155, y, 34, 34, C.black)
    lg.setColor(1, 1, 1)
    lg.draw(self.portrait, 156, y + 1, 0, 32 / 48, 32 / 48)
    gfx.textf(self.ctx.opp.name .. ': "' .. out.line .. '"', theme.T.body(), 196, y + 4, 300, "left", C.paper)
    y = y + 40
  end
  for _, l in ipairs(out.levelUps) do
    gfx.text("* " .. l.name .. " reached level " .. l.level .. "!", theme.T.body(), 320, y, C.gold, { align = "center" })
    y = y + 11
  end
  for _, t in ipairs(out.intel) do
    y = y + gfx.textf(t, theme.T.body(), 120, y, 400, "center", C.green) + 2
  end
  return y
end

function S:draw()
  local run = G.save.run
  local y = self:header()
  if self.step == "loss" then
    if self.n then gfx.text(self.n.name .. " will remember this, and grow stronger.", theme.T.body(), 320, y + 8, C.muted, { align = "center" }) end
    if widgets.button("r_go", 240, 300, 160, 30, "Continue", { color = C.red }) then self:continue() end
  elseif self.step == "fate" then
    local n = self.n
    gfx.text(n.name .. " is at your mercy.", theme.T.head(), 320, math.max(y + 6, 150), C.paper, { align = "center" })
    local opts = {
      { "slay", "Slay", "They forfeit the festival. They might not stay dead.", C.red, false },
      { "recruit", "Recruit", self.out.flawless and "They join your pride as a Legendary." or "Only after a flawless match.", C.blue, not self.out.flawless },
      { "brand", "Brand", "Spare them, but leave a weakness and a grudge.", C.ink3, false },
    }
    for i, o in ipairs(opts) do
      if widgets.button("fate_" .. o[1], 28 + (i - 1) * 200, 214, 184, 56, o[2], { color = o[4], sub = o[3], disabled = o[5] }) then
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
    gfx.label("Choose a cat to join your pride", 320, 162, C.pale, "center")
    local i = self.picker and self.picker:draw()
    if i then
      local v = self.picker.views[i]
      game.addCard(run, self.out.cardChoices[i])
      fx.burst(v.x, v.y, cards.RARITY_COLOR[v.def.rarity], 24, 140)
      G.persist()
      self:nextAfterCards()
    end
    if widgets.button("r_skip", 260, 322, 120, 22, "Skip (+10 fish)", { font = theme.T.num() }) then
      run.fish = run.fish + 10
      sfx.play("coin")
      self:nextAfterCards()
    end
  elseif self.step == "charms" then
    gfx.label("A charm from the festival judges", 320, 162, C.gold, "center")
    for i, id in ipairs(self.out.charmChoices) do
      local info = charms.CHARMS[id]
      local x = 320 - (#self.out.charmChoices * 210) / 2 + (i - 1) * 210 + 5
      local clicked, over = widgets.click("rc" .. i, x, 180, 200, 80)
      gfx.panel(x, 180 - (over and 2 or 0), 200, 80, over and C.ink3 or C.ink2, { border = C.goldDark })
      icons.draw(info.icon, x + 22, 214, info.color and cards.COATS[info.color].color or C.gold, 3)
      gfx.text(info.name, theme.T.headS(), x + 44, 190, C.paper)
      gfx.textf(info.desc, theme.T.body(), x + 44, 206, 150, "left", C.paper2)
      if clicked then
        game.addCharm(run, id)
        sfx.play("coin")
        fx.burst(x + 100, 220, C.gold, 24, 140)
        G.persist()
        self:continue()
      end
    end
    if widgets.button("r_leave", 260, 300, 120, 22, "Leave it", { font = theme.T.num() }) then self:continue() end
  end
end

return S
