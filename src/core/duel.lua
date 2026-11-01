-- Duel engine: best of three rounds, two rows per side. Pure logic, no LÖVE calls.
local cards = require("src.core.cards")
local rng = require("src.core.rng")
local traits = require("src.core.traits")
local util = require("src.core.util")

local getDef, isLegend, levelBonus = cards.getDef, cards.isLegend, cards.levelBonus
local ROWS = cards.ROWS

local M = {}

local HAND_SIZE, MAX_HAND = 8, 10

local function emptySide(setup)
  local deck = {}
  for i, c in ipairs(setup.deck) do
    deck[i] = { uid = c.uid, id = c.id, level = c.level, xp = c.xp, def = c.def }
  end
  return {
    name = setup.name, deck = deck, hand = {}, discard = {},
    rows = { vanguard = {}, arcane = {} }, horn = { vanguard = false, arcane = false },
    passed = false, gems = 2, mods = setup.mods or traits.baseMods(), unitsThisRound = 0, played = {},
  }
end

local function emit(s, e)
  if s.sim then return end
  s.events[#s.events + 1] = e
  if e.t == "log" then s.log[#s.log + 1] = e.text end
end
local function log(s, text) emit(s, { t = "log", text = text }) end

function M.reveal(s, side, trait)
  if not trait or s.sim then return end
  if util.contains(s.revealed[side], trait) then return end
  table.insert(s.revealed[side], trait)
  emit(s, { t = "trait", side = side, trait = trait })
end
local reveal = M.reveal

local function draw(s, side, n, silent)
  local sd = s.sides[side]
  local drawn = 0
  for _ = 1, n do
    if #sd.deck == 0 or #sd.hand >= MAX_HAND then break end
    sd.hand[#sd.hand + 1] = table.remove(sd.deck)
    drawn = drawn + 1
  end
  if drawn > 0 and not silent then emit(s, { t = "draw", side = side, n = drawn }) end
end

local function newUid(s)
  s.uidc = s.uidc + 1
  return "u" .. s.uidc
end

local function other(side) return 3 - side end
M.other = other

function M.allUnits(s, side)
  local out = {}
  for _, row in ipairs(ROWS) do
    for _, unit in ipairs(s.sides[side].rows[row]) do out[#out + 1] = { unit = unit, row = row } end
  end
  return out
end
local allUnits = M.allUnits

local function rawPower(u) return u.def.power + levelBonus(u.level) + u.mod end
M.rawPower = rawPower

function M.hasAdvantage(s, side, row, u)
  if u.def.coat == "none" then return false end
  local beats = cards.COATS[u.def.coat].beats
  if not beats then return false end
  for _, x in ipairs(s.sides[other(side)].rows[row]) do
    if x.def.coat == beats then return true end
  end
  return false
end

function M.unitPower(s, side, row, u)
  local me, opp = s.sides[side], s.sides[other(side)]
  local p = rawPower(u)
  if not isLegend(u.def) then
    if s.weather[row] and not me.mods.weatherImmune then
      p = me.mods.weatherZero and 0 or math.min(p, me.mods.weatherFloor)
    end
    if u.def.ability == "litter" then
      p = p * util.count(me.rows[row], function(x) return x.def.id == u.def.id end)
    end
    p = p + util.count(me.rows[row], function(x) return x ~= u and x.def.ability == "inspire" end)
    local horned = me.horn[row] or util.count(me.rows[row], function(x) return x ~= u and x.def.ability == "yowl" end) > 0
    if horned then p = p * 2 end
  else
    p = p + me.mods.legendBonus
  end
  p = p + (row == "vanguard" and me.mods.vanguardBonus or me.mods.arcaneBonus)
  if u.def.coat ~= "none" then
    p = p + (me.mods.coatBonus[u.def.coat] or 0)
    if M.hasAdvantage(s, side, row, u) then p = p + cards.COAT_ADVANTAGE end
    if opp.mods.dread and opp.mods.dread == u.def.coat then p = p + 2 end
  end
  return math.max(0, p)
end
local unitPower = M.unitPower

function M.rowScore(s, side, row)
  local t = 0
  for _, u in ipairs(s.sides[side].rows[row]) do t = t + unitPower(s, side, row, u) end
  return t
end

function M.score(s, side) return M.rowScore(s, side, "vanguard") + M.rowScore(s, side, "arcane") end

local function strongest(s, side, includeLegend, onlyRow)
  local best, out = -1, {}
  for _, x in ipairs(allUnits(s, side)) do
    if (not onlyRow or x.row == onlyRow) and (includeLegend or not isLegend(x.unit.def)) then
      local p = unitPower(s, side, x.row, x.unit)
      if p > best then best = p; out = { { unit = x.unit, row = x.row, p = p } }
      elseif p == best then out[#out + 1] = { unit = x.unit, row = x.row, p = p } end
    end
  end
  return out
end

local function destroy(s, side, row, u)
  local r = s.sides[side].rows[row]
  if not util.removeValue(r, u) then return end
  if not u.def.token then table.insert(s.sides[u.origin].discard, u.inst) end
  emit(s, { t = "destroy", side = side, uid = u.uid, name = u.def.name, row = row, inst = u.inst })
  log(s, u.def.name .. " is destroyed.")
  local sd = s.sides[side]
  if sd.mods.vengeful then
    local best = strongest(s, side, false)
    if best[1] then
      best[1].unit.mod = best[1].unit.mod + 2
      emit(s, { t = "float", uid = best[1].unit.uid, text = "+2 vengeance", good = side ~= 1 })
      reveal(s, side, sd.mods.source.vengeful)
    end
  end
end

local function damage(s, side, row, u, amount, kind)
  if isLegend(u.def) or amount <= 0 then return end
  local sd = s.sides[side]
  if sd.mods.thickfur then
    emit(s, { t = "float", uid = u.uid, text = "immune", good = side == 1 })
    reveal(s, side, sd.mods.source.thickfur)
    return
  end
  u.mod = u.mod - amount
  emit(s, { t = "float", uid = u.uid, text = "-" .. amount, good = side ~= 1, hit = true })
  log(s, ("%s takes %d (%s)."):format(u.def.name, amount, kind))
  if rawPower(u) <= 0 then destroy(s, side, row, u) end
end

local function revealWeather(s, side)
  local m = s.sides[side].mods
  if m.weatherImmune then reveal(s, side, m.source.weatherImmune) end
  if m.weatherZero then reveal(s, side, m.source.weatherZero) end
end

local function placeUnit(s, side, inst, fromHand)
  local def = getDef(inst)
  local row = cards.rowOf(def.type)
  local boardSide = def.ability == "stray" and other(side) or side
  local unit = { uid = newUid(s), inst = inst, def = def, level = inst.level, mod = 0, ninelivesUsed = false, origin = side }
  local me = s.sides[side]
  if fromHand and boardSide == side then
    if me.unitsThisRound == 0 and me.mods.firstUnitBonus ~= 0 and not isLegend(def) then
      unit.mod = unit.mod + me.mods.firstUnitBonus
      reveal(s, side, me.mods.source.firstUnitBonus)
    end
    me.unitsThisRound = me.unitsThisRound + 1
  end
  local bs = s.sides[boardSide]
  table.insert(bs.rows[row], unit)
  if row == "vanguard" and bs.mods.vanguardBonus ~= 0 then reveal(s, boardSide, bs.mods.source.vanguardBonus) end
  if row == "arcane" and bs.mods.arcaneBonus ~= 0 then reveal(s, boardSide, bs.mods.source.arcaneBonus) end
  local enemy = s.sides[other(side)]
  if enemy.mods.dread and enemy.mods.dread == def.coat then reveal(s, other(side), enemy.mods.source.dread) end
  if s.weather[row] then revealWeather(s, boardSide) end
  return unit, row, boardSide
end

local function triggerUnit(s, side, unit, row, depth)
  depth = depth or 0
  local opp = other(side)
  local me = s.sides[side]
  local ab = unit.def.ability
  if ab == "smite" then
    local targets = strongest(s, opp, false)
    if targets[1] and targets[1].p > 0 then
      emit(s, { t = "shake", amount = 8 })
      for _, t in ipairs(targets) do destroy(s, opp, t.row, t.unit) end
    end
  elseif ab == "hex" then
    local t = strongest(s, opp, false)[1]
    if t then
      local cats = util.count(allUnits(s, side), function(x) return x.unit.def.ability == "hex" and x.unit.origin == side end)
      local om = s.sides[opp].mods
      if om.hexVuln > 0 then reveal(s, opp, om.source.hexVuln) end
      damage(s, opp, t.row, t.unit, cats + me.mods.hexBonus + om.hexVuln, "hex")
    end
  elseif ab == "pounce" then
    local t = strongest(s, opp, false, row)[1]
    if t then
      local om = s.sides[opp].mods
      local dmg = 3 + me.mods.pounceBonus
      if om.pounceVuln then dmg = dmg * 2; reveal(s, opp, om.source.pounceVuln) end
      damage(s, opp, t.row, t.unit, dmg, "pounce")
    end
  elseif ab == "groom" then
    if depth > 3 then return end
    local bestI, bestP = nil, -1
    for i, c in ipairs(me.discard) do
      local d = getDef(c)
      if d.kind == "unit" and not isLegend(d) and d.ability ~= "stray" and not d.token then
        local p = d.power + levelBonus(c.level)
        if p > bestP then bestP = p; bestI = i end
      end
    end
    if bestI then
      local inst = table.remove(me.discard, bestI)
      local u2, r2 = placeUnit(s, side, inst, false)
      emit(s, { t = "summon", side = side, uid = u2.uid })
      emit(s, { t = "float", uid = u2.uid, text = "groomed back!", good = side == 1 })
      log(s, u2.def.name .. " is groomed back to health.")
      triggerUnit(s, side, u2, r2, depth + 1)
    end
  elseif ab == "purr" then
    local weakest, wp = nil, math.huge
    for _, x in ipairs(allUnits(s, side)) do
      if x.unit ~= unit and not isLegend(x.unit.def) then
        local p = unitPower(s, side, x.row, x.unit)
        if p < wp then weakest = x.unit; wp = p end
      end
    end
    if weakest then
      weakest.mod = weakest.mod + 2
      emit(s, { t = "float", uid = weakest.uid, text = "+2 purr", good = side == 1 })
    end
  elseif ab == "muster" then
    local copies = util.filter(me.deck, function(c) return c.id == unit.def.id end)
    for _, c in ipairs(copies) do
      util.removeValue(me.deck, c)
      local u2 = placeUnit(s, side, c, false)
      emit(s, { t = "summon", side = side, uid = u2.uid })
      emit(s, { t = "float", uid = u2.uid, text = "answers the call", good = side == 1 })
    end
  elseif ab == "stray" then
    draw(s, side, 2)
    log(s, ("%s wanders over to %s. %s draws 2."):format(unit.def.name, s.sides[opp].name, me.name))
  end
end

local function bestHornRow(s, side)
  local best, gain = "vanguard", -1
  for _, row in ipairs(ROWS) do
    if not s.sides[side].horn[row] then
      local before = M.rowScore(s, side, row)
      s.sides[side].horn[row] = true
      local g = M.rowScore(s, side, row) - before
      s.sides[side].horn[row] = false
      if g > gain then gain = g; best = row end
    end
  end
  return best
end

local function playSpecial(s, side, inst, def)
  local me = s.sides[side]
  local ab = def.ability
  if ab == "downpour" then
    s.weather.vanguard = true
    emit(s, { t = "banner", text = "Downpour", sub = "Vanguard units drop to 1", color = "blue" })
    revealWeather(s, 1); revealWeather(s, 2)
  elseif ab == "moonfog" then
    s.weather.arcane = true
    emit(s, { t = "banner", text = "Moonfog", sub = "Arcane units drop to 1", color = "blue" })
    revealWeather(s, 1); revealWeather(s, 2)
  elseif ab == "sunbeam" then
    s.weather.vanguard, s.weather.arcane = false, false
    emit(s, { t = "banner", text = "Sunbeam", sub = "The weather clears", color = "gold" })
  elseif ab == "warhorn" then
    local row = bestHornRow(s, side)
    me.horn[row] = true
    emit(s, { t = "rowfx", side = side, row = row, text = "x2" })
    log(s, me.name .. " rallies the " .. row .. ".")
  elseif ab == "box" then
    local best, bp = nil, -1
    for _, x in ipairs(allUnits(s, side)) do
      if not isLegend(x.unit.def) and x.unit.origin == side and not x.unit.def.token then
        local p = x.unit.def.power + levelBonus(x.unit.level)
        if p > bp then best = x; bp = p end
      end
    end
    if best then
      util.removeValue(me.rows[best.row], best.unit)
      me.hand[#me.hand + 1] = best.unit.inst
      emit(s, { t = "unbox", side = side, uid = best.unit.uid, inst = best.unit.inst })
      log(s, best.unit.def.name .. " hides in a box (back to hand).")
    end
  elseif ab == "hairball" then
    local top, hits = 0, {}
    for sd = 1, 2 do
      for _, x in ipairs(strongest(s, sd, false)) do
        if x.p > top then top = x.p; hits = {} end
        if x.p == top and top > 0 then hits[#hits + 1] = { side = sd, row = x.row, unit = x.unit } end
      end
    end
    emit(s, { t = "banner", text = "Hairball!", sub = #hits > 0 and (top .. "-power units destroyed") or "Nothing to hit", color = "red" })
    emit(s, { t = "shake", amount = 10 })
    for _, h in ipairs(hits) do destroy(s, h.side, h.row, h.unit) end
  end
  table.insert(me.discard, inst)
end

function M.canPlay(s, side) return not s.over and s.turn == side and not s.sides[side].passed end

-- Resolve a card from hand without advancing the turn (AI uses this to simulate).
function M.resolvePlay(s, side, handUid)
  local me = s.sides[side]
  local idx
  for i, c in ipairs(me.hand) do if c.uid == handUid then idx = i; break end end
  if not idx then return false end
  local inst = table.remove(me.hand, idx)
  local def = getDef(inst)
  me.played[#me.played + 1] = inst.uid
  log(s, me.name .. " plays " .. def.name .. ".")
  if def.kind == "special" then
    emit(s, { t = "play", side = side, name = def.name, inst = inst, special = true })
    playSpecial(s, side, inst, def)
  else
    local unit, row, boardSide = placeUnit(s, side, inst, true)
    emit(s, { t = "play", side = side, name = def.name, uid = unit.uid, inst = inst, boardSide = boardSide })
    triggerUnit(s, side, unit, row)
  end
  return true
end

local endRound

local function autoPass(s)
  local cur = s.sides[s.turn]
  if not s.over and not cur.passed and #cur.hand == 0 then M.pass(s, s.turn) end
end

local function endTurn(s, side)
  if s.over then return end
  if s.sides[1].passed and s.sides[2].passed then
    endRound(s)
    return
  end
  local o = other(side)
  s.turn = s.sides[o].passed and side or o
  autoPass(s)
end

function M.playCard(s, side, handUid)
  if not M.canPlay(s, side) then return false end
  if not M.resolvePlay(s, side, handUid) then return false end
  endTurn(s, side)
  return true
end

function M.pass(s, side)
  if s.over or s.sides[side].passed then return end
  s.sides[side].passed = true
  emit(s, { t = "pass", side = side })
  log(s, s.sides[side].name .. " passes.")
  endTurn(s, side)
end

local function startRound(s)
  for i = 1, 2 do
    local sd = s.sides[i]
    if sd.mods.bodyguard then
      s.uidc = s.uidc + 1
      local inst = { uid = "g" .. s.uidc, id = "guard", level = 1, xp = 0 }
      local u = placeUnit(s, i, inst, false)
      emit(s, { t = "summon", side = i, uid = u.uid })
      reveal(s, i, sd.mods.source.bodyguard)
    end
  end
  autoPass(s)
end

endRound = function(s)
  local sc = { M.score(s, 1), M.score(s, 2) }
  local winner
  if sc[1] > sc[2] then winner = 1 elseif sc[2] > sc[1] then winner = 2 else winner = 0 end
  s.rounds[#s.rounds + 1] = { scores = sc, winner = winner }
  if winner == 1 or winner == 0 then s.sides[2].gems = s.sides[2].gems - 1 end
  if winner == 2 or winner == 0 then s.sides[1].gems = s.sides[1].gems - 1 end
  emit(s, { t = "roundend", winner = winner, scores = sc, round = s.round })
  log(s, ("Round %d: %s (%d-%d)."):format(s.round, winner == 0 and "tie" or (s.sides[winner].name .. " wins"), sc[1], sc[2]))

  local g1, g2 = s.sides[1].gems, s.sides[2].gems
  if g1 <= 0 or g2 <= 0 then
    s.over = true
    s.result = (g1 > 0 and "win") or (g2 > 0 and "loss") or "draw"
    return
  end

  for i = 1, 2 do
    local sd = s.sides[i]
    for _, row in ipairs(ROWS) do
      local keep = {}
      for _, u in ipairs(sd.rows[row]) do
        if u.def.ability == "ninelives" and not u.ninelivesUsed then
          u.ninelivesUsed = true
          keep[#keep + 1] = u
          emit(s, { t = "float", uid = u.uid, text = "nine lives", good = i == 1 })
        elseif not u.def.token then
          table.insert(s.sides[u.origin].discard, u.inst)
        end
      end
      sd.rows[row] = keep
      sd.horn[row] = false
    end
    sd.passed = false
    sd.unitsThisRound = 0
  end
  emit(s, { t = "clear" })
  s.weather = { vanguard = false, arcane = false }
  s.round = s.round + 1
  for i = 1, 2 do
    draw(s, i, 1)
    local lost = winner == other(i) or winner == 0
    if lost and s.sides[i].mods.secondWind then
      draw(s, i, 2)
      reveal(s, i, s.sides[i].mods.source.secondWind)
    end
  end
  s.turn = winner == 1 and 2 or 1 -- the round loser leads
  emit(s, { t = "banner", text = "Round " .. s.round, sub = (s.turn == 1 and "You lead" or (s.sides[2].name .. " leads")), color = "paper" })
  startRound(s)
end

function M.create(a, b, seed, first)
  local s = {
    sides = { emptySide(a), emptySide(b) },
    weather = { vanguard = false, arcane = false },
    round = 1, turn = first or 1, rng = rng.new(seed), over = false, result = nil,
    rounds = {}, events = {}, log = {}, revealed = { {}, {} }, uidc = 0, sim = false,
  }
  for i = 1, 2 do
    local sd = s.sides[i]
    rng.shuffle(s.rng, sd.deck)
    local n = math.max(5, math.min(MAX_HAND, HAND_SIZE + sd.mods.extraDraw))
    if sd.mods.extraDraw ~= 0 then reveal(s, i, sd.mods.source.extraDraw) end
    draw(s, i, n, true)
  end
  startRound(s)
  return s
end

function M.clone(s)
  local events, logt = s.events, s.log
  s.events, s.log = {}, {}
  local c = util.deepcopy(s)
  s.events, s.log = events, logt
  c.sim = true
  return c
end

-- Swap a hand card for a random card from the deck (pre-duel redraw).
function M.mulligan(s, side, handUid)
  local sd = s.sides[side]
  local i
  for k, c in ipairs(sd.hand) do if c.uid == handUid then i = k; break end end
  if not i or #sd.deck == 0 then return false end
  local c = table.remove(sd.hand, i)
  local j = rng.int(s.rng, #sd.deck) + 1
  local newc = sd.deck[j]
  sd.deck[j] = c
  table.insert(sd.hand, i, newc)
  rng.shuffle(s.rng, sd.deck)
  return true, newc
end

function M.takeEvents(s)
  local e = s.events
  s.events = {}
  return e
end

function M.findUnit(s, uid)
  for side = 1, 2 do
    for _, row in ipairs(ROWS) do
      for _, u in ipairs(s.sides[side].rows[row]) do
        if u.uid == uid then return u, side, row end
      end
    end
  end
end

return M
