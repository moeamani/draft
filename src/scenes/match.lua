-- The Arena table. The rival looms in the dark beyond the table's far edge. Each bout one side
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
local renown = require("src.core.renown")
local overseer = require("src.ui.overseer")
local plates = require("src.ui.plates")
local audio = require("src.audio")
local theme = require("src.ui.theme")
local traits = require("src.core.traits")
local util = require("src.core.util")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c
local T = theme.T

local HORIZON = 100
local RIVAL_Y, MY_Y, HAND_Y = 150, 238, 338
local RIVAL_X = { 248, 320, 392 }
local MY_X = { 248, 320, 392 }
local RIVAL_SCALE = 1 -- cards are only ever drawn 1:1 at rest
local DECK_X, DECK_Y = 186, 328
local RDECK_X, RDECK_Y = 448, 74
local PX, PY, PW, PH = 468, 32, 164, 270
local CUSHION_NAMES = { "Left", "Middle", "Right" }

S.bg = { preset = "match" }
-- the Hands and the Overseer get the darker theme
S.music = function(self) return (self.ctx and (self.ctx.nemesis or self.ctx.boss)) and "high" or "table" end

function S:enter(p)
  local save = G.save
  p = p or {}
  self.tut = nil
  if p.tutorial then
    -- the prologue's practice match against Old Bedimew
    local tutorial = require("src.core.tutorial")
    self.ctx = tutorial.setup()
    self.tut = tutorial.new(self)
  elseif p.boss then
    -- the story's last chapter: the Overseer's table
    self.ctx = require("src.core.story").bossMatch(save)
  else
    self.ctx = game.setupMatch(save)
    G.persist()
  end
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
  if self.tut then
    self.portrait, self.eyes = art.character("bedimew", 128, true)
  elseif self.ctx.boss then
    self.portrait, self.eyes = nil, nil
  else
    self.portrait, self.eyes = art.entrant(save, self.ctx.opp, 128, true)
  end
  local boss = self.ctx.boss
  S.bg = { preset = "match", ramp = (n or boss) and "blood" or "felt" }
  local title = self.tut and "Practice match" or boss and "The High Table" or festival.stageLabel(save.run.festival)
  fx.banner(title, boss and "It sees every card you hold" or "Knock all of their goblets off the table", (n or boss) and C.red or C.gold, 0, 160)
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
  local old = self.rviews[i]
  if old and old.inst == c then return end -- already seated there, face-up
  if old then self:sendAway(old, RDECK_X + 60, RDECK_Y - 60, 0.6) end
  local v = cardview.new(c, RDECK_X, RDECK_Y, 0.5)
  v.livesShown = (self.livesBefore and self.livesBefore[c.uid]) or c.lives
  v.flip, v.tflip = -1, -1
  v.backKind = match.backOf(c)
  if self.s.sides[2].shown[i] and not self.busyResolve then v.tflip = 1 end
  v:setTarget(RIVAL_X[i], RIVAL_Y, RIVAL_SCALE, 0)
  self.rviews[i] = v
  audio.play("deal", 0.9)
end

