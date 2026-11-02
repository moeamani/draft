-- The Arena table. The rival looms in the dark across a candle-lit table. Each bout one side
-- leads (cards face-down on its three cushions) and the other answers, seeing only the backs.
-- Then every cushion duels, and the winners swat goblets off the loser's side of the table.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local cardview = require("src.ui.cardview")
local festival = require("src.core.festival")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local hud = require("src.ui.hud")
local icons = require("src.ui.icons")
local match = require("src.core.match")
local nemesis = require("src.core.nemesis")
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
local T = theme.T

local HORIZON = 100
local RIVAL_Y, MY_Y, HAND_Y = 152, 236, 338
local RIVAL_X = { 258, 320, 382 }
local MY_X = { 246, 320, 394 }
local RIVAL_SCALE = 0.86
local DECK_X, DECK_Y = 186, 328
local RDECK_X, RDECK_Y = 448, 74
local PX, PY, PW, PH = 468, 32, 164, 270
local CUSHION_NAMES = { "Left", "Middle", "Right" }

S.bg = { horizon = HORIZON / 360, light = { 0.5, 0.62 }, radius = 0.72, power = 1.0 }

function S:enter()
  local save = G.save
  self.ctx = game.setupMatch(save)
  G.persist()
  self.s = self.ctx.state
  self.t = 0
  self.views, self.board, self.rviews, self.leaving = {}, {}, {}, {}
  self.slots = { false, false, false }
  self.timeline = {}
  self.busy = true
  self.finished = false
  self.log = {}
  self.falling = {}
  self.gob = { self.s.sides[1].goblets, self.s.sides[2].goblets }
  self.blink = 3
  local n = self.ctx.nemesis
  self.portrait, self.eyes = art.entrant(save, self.ctx.opp, 128, true)
  S.bg = { horizon = HORIZON / theme.H, light = { 0.5, 0.62 }, radius = 0.72, power = 1.0, ramp = n and "blood" or "felt" }
  fx.banner(festival.stageLabel(save.run.festival), "Knock all of their goblets off the table", n and C.red or C.gold, 0, 160)
  self:at(1.0, function() self:beginBout() end)
end

-- ---------------------------------------------------------------- helpers

