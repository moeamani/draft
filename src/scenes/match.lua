-- The match table: pick up to 5 cats, form a Formation, reveal, count the score, knock Pride off.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local cardview = require("src.ui.cardview")
local charms = require("src.core.charms")
local festival = require("src.core.festival")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local hud = require("src.ui.hud")
local icons = require("src.ui.icons")
local match = require("src.core.match")
local overlays = require("src.ui.overlays")
local picker = require("src.ui.picker")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local traits = require("src.core.traits")
local util = require("src.core.util")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c

local CX = 397
local RIVAL_HAND_Y, RIVAL_ZONE_Y, MY_ZONE_Y, HAND_Y = 18, 84, 172, 290
local DECK_X, DECK_Y = 618, 292

local function fmt(x)
  if math.abs(x - math.floor(x)) < 0.01 then return tostring(math.floor(x + 0.5)) end
  return string.format("%.1f", x)
end

function S:enter()
  local save = G.save
  self.ctx = game.setupMatch(save)
  G.persist()
  self.s = self.ctx.state
  self.t = 0
  self.hand, self.zone, self.leaving = {}, { {}, {} }, {}
  self.selected = {}
  self.timeline = {}
  self.lock = 0.4
  self.animating = false
  self.finished = false
  self.sortMode = "coat"
  self.disp = { {}, {} }
  self.pride = { self.s.sides[1].pride, self.s.sides[2].pride }
  self.prideShow = { self.pride[1], self.pride[2] }
  self.message = "Pick up to 5 cats, then PLAY."
  local n = self.ctx.nemesis
  self.rivalPortrait = art.entrant(save, self.ctx.opp, 32)
  self.myPortrait = art.player(save.playerName, 32)
  S.bg = n and { C.black, { 0.28, 0.05, 0.04 }, C.red, spin = 1.6 } or { C.ink, C.ink2, C.gold, spin = 1.0 }
  self:sortHand()
  self:rivalReady()
  fx.banner(festival.stageLabel(save.run.festival), "First to 0 Pride loses", n and C.red or C.gold)
end

-- ---------------------------------------------------------------- helpers