-- A card view leaving the table (to a pile, or carried off).
function S:sendAway(v, x, y, rot)
  v:setTarget(x, y, 0.5, rot or 0.6)
  v.leaveT = 0.7
  self.leaving[#self.leaving + 1] = v
end

-- Hold the Cushion: pull your seated cat on cushion i back to your hand (it loses its Warmth).
function S:retreat(i)
  local v = self.board[i]
  if not v or self.busy then return false end
  if not match.retreat(self.s, 1, i) then return false end
  self.board[i] = nil
  self.views[v.inst.uid] = v
  v.selected, v.paws, v.previewInfo, v.risk = false, nil, nil, nil
  self:popText(v, "Pulled back", C.pale)
  audio.play("select", 0.8)
  return true
end

-- The autotest's and fuzzer's player: the AI's suggested move, through the scene.
function S:applySuggestion()
  local slots, retreat = match.suggest(self.s, 1, 0)
  for _, i in ipairs(retreat) do self:retreat(i) end
  self.slots = {}
  for i = 1, 3 do self.slots[i] = (not self.s.sides[1].seated[i]) and slots[i] or false end
end

function S:beginBout()
  local s = self.s
  self.slots = { false, false, false }
  -- seated cats keep their places; anything else still on the table goes
  local board, rv = {}, {}
  for i = 1, 3 do
    local mine, theirs = self.board[i], self.rviews[i]
    if mine and s.sides[1].seated[i] == mine.inst then board[i] = mine elseif mine then self:sendAway(mine, DECK_X - 70, 400, -0.6) end
    if theirs and s.sides[2].seated[i] == theirs.inst then rv[i] = theirs
    elseif theirs then
      self:popText(theirs, "Pulled back", C.pale)
      self:sendAway(theirs, RDECK_X, RDECK_Y, 0.4)
    end
  end
  self.board, self.rviews = board, rv
  self.rec = nil
  self.busyResolve = false
  self.confirmEmpty = false
  for k, c in ipairs(s.sides[1].hand) do
    if not self.views[c.uid] then
      local v = cardview.new(c, DECK_X, DECK_Y, 0.6)
      v.rot = -0.4
      self.views[c.uid] = v
      self:at(k * 0.05, function() audio.play("deal", 1 + k * 0.04, 0.7) end)
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
  if self.board[i] then self:retreat(i) end -- swapping out a seated cat pulls it back first
  local occupant = self.slots[i]
  if from ~= "hand" then self.slots[from] = false end
  if occupant and occupant ~= uid and from ~= "hand" then self.slots[from] = occupant end
  self.slots[i] = uid
  audio.play("place", 1.05)
end

function S:firstFree()
  for i = 1, 3 do if not self.slots[i] and not self.board[i] then return i end end
end

function S:drop()
  local d = self.drag
  self.drag = nil
  if d.moved then
    local target = self:cushionAt(widgets.mx, widgets.my)
    if target then self:placeAt(d.uid, target, d.from)
    elseif d.from ~= "hand" then self.slots[d.from] = false; audio.play("select", 0.8) end
  elseif d.from == "hand" then
    local free = self:firstFree()
    if free then self:placeAt(d.uid, free, "hand")
    else fx.toast("All three cushions are taken. Click a card on a cushion to take it back.", "bad") end
  else
    self.slots[d.from] = false
    audio.play("select", 0.8)
  end
end

-- ---------------------------------------------------------------- the bout

function S:charge()
  if self.busy or self.finished then return end
  if self.tut and not self.tut:allowCharge() then
    fx.toast("Follow Bedimew's lesson first.", "info")
    return
  end
  local s = self.s
  local placed = 0
  for i = 1, 3 do if self.slots[i] or self.board[i] then placed = placed + 1 end end
  if placed == 0 and #self:handList() > 0 and not self.confirmEmpty then
    fx.toast("Your cushions are empty, so every rival cat would swat unopposed. Press Charge again to send nobody.", "bad")
    self.confirmEmpty = true
    return
  end
  local lead = s.lead
  local slots = { self.slots[1], self.slots[2], self.slots[3] }
  local rec = match.commit(s, slots)
  if not rec then return end
  -- hearts show what each cat had before this bout, until its duel takes them
  local before = {}
  for _, w in ipairs(rec.wounds or {}) do before[w.uid] = w.left + w.cost end
  self.livesBefore = before
  for i = 1, 3 do
    local uid = slots[i]
    if uid and self.views[uid] then self.views[uid].livesShown = before[uid] or self.views[uid].inst.lives end
    if self.board[i] then self.board[i].livesShown = before[self.board[i].inst.uid] or self.board[i].inst.lives end
    if self.rviews[i] then self.rviews[i].livesShown = before[self.rviews[i].inst.uid] or self.rviews[i].inst.lives end
  end
  self.busy, self.busyResolve, self.drag = true, true, nil
  self.rec = rec
  for i = 1, 3 do
    local c = rec.cards[2][i]
    if c then game.noteSeen(G.save, c.id) end
  end
  for i = 1, 3 do
    local uid = slots[i]
    if uid then
      self.board[i] = self.views[uid]
      self.views[uid] = nil
    end
  end
  self.slots = { false, false, false }
  audio.play("whoosh")
  self:animate(rec, lead)
end

local function signed(n) return (n >= 0 and "+" or "") .. n end

-- What just happened to a card, as a tag popping above it. col is the text colour the old
-- floats used; it picks the tag's plate.
local TAG_PLATE
function S:popText(v, text, col, dy)
  TAG_PLATE = TAG_PLATE or {
    [C.green] = theme.hex("#1f6b45"), [C.red] = C.redDark, [C.redText] = C.redDark, [C.cyan] = C.blueDark,
    [C.goldText] = C.goldDark, [C.gold] = C.goldDark, [C.pale] = C.slate,
  }
  fx.tag(v.x, v.y - 34 + (dy or 0), text, TAG_PLATE[col] or C.ink3)
  v.bounce = 0.5
end

-- The scoring ladder: every step of a bout's reveal rings one note higher up the scale.
function S:ring(vol)
  audio.note(self.ladder or 0, vol)
  self.ladder = math.min(10, (self.ladder or 0) + 1)
end

function S:animate(rec, lead)
  local s = self.s
  local d = 0.15
  self.ladder = 0
  -- a seated rival cat that was pulled back leaves before the reveal
  for i = 1, 3 do
    local r = self.rviews[i]
    if r and r.inst ~= rec.cards[2][i] then
      self:popText(r, "Pulled back", C.pale)
      self:sendAway(r, RDECK_X, RDECK_Y, 0.4)
      self.rviews[i] = nil
    end
  end
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
        if v and v.tflip < 0 then v.tflip = 1; audio.play("flip", 1 + i * 0.05) end
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
        local function view() return side == 1 and self.board[i] or self.rviews[i] end
        local fights = inf.kind == "cat" or inf.kind == "box"
        -- each modifier pops on its own beat, and the Paws badge counts along with it
        local running = inf.paws
        for _, m in ipairs(inf.mods) do running = running - m.amount end
        local dy = 0
        for _, m in ipairs(inf.mods) do
          running = running + m.amount
          local now, at = running, dy
          self:at(d, function()
            local v = view()
            if not v then return end
            if fights then v.paws = math.max(0, now) end
            self:popText(v, signed(m.amount) .. " " .. m.text, m.amount >= 0 and C.green or C.red, at)
            self:ring(0.55)
          end)
          d = d + 0.16
          dy = dy - 14
        end
        local last = dy
        self:at(d, function()
          local v = view()
          if not v then return end
          if fights then v.paws = math.max(0, inf.paws) end
          local y = last
          for _, nt in ipairs(inf.notes or {}) do self:popText(v, nt.text, C.cyan, y); y = y - 14 end
          if inf.status == "nap" then v.dim = 0.7; self:popText(v, inf.napBy == "hairball" and "Disgusted!" or "Zzz...", C.pale, y); audio.play("pass", 1.2, 0.5)
          elseif inf.status == "fog" then v.dim = 0.8; self:popText(v, "Lost in the fog", C.pale, y); audio.play("pass", 0.8, 0.5) end
        end)
        d = d + 0.2
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
        audio.play("reveal")
      end
    end
    if rec.secondWind then
      fx.toast((rec.secondWind == 2 and s.sides[2].name or "You") .. " get a second wind! Two goblets go back up.", "info")
    end
    for _, t in ipairs(rec.revealed or {}) do
      local info = traits.TRAITS[t]
      if info then audio.play("reveal"); fx.toast(s.sides[2].name .. " is " .. info.name .. "! " .. info.desc, "info") end
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
    return 208 - (max - k) * sp, 150
  end
  return 208 - (max - k) * sp, 250
end

function S:knock(side, n)
  for j = 1, n do
    self:at((j - 1) * 0.11, function()
      if self.gob[side] <= 0 then return end
      local k = self.gob[side]
      self.gob[side] = k - 1
      local x, y = self:gobletPos(side, k)
      self.falling[#self.falling + 1] = { x = x, y = y, vx = -30 - love.math.random() * 50, vy = -70, rot = 0, vr = -4 - love.math.random() * 4, t = 0, side = side }
      fx.burst(x, y - 3, side == 2 and C.steel or C.gold, 10, 70)
      fx.addShake(3 + j)
      fx.addPulse(x, y, 0.35 + 0.1 * j)
      audio.play("goblet", 0.92 + j * 0.1, 0.9)
    end)
  end
end

function S:duel(i, du, rec)
  local a, b = self.board[i], self.rviews[i]
  local ia, ib = rec.info[1][i], rec.info[2][i]
  local function nameOf(inf) return inf.def and cards.shortName(inf.def) or "nobody" end
  -- both fighters lunge
  if a and ia.status == "fight" then a:setTarget(MY_X[i], MY_Y - 16, 1, 0) end
  if b and ib.status == "fight" then b:setTarget(RIVAL_X[i], RIVAL_Y + 14, RIVAL_SCALE, 0) end
  audio.play("swat", 0.9)
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
      if du.reason == "duel" then audio.play("hit", 1, 0.8) end
      if du.winner == 1 then self:ring(0.8) end
      if du.reason == "duel" then
        line = ("%s: %s %d beats %s %d%s"):format(where, nameOf(winf), math.max(0, winf.paws), nameOf(linf), math.max(0, linf.paws), du.tie and (du.silk and " (tie, silk cushion)" or " (tie)") or "")
      else
        line = ("%s: %s walks in unopposed"):format(where, nameOf(winf))
      end
      line = line .. (du.swats > 1 and (". " .. du.swats .. " goblets fall.") or ". A goblet falls.")
      self:knock(3 - du.winner, du.swats)
      if du.winner == 1 and du.swats > 1 then audio.play("cheer", 1, 0.5) end
      local w = du.wound
      if w and lv then
        lv.livesShown = w.left
        if w.captured then
          lv.captured = w.rescued and "rescued" or "captured"
          local mx = w.side == 1 and MY_X[i] or RIVAL_X[i]
          local my = w.side == 1 and MY_Y or RIVAL_Y
          if w.rescued then
            fx.float(mx, my + 6, "RESCUED!", C.goldText, true)
            fx.burst(mx, my, C.gold, 24, 140)
          else
            fx.float(mx, my + 6, w.side == 1 and "CAPTURED!" or "Captured!", w.side == 1 and C.redText or C.goldText, true)
            fx.burst(mx, my, w.side == 1 and C.red or C.gold, 20, 120)
          end
          fx.addShake(6)
          fx.addPunch(w.side == 1 and 1 or 0.7)
          G.hitstop = 0.14
          audio.play(w.rescued and "rescue" or "capture", w.side == 1 and 0.9 or 1.1, 0.9)
          local who = cards.shortName(linf.def)
          if w.rescued then line = line .. " " .. who .. " is yours again!"
          elseif w.side == 1 then line = line .. " " .. who .. " is captured!"
          else line = line .. " You capture " .. who .. "!" end
        else
          self:popText(lv, w.crushed and "Crushed! -2 lives" or "-1 life", C.redText, 14)
          if w.crushed then G.hitstop = 0.08; fx.addShake(4); fx.addPunch(0.45) end
        end
      end
      if du.groom then fx.float(du.winner == 1 and MY_X[i] or RIVAL_X[i], (du.winner == 1 and MY_Y or RIVAL_Y) + 30, "Groom: +1 goblet", C.green) end
    else
      line = ("%s: nobody swats."):format(where)
      fx.float((MY_X[i] + RIVAL_X[i]) / 2, (MY_Y + RIVAL_Y) / 2 - 6, "No swat", C.muted)
      audio.play("pass", 1, 0.6)
    end
    self.log[#self.log + 1] = { text = line, col = du.winner == 1 and C.gold or du.winner == 2 and C.red or C.muted }
  end)
end

function S:clearBoard(rec)
  if not self.tut then G.award(renown.boutFeats(self.s, rec)) end
  local returns = {}
  for _, uid in ipairs(rec.returns or {}) do returns[uid] = true end
  local s = self.s
  local keepMine, keepTheirs = {}, {}
  for i = 1, 3 do
    -- Hold the Cushion: winners stay seated and warm up
    local v = self.board[i]
    if v and rec.stays[1][i] and not v.captured then
      keepMine[i] = v
      v.dim, v.paws = 0, nil
      v:setTarget(MY_X[i], MY_Y, 1, 0)
      local w = rec.stays[1][i]
      self:popText(v, w >= match.HOT and ("HOT SEAT! Warmth " .. w) or ("+1 Warmth (" .. w .. ")"), w >= match.HOT and C.goldText or C.green)
      if w >= match.HOT then fx.burst(v.x, v.y, theme.hex("#ff8a3a"), 18, 120); audio.play("hot", 1, 0.8); fx.addPulse(v.x, v.y, 0.5) end
      v = nil
    end
    local r = self.rviews[i]
    if r and rec.stays[2][i] and not r.captured then
      keepTheirs[i] = r
      r.dim, r.paws = 0, nil
      r:setTarget(RIVAL_X[i], RIVAL_Y, RIVAL_SCALE, 0)
      local w = rec.stays[2][i]
      self:popText(r, w >= match.HOT and ("HOT SEAT! Warmth " .. w) or ("Holds on (" .. w .. ")"), w >= match.HOT and C.redText or C.pale)
      self.rviews[i] = nil
    end
    if v then
      v.dim, v.paws = 0, nil
      if v.captured then
        -- carried off to the rival's side of the table
        v:setTarget(RDECK_X, RDECK_Y - 10, 0.5, 0.8)
        v.leaveT = 0.8
        self.leaving[#self.leaving + 1] = v
      elseif returns[v.inst.uid] and util.find(self.s.sides[1].hand, function(c) return c.uid == v.inst.uid end) then
        self.views[v.inst.uid] = v
        self:popText(v, "Nine Lives: back to hand", C.cyan)
      else
        v:setTarget(DECK_X - 70, 400, 0.6, -0.6)
        v.leaveT = 0.6
        self.leaving[#self.leaving + 1] = v
      end
    end
    local r = self.rviews[i]
    if r and r.captured then
      -- yours now: off to your pile
      r:setTarget(DECK_X, DECK_Y, 0.5, -0.8)
      r.leaveT = 0.8
      self.leaving[#self.leaving + 1] = r
    elseif r then
      r:setTarget(RDECK_X + 60, RDECK_Y - 60, 0.5, 0.6)
      r.leaveT = 0.6
      self.leaving[#self.leaving + 1] = r
    end
  end
  self.board, self.rviews = keepMine, keepTheirs
  audio.play("whoosh", 1, 0.5)
end

function S:finish()
  if self.finished then return end
  self.finished = true
  local won = self.s.result == "win"
  fx.banner(won and "Victory!" or "Defeat", won and "The crowd roars" or "The crowd groans", won and C.gold or C.red, 0, 160)
  audio.play(won and "win" or "lose")
  if won then for i = 1, 4 do fx.burst(160 + i * 64, 150, C.gold, 16, 140) end end
  if self.tut then
    -- the prologue goes on, win or lose
    local story = require("src.core.story")
    G.award({ "prologue" })
    self:at(1.8, function()
      G.go("cutscene", {
        lines = story.lines(G.save, "prologue_outro"), bg = { preset = "menu" },
        onDone = function()
          G.save.story.done[0] = true
          G.save.story.chapter = math.max(1, G.save.story.chapter)
          G.persist()
          G.go("story")
        end,
      })
    end)
    return
  end
  if self.ctx.boss then
    -- the High Table settles the story, not a festival
    local story = require("src.core.story")
    local chapter = G.save.story.chapter
    local result = story.finishBoss(G.save, won)
    if won then
      G.addRenown(100)
      G.award({ "storyteller", "overseen" })
    end
    G.persist()
    self:at(1.8, function()
      G.go("cutscene", {
        lines = story.lines(G.save, result, chapter), bg = { preset = "vs", ramp = won and "felt" or "blood" },
        title = won and "The ledger is yours" or "The Overseer laughs", sub = story.CHAPTERS[chapter].goalText,
        onDone = function() G.go("story") end,
      })
    end)
    return
  end
  local out = game.resolveMatch(G.save, self.ctx)
  G.persist()
  -- Renown for the match, then any feats it earned
  local gain, lines = renown.matchRenown(self.ctx, out)
  gain = math.floor(gain * (renown.STAKES[G.save.run.stake or 1] or renown.STAKES[1]).renown + 0.5)
  out.renownBefore, out.renownGain, out.renownLines = G.profile.renown, gain, lines
  renown.noteMatch(G.profile, self.ctx, out)
  G.addRenown(gain)
  out.feats = G.award(renown.matchFeats(self.ctx, out, G.save))
  out.renownAfter = G.profile.renown
  self:at(1.8, function() G.go("result", { ctx = self.ctx, out = out }) end)
end

-- ---------------------------------------------------------------- update

function S:update(dt)
  self.t = self.t + dt
  if self.tut then self.tut:update(dt) end
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
    elseif widgets.pressed and self.hoverBoard and not self.drag then
      self.seatPress = { i = self.hoverBoard, sx = mx, sy = my }
    end
    local sp = self.seatPress
    if sp and widgets.down and (math.abs(mx - sp.sx) + math.abs(my - sp.sy) > 4) and self.board[sp.i] then
      -- dragging a seated cat: pull it back and carry it like a hand card
      local uid = self.board[sp.i].inst.uid
      if self:retreat(sp.i) then self.drag = { uid = uid, from = "hand", sx = sp.sx, sy = sp.sy, moved = true } end
      self.seatPress = nil
    elseif sp and widgets.released then
      if self.board[sp.i] and self.board[sp.i]:contains(mx, my) then self:retreat(sp.i) end
      self.seatPress = nil
    end
    if self.drag and widgets.down and (math.abs(mx - self.drag.sx) + math.abs(my - self.drag.sy) > 4) then self.drag.moved = true end
    if self.drag and widgets.released then self:drop() end
  elseif self.drag and not widgets.down then
    self.drag = nil
  end
  if not widgets.down then self.seatPress = nil end
  -- live numbers for the cards on your cushions
  self.previewRec = nil
  if not self.busy then
    local pr = match.preview(self.s, self.slots)
    self.previewRec = pr
    for i = 1, 3 do
      local uid = self.slots[i]
      local v = (uid and self.views[uid]) or self.board[i]
      if v then
        local inf = pr.info[1][i]
        v.paws = (inf.kind == "cat" or inf.kind == "box") and math.max(0, inf.paws) or nil
        v.previewInfo = inf
        -- would this cat be captured if it loses here?
        local du = pr.duels[i]
        local lives = v.inst.lives or 2
        local risk = 0
        if inf.kind == "cat" and inf.def.ability ~= "ninelives" and du.reason == "duel" and lives <= 2 then
          if du.pCrush then risk = lives <= 1 and (1 - du.p) or du.pCrush[1]
          elseif du.winner == 2 and (lives <= 1 or (du.margin or 0) >= match.CRUSH) then risk = 1 end
        end
        v.risk = risk >= 0.45
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
    v.bob = (not hov) and k * 1.7 or nil -- cards in hand float; the one you point at holds still
    v.paws, v.previewInfo, v.risk = nil, nil, nil
    v:setTarget(320 + math.floor(off * spacing), HAND_Y + math.floor(off * off * 1.2) - (hov and 22 or 0), 1, 0)
  end
  for i = 1, 3 do
    local uid = self.slots[i]
    local v = uid and self.views[uid]
    if v and not (self.drag and self.drag.moved and self.drag.uid == uid) then
      v.hovered = uid == self.hoverUid
      v.selected = true
      v.bob = nil
      v:setTarget(MY_X[i], MY_Y, 1, 0)
    end
  end
  if self.drag and self.drag.moved then
    local v = self.views[self.drag.uid]
    if v then v.hovered = true; v.bob = nil; v:setTarget(mx, my, 1, 0) end
  end
  for i = 1, 3 do
    local b = self.board[i]
    if b and not self.busyResolve then
      b.hovered = self.hoverBoard == i
      b.selected = true
      b:setTarget(MY_X[i], MY_Y, 1, 0)
    end
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
  if self.ctx.boss then
    -- the Overseer looms over its own table
    lg.setScissor(G.scissor(0, 0, theme.W, HORIZON + 2))
    overseer.draw(320, HORIZON + 4, 320, self.t)
    lg.setScissor()
    lg.setColor(1, 1, 1)
    lg.draw(cardview.pile(), RDECK_X - 14, RDECK_Y - 18)
    return
  end
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
  local pile = cardview.pile()
  lg.setColor(1, 1, 1)
  lg.draw(pile, RDECK_X - 14, RDECK_Y - 18)
end

local CUSHION_LOOK = theme.CUSHION

-- A cushion is a dithered slot plate; the number shows which key places a card there.
-- kind: its upholstery (or false), which tints the plate.
local function cushion(x, y, col, num, lit, kind)
  local w, h = 62, 84
  local x0, y0 = math.floor(x - w / 2), math.floor(y - h / 2)
  theme.set(C.black, 0.45)
  lg.rectangle("fill", x0 + 1, y0 + 2, w, h)
  if kind and CUSHION_LOOK[kind] then col = theme.mix(col, CUSHION_LOOK[kind].col, 0.7) end
  plates.draw(plates.plate(w, h, col, { light = 0.06, shade = 0.2 }), x0, y0)
  if lit then
    theme.set(C.gold)
    lg.rectangle("fill", x0 - 2, y0 - 2, w + 4, 1)
    lg.rectangle("fill", x0 - 2, y0 + h + 1, w + 4, 1)
    lg.rectangle("fill", x0 - 2, y0 - 2, 1, h + 4)
    lg.rectangle("fill", x0 + w + 1, y0 - 2, 1, h + 4)
  end
  if num then plates.print(num, 26, x, y - 16, theme.mix(col, C.paper, 0.3), { align = "center" }) end
end

-- A small badge on the corner of every upholstered cushion, drawn over the cards.
function S:drawCushionBadges()
  for side = 1, 2 do
    for i = 1, 3 do
      local kind = self.s.sides[side].cushions[i]
      local look = kind and CUSHION_LOOK[kind]
      if look then
        local x = (side == 1 and MY_X or RIVAL_X)[i] + 31 - 6
        local y = (side == 1 and MY_Y or RIVAL_Y) + 42 - 6
        gfx.box(x - 6, y - 6, 13, 13, C.black)
        gfx.box(x - 5, y - 5, 11, 11, look.col)
        icons.draw(look.icon, x, y, C.white)
      end
    end
  end
end

-- A gold link between bonded cats sitting side by side.
function S:drawBondLinks()
  local rec = self.busyResolve and self.rec or self.previewRec
  if not rec or not rec.bonds then return end
  for _, b in ipairs(rec.bonds) do
    if b.side == 1 or self.busyResolve then
      local x = math.floor(((b.side == 1 and MY_X or RIVAL_X)[b.a] + (b.side == 1 and MY_X or RIVAL_X)[b.b]) / 2)
      local y = (b.side == 1 and MY_Y or RIVAL_Y)
      local pulse = 0.75 + 0.25 * math.sin(self.t * 5)
      for k = -1, 1 do
        gfx.box(x - 4, y + k * 9 - 3, 9, 7, C.black)
        gfx.box(x - 3, y + k * 9 - 2, 7, 5, C.gold, pulse)
        gfx.box(x - 1, y + k * 9, 3, 1, C.black)
      end
    end
  end
end

function S:drawGoblets(side)
  local sd = self.s.sides[side]
  local col = side == 1 and C.gold or C.steel
  -- a dark tray on the table, so the goblets and their count read on the mustard
  local x0, gy = self:gobletPos(side, 1)
  local x1 = self:gobletPos(side, sd.maxGoblets)
  gfx.box(x0 - 30, gy - 11, x1 - x0 + 40, 21, C.black, 0.85)
  gfx.box(x0 - 29, gy - 10, x1 - x0 + 38, 19, C.deep, 0.9)
  for k = 1, sd.maxGoblets do
    local x, y = self:gobletPos(side, k)
    if k <= self.gob[side] then
      icons.draw("goblet", x, y, col)
    else
      theme.set(C.black, 0.35)
      lg.rectangle("fill", x - 3, y + 4, 7, 2)
    end
  end
  gfx.text(tostring(self.gob[side]), T.big(), x0 - 10, gy - 8, col, { align = "right", bg = C.deep })
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
  local ph = 76 + (n and 30 or 0)
  gfx.panel(8, 8, 180, ph, C.deep)
  local nsize = plates.textWidth(sd.name, 22) <= 160 and 22 or 18
  plates.header(8, 8, 180, 30, n and C.night or C.red, sd.name, { size = nsize, streak = n and 1.0 or 0.43 })
  gfx.text(sub, T.body(), 14, 40, n and C.red or C.paper2)
  local coat = cards.COATS[opp.coat]
  local onTable = 0
  if not self.busyResolve then for i = 1, 3 do if sd.placed[i] then onTable = onTable + 1 end end end
  gfx.text(coat.name .. " coat", T.body(), 14, 56, coat.color)
  gfx.text(("Hand %d  Deck %d"):format(#sd.hand - onTable, #sd.deck), T.body(), 182, 56, C.paper2, { align = "right" })
  if n then overlays.traitChips(n, 14, 76, 170, s.revealed) end
  -- you
  local me = s.sides[1]
  gfx.panel(8, 292, 168, 60, C.deep)
  plates.header(8, 292, 168, 26, C.ink3, me.name, { size = 18 })
  gfx.text(("Deck %d  Discard %d"):format(#me.deck, #me.discard), T.body(), 14, 318, C.paper2)
  if save.run and not self.tut then hud.charmRow(save.run, 14, 335) end
end

function S:inspectLines()
  local v, inf, side
  if self.drag and self.drag.moved then v = self.views[self.drag.uid]
  elseif self.hoverUid then v = self.views[self.hoverUid]
  elseif self.hoverR then v, side = self.rviews[self.hoverR], 2
  elseif self.hoverBoard then v = self.board[self.hoverBoard] end
  if not v then
    local mine = self:cushionAt(widgets.mx, widgets.my)
    local theirs
    for i = 1, 3 do
      if math.abs(widgets.mx - RIVAL_X[i]) <= 31 and math.abs(widgets.my - RIVAL_Y) <= 42 then theirs = i end
    end
    local si, i = mine and 1 or (theirs and 2), mine or theirs
    local kind = si and self.s.sides[si].cushions[i]
    if kind then
      local ck = match.CUSHION_KINDS[kind]
      return { { text = ck.name .. " cushion", font = T.big() },
        { text = (si == 1 and "Your " or "Their ") .. CUSHION_NAMES[i]:lower() .. " cushion", color = C.muted },
        { text = ck.desc, color = C.paper } }
    end
    return nil
  end
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
  return picker.cardLines(v.def, v.inst, self.rec and self.rec.info and self:infoFor(v) or v.previewInfo), v.def
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

-- Bedimew's lesson, in place of the inspect panel while the tutorial runs.
function S:drawTutorial()
  local tut = self.tut
  local st = tut:step()
  gfx.panel(PX, PY, PW, PH, C.deep)
  plates.header(PX, PY, PW, 24, C.goldDark, "Old Bedimew", { size = 18, streak = 0.43 })
  local me = art.character("bedimew", 48)
  gfx.box(PX + 6, PY + 30, 50, 50, C.black)
  lg.setColor(1, 1, 1)
  lg.draw(me, PX + 7, PY + 31)
  gfx.text(("Lesson %d of %d"):format(tut.i, #tut.STEPS), T.small(), PX + 62, PY + 34, C.muted, { bg = C.deep })
  local y = PY + 86
  y = y + gfx.textf(st.text, theme.font("body", 10.5), PX + 8, y, PW - 16, "left", C.paper, { bg = C.deep }) + 8
  if st.next then
    if widgets.button("tut_next", PX + 8, PY + PH - 34, PW - 16, 26, st.last and "Let's fight" or "Next", { color = C.red }) then
      audio.play("click")
      tut:advance()
    end
  end
end

function S:drawHighlights()
  local st = self.tut and self.tut:step()
  if not st or not st.target then return end
  local pulse = 0.65 + 0.35 * math.sin(self.t * 6)
  local bob = math.floor(math.sin(self.t * 5) * 2 + 0.5)
  local function frame(x, y, w, h)
    theme.set(C.goldText, pulse)
    lg.rectangle("fill", x, y, w, 2); lg.rectangle("fill", x, y + h - 2, w, 2)
    lg.rectangle("fill", x, y, 2, h); lg.rectangle("fill", x + w - 2, y, 2, h)
  end
  local function arrow(x, y)
    theme.set(C.black)
    lg.polygon("fill", x - 7, y - 1, x + 7, y - 1, x, y + 8)
    theme.set(C.goldText)
    lg.polygon("fill", x - 5, y, x + 5, y, x, y + 6)
  end
  if st.target[1] == "cushion" then
    local i = st.target[2]
    frame(MY_X[i] - 36, MY_Y - 47, 72, 94)
    arrow(MY_X[i], MY_Y - 58 + bob)
  elseif st.target[1] == "charge" then
    frame(PX - 3, 306, PW + 6, 48)
  end
  if st.card then
    for _, c in ipairs(self:handList()) do
      local v = self.views[c.uid]
      if v and v.def.id == st.card and not (self.drag and self.drag.uid == c.uid) then
        frame(v.x - 31, v.y - 42, 62, 84)
        arrow(v.x, v.y - 54 + bob)
      end
    end
  end
end

function S:drawPanel()
  local s = self.s
  if self.tut and self.tut:active() then return self:drawTutorial() end
  gfx.panel(PX, PY, PW, PH, C.deep)
  local x, y, w = PX + 7, PY + 28, PW - 14
  local lines, def = self:inspectLines()
  if lines then
    -- the card's name is the panel's title card, then its illustration
    local first = table.remove(lines, 1)
    local tsize = plates.textWidth(first.text, 18) <= PW - 16 and 18 or 14
    plates.header(PX, PY, PW, 24, C.ink3, first.text, { size = tsize })
    -- the big illustration, unless the text needs the room (then the small one)
    local textH = 0
    for _, l in ipairs(lines) do textH = textH + gfx.wrapHeight(l.text, l.font or T.body(), w) + (l.gap or 3) end
    if def then
      local pic = art.illustration(def)
      local iw, ih = pic:getDimensions()
      if y + ih + 2 + textH > PY + PH - 3 then
        pic = art.card(def)
        iw, ih = pic:getDimensions()
      end
      local ix = math.floor(PX + (PW - iw) / 2)
      gfx.box(ix - 1, y - 2, iw + 2, ih + 2, C.black)
      plates.draw(pic, ix, y - 1)
      y = y + ih + 2
    end
    lg.setScissor(G.scissor(PX, PY, PW, PH - 2))
    for _, l in ipairs(lines) do
      y = y + gfx.textf(l.text, l.font or T.body(), x, y, w, "left", l.color or C.paper) + (l.gap or 3)
    end
    lg.setScissor()
    return
  end
  local blue = theme.hex("#2471fc")
  if self.busyResolve or (self.busy and #self.log > 0) then
    plates.header(PX, PY, PW, 24, C.night, "Bout " .. (self.rec and self.rec.bout or s.bout), { size = 18, streak = 1.0 })
    for _, l in ipairs(self.log) do y = y + gfx.textf(l.text, T.body(), x, y, w, "left", l.col) + 4 end
    return
  end
  local lead = s.lead
  plates.header(PX, PY, PW, 24, lead == 1 and blue or C.red, "Bout " .. s.bout .. (lead == 1 and ": you lead" or ": you answer"), { size = 16, streak = 0.43 })
  local tip
  local ties = match.tiesTo(s) == 1 and "Ties go to you." or "Ties go to them."
  if lead == 1 then
    tip = "Put up to 3 cards on your cushions. The rival sees only their backs, then answers. " .. ties
  else
    tip = "The rival has led. A card back shows the cat's coat; a dark back is a Shadow cat or a trick. " .. ties
  end
  y = y + gfx.textf(tip, T.body(), x, y, w, "left", C.paper) + 6
  if s.omen then
    y = y + gfx.textf("Omen: " .. s.omen.name .. ". " .. s.omen.desc, T.body(), x, y, w, "left", C.gold) + 6
  end
  y = y + gfx.textf("Click a card to place it, drag to choose a cushion. Then Charge! Winners stay seated and warm up; click a seated cat to pull it back.", T.body(), x, y, w, "left", C.paper2) + 6
  gfx.label("Coat edge: +" .. match.edge(s) .. " Paws", x, y, C.gold)
  y = y + 12
  for _, pair in ipairs({ { "ember", "gilt" }, { "gilt", "tide" }, { "tide", "ember" } }) do
    local a, b = cards.COATS[pair[1]], cards.COATS[pair[2]]
    plates.draw(plates.titleCard(50, 15, a.color, { label = a.name, size = 13, outline = C.black }), x, y)
    gfx.text("beats", T.body(), x + 56, y - 1, C.paper2)
    plates.draw(plates.titleCard(50, 15, b.color, { label = b.name, size = 13, outline = C.black }), x + 96, y)
    y = y + 19
  end
end

function S:draw()
  local s = self.s
  self:drawRival()
  -- cushions
  for i = 1, 3 do
    cushion(RIVAL_X[i], RIVAL_Y, self.ctx.nemesis and theme.hex("#3a1513") or C.ink, nil, false, s.sides[2].cushions[i])
    local dropTarget = self.drag and self.drag.moved and self:cushionAt(widgets.mx, widgets.my) == i
    cushion(MY_X[i], MY_Y, C.ink2, (not self.slots[i] and not self.board[i]) and tostring(i) or nil, dropTarget, s.sides[1].cushions[i])
  end
  -- what the rival's empty cushions mean right now
  if not self.busyResolve and not self.finished then
    for i = 1, 3 do
      if not self.rviews[i] then
        if s.lead == 1 then
          plates.print("?", 26, RIVAL_X[i], RIVAL_Y - 16, C.ink3, { align = "center" })
        elseif not self.busy and not s.sides[2].placed[i] then
          gfx.text("Empty", T.body(), RIVAL_X[i], RIVAL_Y - 9, C.paper2, { align = "center", shadow = false })
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
  lg.setColor(1, 1, 1)
  lg.draw(cardview.pile(), DECK_X - 14, DECK_Y - 18)
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
  self:drawCushionBadges()
  self:drawBondLinks()
  -- shown rival cards get an eye
  for i = 1, 3 do
    local v = self.rviews[i]
    if v and s.sides[2].shown[i] and not self.busyResolve then
      icons.draw("eye", v.x + 20, v.y - 30, C.cyan)
    end
  end
  self:drawPlaques()
  self:drawHighlights()
  -- right column
  if widgets.button("m_rules", PX, 8, 52, 18, "Rules", { font = T.body() }) then overlays.help() end
  if widgets.button("m_deck", PX + 56, 8, 52, 18, "Pride", { disabled = self.tut ~= nil or not G.save.run }) then overlays.deck(G.save.run.deck) end
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