function S:at(delay, fn) self.timeline[#self.timeline + 1] = { t = delay, fn = fn } end

local function onSlot(slots, uid)
  for i = 1, 3 do if slots[i] == uid then return i end end
end

function S:handList()
  local out = {}
  for _, c in ipairs(self.s.sides[1].hand) do
    local v = self.views[c.uid]
    if v and not onSlot(self.slots, c.uid) and not (self.drag and self.drag.moved and self.drag.uid == c.uid) then out[#out + 1] = c end
  end
  return out
end

function S:cushionAt(x, y)
  for i = 1, 3 do
    if math.abs(x - MY_X[i]) <= 34 and math.abs(y - MY_Y) <= 46 then return i end
  end
end

function S:rivalCard(i, c)
  local v = cardview.new(c, RDECK_X, RDECK_Y, 0.5)
  v.flip, v.tflip = -1, -1
  v.backKind = match.backOf(c)
  if self.s.sides[2].shown[i] and not self.busyResolve then v.tflip = 1 end
  v:setTarget(RIVAL_X[i], RIVAL_Y, RIVAL_SCALE, 0)
  self.rviews[i] = v
  sfx.play("card", 0.9)
end

function S:beginBout()
  local s = self.s
  self.slots = { false, false, false }
  self.board = {}
  self.rviews = {}
  self.rec = nil
  self.busyResolve = false
  self.confirmEmpty = false
  for k, c in ipairs(s.sides[1].hand) do
    if not self.views[c.uid] then
      local v = cardview.new(c, DECK_X, DECK_Y, 0.6)
      v.rot = -0.4
      self.views[c.uid] = v
      self:at(k * 0.05, function() sfx.play("flip", 1 + k * 0.03, 0.5) end)
    end
  end
  local lead = s.lead
  local d = 0.3
  if lead == 2 then
    for i = 1, 3 do
      local c = s.sides[2].placed[i]
      if c then self:at(d, function() self:rivalCard(i, c) end); d = d + 0.18 end
    end
  end
  fx.banner("Bout " .. s.bout, lead == 1 and "You lead. The rival will answer your card backs." or "The rival leads. Answer their card backs.",
    lead == 1 and C.gold or C.red, 0, 160)
  self:at(d + 0.5, function() self.busy = false end)
end

function S:placeAt(uid, i, from)
  local occupant = self.slots[i]
  if from ~= "hand" then self.slots[from] = false end
  if occupant and occupant ~= uid and from ~= "hand" then self.slots[from] = occupant end
  self.slots[i] = uid
  sfx.play("card", 1.1)
end

function S:firstFree()
  for i = 1, 3 do if not self.slots[i] then return i end end
end

function S:drop()
  local d = self.drag
  self.drag = nil
  if d.moved then
    local target = self:cushionAt(widgets.mx, widgets.my)
    if target then self:placeAt(d.uid, target, d.from)
    elseif d.from ~= "hand" then self.slots[d.from] = false; sfx.play("select", 0.8) end
  elseif d.from == "hand" then
    local free = self:firstFree()
    if free then self:placeAt(d.uid, free, "hand")
    else fx.toast("All three cushions are taken. Click a card on a cushion to take it back.", "bad") end
  else
    self.slots[d.from] = false
    sfx.play("select", 0.8)
  end
end

-- ---------------------------------------------------------------- the bout

function S:charge()
  if self.busy or self.finished then return end
  local s = self.s
  local placed = 0
  for i = 1, 3 do if self.slots[i] then placed = placed + 1 end end
  if placed == 0 and #self:handList() > 0 and not self.confirmEmpty then
    fx.toast("Your cushions are empty, so every rival cat would swat unopposed. Press Charge again to send nobody.", "bad")
    self.confirmEmpty = true
    return
  end
  local lead = s.lead
  local slots = { self.slots[1], self.slots[2], self.slots[3] }
  local rec = match.commit(s, slots)
  if not rec then return end
  self.busy, self.busyResolve, self.drag = true, true, nil
  self.rec = rec
  for i = 1, 3 do
    local uid = slots[i]
    if uid then
      self.board[i] = self.views[uid]
      self.views[uid] = nil
    end
  end
  self.slots = { false, false, false }
  sfx.play("whoosh")
  self:animate(rec, lead)
end

local function signed(n) return (n >= 0 and "+" or "") .. n end

function S:popText(v, text, col, dy)
  fx.float(v.x, v.y - 30 + (dy or 0), text, col)
  v.bounce = 0.5
end

function S:animate(rec, lead)
  local s = self.s
  local d = 0.15
  if lead == 1 then
    for i = 1, 3 do
      local c = rec.cards[2][i]
      if c then self:at(d, function() self:rivalCard(i, c) end); d = d + 0.2 end
    end
    d = d + 0.4
  end
  -- reveal
  for i = 1, 3 do
    if rec.cards[2][i] then
      self:at(d, function()
        local v = self.rviews[i]
        if v and v.tflip < 0 then v.tflip = 1; sfx.play("flip", 1 + i * 0.05) end
      end)
      d = d + 0.14
    end
  end
  d = d + 0.35
  -- modifiers, card by card
  for side = 1, 2 do
    for i = 1, 3 do
      local inf = rec.info[side][i]
      if inf.kind ~= "empty" and (#inf.mods > 0 or inf.notes or inf.status == "nap" or inf.status == "fog" or inf.kind == "box") then
        self:at(d, function()
          local v = side == 1 and self.board[i] or self.rviews[i]
          if not v then return end
          if inf.kind == "cat" or inf.kind == "box" then v.paws = math.max(0, inf.paws) end
          local dy = 0
          for _, m in ipairs(inf.mods) do
            self:popText(v, signed(m.amount) .. " " .. m.text, m.amount >= 0 and C.green or C.red, dy)
            dy = dy - 13
          end
          for _, nt in ipairs(inf.notes or {}) do self:popText(v, nt.text, C.cyan, dy); dy = dy - 13 end
          if inf.status == "nap" then v.dim = 0.7; self:popText(v, inf.napBy == "hairball" and "Disgusted!" or "Zzz...", C.pale, dy)
          elseif inf.status == "fog" then v.dim = 0.8; self:popText(v, "Lost in the fog", C.pale, dy) end
          sfx.play("tick", 0.9 + i * 0.1)
        end)
        d = d + 0.32
      end
    end
  end
  d = d + 0.25
  -- duels, left to right
  for i = 1, 3 do
    local du = rec.duels[i]
    if rec.cards[1][i] or rec.cards[2][i] then
      self:at(d, function() self:duel(i, du, rec) end)
      d = d + (du.winner > 0 and 1.0 or 0.6)
    end
  end
  -- aftermath
  self:at(d, function()
    for side = 1, 2 do
      if rec.healed[side] > 0 then
        fx.toast((side == 1 and "Your" or s.sides[2].name .. "'s") .. " groomer sets a goblet back up.", "info")
        sfx.play("reveal")
      end
    end
    if rec.secondWind then
      fx.toast((rec.secondWind == 2 and s.sides[2].name or "You") .. " get a second wind! Two goblets go back up.", "info")
    end
    for _, t in ipairs(rec.revealed or {}) do
      local info = traits.TRAITS[t]
      if info then sfx.play("reveal"); fx.toast(s.sides[2].name .. " is " .. info.name .. "! " .. info.desc, "info") end
    end
    self.gob = { s.sides[1].goblets, s.sides[2].goblets }
  end)
  d = d + 0.8
  self:at(d, function() self:clearBoard(rec) end)
  d = d + 0.5
  self:at(d, function()
    if s.over then self:finish() else self:beginBout() end
  end)
end

function S:gobletPos(side, k)
  local max = self.s.sides[side].maxGoblets
  local sp = max > 8 and 9 or 11
  if side == 2 then
    return 226 - (max - k) * sp, 150
  end
  return 210 - (max - k) * sp, 248
end

function S:knock(side, n)
  for _ = 1, n do
    if self.gob[side] > 0 then
      local k = self.gob[side]
      self.gob[side] = k - 1
      local x, y = self:gobletPos(side, k)
      self.falling[#self.falling + 1] = { x = x, y = y, vx = -30 - love.math.random() * 50, vy = -70, rot = 0, vr = -4 - love.math.random() * 4, t = 0, side = side }
      fx.burst(x, y - 3, C.paper, 10, 60)
    end
  end
  fx.addShake(n >= 2 and 6 or 4)
  sfx.play("hit")
end

function S:duel(i, du, rec)
  local a, b = self.board[i], self.rviews[i]
  local ia, ib = rec.info[1][i], rec.info[2][i]
  local function nameOf(inf) return inf.def and cards.shortName(inf.def) or "nobody" end
  -- both fighters lunge
  if a and ia.status == "fight" then a:setTarget(MY_X[i], MY_Y - 16, 1, 0) end
  if b and ib.status == "fight" then b:setTarget(RIVAL_X[i], RIVAL_Y + 14, RIVAL_SCALE, 0) end
  sfx.play("card", 0.8)
  self:at(0.16, function()
    if a then a:setTarget(MY_X[i], MY_Y, 1, 0) end
    if b then b:setTarget(RIVAL_X[i], RIVAL_Y, RIVAL_SCALE, 0) end
    local line
    local where = CUSHION_NAMES[i]
    if du.winner > 0 then
      local wv, lv = du.winner == 1 and a or b, du.winner == 1 and b or a
      local winf, linf = du.winner == 1 and ia or ib, du.winner == 1 and ib or ia
      if wv then wv.flash = 0.8; wv.bounce = 1 end
      if lv and du.reason == "duel" then lv.dim = 0.55 end
      local swat = du.swats > 1 and ("Swat x" .. du.swats .. "!") or "Swat!"
      fx.float((MY_X[i] + RIVAL_X[i]) / 2, (MY_Y + RIVAL_Y) / 2 - 6, swat, du.winner == 1 and C.gold or C.red, true)
      if du.reason == "duel" then
        line = ("%s: %s %d beats %s %d%s"):format(where, nameOf(winf), math.max(0, winf.paws), nameOf(linf), math.max(0, linf.paws), du.tie and " (tie)" or "")
      else
        line = ("%s: %s walks in unopposed"):format(where, nameOf(winf))
      end
      line = line .. (du.swats > 1 and (". " .. du.swats .. " goblets fall.") or ". A goblet falls.")
      self:knock(3 - du.winner, du.swats)
      if du.winner == 1 then sfx.play("cheer", 1, 0.5) end
      if du.groom then fx.float(du.winner == 1 and MY_X[i] or RIVAL_X[i], (du.winner == 1 and MY_Y or RIVAL_Y) + 30, "Groom: +1 goblet", C.green) end
    else
      line = ("%s: nobody swats."):format(where)
      fx.float((MY_X[i] + RIVAL_X[i]) / 2, (MY_Y + RIVAL_Y) / 2 - 6, "No swat", C.muted)
      sfx.play("pass", 1, 0.6)
    end
    self.log[#self.log + 1] = { text = line, col = du.winner == 1 and C.gold or du.winner == 2 and C.red or C.muted }
  end)
end

function S:clearBoard(rec)
  local returns = {}
  for _, uid in ipairs(rec.returns or {}) do returns[uid] = true end
  for i = 1, 3 do
    local v = self.board[i]
    if v then
      v.dim, v.paws = 0, nil
      if returns[v.inst.uid] and util.find(self.s.sides[1].hand, function(c) return c.uid == v.inst.uid end) then
        self.views[v.inst.uid] = v
        self:popText(v, "Nine Lives: back to hand", C.cyan)
      else
        v:setTarget(DECK_X - 70, 400, 0.6, -0.6)
        v.leaveT = 0.6
        self.leaving[#self.leaving + 1] = v
      end
    end
    local r = self.rviews[i]
    if r then
      r:setTarget(RDECK_X + 60, RDECK_Y - 60, 0.5, 0.6)
      r.leaveT = 0.6
      self.leaving[#self.leaving + 1] = r
    end
  end
  self.board, self.rviews = {}, {}
  sfx.play("whoosh", 1, 0.5)
end

function S:finish()
  if self.finished then return end
  self.finished = true
  local won = self.s.result == "win"
  fx.banner(won and "Victory!" or "Defeat", won and "The crowd roars" or "The crowd groans", won and C.gold or C.red, 0, 160)
  sfx.play(won and "win" or "lose")
  if won then for i = 1, 4 do fx.burst(160 + i * 64, 150, C.gold, 16, 140) end end
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
  self.blink = self.blink - dt
  if self.blink < -0.14 then self.blink = 2.5 + love.math.random() * 3 end
  for i = #self.falling, 1, -1 do
    local f = self.falling[i]
    f.t = f.t + dt
    f.vy = f.vy + 420 * dt
    f.x, f.y, f.rot = f.x + f.vx * dt, f.y + f.vy * dt, f.rot + f.vr * dt
    if f.t > 1.2 then table.remove(self.falling, i) end
  end
  local mx, my = widgets.mx, widgets.my
  local active = widgets.layer == widgets.top and not self.busy and not self.finished
  -- what is under the mouse
  self.hoverUid, self.hoverFrom, self.hoverR, self.hoverBoard = nil, nil, nil, nil
  if widgets.layer == widgets.top then
    for i = 1, 3 do
      local uid = self.slots[i]
      if uid and self.views[uid] and self.views[uid]:contains(mx, my) then self.hoverUid, self.hoverFrom = uid, i end
    end
    if not self.hoverUid then
      local list = self:handList()
      for k = #list, 1, -1 do
        local v = self.views[list[k].uid]
        if v:contains(mx, my) then self.hoverUid, self.hoverFrom = list[k].uid, "hand"; break end
      end
    end
    for i = 1, 3 do
      if self.board[i] and self.board[i]:contains(mx, my) then self.hoverBoard = i end
      if self.rviews[i] and self.rviews[i]:contains(mx, my) then self.hoverR = i end
    end
  end
  -- drag and click
  if active then
    if widgets.pressed and self.hoverUid and not self.drag then
      self.drag = { uid = self.hoverUid, from = self.hoverFrom, sx = mx, sy = my, moved = false }
    end
    if self.drag and widgets.down and (math.abs(mx - self.drag.sx) + math.abs(my - self.drag.sy) > 4) then self.drag.moved = true end
    if self.drag and widgets.released then self:drop() end
  elseif self.drag and not widgets.down then
    self.drag = nil
  end
  -- live numbers for the cards on your cushions
  if not self.busy then
    local pr = match.preview(self.s, self.slots)
    for i = 1, 3 do
      local uid = self.slots[i]
      if uid and self.views[uid] then
        local inf = pr.info[1][i]
        self.views[uid].paws = (inf.kind == "cat" or inf.kind == "box") and math.max(0, inf.paws) or nil
        self.views[uid].previewInfo = inf
      end
    end
  end
  -- layout: hand fan, cushions, drag
  local list = self:handList()
  local n = #list
  local spacing = math.min(54, 270 / math.max(1, n))
  for k, c in ipairs(list) do
    local v = self.views[c.uid]
    local off = k - (n + 1) / 2
    local hov = c.uid == self.hoverUid and not self.drag
    v.hovered = hov
    v.selected = false
    v.paws, v.previewInfo = nil, nil
    v:setTarget(320 + math.floor(off * spacing), HAND_Y + math.floor(off * off * 1.2) - (hov and 22 or 0), hov and 1.05 or 1, off * 0.05)
  end
  for i = 1, 3 do
    local uid = self.slots[i]
    local v = uid and self.views[uid]
    if v and not (self.drag and self.drag.moved and self.drag.uid == uid) then
      v.hovered = uid == self.hoverUid
      v.selected = true
      v:setTarget(MY_X[i], MY_Y, 1, 0)
    end
  end
  if self.drag and self.drag.moved then
    local v = self.views[self.drag.uid]
    if v then v.hovered = true; v:setTarget(mx, my, 1.08, 0) end
  end
  for _, v in pairs(self.views) do v:update(dt) end
  for i = 1, 3 do
    if self.board[i] then self.board[i]:update(dt) end
    if self.rviews[i] then self.rviews[i]:update(dt) end
  end
  for i = #self.leaving, 1, -1 do
    local v = self.leaving[i]
    v:update(dt)
    v.leaveT = (v.leaveT or 0) - dt
    if v.leaveT <= 0 then table.remove(self.leaving, i) end
  end
end

-- ---------------------------------------------------------------- draw

function S:drawRival()
  local sd = self.s.sides[2]
  local px, py = 320 - 64, HORIZON - 106 + math.floor(math.sin(self.t * 1.3) * 1.5 + 0.5)
  lg.setScissor(G.scissor(0, 0, theme.W, HORIZON + 2))
  lg.setColor(0.4, 0.4, 0.44)
  lg.draw(self.portrait, px, py)
  if self.eyes and self.blink > 0 then
    local e = self.eyes
    local col = e[5]
    for j = 0, 1 do
      local ex, ey = px + math.floor(e[1 + j * 2]), py + math.floor(e[2 + j * 2])
      theme.set(col, 0.35)
      lg.rectangle("fill", ex - 3, ey - 2, 6, 4)
      theme.set(col)
      lg.rectangle("fill", ex - 2, ey - 1, 4, 2)
      theme.set(C.paper)
      lg.rectangle("fill", ex - 1, ey - 1, 1, 1)
    end
  end
  lg.setScissor()
  -- the rival's draw pile
  local back = cardview.back("plain")
  for k = 0, 2 do
    lg.setColor(1, 1, 1)
    lg.draw(back, RDECK_X + k, RDECK_Y - k, 0.1, 0.42, 0.42, cardview.W / 2, cardview.H / 2)
  end
end

local function cushion(x, y, scale, col, num, lit)
  local w, h = math.floor(62 * scale), math.floor(84 * scale)
  local x0, y0 = math.floor(x - w / 2), math.floor(y - h / 2)
  gfx.box(x0 + 1, y0 + 3, w, h, C.black, 0.5)
  gfx.box(x0, y0, w, h, C.black)
  gfx.box(x0 + 1, y0 + 1, w - 2, h - 2, col)
  theme.set(theme.mix(col, C.paper, 0.18))
  lg.rectangle("fill", x0 + 3, y0 + 1, w - 6, 1)
  theme.set(theme.darken(col, 0.7))
  lg.rectangle("fill", x0 + 4, y0 + 4, w - 8, h - 8)
  theme.set(col)
  lg.rectangle("fill", x0 + 5, y0 + 5, w - 10, h - 10)
  -- gold tassels
  for _, p in ipairs({ { x0 - 1, y0 - 1 }, { x0 + w - 2, y0 - 1 }, { x0 - 1, y0 + h - 2 }, { x0 + w - 2, y0 + h - 2 } }) do
    gfx.box(p[1], p[2], 3, 3, C.gold)
  end
  if lit then
    theme.set(C.gold)
    lg.rectangle("line", x0 - 1.5, y0 - 1.5, w + 3, h + 3)
  end
  if num then gfx.text(num, T.big(), x, y - 11, theme.mix(col, C.paper, 0.35), { align = "center", shadow = false }) end
end

function S:drawGoblets(side)
  local sd = self.s.sides[side]
  local col = side == 1 and C.gold or C.steel
  for k = 1, sd.maxGoblets do
    local x, y = self:gobletPos(side, k)
    if k <= self.gob[side] then
      icons.draw("goblet", x, y, col)
    else
      theme.set(C.black, 0.35)
      lg.rectangle("fill", x - 3, y + 4, 7, 2)
    end
  end
  local x0 = self:gobletPos(side, 1)
  gfx.text(tostring(self.gob[side]), T.big(), x0 - 10, (side == 1 and 248 or 150) - 12, col, { align = "right" })
end

function S:drawPlaques()
  local s = self.s
  local save = G.save
  -- the rival
  local n = self.ctx.nemesis
  local sd = s.sides[2]
  local opp = self.ctx.opp
  local sub = n and nemesis.RANK_TITLES[game.rankOf(save, n)] or ("the " .. (opp.title or "Stray"))
  if n and game.rankOf(save, n) == 0 then sub = n.epithet end
  local ph = 66 + (n and 30 or 0)
  gfx.panel(8, 8, 176, ph, C.deep, { border = n and C.redDark or C.ink3 })
  gfx.text(sd.name, T.big(), 14, 9, C.paper)
  gfx.text(sub, T.body(), 14, 29, n and C.red or C.muted)
  local coat = cards.COATS[opp.coat]
  local onTable = 0
  if not self.busyResolve then for i = 1, 3 do if sd.placed[i] then onTable = onTable + 1 end end end
  gfx.text(coat.name .. " coat", T.body(), 14, 45, coat.color)
  gfx.text(("Hand %d  Deck %d"):format(#sd.hand - onTable, #sd.deck), T.body(), 178, 45, C.paper2, { align = "right" })
  if n then overlays.traitChips(n, 14, 64, 166, s.revealed) end
  -- you
  local me = s.sides[1]
  gfx.panel(8, 296, 160, 56, C.deep, { border = C.goldDark })
  gfx.text(me.name, T.big(), 14, 297, C.gold)
  gfx.text(("Deck %d  Discard %d"):format(#me.deck, #me.discard), T.body(), 14, 317, C.muted)
  hud.charmRow(save.run, 14, 334)
end

function S:inspectLines()
  local v, inf, side
  if self.drag and self.drag.moved then v = self.views[self.drag.uid]
  elseif self.hoverUid then v = self.views[self.hoverUid]
  elseif self.hoverR then v, side = self.rviews[self.hoverR], 2
  elseif self.hoverBoard then v = self.board[self.hoverBoard] end
  if not v then return nil end
  if side == 2 and v.flip < 0 then
    local back = v.backKind
    local lines = { { text = "Face-down card", font = T.big() } }
    if back == "dark" then
      lines[#lines + 1] = { text = "A dark back: a Shadow cat or a trick. No coat edge either way, if it's a cat.", color = C.paper2 }
    else
      local coat = cards.COATS[back]
      local beatenBy
      for k, cc in pairs(cards.COATS) do if cc.beats == back then beatenBy = cc.name end end
      lines[#lines + 1] = { text = "The back is " .. coat.name .. ", so this is an " .. coat.name .. " cat.", color = coat.color }
      lines[#lines + 1] = { text = "Answer with " .. beatenBy .. " for the coat edge (+" .. match.COAT_EDGE .. " Paws).", color = C.paper2 }
    end
    return lines
  end
  return picker.cardLines(v.def, v.inst, self.rec and self.rec.info and self:infoFor(v) or v.previewInfo)
end

function S:infoFor(v)
  local rec = self.rec
  for side = 1, 2 do
    for i = 1, 3 do
      local inf = rec.info[side][i]
      if inf.inst and inf.inst.uid == v.inst.uid then return inf end
    end
  end
end

function S:drawPanel()
  local s = self.s
  gfx.panel(PX, PY, PW, PH, C.deep, { border = C.goldDark })
  local x, y, w = PX + 7, PY + 5, PW - 14
  local lines = self:inspectLines()
  if lines then
    for _, l in ipairs(lines) do
      y = y + gfx.textf(l.text, l.font or T.body(), x, y, w, "left", l.color or C.paper) + (l.gap or 3)
    end
    return
  end
  if self.busyResolve or (self.busy and #self.log > 0) then
    gfx.label("Bout " .. (self.rec and self.rec.bout or s.bout), x, y, C.gold)
    y = y + 12
    for _, l in ipairs(self.log) do y = y + gfx.textf(l.text, T.body(), x, y, w, "left", l.col) + 4 end
    return
  end
  local lead = s.lead
  gfx.label("Bout " .. s.bout .. (lead == 1 and " - you lead" or " - you answer"), x, y, lead == 1 and C.gold or C.red)
  y = y + 13
  local tip
  if lead == 1 then
    tip = "Put up to 3 cards on your cushions. The rival sees only their backs, then answers. Ties go to you."
  else
    tip = "The rival has led. A card back shows the cat's coat; a dark back is a Shadow cat or a trick. Ties go to them."
  end
  y = y + gfx.textf(tip, T.body(), x, y, w, "left", C.paper) + 6
  y = y + gfx.textf("Click a card to place it, drag to choose a cushion. Then Charge!", T.body(), x, y, w, "left", C.paper2) + 6
  gfx.label("Coat edge: +" .. match.COAT_EDGE .. " Paws", x, y, C.gold)
  y = y + 12
  for _, pair in ipairs({ { "ember", "gilt" }, { "gilt", "tide" }, { "tide", "ember" } }) do
    local a, b = cards.COATS[pair[1]], cards.COATS[pair[2]]
    local cw = gfx.chip(a.name, x, y, nil)
    gfx.box(x + 1, y + 1, cw - 2, gfx.CHIP_H - 2, a.color)
    gfx.text(a.name, T.small(), x + 4, y + 1, pair[1] == "gilt" and C.black or C.paper, { shadow = false })
    gfx.text("beats", T.body(), x + cw + 5, y - 2, C.paper2)
    local bx = x + cw + 40
    local bw = gfx.chip(b.name, bx, y, nil)
    gfx.box(bx + 1, y + 1, bw - 2, gfx.CHIP_H - 2, b.color)
    gfx.text(b.name, T.small(), bx + 4, y + 1, pair[2] == "gilt" and C.black or C.paper, { shadow = false })
    y = y + 16
  end
end

function S:draw()
  local s = self.s
  self:drawRival()
  -- cushions
  for i = 1, 3 do
    cushion(RIVAL_X[i], RIVAL_Y, RIVAL_SCALE, theme.hex("#4a1712"), nil, false)
    local dropTarget = self.drag and self.drag.moved and self:cushionAt(widgets.mx, widgets.my) == i
    cushion(MY_X[i], MY_Y, 1, theme.hex("#5a1f19"), (not self.slots[i] and not self.board[i]) and tostring(i) or nil, dropTarget)
  end
  -- what the rival's empty cushions mean right now
  if not self.busyResolve and not self.finished then
    for i = 1, 3 do
      if not self.rviews[i] then
        if s.lead == 1 then
          gfx.text("?", T.big(), RIVAL_X[i], RIVAL_Y - 12, theme.hex("#7a3a30"), { align = "center", shadow = false })
        elseif not self.busy and not s.sides[2].placed[i] then
          gfx.text("Empty", T.body(), RIVAL_X[i], RIVAL_Y - 9, theme.hex("#c08070"), { align = "center", shadow = false })
        end
      end
    end
  end
  self:drawGoblets(2)
  self:drawGoblets(1)
  for _, f in ipairs(self.falling) do
    local a = math.max(0, 1 - f.t / 1.2)
    icons.draw("goblet", f.x, f.y, theme.mix(f.side == 1 and C.gold or C.steel, C.black, 1 - a), 1, f.rot)
  end
  -- my draw pile
  local back = cardview.back("plain")
  for k = 0, 2 do
    lg.setColor(1, 1, 1)
    lg.draw(back, DECK_X + k, DECK_Y - k, -0.1, 0.5, 0.5, cardview.W / 2, cardview.H / 2)
  end
  gfx.text(tostring(#s.sides[1].deck), T.body(), DECK_X, DECK_Y + 18, C.paper, { align = "center" })
  -- cards
  for i = 1, 3 do if self.rviews[i] then self.rviews[i]:draw() end end
  for i = 1, 3 do if self.board[i] then self.board[i]:draw() end end
  for _, v in ipairs(self.leaving) do v:draw() end
  for i = 1, 3 do
    local uid = self.slots[i]
    if uid and self.views[uid] and not (self.drag and self.drag.uid == uid and self.drag.moved) then self.views[uid]:draw() end
  end
  local list = self:handList()
  for _, c in ipairs(list) do if c.uid ~= self.hoverUid then self.views[c.uid]:draw() end end
  if self.hoverUid and self.views[self.hoverUid] and self.hoverFrom == "hand" then self.views[self.hoverUid]:draw() end
  if self.drag and self.drag.moved and self.views[self.drag.uid] then self.views[self.drag.uid]:draw() end
  -- shown rival cards get an eye
  for i = 1, 3 do
    local v = self.rviews[i]
    if v and s.sides[2].shown[i] and not self.busyResolve then
      icons.draw("eye", v.x + 20, v.y - 30, C.cyan)
    end
  end
  self:drawPlaques()
  -- right column
  if widgets.button("m_rules", PX, 8, 52, 18, "Rules", { font = T.body() }) then overlays.help() end
  if widgets.button("m_deck", PX + 56, 8, 52, 18, "Pride", { font = T.body() }) then overlays.deck(G.save.run.deck) end
  if widgets.button("m_menu", PX + 112, 8, 52, 18, "Menu", { font = T.body() }) then overlays.pause() end
  self:drawPanel()
  local idle = not self.busy and not self.finished
  local label = idle and "Charge!" or "..."
  if widgets.button("m_charge", PX, 310, PW, 40, label, { color = C.red, disabled = not idle, font = T.huge() }) then self:charge() end
end

function S:keypressed(k)
  if k == "escape" then overlays.pause()
  elseif k == "return" or k == "space" then self:charge()
  elseif (k == "1" or k == "2" or k == "3") and not self.busy and self.hoverUid then
    self:placeAt(self.hoverUid, tonumber(k), self.hoverFrom)
  elseif k == "backspace" and not self.busy then
    self.slots = { false, false, false }
  end
end

return S
