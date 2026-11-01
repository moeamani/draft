local art = require("src.ui.art")
local charms = require("src.core.charms")
local cards = require("src.core.cards")
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

function S:enter(p)
  self.ctx, self.out = p.ctx, p.out
  self.t = 0
  local win = self.out.result == "win"
  self.n = self.ctx.nemesis
  S.bg = win and { C.ink, { 0.32, 0.25, 0.02 }, C.gold, spin = 1.4 } or { C.black, { 0.25, 0.05, 0.04 }, C.red, spin = 0.8 }
  if win and self.n then self.step = "fate"
  elseif win then self.step = "cards"
  else self.step = "loss" end
  if self.step == "cards" then self:makeCards() end
  sfx.play(win and "win" or "lose")
  if win then
    for i = 1, 3 do fx.burst(400 + i * 200, 200, C.gold, 20, 500, 7) end
  end
end

function S:makeCards()
  local items = {}
  for i, id in ipairs(self.out.cardChoices) do items[i] = { id = id } end
  self.picker = picker.new(items, { x = 800, y = 560, scale = 0.95, gap = 50, dealFrom = { 800, 1200 } })
end

function S:update(dt)
  self.t = self.t + dt
  if self.picker then self.picker:update(dt) end
end

local function after(self)
  local save = G.save
  local run = save.run
  if self.out.runOver then
    game.finishRun(save, "defeat")
    G.persist()
    return G.go("summary")
  end
  if self.out.result == "win" then
    game.advance(save)
    G.persist()
    return G.go(save.run.phase == "over" and "summary" or "map")
  end
  run.options = game.genOptions(save)
  G.persist()
  G.go("map")
end

function S:header()
  local out = self.out
  local win = out.result == "win"
  local title = win and "Victory" or out.result == "draw" and "A Bitter Draw" or "Defeat"
  gfx.wavy(title, theme.font("bold", 88), 800, 30, win and C.gold or C.red, self.t, 5)
  local run = G.save.run
  local sub = win and ("+" .. out.fish .. " fish" .. (out.flawless and "   -   flawless" or "")) or ("-" .. out.livesLost .. (out.livesLost == 1 and " life" or " lives") .. "   -   " .. run.lives .. " remaining")
  gfx.text(sub, theme.font("monoBold", 20), 800, 140, win and C.gold or C.paper, { align = "center", shadow = 0 })
  local y = 180
  if out.line ~= "" then
    if self.n then
      local p = art.nemesis(self.n, game.rankOf(G.save, self.n))
      p:setFilter("nearest", "nearest")
      lg.setColor(1, 1, 1)
      lg.draw(p, 420, y, 0, 64 / 64, 64 / 64)
      gfx.textf(self.n.name .. ': "' .. out.line .. '"', theme.font("italic", 24), 500, y + 16, 700, "left", C.paper)
    else
      gfx.text(out.line, theme.font("italic", 24), 800, y + 16, C.paper, { align = "center" })
    end
    y = y + 80
  end
  for _, l in ipairs(out.levelUps) do
    gfx.text("* " .. l.name .. " reached level " .. l.level .. "!", theme.font("serif", 21), 800, y, C.gold, { align = "center" })
    y = y + 30
  end
  for _, t in ipairs(out.intel) do
    y = y + gfx.textf(t, theme.font("serif", 20), 300, y, 1000, "center", C.green) + 4
  end
  if out.promoted then
    y = y + gfx.textf(out.promoted, theme.font("bold", 21), 300, y, 1000, "center", C.red) + 4
  end
  return y
end

