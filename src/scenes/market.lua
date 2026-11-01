local cards = require("src.core.cards")
local charms = require("src.core.charms")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local hud = require("src.ui.hud")
local icons = require("src.ui.icons")
local overlays = require("src.ui.overlays")
local picker = require("src.ui.picker")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local S = {}
local C = theme.c
S.bg = { C.ink, { 0.3, 0.22, 0.02 }, C.gold, spin = 1.0 }

function S:enter()
  self.t = 0
  self.stock = game.makeMarket(G.save.run)
  self.picker = picker.new(self.stock.cards, { x = 196, y = 110, scale = 1.2, gap = 14, dealFrom = { 196, 420 } })
end

function S:update(dt)
  self.t = self.t + dt
  self.picker:update(dt)
end

local function charmBox(id, x, y, w, price, sold, key)
  local info = charms.CHARMS[id]
  local clicked, over = widgets.click(key, x, y, w, 48)
  gfx.panel(x, y - ((over and not sold) and 2 or 0), w, 48, sold and C.deep or (over and C.ink3 or C.ink2), { border = sold and nil or C.goldDark })
  if sold then
    gfx.text("SOLD", theme.T.numL(), x + w / 2, y + 14, C.muted, { align = "center" })
    return false
  end
  icons.draw(info.icon, x + 16, y + 24, info.color and cards.COATS[info.color].color or C.gold, 2)
  gfx.text(info.name, theme.T.body(), x + 32, y + 5, C.paper)
  gfx.textf(info.desc, theme.T.tiny(), x + 32, y + 16, w - 80, "left", C.paper2)
  gfx.panel(x + w - 42, y + 16, 38, 14, C.gold)
  gfx.text(price .. " fish", theme.T.tiny(), x + w - 23, y + 19, C.black, { align = "center", shadow = false })
  return clicked
end

function S:draw()
  local run = G.save.run
  hud.draw(run)
  gfx.wavy("Mews Market", theme.T.head(), 196, 32, C.gold, self.t, 1)
  gfx.text('"Fresh cats! Slightly used charms! No refunds!"', theme.T.tiny(), 196, 58, C.muted, { align = "center" })
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
  gfx.label("Charms (" .. #run.charms .. "/" .. charms.MAX .. ")", 392, 36, C.gold)
  for k, ch in ipairs(self.stock.charms) do
    if charmBox(ch.id, 392, 48 + (k - 1) * 54, 240, ch.price, ch.sold, "charm" .. k) then
      if run.fish < ch.price then fx.toast("Not enough fish.", "bad")
      elseif not game.addCharm(run, ch.id) then fx.toast("You can only carry 5 charms.", "bad")
      else
        run.fish = run.fish - ch.price
        ch.sold = true
        sfx.play("coin")
        fx.burst(512, 72 + (k - 1) * 54, C.gold, 20, 120)
        G.persist()
      end
    end
  end
  gfx.label("Services", 392, 160, C.gold)
  if widgets.button("m_rm", 392, 172, 240, 36, "Send a cat home", { sub = "Remove a card - " .. game.REMOVE_PRICE .. " fish", disabled = self.stock.removed or run.fish < game.REMOVE_PRICE or #run.deck <= 10 }) then
    overlays.chooseCard("Send which cat home?", run.deck, nil, function(c)
      run.fish = run.fish - game.REMOVE_PRICE
      game.removeCard(run, c.uid)
      self.stock.removed = true
      fx.toast(cards.getDef(c).name .. " goes home for a nap.", "info")
      G.persist()
    end)
  end
  if widgets.button("m_up", 392, 214, 240, 36, "Pay a trainer", { sub = "+1 level to a cat - " .. game.UPGRADE_PRICE .. " fish", disabled = self.stock.upgraded or run.fish < game.UPGRADE_PRICE }) then
    overlays.chooseCard("Train which cat?", run.deck, function(c) return cards.getDef(c).kind == "unit" and c.level < 3 end, function(c)
      run.fish = run.fish - game.UPGRADE_PRICE
      game.upgradeCard(run, c.uid)
      self.stock.upgraded = true
      fx.toast(cards.getDef(c).name .. " reaches level " .. c.level .. "!", "good")
      sfx.play("reveal")
      G.persist()
    end)
  end
  if widgets.button("m_leave", 392, 318, 240, 30, "Back to the grounds", { color = C.red }) then
    G.persist()
    G.go("hub")
  end
end

return S
