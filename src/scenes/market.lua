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
local audio = require("src.audio")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
S.bg = { preset = "table" }
local C = theme.c
local T = theme.T

function S:enter()
  self.t = 0
  self.stock = game.makeMarket(G.save.run)
  local n = #self.stock.cards
  self.picker = picker.new(self.stock.cards, { x = 196, y = 142, scale = 1, gap = n > 4 and 8 or 16, dealFrom = { 196, 420 } })
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
      if c.pawn then
        game.buyBack(run, c)
        fx.toast(cards.getDef(c).name .. " is back in your pride.", "good")
      else
        game.addCard(run, c.id)
      end
      audio.play("coin")
      local v = self.picker.views[i]
      fx.burst(v.x, v.y, C.gold, 20, 120)
      G.persist()
    end
  end
  for k, c in ipairs(self.stock.cards) do
    local v = self.picker.views[k]
    if c.pawn and not c.sold and v then gfx.chip("yours: pawned", math.floor(v.x - 28), math.floor(v.y - 52), "strength") end
  end
  gfx.text("Hover a card to read it. Click to buy.", T.body(), 196, 214, C.muted, { align = "center" })
  self:drawUpholsterer(run)
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
          audio.play("coin")
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
      audio.play("reveal")
      G.persist()
    end)
  end
  if widgets.button("m_leave", 392, 314, 240, 34, "Back to the grounds", { color = C.red }) then
    G.persist()
    G.go("hub")
  end
end

-- The upholsterer: one cushion upgrade a visit, kept for the rest of the festival.
function S:drawUpholsterer(run)
  local offer = self.stock.cushion
  if not offer then return end
  local match = require("src.core.match")
  local ck = match.CUSHION_KINDS[offer.kind]
  local look = theme.CUSHION[offer.kind]
  plates.header(8, 236, 376, 22, look.col, "Upholsterer", { size = 16, streak = 0.43 })
  local have = run.cushions or {}
  -- your three cushions as they are now
  for i = 1, 3 do
    local x, y = 16 + (i - 1) * 30, 266
    local kind = have[i]
    local col = kind and theme.CUSHION[kind].col or C.ink2
    gfx.box(x, y, 24, 30, C.black)
    gfx.box(x + 1, y + 1, 22, 28, col)
    if i == offer.slot then
      theme.set(C.gold)
      lg.rectangle("line", x - 1.5, y - 1.5, 27, 33)
    end
    gfx.text(({ "L", "M", "R" })[i], T.small(), x + 12, y + 30, C.muted, { align = "center" })
  end
  if offer.sold then
    gfx.panel(112, 264, 272, 52, C.deep, { border = C.ink3 })
    gfx.text("Your " .. match.CUSHION_NAMES[offer.slot]:lower() .. " cushion is now " .. ck.name .. ".", T.body(), 248, 281, C.muted, { align = "center" })
    return
  end
  local title = ck.name .. ": " .. match.CUSHION_NAMES[offer.slot]:lower() .. " cushion"
  local desc = ck.desc .. (have[offer.slot] and (" Replaces " .. match.CUSHION_KINDS[have[offer.slot]].name .. ".") or "")
  if widgets.choice("uph", 112, 264, 272, 52, title, desc, { icon = look.icon, iconColor = look.col }) then
    if run.fish < offer.price then fx.toast("Not enough fish.", "bad")
    else
      run.fish = run.fish - offer.price
      game.upholster(run, offer.slot, offer.kind)
      offer.sold = true
      audio.play("coin")
      fx.burst(248, 290, look.col, 20, 120)
      fx.toast("Your " .. match.CUSHION_NAMES[offer.slot]:lower() .. " cushion is now " .. ck.name .. ".", "good")
      G.persist()
    end
  end
  local label = offer.price .. " fish"
  local pw = T.body():getWidth(label) + 10
  gfx.panel(16, 310, pw, 16, C.gold)
  gfx.text(label, T.body(), 16 + pw / 2, 309, C.black, { align = "center", shadow = false })
end

return S
