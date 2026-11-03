local cards = require("src.core.cards")
local charms = require("src.core.charms")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local hud = require("src.ui.hud")
local icons = require("src.ui.icons")
local overlays = require("src.ui.overlays")
local picker = require("src.ui.picker")
local plates = require("src.ui.plates")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local S = {}
local C = theme.c
local T = theme.T

function S:enter()
  self.t = 0
  self.stock = game.makeMarket(G.save.run)
  self.picker = picker.new(self.stock.cards, { x = 196, y = 142, scale = 1, gap = 16, dealFrom = { 196, 420 } })
end

function S:update(dt)
  self.t = self.t + dt
  self.picker:update(dt)
end

function S:draw()
  local run = G.save.run
  hud.draw(run)
  plates.header(8, 40, 376, 40, C.gold, "Mews Market", { size = 28, streak = 0.43, align = "center" })
  gfx.text('"Fresh cats! Slightly used charms! No refunds!"', T.body(), 196, 86, C.paper2, { align = "center" })
  local i = self.picker:draw()
  if i then
    local c = self.stock.cards[i]
    if c.sold then
    elseif run.fish < c.price then fx.toast("Not enough fish.", "bad")
    else
      run.fish = run.fish - c.price
      c.sold = true
      game.addCard(run, c.id)
      sfx.play("coin")
      local v = self.picker.views[i]
      fx.burst(v.x, v.y, C.gold, 20, 120)
      G.persist()
    end
  end
  gfx.text("Hover a card to read it. Click to buy.", T.body(), 196, 214, C.muted, { align = "center" })
  gfx.label("Charms (" .. #run.charms .. "/" .. charms.MAX .. ")", 392, 40, C.gold)
  for k, ch in ipairs(self.stock.charms) do
    local info = charms.CHARMS[ch.id]
    local y = 50 + (k - 1) * 70
    if ch.sold then
      gfx.panel(392, y, 240, 64, C.deep, { border = C.ink3 })
      gfx.text("Sold", T.big(), 512, y + 18, C.muted, { align = "center" })
    else
      local label = ch.price .. " fish"
      if widgets.choice("charm" .. k, 392, y, 240, 64, info.name, info.desc, { icon = info.icon, iconColor = info.color and cards.COATS[info.color].color or C.gold }) then
        if run.fish < ch.price then fx.toast("Not enough fish.", "bad")
        elseif not game.addCharm(run, ch.id) then fx.toast("You can only carry 5 charms.", "bad")
        else
          run.fish = run.fish - ch.price
          ch.sold = true
          sfx.play("coin")
          fx.burst(512, y + 30, C.gold, 20, 120)
          G.persist()
        end
      end
      local pw = T.body():getWidth(label) + 10
      gfx.panel(628 - pw, y + 6, pw, 16, C.gold)
      gfx.text(label, T.body(), 628 - pw / 2, y + 5, C.black, { align = "center", shadow = false })
    end
  end
  gfx.label("Services", 392, 192, C.gold)
  if widgets.button("m_rm", 392, 202, 240, 40, "Send a cat home", { font = T.body(), sub = "Remove a card for " .. game.REMOVE_PRICE .. " fish", disabled = self.stock.removed or run.fish < game.REMOVE_PRICE or #run.deck <= 10 }) then
    overlays.chooseCard("Send which cat home?", run.deck, nil, function(c)
      run.fish = run.fish - game.REMOVE_PRICE
      game.removeCard(run, c.uid)
      self.stock.removed = true
      fx.toast(cards.getDef(c).name .. " goes home for a nap.", "info")
      G.persist()
    end)
  end
  if widgets.button("m_up", 392, 248, 240, 40, "Pay a trainer", { font = T.body(), sub = "+1 level to a cat for " .. game.UPGRADE_PRICE .. " fish", disabled = self.stock.upgraded or run.fish < game.UPGRADE_PRICE }) then
    overlays.chooseCard("Train which cat?", run.deck, function(c) return cards.getDef(c).kind == "unit" and c.level < 3 end, function(c)
      run.fish = run.fish - game.UPGRADE_PRICE
      game.upgradeCard(run, c.uid)
      self.stock.upgraded = true
      fx.toast(cards.getDef(c).name .. " reaches level " .. c.level .. "!", "good")
      sfx.play("reveal")
      G.persist()
    end)
  end
  if widgets.button("m_leave", 392, 314, 240, 34, "Back to the grounds", { color = C.red }) then
    G.persist()
    G.go("hub")
  end
end

return S