function S:draw()
  local run = G.save.run
  local y = self:header()
  if self.step == "loss" then
    if self.n then gfx.text(self.n.name .. " grows stronger from this. Their next appearance will be harder.", theme.font("serif", 20), 800, y + 20, C.muted, { align = "center", shadow = 0 }) end
    if widgets.button("r_go", 620, 640, 360, 76, self.out.runOver and "Your last life..." or "Lick your wounds", { color = C.red }) then after(self) end
  elseif self.step == "fate" then
    local n = self.n
    gfx.text(n.name .. " is at your mercy.", theme.font("bold", 40), 800, math.max(y + 10, 330), C.paper, { align = "center" })
    local by = 470
    local opts = {
      { "slay", "Slay", "Remove them from the Hands. They might not stay dead.", C.red, false },
      { "recruit", "Recruit", self.out.flawless and "They join your pride as a Legendary card." or "Only after a flawless 2-0 win.", C.blue, not self.out.flawless },
      { "brand", "Brand", "Spare them, but leave a weakness. They will hate you for it.", C.ink3, false },
    }
    for i, o in ipairs(opts) do
      if widgets.button("fate_" .. o[1], 200 + (i - 1) * 420, by, 380, 140, o[2], { color = o[4], size = 40, sub = o[3], disabled = o[5] }) then
        local txt = game.decideFate(G.save, n, o[1])
        local situation = o[1] == "slay" and "slain" or o[1] == "recruit" and "recruit" or "brand"
        local line = nemesis.speak({ s = math.floor(love.math.random() * 2 ^ 30) + 1 }, n, situation, G.save.playerName)
        G.persist()
        fx.addShake(o[1] == "slay" and 12 or 5)
        if o[1] == "slay" then sfx.play("burn"); fx.burst(800, 400, C.red, 50, 600, 9) else sfx.play("reveal") end
        overlays.message(n.name, '"' .. line .. '"\n\n' .. txt, function() self.step = "cards"; self:makeCards() end, art.nemesis(n, 0))
      end
    end
  elseif self.step == "cards" then
    gfx.label("Choose a cat to join your pride", 800, 352, C.pale, "center")
    local i = self.picker and self.picker:draw()
    if i then
      local v = self.picker.views[i]
      game.addCard(run, self.out.cardChoices[i])
      fx.burst(v.x, v.y, cards.RARITY_COLOR[v.def.rarity], 30, 450, 8)
      G.persist()
      self:nextAfterCards()
    end
    if widgets.button("r_skip", 680, 820, 240, 56, "Skip (+10 fish)", { size = 20 }) then
      run.fish = run.fish + 10
      sfx.play("coin")
      self:nextAfterCards()
    end
  elseif self.step == "charms" then
    gfx.label("The Warlord's hoard: choose a charm", 800, 380, C.gold, "center")
    for i, id in ipairs(self.out.charmChoices) do
      local info = charms.CHARMS[id]
      local x = 800 - (#self.out.charmChoices * 440) / 2 + (i - 1) * 440 + 20
      local clicked, over = widgets.click("rc" .. i, x, 440, 400, 170)
      gfx.panel(x, 440 - (over and 6 or 0), 400, 170, over and C.ink3 or C.ink2, { border = C.gold, lw = 3, r = 18 })
      local col = info.color and cards.COATS[info.color].color or C.gold
      icons.draw(info.icon, x + 60, 520, 64, col, math.sin(self.t * 2 + i) * 0.1)
      gfx.text(info.name, theme.font("bold", 26), x + 112, 466, C.paper)
      gfx.textf(info.desc, theme.font("serif", 19), x + 112, 504, 270, "left", C.paper2, { shadow = false })
      if clicked then
        game.addCharm(run, id)
        sfx.play("coin")
        fx.burst(x + 200, 520, C.gold, 30, 500, 8)
        G.persist()
        after(self)
      end
    end
    if widgets.button("r_leave", 680, 700, 240, 56, "Leave it", { size = 20 }) then after(self) end
  end
end

function S:nextAfterCards()
  local run = G.save.run
  if #self.out.charmChoices > 0 and #run.charms < charms.MAX then
    self.step = "charms"
    self.picker = nil
  else
    after(self)
  end
end

return S
