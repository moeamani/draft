-- The duel table: rows, hand fan, animated scores, event-driven juice.
local ai = require("src.core.ai")
local art = require("src.ui.art")
local cards = require("src.core.cards")
local cardview = require("src.ui.cardview")
local duel = require("src.core.duel")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local overlays = require("src.ui.overlays")
local picker = require("src.ui.picker")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local traits = require("src.core.traits")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c

local BOARD_X, BOARD_W = 372, 1206
local ROW_H = 124
local ROW_Y = { [2] = { arcane = 30, vanguard = 162 }, [1] = { vanguard = 318, arcane = 450 } }
local UNIT_SCALE = 0.4
local HAND_SCALE = 0.6

function S:enter(p)
  local save = G.save
  self.node = p.node
  self.ctx = game.setupDuel(save, p.node)
  G.persist()
  self.s = self.ctx.state
  self.t = 0
  self.views = {}       -- unit uid -> view
  self.hand = {}        -- inst uid -> view
  self.leaving = {}
  self.flashPending = {}
  self.phase = "mulligan"
  self.mulls = 2
  self.lock = 0.6
  self.hold = 0
  self.aiWait = 0
  self.timeline = {}
  self.disp = { 0, 0 }
  self.scorePop = { 0, 0 }
  self.override = nil
  self.finished = false
  local n = self.ctx.nemesis
  if n then
    self.enemyPortrait = art.nemesis(n, game.rankOf(save, n))
    S.bg = { C.black, { 0.28, 0.05, 0.04 }, C.red, spin = 1.8 }
  else
    self.enemyPortrait = art.stray(p.node.foe)
    S.bg = { C.ink, C.ink2, p.node.foe.elite and C.red or C.gold, spin = 1.1 }
  end
  self.playerPortrait = art.player(save.playerName)
  self.style = ai.STYLES[self.ctx.personality] or ai.STYLES.default
  duel.takeEvents(self.s)
  fx.banner(n and ("vs " .. n.name) or ("vs " .. self.ctx.foeName), "Redraw up to 2 cards, then keep your hand", n and C.red or C.paper)
  sfx.play("round")
end

-- ---------------------------------------------------------------- layout

local function rowCenterY(side, row) return ROW_Y[side][row] + ROW_H / 2 end

function S:handLayout()
  local hand = self.s.sides[1].hand
  local n = #hand
  local spacing = math.min(126, 980 / math.max(1, n))
  local hover
  for i = n, 1, -1 do
    local v = self.hand[hand[i].uid]
    if v and not hover and widgets.layer == widgets.top and v:contains(widgets.mx, widgets.my) then hover = i end
  end
  self.hoverHand = hover and hand[hover] or nil
  for i, inst in ipairs(hand) do
    local v = self.hand[inst.uid]
    if not v then
      v = cardview.new(inst, 1500, 1000, HAND_SCALE)
      v.rot = -0.6
      self.hand[inst.uid] = v
    end
    local k = i - (n + 1) / 2
    local x = 975 + k * spacing
    local y = 772 + (k * k) * 2.2
    local live = (self.phase == "mulligan") or duel.canPlay(self.s, 1)
    if i == hover then
      v.hovered = true
      v:setTarget(x, 712, 0.74, 0)
    else
      v.hovered = false
      v:setTarget(x, y + (live and 0 or 18), HAND_SCALE, k * 0.045)
    end
  end
end