function S:at(delay, fn) self.timeline[#self.timeline + 1] = { t = delay, fn = fn } end

function S:sortHand()
  local hand = self.s.sides[1].hand
  local order = { ember = 1, tide = 2, gilt = 3, shadow = 4, none = 5 }
  if self.sortMode == "coat" then
    table.sort(hand, function(a, b)
      local da, db = cards.getDef(a), cards.getDef(b)
      if da.coat ~= db.coat then return order[da.coat] < order[db.coat] end
      return cards.paws(a) > cards.paws(b)
    end)
  else
    table.sort(hand, function(a, b)
      local pa, pb = cards.paws(a), cards.paws(b)
      if pa ~= pb then return pa > pb end
      return cards.getDef(a).coat < cards.getDef(b).coat
    end)
  end
end

function S:rivalReady()
  local b = self.s.sides[2]
  self.zone[2] = {}
  local sel = b.selection or {}
  for i, uid in ipairs(sel) do
    local inst
    for _, c in ipairs(b.hand) do if c.uid == uid then inst = c end end
    if inst then
      local v = cardview.new(inst, CX, -60, 0.9)
      v.flip, v.tflip = -1, -1
      self.zone[2][#self.zone[2] + 1] = v
    end
  end
  self:layoutZone(2)
end

function S:layoutZone(side)
  local list = self.zone[side]
  local n = #list
  for i, v in ipairs(list) do
    local x = CX + math.floor((i - (n + 1) / 2) * 50)
    v:setTarget(x, side == 2 and RIVAL_ZONE_Y or MY_ZONE_Y, 0.9, 0)
  end
end

function S:isSelected(uid) return util.contains(self.selected, uid) end

function S:toggle(inst)
  if self.animating or self.lock > 0 then return end
  if self:isSelected(inst.uid) then
    util.removeValue(self.selected, inst.uid)
    sfx.play("select", 0.8)
  elseif #self.selected < match.MAX_PLAY then
    self.selected[#self.selected + 1] = inst.uid
    sfx.play("select", 1.1)
  else
    fx.toast("Up to 5 cards per exchange.", "bad")
  end
end

function S:layoutHand()
  local hand = self.s.sides[1].hand
  local n = #hand
  local spacing = math.min(50, 400 / math.max(1, n))
  local hover
  for i = n, 1, -1 do
    local v = self.hand[hand[i].uid]
    if v and not hover and widgets.layer == widgets.top and v:contains(widgets.mx, widgets.my) then hover = hand[i] end
  end
  self.hoverInst = hover
  local preview = self.previewR
  local scoring = {}
  if preview then for _, c in ipairs(preview.scoring) do scoring[c.inst.uid] = true end end
  for i, inst in ipairs(hand) do
    local v = self.hand[inst.uid]
    if not v and not self.animating then
      v = cardview.new(inst, DECK_X, DECK_Y, 1)
      v.rot = 0.6
      self.hand[inst.uid] = v
      sfx.play("flip", 1 + i * 0.03, 0.5)
    end
    if v then
      local k = i - (n + 1) / 2
      local x = CX + math.floor(k * spacing)
      local sel = self:isSelected(inst.uid)
      v.selected = sel
      v.scoring = sel and scoring[inst.uid]
      v.hovered = inst == hover
      local y = HAND_Y + math.floor(k * k * 0.6) - (sel and 12 or 0) - (v.hovered and 4 or 0)
      v:setTarget(x, y, v.hovered and 1.12 or 1, k * 0.03)
    end
  end
end

-- ---------------------------------------------------------------- play / redraw

function S:redraw()
  if self.animating or self.lock > 0 or #self.selected == 0 then return end
  local sd = self.s.sides[1]
  if sd.redrawsLeft <= 0 then return fx.toast("No redraws left this exchange.", "bad") end
  local uids = util.map(self.selected, function(x) return x end)
  for _, uid in ipairs(uids) do
    local v = self.hand[uid]
    if v then
      self.hand[uid] = nil
      v:setTarget(DECK_X + 40, DECK_Y - 40, 0.8, 0.8)
      v.leaveT = 0.5
      self.leaving[#self.leaving + 1] = v
    end
  end
  match.redraw(self.s, 1, uids)
  self.selected = {}
  self:sortHand()
  sfx.play("whoosh", 1.2, 0.6)
  self.lock = 0.3
end

local function popAt(v, text, col)
  if v then
    v.bounce = 1
    fx.float(v.x, v.y - 42, text, col)
  end
end

function S:findView(side, uid)
  for _, v in ipairs(self.zone[side]) do if v.inst.uid == uid then return v end end
end

function S:play()
  if self.animating or self.lock > 0 or #self.selected == 0 then return end
  local s = self.s
  local uids = util.map(self.selected, function(x) return x end)
  self.selected = {}
  self.previewR = nil
  -- move my cards to the table
  self.zone[1] = {}
  for _, uid in ipairs(uids) do
    local v = self.hand[uid]
    if v then
      self.hand[uid] = nil
      v.selected = false
      self.zone[1][#self.zone[1] + 1] = v
    end
  end
  self:layoutZone(1)
  local rec = match.commit(s, uids)
  if not rec then return end
  self.animating = true
  sfx.play("card")
  local d = 0.3
  -- reveal the rival
  for i, v in ipairs(self.zone[2]) do
    self:at(d + i * 0.07, function() v.tflip = 1; sfx.play("flip", 1 + i * 0.05) end)
  end
  d = d + 0.25 + #self.zone[2] * 0.07
  local r1, r2 = rec.r[1], rec.r[2]
  self:at(d, function()
    self.disp[1] = { paws = 0, cheer = 0, name = r1.formation and r1.formation.name or "No formation", active = true }
    self.disp[2] = { paws = 0, cheer = 0, name = r2.formation and r2.formation.name or "No formation", active = false }
    -- light up the cats that actually score
    for _, c in ipairs(r1.scoring) do local v = self:findView(1, c.inst.uid); if v then v.selected = true end end
  end)
  d = d + 0.3
  local function scoreSide(side, r, speed)
    for k, st in ipairs(r.steps) do
      self:at(d, function()
        local disp = self.disp[side]
        disp.paws, disp.cheer, disp.active = st.paws, st.cheer, true
        local v = type(st.ref) == "string" and self:findView(side, st.ref)
        local col = st.target == "paws" and C.cyan or st.target == "cheer" and C.red or st.target == "xcheer" and C.red or st.target == "hex" and C.gold or C.paper
        if st.amount and st.amount < 0 then col = C.muted end
        if v then popAt(v, st.text, col)
        elseif st.ref ~= "formation" then fx.float(side == 1 and 76 or 76, side == 1 and 148 or 112, st.text, col) end
        sfx.play("tick", 0.9 + k * 0.05, 0.8)
      end)
      d = d + speed
    end
    self:at(d, function()
      local disp = self.disp[side]
      disp.total = r.total
      disp.paws, disp.cheer = r.paws, r.cheer
      fx.addShake(side == 1 and 3 or 2)
      sfx.play("slam", side == 1 and 1.2 or 1.0, 0.7)
    end)
    d = d + 0.35
  end
  scoreSide(1, r1, 0.17)
  self:at(d, function() self.disp[2].active = true end)
  scoreSide(2, r2, 0.1)
  -- verdict
  self:at(d, function()
    if rec.winner == 0 then
      fx.banner("Stalemate", "No Pride lost", C.paper)
    else
      local loser = 3 - rec.winner
      self.pride[loser] = s.sides[loser].pride + (rec.heal[loser] or 0) * 0 -- heal shown separately below
      self.pride[loser] = rec.prideBefore[loser] - rec.damage
      fx.float(76, loser == 1 and 214 or 50, "-" .. rec.damage, C.red, true)
      fx.addShake(rec.damage >= 35 and 9 or 5)
      sfx.play("hit")
      if rec.winner == 1 then sfx.play("cheer", 1, 0.8) end
      fx.burst(76, loser == 1 and 214 or 50, C.red, 18, 90)
      self.message = rec.winner == 1 and ("You win the exchange! " .. rec.damage .. " Pride off " .. s.sides[2].name .. ".") or (s.sides[2].name .. " wins the exchange. -" .. rec.damage .. " Pride.")
    end
  end)
  d = d + 0.6
  self:at(d, function()
    for i = 1, 2 do
      if rec.heal[i] > 0 then fx.float(76, i == 1 and 214 or 50, "+" .. rec.heal[i], C.green) end
      self.pride[i] = s.sides[i].pride
    end
    if rec.secondWind then fx.toast((rec.secondWind == 2 and s.sides[2].name or "You") .. " get a second wind! +20 Pride", "info") end
    for _, t in ipairs(rec.revealed or {}) do
      local info = traits.TRAITS[t]
      if info then sfx.play("reveal"); fx.toast(s.sides[2].name .. " has " .. info.name .. "! " .. info.desc, "info") end
    end
  end)
  d = d + 0.5
  -- clear the table
  self:at(d, function()
    local inHand = {}
    for _, c in ipairs(s.sides[1].hand) do inHand[c.uid] = true end
    for _, v in ipairs(self.zone[1]) do
      v.selected = false
      if inHand[v.inst.uid] then self.hand[v.inst.uid] = v
      else
        v:setTarget(680, MY_ZONE_Y + 20, 0.7, 0.9)
        v.leaveT = 0.6
        self.leaving[#self.leaving + 1] = v
      end
    end
    for _, v in ipairs(self.zone[2]) do
      v:setTarget(680, RIVAL_ZONE_Y - 30, 0.7, -0.9)
      v.leaveT = 0.6
      self.leaving[#self.leaving + 1] = v
    end
    self.zone = { {}, {} }
    sfx.play("whoosh", 1, 0.5)
  end)
  d = d + 0.35
  self:at(d, function()
    if s.over then
      self:finish()
    else
      self.animating = false
      self.disp = { {}, {} }
      self:sortHand()
      self:rivalReady()
      self.lock = 0.4
    end
  end)
end

function S:finish()
  if self.finished then return end
  self.finished = true
  local won = self.s.result == "win"
  fx.banner(won and "Victory!" or "Defeat", won and "The crowd roars" or "The crowd groans", won and C.gold or C.red)
  sfx.play(won and "win" or "lose")
  if won then for i = 1, 4 do fx.burst(160 + i * 90, 120, C.gold, 16, 140) end end
  local out = game.resolveMatch(G.save, self.ctx)
  G.persist()
  self:at(1.8, function() G.go("result", { ctx = self.ctx, out = out }) end)
end

-- ---------------------------------------------------------------- update

function S:update(dt)
  self.t = self.t + dt
  for i = #self.timeline, 1, -1 do
    local e = self.timeline[i]
    e.t = e.t - dt
    if e.t <= 0 then table.remove(self.timeline, i); e.fn() end
  end
  self.lock = math.max(0, self.lock - dt)
  if not self.animating and #self.selected > 0 then
    self.previewR = match.preview(self.s, 1, self.selected)
  elseif not self.animating then
    self.previewR = nil
  end
  self:layoutHand()
  for i = 1, 2 do
    self.prideShow[i] = self.prideShow[i] + (self.pride[i] - self.prideShow[i]) * math.min(1, dt * 6)
  end
  for _, v in pairs(self.hand) do v:update(dt) end
  for side = 1, 2 do for _, v in ipairs(self.zone[side]) do v:update(dt) end end
  for i = #self.leaving, 1, -1 do
    local v = self.leaving[i]
    v:update(dt)
    v.leaveT = (v.leaveT or 0) - dt
    if v.leaveT <= 0 then table.remove(self.leaving, i) end
  end
  self.hoverZone = nil
  if not self.hoverInst and widgets.layer == widgets.top then
    for side = 1, 2 do
      for _, v in ipairs(self.zone[side]) do
        if v.flip > 0 and v:contains(widgets.mx, widgets.my) then self.hoverZone = v end
      end
    end
  end
  for side = 1, 2 do for _, v in ipairs(self.zone[side]) do v.hovered = v == self.hoverZone end end
end

-- ---------------------------------------------------------------- draw

function S:drawSide(side, y)
  local s = self.s
  local sd = s.sides[side]
  local h = 56
  gfx.panel(4, y, 148, h, C.deep, { border = side == 2 and C.redDark or C.goldDark })
  local p = side == 2 and self.rivalPortrait or self.myPortrait
  gfx.box(7, y + 3, 34, 34, C.black)
  lg.setColor(1, 1, 1)
  lg.draw(p, 8, y + 4)
  local name = sd.name
  local f = theme.T.body()
  while f:getWidth(name) > 104 and #name > 3 do name = name:sub(1, -2) end
  gfx.text(name, f, 45, y + 4, C.paper)
  gfx.text("PRIDE", theme.T.tiny(), 45, y + 15, C.muted)
  gfx.text(math.max(0, math.floor(self.prideShow[side] + 0.5)) .. "/" .. sd.maxPride, theme.T.num(), 148, y + 12, C.paper, { align = "right" })
  local frac = math.max(0, self.prideShow[side]) / sd.maxPride
  gfx.bar(45, y + 25, 102, 10, frac, frac > 0.5 and C.green or frac > 0.25 and C.gold or C.red)
  local wins = sd.wins
  gfx.text("EXCHANGES WON " .. wins, theme.T.tiny(), 8, y + 42, C.muted)
end

function S:drawScore(side, y)
  local disp = self.disp[side]
  local has = disp.name ~= nil
  gfx.panel(4, y, 148, 40, has and disp.active and C.ink2 or C.deep)
  local label = side == 1 and "YOU" or "RIVAL"
  gfx.text(label, theme.T.tiny(), 8, y + 3, side == 1 and C.gold or C.red)
  if not has then
    gfx.text(side == 1 and "--" or "??", theme.T.body(), 146, y + 3, C.muted, { align = "right" })
    return
  end
  gfx.text(disp.name, theme.T.body(), 146, y + 3, C.paper, { align = "right" })
  gfx.box(8, y + 14, 50, 22, C.blueDark)
  gfx.text(fmt(disp.paws or 0), theme.T.numL(), 33, y + 14, C.paper, { align = "center" })
  gfx.text("x", theme.T.num(), 64, y + 19, C.paper, { align = "center" })
  gfx.box(70, y + 14, 34, 22, C.redDark)
  gfx.text(fmt(disp.cheer or 0), theme.T.numL(), 87, y + 14, C.paper, { align = "center" })
  if disp.total then
    gfx.outlined(tostring(disp.total), theme.T.numL(), 146, y + 14, C.gold, { align = "right" })
  end
end

function S:draw()
  local s = self.s
  local save = G.save
  -- left column
  self:drawSide(2, 4)
  self:drawScore(2, 64)
  self:drawScore(1, 108)
  self:drawSide(1, 152)
  gfx.panel(4, 212, 148, 66, C.deep)
  gfx.text("EXCHANGE " .. s.exchange, theme.T.tiny(), 8, 215, C.pale)
  gfx.textf(self.message, theme.T.tiny(), 8, 226, 140, "left", C.paper)
  hud.charmRow(save.run, 6, 282)
  gfx.text("DECK " .. #s.sides[1].deck .. "  DISCARD " .. #s.sides[1].discard, theme.T.tiny(), 8, 302, C.muted)
  if widgets.button("m_rules", 6, 316, 70, 16, "Rules", { font = theme.T.num() }) then overlays.help() end
  if widgets.button("m_menu", 80, 316, 70, 16, "Menu", { font = theme.T.num() }) then overlays.pause() end
  if widgets.button("m_deck", 6, 336, 144, 16, "View pride", { font = theme.T.num() }) then overlays.deck(save.run.deck) end

  -- rival hand (backs)
  local b = s.sides[2]
  local nb = #b.hand - #(b.selection or {})
  local back = cardview.back()
  for i = 1, math.max(0, nb) do
    local k = i - (nb + 1) / 2
    lg.setColor(1, 1, 1)
    lg.draw(back, CX + math.floor(k * 16), RIVAL_HAND_Y, k * 0.05, 0.45, 0.45, cardview.W / 2, cardview.H / 2)
  end
  -- zones
  gfx.text("RIVAL'S PLAY", theme.T.tiny(), 164, 46, C.red)
  local hint
  if not self.animating and (b.mods.showsCoat or s.sides[1].mods.seeCoat) and b.shownCoat then
    hint = "Readies a " .. cards.COATS[b.shownCoat].name:upper() .. " formation"
  elseif not self.animating then
    hint = "Choosing " .. #(b.selection or {}) .. " card" .. (#(b.selection or {}) == 1 and "" or "s") .. "..."
  end
  if hint then gfx.text(hint, theme.T.tiny(), 630, 46, C.muted, { align = "right" }) end
  theme.set(C.gold, 0.5)
  lg.rectangle("fill", 170, 130, 452, 1)
  gfx.text("YOUR PLAY", theme.T.tiny(), 164, 134, C.gold)
  -- deck pile
  for i = 0, 2 do
    lg.setColor(1, 1, 1)
    lg.draw(back, DECK_X + i, DECK_Y - i, 0, 0.5, 0.5, cardview.W / 2, cardview.H / 2)
  end
  gfx.text(tostring(#s.sides[1].deck), theme.T.num(), DECK_X, DECK_Y + 20, C.paper, { align = "center" })

  for side = 1, 2 do for _, v in ipairs(self.zone[side]) do if v ~= self.hoverZone then v:draw() end end end
  for _, v in ipairs(self.leaving) do v:draw() end
  if self.hoverZone then self.hoverZone:draw() end

  -- preview line
  if self.previewR and not self.animating then
    local r = self.previewR
    local txt = r.formation and (r.formation.name:upper() .. "   " .. fmt(r.paws) .. " x " .. fmt(r.cheer) .. " = " .. r.total) or "Tricks only - no formation"
    gfx.panel(CX - 120, 212, 240, 16, C.deep, { border = C.goldDark })
    gfx.text(txt, theme.T.body(), CX, 215, C.gold, { align = "center" })
  end

  -- hand
  local hand = s.sides[1].hand
  for _, inst in ipairs(hand) do
    local v = self.hand[inst.uid]
    if v and inst ~= self.hoverInst then v:draw() end
  end
  if self.hoverInst then
    local v = self.hand[self.hoverInst.uid]
    if v then
      v:draw()
      if widgets.released and widgets.layer == widgets.top then self:toggle(self.hoverInst) end
      local tx = v.x + 34
      if tx + 150 > theme.W then tx = v.x - 184 end
      widgets.tooltip(function() picker.cardTooltip(v.def, v.inst, tx, 150) end)
    end
  elseif self.hoverZone then
    local v = self.hoverZone
    widgets.tooltip(function() picker.cardTooltip(v.def, v.inst, v.x + 30, v.y - 30) end)
  end

  -- buttons
  local idle = not self.animating and self.lock <= 0
  local nsel = #self.selected
  if widgets.button("m_play", CX - 112, 330, 104, 24, "Play " .. (nsel > 0 and nsel or ""), { color = C.red, disabled = not idle or nsel == 0 }) then self:play() end
  local rd = s.sides[1].redrawsLeft
  if widgets.button("m_redraw", CX - 2, 330, 104, 24, "Redraw " .. rd, { color = C.blue, disabled = not idle or nsel == 0 or rd <= 0 }) then self:redraw() end
  if widgets.button("m_sort", CX + 108, 330, 60, 24, self.sortMode == "coat" and "By coat" or "By paws", { font = theme.T.num(), disabled = not idle }) then
    self.sortMode = self.sortMode == "coat" and "paws" or "coat"
    self:sortHand()
  end
end

function S:keypressed(k)
  if k == "escape" then overlays.pause()
  elseif k == "return" or k == "space" then self:play()
  elseif k == "r" then self:redraw()
  elseif k == "s" then
    self.sortMode = self.sortMode == "coat" and "paws" or "coat"
    self:sortHand()
  end
end

return S
