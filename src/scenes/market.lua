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
local cards = require("src.core.cards")

local S = {}
local C = theme.c
S.bg = { C.ink, { 0.3, 0.22, 0.02 }, C.gold, spin = 1.0 }

function S:enter()
  self.t = 0
  self.stock = game.makeMarket(G.save.run)
  self.picker = picker.new(self.stock.cards, { x = 560, y = 360, scale = 0.82, gap = 30, dealFrom = { 560, 1200 } })
end

function S:update(dt)
  self.t = self.t + dt
  self.picker:update(dt)
end

local function charmBox(id, x, y, w, price, sold, key)
  local info = charms.CHARMS[id]
  local clicked, over = widgets.click(key, x, y, w, 100)
  local col = info.color and cards.COATS[info.color].color or C.gold
  gfx.panel(x, y - (over and 4 or 0), w, 100, over and C.ink3 or C.ink2, { border = sold and { 0.3, 0.3, 0.3 } or C.gold, lw = 2, r = 14, alpha = sold and 0.4 or 1 })
  if sold then
    gfx.text("SOLD", theme.font("monoBold", 26), x + w / 2, y + 34, C.muted, { align = "center" })
    return false
  end
  icons.draw(info.icon, x + 46, y + 50, 44, col, math.sin(G.time * 2) * 0.1)
  gfx.text(info.name, theme.font("bold", 22), x + 86, y + 14, C.paper)
  gfx.textf(info.desc, theme.font("serif", 16), x + 86, y + 44, w - 100, "left", C.paper2, { shadow = false })
  gfx.panel(x + w - 84, y - 12, 92, 32, C.gold, { r = 10, depth = 3, sheen = false })
  gfx.text(price .. " fish", theme.font("bold", 18), x + w - 38, y - 8, C.black, { align = "center", shadow = 0 })
  return clicked
end

function S:draw()
  local run = G.save.run
  hud.draw(run)
  gfx.wavy("Mews Market", theme.font("bold", 60), 560, 92, C.gold, self.t, 3)
  gfx.text('"Fresh cats! Slightly used charms! No refunds!"', theme.font("italic", 20), 560, 168, C.muted, { align = "center", shadow = 0 })
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
      fx.burst(v.x, v.y, C.gold, 24, 380, 7)
      G.persist()
    end
  end
  gfx.label("Charms (" .. #run.charms .. "/" .. charms.MAX .. ")", 1150, 120, C.gold)
  for k, ch in ipairs(self.stock.charms) do
    if charmBox(ch.id, 1150, 150 + (k - 1) * 130, 400, ch.price, ch.sold, "charm" .. k) then
      if run.fish < ch.price then fx.toast("Not enough fish.", "bad")
      elseif not game.addCharm(run, ch.id) then fx.toast("You can only carry 5 charms.", "bad")
      else
        run.fish = run.fish - ch.price
        ch.sold = true
        sfx.play("coin")
        fx.burst(1350, 200 + (k - 1) * 130, C.gold, 24, 380, 7)
        G.persist()
      end
    end
  end
  gfx.label("Services", 1150, 430, C.gold)
  if widgets.button("m_up", 1150, 460, 400, 80, "Train a cat", { sub = "+1 level (+2 power)  -  " .. game.UPGRADE_PRICE .. " fish", disabled = self.stock.upgraded or run.fish < game.UPGRADE_PRICE }) then
    overlays.chooseCard("Train which cat?", run.deck, function(c) return cards.getDef(c).kind == "unit" and c.level < 3 end, function(c)
      run.fish = run.fish - game.UPGRADE_PRICE
      game.upgradeCard(run, c.uid)
      self.stock.upgraded = true
      fx.toast(cards.getDef(c).name .. " reaches level " .. c.level .. "!", "good")
      sfx.play("reveal")
      G.persist()
    end)
  end
  if widgets.button("m_rm", 1150, 560, 400, 80, "Send a cat home", { sub = "Remove a card  -  " .. game.REMOVE_PRICE .. " fish", disabled = self.stock.removed or run.fish < game.REMOVE_PRICE or #run.deck <= 10 }) then
    overlays.chooseCard("Send which cat home?", run.deck, nil, function(c)
      run.fish = run.fish - game.REMOVE_PRICE
      game.removeCard(run, c.uid)
      self.stock.removed = true
      fx.toast(cards.getDef(c).name .. " goes home for a nap.", "info")
      G.persist()
    end)
  end
  if widgets.button("m_leave", 1150, 740, 400, 74, "Leave market", { color = C.red }) then
    game.advance(G.save)
    G.persist()
    G.go(G.save.run.phase == "over" and "summary" or "map")
  end
end

return S