function S:boardLayout()
  local s = self.s
  local seen = {}
  for side = 1, 2 do
    for _, row in ipairs(cards.ROWS) do
      local units = s.sides[side].rows[row]
      local n = #units
      local spacing = math.min(90, (BOARD_W - 160) / math.max(1, n))
      for i, u in ipairs(units) do
        seen[u.uid] = true
        local v = self.views[u.uid]
        if not v then
          local hv = self.hand[u.inst.uid]
          if hv then
            v = hv
            self.hand[u.inst.uid] = nil
            v.inst = u.inst
          else
            local sx, sy = (side == 2) and 975 or 975, (side == 2) and -160 or 1050
            v = cardview.new(u.inst, sx, sy, UNIT_SCALE)
          end
          v.def = u.def
          v.style = "compact"
          v.hovered = false
          v.flash = 1
          self.views[u.uid] = v
        end
        local x = BOARD_X + 90 + (BOARD_W - 90) / 2 + (i - (n + 1) / 2) * spacing
        v:setTarget(x, rowCenterY(side, row), UNIT_SCALE, 0)
        v.power = duel.unitPower(s, side, row, u)
        v.adv = duel.hasAdvantage(s, side, row, u)
        v.stray = u.origin ~= side
        v.side, v.row, v.unit = side, row, u
      end
    end
  end
  for uid, v in pairs(self.views) do
    if not seen[uid] then
      self.views[uid] = nil
      if not v.dying then
        v:setTarget(v.side == 1 and -120 or 1720, v.y + (v.side == 1 and 120 or -120), 0.3, v.side == 1 and -0.8 or 0.8)
        v.leaveT = 0.9
      end
      self.leaving[#self.leaving + 1] = v
    end
  end
  -- hand views whose card left the hand without becoming a unit (specials)
  local inHand = {}
  for _, c in ipairs(s.sides[1].hand) do inHand[c.uid] = true end
  for uid, v in pairs(self.hand) do
    if not inHand[uid] then
      self.hand[uid] = nil
      v:setTarget(975, 420, 0.8, 0)
      v.dying = 0
      v.flash = 1
      self.leaving[#self.leaving + 1] = v
    end
  end
end

-- ---------------------------------------------------------------- events

function S:at(delay, fn) self.timeline[#self.timeline + 1] = { t = delay, fn = fn } end

function S:viewPos(uid)
  local v = self.views[uid]
  if v then return v.tx, v.ty end
end

function S:process()
  local events = duel.takeEvents(self.s)
  local roundEnded = false
  for _, e in ipairs(events) do if e.t == "roundend" then roundEnded = true end end
  if not roundEnded then self:boardLayout() end
  local d = 0.05
  local maxT = 0.35
  for _, e in ipairs(events) do
    if e.t == "play" then
      if e.side == 2 then
        sfx.play("enemy")
        if e.special then
          local v = cardview.new(e.inst, 975, -150, 0.8)
          v:setTarget(975, 300, 0.8, 0)
          v.dying = -0.6
          self.leaving[#self.leaving + 1] = v
        end
      else
        sfx.play("card")
      end
      fx.addShake(3)
    elseif e.t == "float" then
      local uid, txt, good, hit = e.uid, e.text, e.good, e.hit
      self:at(d, function()
        local x, y = self:viewPos(uid)
        if x then
          fx.float(x, y - 40, txt, good and { 0.55, 1, 0.6 } or C.red, 30)
          if hit then sfx.play("hit"); fx.burst(x, y, C.red, 10, 240, 5); fx.addShake(5) end
        end
      end)
      d = d + 0.18
    elseif e.t == "destroy" then
      local v
      for _, lv in ipairs(self.leaving) do if lv.unit and lv.unit.uid == e.uid then v = lv end end
      if v then
        v.dying = -d
        v.leaveT = nil
        v:setTarget(v.x, v.y, v.s, 0)
        local x, y = v.x, v.y
        self:at(d, function()
          sfx.play("burn")
          fx.burst(x, y, { 1, 0.55, 0.1 }, 22, 300, 6)
          fx.addShake(6)
        end)
      end
      d = d + 0.2
    elseif e.t == "banner" then
      local text, sub, col = e.text, e.sub, e.color == "red" and C.red or e.color == "blue" and C.cyan or e.color == "gold" and C.gold or C.paper
      self:at(d, function() fx.banner(text, sub, col); sfx.play("round") end)
      d = d + 1.5
    elseif e.t == "roundend" then
      local sc, winner = e.scores, e.winner
      self.override = sc
      self.hold = d + 1.9
      local label = winner == 0 and "Round tied" or winner == 1 and "You take the round" or (self.s.sides[2].name .. " takes the round")
      self:at(d + 0.35, function()
        fx.banner(label, sc[1] .. "  -  " .. sc[2], winner == 1 and C.gold or winner == 2 and C.red or C.paper)
        sfx.play(winner == 1 and "win" or "lose", 1, 0.7)
        for side = 1, 2 do
          if winner == 0 or winner ~= side then
            fx.burst(side == 1 and 120 or 120, side == 1 and 600 or 210, C.red, 30, 380, 7)
          end
        end
        fx.flash = 0.6
      end)
      d = d + 1.9
    elseif e.t == "clear" then
      self:at(d, function() self.override = nil end)
    elseif e.t == "trait" then
      local side, tr = e.side, e.trait
      self:at(d, function()
        sfx.play("reveal")
        local info = traits.TRAITS[tr]
        fx.toast((side == 2 and self.s.sides[2].name or "You") .. ": " .. (info and info.name or tr) .. " revealed!", side == 2 and "info" or "good")
      end)
      d = d + 0.3
    elseif e.t == "pass" then
      if e.side == 2 then fx.toast(self.s.sides[2].name .. " passes.", "info") end
      sfx.play("pass")
    elseif e.t == "shake" then
      local a = e.amount
      self:at(d, function() fx.addShake(a) end)
    elseif e.t == "rowfx" then
      local side, row = e.side, e.row
      self:at(d, function()
        fx.float(BOARD_X + BOARD_W / 2, rowCenterY(side, row), "x2", C.gold, 54)
        fx.burst(BOARD_X + BOARD_W / 2, rowCenterY(side, row), C.gold, 30, 500, 7)
      end)
      d = d + 0.3
    elseif e.t == "unbox" then
      local v = self.views[e.uid]
      if v then
        self.views[e.uid] = nil
        v.style = "full"
        self.hand[e.inst.uid] = v
      end
    end
    if d > maxT then maxT = d end
  end
  self.lock = math.max(self.lock, maxT + 0.25)
end

-- ---------------------------------------------------------------- actions

function S:playHand(inst)
  if self.phase == "mulligan" then
    if self.mulls <= 0 then return end
    local old = self.hand[inst.uid]
    local ok = duel.mulligan(self.s, 1, inst.uid)
    if ok then
      self.mulls = self.mulls - 1
      if old then
        old:setTarget(1500, 1100, HAND_SCALE, 0.8)
        old.leaveT = 0.6
        self.leaving[#self.leaving + 1] = old
        self.hand[inst.uid] = nil
      end
      sfx.play("card")
      if self.mulls <= 0 then self:at(0.4, function() self:startPlay() end) end
    end
    return
  end
  if self.lock > 0 or not duel.canPlay(self.s, 1) then return end
  local v = self.hand[inst.uid]
  if v then v.flash = 1 end
  duel.playCard(self.s, 1, inst.uid)
  self:process()
end

function S:pass()
  if self.phase == "mulligan" then return self:startPlay() end
  if self.lock > 0 or not duel.canPlay(self.s, 1) then return end
  duel.pass(self.s, 1)
  self:process()
end

function S:startPlay()
  if self.phase ~= "mulligan" then return end
  self.phase = "play"
  duel.takeEvents(self.s)
  if self.ctx.spyglass then fx.toast("Spyglass: " .. self.ctx.nemesis.name .. " has " .. traits.TRAITS[self.ctx.spyglass].name, "info") end
  fx.banner(self.s.turn == 1 and "You lead" or (self.s.sides[2].name .. " leads"), "Round 1", C.gold)
  self.lock = 1.2
  self.aiWait = 0.6
end

-- ---------------------------------------------------------------- update

function S:update(dt)
  self.t = self.t + dt
  local s = self.s
  for i = #self.timeline, 1, -1 do
    local e = self.timeline[i]
    e.t = e.t - dt
    if e.t <= 0 then table.remove(self.timeline, i); e.fn() end
  end
  self.lock = math.max(0, self.lock - dt)
  if self.hold > 0 then self.hold = self.hold - dt else self:boardLayout() end
  self:handLayout()

  for side = 1, 2 do
    local target = self.override and self.override[side] or duel.score(s, side)
    local before = math.floor(self.disp[side] + 0.5)
    self.disp[side] = self.disp[side] + (target - self.disp[side]) * math.min(1, dt * 8)
    if math.abs(target - self.disp[side]) < 0.5 then self.disp[side] = target end
    if math.floor(self.disp[side] + 0.5) ~= before then
      self.scorePop[side] = 1
      sfx.play("chip", 1 + side * 0.1, 0.35)
    end
    self.scorePop[side] = math.max(0, self.scorePop[side] - dt * 4)
  end

  for _, v in pairs(self.views) do v:update(dt); v:updatePowerPop(v.power or 0, dt) end
  for _, v in pairs(self.hand) do v:update(dt) end
  for i = #self.leaving, 1, -1 do
    local v = self.leaving[i]
    v:update(dt)
    if v.leaveT then v.leaveT = v.leaveT - dt end
    if (v.leaveT and v.leaveT <= 0) or (v.dying and v.dying >= 1) then table.remove(self.leaving, i) end
  end

  self.hoverUnit = nil
  if not self.hoverHand and widgets.layer == widgets.top then
    for _, v in pairs(self.views) do
      if v:contains(widgets.mx, widgets.my) then self.hoverUnit = v end
    end
  end
  for _, v in pairs(self.views) do v.hovered = v == self.hoverUnit end

  if self.phase == "play" and not s.over and s.turn == 2 and self.lock <= 0 and #self.timeline == 0 then
    self.aiWait = self.aiWait + dt
    if self.aiWait > 0.75 then
      self.aiWait = 0
      local a = ai.choose(s, 2, self.style)
      if a.type == "pass" then
        if s.sides[2].mods.arrogant and duel.score(s, 2) > duel.score(s, 1) and not s.sides[1].passed and not require("src.core.util").contains(s.revealed[2], "arrogant") then
          table.insert(s.revealed[2], "arrogant")
          fx.toast(s.sides[2].name .. " passes smugly: Arrogant revealed!", "info")
        end
        duel.pass(s, 2)
      else
        duel.playCard(s, 2, a.uid)
      end
      self:process()
    end
  end

  if s.over and not self.finished and self.lock <= 0 and #self.timeline == 0 and self.hold <= 0 then
    self.finished = true
    local out = game.resolveDuel(G.save, self.ctx)
    G.persist()
    self:at(0.3, function() G.go("reward", { ctx = self.ctx, out = out }) end)
  end
end

-- ---------------------------------------------------------------- draw

local function gems(x, y, n, col)
  for i = 1, 2 do
    local on = i <= n
    icons.draw("gem", x + (i - 1) * 34, y + (on and math.sin(G.time * 3 + i) * 2 or 0), 30, on and col or { 0.2, 0.26, 0.23 })
  end
end

function S:drawPanel(side, x, y, w, h)
  local s = self.s
  local sd = s.sides[side]
  local active = self.phase == "play" and not s.over and s.turn == side
  local pulse = active and (0.6 + 0.4 * math.sin(self.t * 5)) or 0
  local border = active and C.gold or (side == 2 and { C.red[1], C.red[2], C.red[3], 0.5 } or { 1, 1, 1, 0.12 })
  gfx.panel(x, y, w, h, { 0.03, 0.06, 0.05, 0.9 }, { border = border, lw = 2 + pulse * 2, r = 16 })
  local portrait = side == 2 and self.enemyPortrait or self.playerPortrait
  portrait:setFilter("nearest", "nearest")
  lg.setColor(1, 1, 1)
  lg.draw(portrait, x + 16, y + 16, 0, 96 / 64, 96 / 64)
  local nf = theme.font("bold", 26)
  local name = sd.name
  while nf:getWidth(name) > w - 140 and #name > 3 do name = name:sub(1, -2) end
  gfx.text(name, nf, x + 126, y + 16, C.paper)
  local sub = side == 2 and (self.ctx.nemesis and self.ctx.nemesis.epithet or ("the " .. (self.node.foe and self.node.foe.title or ""))) or "Champion"
  gfx.textf(sub, theme.font("italic", 16), x + 126, y + 48, w - 140, "left", C.muted, { shadow = false })
  gems(x + 140, y + 92, sd.gems, side == 1 and C.gold or C.red)
  gfx.text(("hand %d   deck %d"):format(#sd.hand, #sd.deck), theme.font("mono", 14), x + 16, y + 122, C.muted, { shadow = 0 })
  if sd.passed then
    gfx.panel(x + w - 96, y + 118, 84, 26, C.muted, { r = 13, depth = 2, sheen = false })
    gfx.text("PASSED", theme.font("monoBold", 13), x + w - 54, y + 123, C.ink, { align = "center", shadow = 0 })
  end
  -- big score
  local sc = math.floor(self.disp[side] + 0.5)
  local pop = 1 + self.scorePop[side] * 0.25
  local sf = theme.font("bold", 64)
  lg.push()
  lg.translate(x + w - 64, y + 70)
  lg.scale(pop)
  gfx.text(tostring(sc), sf, 0, -sf:getHeight() / 2, side == 1 and C.gold or C.red, { align = "center", shadow = 4 })
  lg.pop()
  if side == 2 and self.ctx.nemesis then
    overlays.traitChips(self.ctx.nemesis, x + 16, y + 150, w - 32, theme.font("mono", 12), s.revealed[2])
  elseif side == 2 and #s.revealed[2] > 0 then
    local cx = x + 16
    for _, t in ipairs(s.revealed[2]) do cx = cx + gfx.chip(traits.TRAITS[t] and traits.TRAITS[t].name or t, cx, y + 150, "strength", theme.font("mono", 12)) + 6 end
  end
end

function S:drawRow(side, row)
  local s = self.s
  local y = ROW_Y[side][row]
  local weather = s.weather[row]
  local col = side == 2 and { 0.12, 0.04, 0.04, 0.55 } or { 0.02, 0.06, 0.05, 0.55 }
  gfx.panel(BOARD_X, y, BOARD_W, ROW_H, col, { r = 16, depth = 4, border = weather and C.cyan or { 1, 1, 1, 0.07 }, lw = weather and 3 or 2, sheen = false })
  icons.draw(row == "vanguard" and "sword" or "orb", BOARD_X + 44, y + 28, 26, C.muted)
  local rs = duel.rowScore(s, side, row)
  lg.setColor(0, 0, 0, 0.5)
  lg.circle("fill", BOARD_X + 46, y + 80, 31)
  theme.set(side == 2 and C.red or C.paper)
  lg.circle("fill", BOARD_X + 44, y + 77, 30)
  theme.set(C.black)
  lg.circle("fill", BOARD_X + 44, y + 77, 26)
  local f = theme.font("bold", 26)
  gfx.text(tostring(rs), f, BOARD_X + 44, y + 77 - f:getHeight() / 2, C.paper, { align = "center", shadow = 0 })
  local horned = s.sides[side].horn[row]
  for _, u in ipairs(s.sides[side].rows[row]) do if u.def.ability == "yowl" then horned = true end end
  if horned then
    icons.draw("notes", BOARD_X + BOARD_W - 34, y + 30, 30, C.gold, math.sin(self.t * 4) * 0.2)
    gfx.text("x2", theme.font("bold", 22), BOARD_X + BOARD_W - 34, y + 54, C.gold, { align = "center" })
  end
  if weather then
    lg.setScissor(BOARD_X, y, BOARD_W, ROW_H)
    if row == "vanguard" then
      lg.setColor(0.55, 0.75, 1, 0.35)
      lg.setLineWidth(2)
      for i = 0, 60 do
        local rx = BOARD_X + ((i * 53 + self.t * 260) % (BOARD_W + 60)) - 30
        local ry = y + ((i * 37 + self.t * 520) % ROW_H)
        lg.line(rx, ry, rx - 6, ry + 14)
      end
      lg.setLineWidth(1)
    else
      for i = 0, 3 do
        lg.setColor(0.8, 0.84, 0.88, 0.12)
        local ox = math.sin(self.t * 0.6 + i) * 60
        lg.ellipse("fill", BOARD_X + BOARD_W * (0.2 + i * 0.22) + ox, y + ROW_H / 2, 260, 40)
      end
    end
    lg.setScissor()
  end
end

function S:draw()
  local s = self.s
  -- left column
  self:drawPanel(2, 20, 30, 330, 250)
  self:drawPanel(1, 20, 470, 330, 200)
  -- middle info
  gfx.label("Round " .. s.round, 185, 302, C.pale, "center")
  local myTurn = self.phase == "play" and duel.canPlay(s, 1)
  local label = self.phase == "mulligan" and ("Redraw " .. self.mulls .. " more") or s.over and "Duel over" or myTurn and "Your turn" or (s.sides[1].passed and s.sides[2].passed) and "..." or (s.sides[2].name .. " is thinking")
  local lf = theme.font("bold", 28)
  local lp = myTurn and (1 + math.sin(self.t * 5) * 0.04) or 1
  lg.push()
  lg.translate(185, 344)
  lg.scale(lp)
  gfx.textf(label, lf, -160, -lf:getHeight() / 2, 320, "center", myTurn and C.gold or C.muted)
  lg.pop()
  local wy = 392
  if s.weather.vanguard then icons.draw("umbrella", 120, wy + 12, 24, C.cyan); gfx.text("Downpour", theme.font("serif", 18), 140, wy, C.cyan, { shadow = 0 }); wy = wy + 28 end
  if s.weather.arcane then icons.draw("cloud", 120, wy + 12, 24, C.cyan); gfx.text("Moonfog", theme.font("serif", 18), 140, wy, C.cyan, { shadow = 0 }) end

  -- enemy hand backs
  local back = cardview.back()
  local nh = #s.sides[2].hand
  for i = 1, nh do
    local k = i - (nh + 1) / 2
    lg.setColor(1, 1, 1)
    lg.draw(back, 185 + k * 22, 284 - 30, k * 0.06, 0.16, 0.16, cardview.W / 2, cardview.H / 2)
  end

  -- pass button
  local passLabel = self.phase == "mulligan" and "Keep hand" or "Pass"
  if widgets.button("pass", 40, 700, 290, 84, passLabel, { color = C.red, size = 36, disabled = self.phase == "play" and (not myTurn or self.lock > 0) }) then self:pass() end
  if widgets.button("d_menu", 40, 800, 140, 48, "Menu", { size = 18 }) then overlays.pause() end
  if widgets.button("d_help", 190, 800, 140, 48, "Rules", { size = 18 }) then overlays.help() end

  -- board
  for _, side in ipairs({ 2, 1 }) do
    for _, row in ipairs({ side == 2 and "arcane" or "vanguard", side == 2 and "vanguard" or "arcane" }) do self:drawRow(side, row) end
  end
  -- divider
  local dy = 298
  lg.setColor(C.gold[1], C.gold[2], C.gold[3], 0.6)
  lg.rectangle("fill", BOARD_X + 40, dy + 8, BOARD_W - 80, 3)
  gfx.text(tostring(math.floor(self.disp[2] + 0.5)), theme.font("monoBold", 14), BOARD_X + BOARD_W - 30, dy - 2, C.red, { shadow = 0 })
  gfx.text(tostring(math.floor(self.disp[1] + 0.5)), theme.font("monoBold", 14), BOARD_X + 10, dy - 2, C.gold, { shadow = 0 })

  for _, v in pairs(self.views) do if v ~= self.hoverUnit then v:draw({ power = v.power, advantage = v.adv, strayMark = v.stray }) end end
  for _, v in ipairs(self.leaving) do v:draw({ power = v.power }) end
  if self.hoverUnit then local v = self.hoverUnit; v:draw({ power = v.power, advantage = v.adv, strayMark = v.stray }) end

  -- hand
  local hand = s.sides[1].hand
  for _, inst in ipairs(hand) do
    local v = self.hand[inst.uid]
    if v and inst ~= self.hoverHand then v:draw() end
  end
  if self.hoverHand then
    local v = self.hand[self.hoverHand.uid]
    if v then
      v:draw()
      if widgets.released and widgets.layer == widgets.top then self:playHand(self.hoverHand) end
      widgets.tooltip(function() picker.cardTooltip(v.def, v.inst, v.x + 110, 380) end)
    end
  elseif self.hoverUnit then
    local v = self.hoverUnit
    widgets.tooltip(function() picker.cardTooltip(v.def, v.inst, v.x + 60, v.y - 60) end)
  end
  if self.phase == "mulligan" then
    gfx.panel(800, 598, 350, 40, C.cyan, { r = 20, depth = 4, sheen = false })
    gfx.text("Click a card to swap it (" .. self.mulls .. " left)", theme.font("serif", 20), 975, 605, C.ink, { align = "center", shadow = 0 })
  end
end

function S:keypressed(k)
  if k == "escape" then overlays.pause()
  elseif k == "space" or k == "p" then self:pass() end
end

return S
