-- A festival match: both sides pick up to 5 cards, form a Formation, reveal, and the higher
-- score wins the exchange and knocks Pride off the loser. First to 0 Pride loses.
local cards = require("src.core.cards")
local formations = require("src.core.formations")
local rng = require("src.core.rng")
local traits = require("src.core.traits")
local util = require("src.core.util")

local M = {}

M.PRIDE = 100
M.HAND = 8
M.MAX_PLAY = 5
M.REDRAWS = 2
M.MAX_EXCHANGES = 14

local function other(i) return 3 - i end
M.other = other

local function newSide(setup)
  local deck, counts = {}, {}
  for i, c in ipairs(setup.deck) do
    deck[i] = { uid = c.uid, id = c.id, level = c.level, xp = c.xp, def = c.def }
    counts[c.id] = (counts[c.id] or 0) + 1
  end
  local mods = setup.mods or traits.baseMods()
  local pride = M.PRIDE + mods.pride
  return {
    name = setup.name, deck = deck, discard = {}, hand = {}, mods = mods, pride = pride, maxPride = pride,
    redrawsLeft = M.REDRAWS + mods.redraws, wins = 0, extraDraw = 0, nineUsed = {}, vengeance = false,
    secondWindUsed = false, counts = counts, selection = nil, scored = {},
  }
end

local function handSize(sd) return math.max(4, math.min(10, M.HAND + sd.mods.handSize)) end

local function drawOne(s, sd)
  if #sd.deck == 0 then
    if #sd.discard == 0 then return nil end
    sd.deck, sd.discard = sd.discard, {}
    rng.shuffle(s.rng, sd.deck)
  end
  local c = table.remove(sd.deck)
  sd.hand[#sd.hand + 1] = c
  return c
end

local function refill(s, sd)
  local target = math.min(10, handSize(sd) + sd.extraDraw)
  sd.extraDraw = 0
  local drawn = {}
  while #sd.hand < target do
    local c = drawOne(s, sd)
    if not c then break end
    drawn[#drawn + 1] = c
  end
  return drawn
end

local function findInHand(sd, uid)
  for i, c in ipairs(sd.hand) do if c.uid == uid then return c, i end end
end

local function catData(inst)
  local d = cards.getDef(inst)
  return { paws = cards.paws(inst), coat = d.coat, type = d.type, ability = d.ability, inst = inst, def = d }
end

-- ---------------------------------------------------------------- scoring

local function step(r, target, amount, text, ref)
  r.steps[#r.steps + 1] = { target = target, amount = amount, text = text, ref = ref, paws = r.paws, cheer = r.cheer }
end

local function push(r, target, amount, text, ref)
  if target == "paws" then r.paws = r.paws + amount
  elseif target == "cheer" then r.cheer = r.cheer + amount
  elseif target == "xcheer" then r.cheer = r.cheer * amount end
  step(r, target, amount, text, ref)
end

-- Score one side's selection on its own (no rival interaction yet).
function M.evaluate(s, si, uids)
  local sd = s.sides[si]
  local m = sd.mods
  local catsD, tricks = {}, {}
  for _, uid in ipairs(uids) do
    local c = findInHand(sd, uid)
    if c then
      local d = cards.getDef(c)
      if d.kind == "special" then tricks[#tricks + 1] = c else catsD[#catsD + 1] = catData(c) end
    end
  end
  local hasWild = false
  for _, t in ipairs(tricks) do if cards.getDef(t).ability == "box" then hasWild = true end end
  local f, idx = formations.detect(catsD, hasWild)
  local scoring = {}
  for _, i in ipairs(idx) do scoring[#scoring + 1] = catsD[i] end
  local r = {
    side = si, formation = f, scoring = scoring, played = uids, tricks = tricks, paws = 0, cheer = 0, steps = {},
    out = { hex = 0, cheerMinus = 0, half = false, fog = false }, heal = 0, returns = {}, extraDraw = 0, pounces = 0,
    coat = f and formations.coatOf(scoring, f.id) or nil, total = 0,
  }
  if f then
    push(r, "paws", f.paws, f.name, "formation")
    push(r, "cheer", f.cheer, f.name, "formation")
  else
    r.cheer = 1
  end
  local magicN, physN, legend = 0, 0, false
  for _, c in ipairs(scoring) do
    if c.type == "magic" then magicN = magicN + 1 else physN = physN + 1 end
    if c.def.rarity == "legendary" then legend = true end
  end
  local best
  for _, c in ipairs(scoring) do
    local p = c.paws + (m.coatPaws[c.coat] or 0)
    push(r, "paws", p, "+" .. p, c.inst.uid)
    local ab = c.ability
    if ab == "smite" then push(r, "xcheer", 2, "x2 Cheer", c.inst.uid)
    elseif ab == "inspire" then
      local n = magicN - (c.type == "magic" and 1 or 0)
      if n > 0 then push(r, "cheer", 2 * n, "+" .. 2 * n .. " Cheer", c.inst.uid) end
    elseif ab == "hex" then r.out.hex = r.out.hex + 6 + m.hexBonus; step(r, "hex", 6 + m.hexBonus, "Hex!", c.inst.uid)
    elseif ab == "litter" then
      local n = 0
      for _, o in ipairs(scoring) do if o ~= c and o.coat == c.coat then n = n + 1 end end
      if n > 0 then push(r, "paws", 6 * n, "+" .. 6 * n, c.inst.uid) end
    elseif ab == "pounce" then r.pounces = r.pounces + 1; r.pounceRef = c.inst.uid
    elseif ab == "groom" then r.heal = r.heal + 6; step(r, "heal", 6, "+6 Pride", c.inst.uid)
    elseif ab == "purr" then
      if #scoring > 1 then push(r, "paws", 3 * (#scoring - 1), "+" .. 3 * (#scoring - 1), c.inst.uid) end
    elseif ab == "muster" then
      local n = sd.counts[c.def.id] or 1
      push(r, "cheer", n, "+" .. n .. " Cheer", c.inst.uid)
    elseif ab == "ninelives" then
      if not sd.nineUsed[c.inst.uid] then r.returns[#r.returns + 1] = c.inst.uid end
    elseif ab == "stray" then r.extraDraw = r.extraDraw + 2
    end
    if not best or c.paws > best.paws then best = c end
  end
  for _, c in ipairs(scoring) do
    if c.ability == "yowl" then
      local top
      for _, o in ipairs(scoring) do if o ~= c and (not top or o.paws > top.paws) then top = o end end
      if top then push(r, "paws", top.paws, "Again! +" .. top.paws, top.inst.uid) end
    end
  end
  r.topPaws = best and best.paws or 0
  for _, t in ipairs(tricks) do
    local ab = cards.getDef(t).ability
    if ab == "sunbeam" then push(r, "cheer", 3, "+3 Cheer", t.uid)
    elseif ab == "warhorn" then push(r, "xcheer", 1.5, "x1.5 Cheer", t.uid)
    elseif ab == "downpour" then r.out.cheerMinus = r.out.cheerMinus + 2
    elseif ab == "moonfog" then r.out.fog = true
    elseif ab == "hairball" then r.out.half = true
    end
  end
  if f then
    if m.flatPaws > 0 then push(r, "paws", m.flatPaws, "+" .. m.flatPaws, "charm:cream") end
    if m.physPaws > 0 and physN >= 3 then push(r, "paws", m.physPaws, "Warlord +" .. m.physPaws, "trait:warlord") end
    if m.magicCheer > 0 and magicN >= 3 then push(r, "cheer", m.magicCheer, "Archmage +" .. m.magicCheer, "trait:archmage") end
    if m.grudge > 0 then push(r, "cheer", m.grudge, "Grudge +" .. m.grudge, "trait:grudge") end
    if sd.vengeance then push(r, "cheer", 3, "Vengeance +3", "trait:vengeful") end
    if m.drum and s.exchange == 1 then push(r, "cheer", 4, "+4 Cheer", "charm:drum") end
    if m.tally and sd.wins > 0 then push(r, "cheer", sd.wins, "+" .. sd.wins .. " Cheer", "charm:tally") end
    if m.legendCheer > 0 and legend then push(r, "cheer", m.legendCheer, "+" .. m.legendCheer .. " Cheer", "charm:crown") end
    if m.covenCheer > 0 and f.id == "coven" then push(r, "cheer", m.covenCheer, "+" .. m.covenCheer .. " Cheer", "charm:candle") end
  end
  return r
end

local function finalize(r, mult)
  r.mult = mult or 1
  r.total = math.floor(math.max(0, r.paws) * math.max(1, r.cheer) * r.mult + 0.5)
  if not r.formation then r.total = 0 end
  return r.total
end

-- Apply everything that depends on the rival: coat advantage, pounce, hexes, weather, debuffs.
local function cross(s, r, rr, si)
  local me, them = s.sides[si], s.sides[other(si)]
  local m = me.mods
  if r.formation then
    local adv = r.coat and rr.coat and cards.COATS[r.coat] and cards.COATS[r.coat].beats == rr.coat
    if adv then
      push(r, "cheer", 2, "Coat advantage +2", "coat")
      if r.pounces > 0 then push(r, "paws", (12 + m.pounceBonus) * r.pounces, "Pounce!", r.pounceRef) end
    end
    if them.mods.dread and r.coat == them.mods.dread then push(r, "cheer", 2, "They fear you +2", "trait:dread") end
  end
  local rival = si == 2
  if rr.out.hex > 0 then
    if m.hexImmune then step(r, "note", 0, "Thick Fur shrugs off the hex", "trait:thickfur")
    else
      local amt = rr.out.hex * (m.hexVuln and 2 or 1)
      push(r, "paws", -amt, "Hexed -" .. amt, (m.hexVuln and rival) and "trait:superstitious" or "rival")
    end
  end
  local weatherMult = m.weatherImmune and 0 or (m.weatherDouble and 2 or 1)
  local immuneRef = rival and "trait:rainsoaked" or "charm:cloak"
  local doubleRef = (m.weatherDouble and rival) and "trait:hydrophobic" or "rival"
  if rr.out.cheerMinus > 0 then
    if weatherMult == 0 then step(r, "note", 0, "Immune to the rain", immuneRef)
    else push(r, "cheer", -rr.out.cheerMinus * weatherMult, "Soaked -" .. rr.out.cheerMinus * weatherMult, doubleRef) end
  end
  if rr.out.fog and r.topPaws > 0 then
    if weatherMult == 0 then step(r, "note", 0, "Sees through the fog", immuneRef)
    else push(r, "paws", -math.min(r.topPaws * weatherMult, r.paws), "Lost in fog", doubleRef) end
  end
  if rr.out.half then push(r, "xcheer", 0.5, "Hairball! x0.5", "rival") end
  if them.mods.rivalCheer > 0 then push(r, "cheer", -them.mods.rivalCheer, "Distracted -" .. them.mods.rivalCheer, "charm:yarn") end
  local mult = 1
  if r.formation and m.sealRound and r.formation.id == "roundtable" then mult = 2; step(r, "mult", 2, "Round Seal x2", "charm:seal") end
  if r.formation and m.lucky and rng.chance(s.rng, 0.25) then r.cheer = r.cheer * 2; step(r, "xcheer", 2, "Lucky! x2", "charm:lucky") end
  if m.lazy and s.exchange == 1 then mult = mult * 0.5; step(r, "mult", 0.5, "Lazy x0.5", "trait:lazy") end
  finalize(r, mult)
end

-- Own-only estimate (for the player's live preview and the AI).
function M.preview(s, si, uids)
  local r = M.evaluate(s, si, uids)
  finalize(r, 1)
  return r
end

-- ---------------------------------------------------------------- AI

local SPECIAL_GOOD = { sunbeam = true, warhorn = true, downpour = true, moonfog = true, hairball = true }

local function bestSelection(s, si, noise)
  local sd = s.sides[si]
  local catsIdx, trickIdx = {}, {}
  for i, c in ipairs(sd.hand) do
    if cards.getDef(c).kind == "special" then trickIdx[#trickIdx + 1] = i else catsIdx[#catsIdx + 1] = i end
  end
  local n = #catsIdx
  local candidates = {}
  for mask = 1, 2 ^ n - 1 do
    local sub, m, k = {}, mask, 1
    local size = 0
    while m > 0 do
      if m % 2 == 1 then size = size + 1 end
      m = math.floor(m / 2)
    end
    if size <= M.MAX_PLAY then
      m, k = mask, 1
      local sum = 0
      local data = {}
      while m > 0 do
        if m % 2 == 1 then
          local inst = sd.hand[catsIdx[k]]
          sub[#sub + 1] = inst.uid
          local cd = catData(inst)
          data[#data + 1] = cd
          sum = sum + cd.paws
        end
        m = math.floor(m / 2)
        k = k + 1
      end
      local f, v = formations.exact(data, false)
      if f then candidates[#candidates + 1] = { uids = sub, rough = v } end
    end
  end
  if #candidates == 0 then
    local only = {}
    for _, i in ipairs(trickIdx) do only[#only + 1] = sd.hand[i].uid end
    return { uids = only, total = 0 }
  end
  table.sort(candidates, function(a, b) return a.rough > b.rough end)
  local best, bestV
  for i = 1, math.min(6, #candidates) do
    local cand = candidates[i]
    local uids = util.map(cand.uids, function(x) return x end)
    for _, ti in ipairs(trickIdx) do
      local t = sd.hand[ti]
      if #uids < M.MAX_PLAY and SPECIAL_GOOD[cards.getDef(t).ability] then uids[#uids + 1] = t.uid end
    end
    local r = M.preview(s, si, uids)
    local v = r.total + r.out.hex * 3 + r.out.cheerMinus * 12 + (r.out.half and 40 or 0) + (r.out.fog and 25 or 0) + r.heal * 2
    if noise and noise > 0 then v = v * (1 + (rng.next(s.rng) - 0.5) * noise) end
    if not bestV or v > bestV then best, bestV = { uids = uids, total = r.total, r = r }, v end
  end
  return best
end
M.bestSelection = bestSelection

M.STYLES = {
  brute = { noise = 0.15, redrawBelow = 2 },
  schemer = { noise = 0.0, redrawBelow = 3 },
  zealot = { noise = 0.1, redrawBelow = 3 },
  coward = { noise = 0.35, redrawBelow = 2 },
  trickster = { noise = 0.25, redrawBelow = 3 },
  default = { noise = 0.15, redrawBelow = 3 },
}

local WEAK = { lone = 1, duet = 2, vanguard = 3, conclave = 3, litter = 4 }

function M.aiPrepare(s, si, style)
  style = style or M.STYLES.default
  local sd = s.sides[si]
  for _ = 1, sd.redrawsLeft do
    local best = bestSelection(s, si, 0)
    local f = best.r and best.r.formation
    local weak = not f or (WEAK[f.id] or 9) < style.redrawBelow
    if not weak then break end
    local keep = {}
    for _, uid in ipairs(best.uids) do keep[uid] = true end
    local toss = {}
    local sorted = util.filter(sd.hand, function(c) return not keep[c.uid] end)
    table.sort(sorted, function(a, b) return cards.paws(a) < cards.paws(b) end)
    for i = 1, math.min(M.MAX_PLAY, #sorted) do toss[#toss + 1] = sorted[i].uid end
    if #toss == 0 then break end
    M.redraw(s, si, toss)
  end
  local best = bestSelection(s, si, style.noise)
  sd.selection = best.uids
  sd.shownCoat = best.r and best.r.coat or nil
  return best
end

-- ---------------------------------------------------------------- actions

function M.create(a, b, seed, aiStyle)
  local s = {
    sides = { newSide(a), newSide(b) }, rng = rng.new(seed), exchange = 1, over = false, result = nil,
    history = {}, last = nil, aiStyle = aiStyle, revealed = {},
  }
  for i = 1, 2 do
    rng.shuffle(s.rng, s.sides[i].deck)
    refill(s, s.sides[i])
  end
  M.aiPrepare(s, 2, aiStyle)
  return s
end

function M.redraw(s, si, uids)
  local sd = s.sides[si]
  if sd.redrawsLeft <= 0 or #uids == 0 or #uids > M.MAX_PLAY then return nil end
  for _, uid in ipairs(uids) do
    local c, i = findInHand(sd, uid)
    if c then table.remove(sd.hand, i); sd.discard[#sd.discard + 1] = c end
  end
  sd.redrawsLeft = sd.redrawsLeft - 1
  local drawn = {}
  for _ = 1, #uids do
    local c = drawOne(s, sd)
    if c then drawn[#drawn + 1] = c end
  end
  return drawn
end

local function damageFor(win, lose, glass)
  local d = math.floor(16 + 32 * (1 - lose / math.max(1, win)) + 0.5)
  d = math.max(16, math.min(48, d))
  if glass then d = math.floor(d * 1.25 + 0.5) end
  return d
end

-- Commit the player's selection and resolve the exchange. Returns the exchange record.
function M.commit(s, uids)
  if s.over then return nil end
  if #uids == 0 or #uids > M.MAX_PLAY then return nil end
  local a, b = s.sides[1], s.sides[2]
  local r1 = M.evaluate(s, 1, uids)
  local r2 = M.evaluate(s, 2, b.selection or {})
  cross(s, r1, r2, 1)
  cross(s, r2, r1, 2)
  local rec = { exchange = s.exchange, r = { r1, r2 }, winner = 0, damage = 0, heal = { 0, 0 }, secondWind = nil, prideBefore = { a.pride, b.pride } }
  if r1.total > r2.total then rec.winner = 1 elseif r2.total > r1.total then rec.winner = 2 end
  a.vengeance, b.vengeance = false, false
  if rec.winner > 0 then
    local w, l = rec.winner, other(rec.winner)
    local loser = s.sides[l]
    rec.damage = damageFor(rec.r[w].total, rec.r[l].total, loser.mods.glassJaw)
    loser.pride = loser.pride - rec.damage
    s.sides[w].wins = s.sides[w].wins + 1
    if loser.mods.vengeful then loser.vengeance = true end
  end
  for i = 1, 2 do
    local sd, r = s.sides[i], rec.r[i]
    if r.heal > 0 and sd.pride > 0 then
      local h = math.min(r.heal, sd.maxPride - sd.pride)
      sd.pride = sd.pride + h
      rec.heal[i] = h
    end
    if sd.mods.secondWind and not sd.secondWindUsed and sd.pride > 0 and sd.pride < 30 then
      sd.secondWindUsed = true
      sd.pride = math.min(sd.maxPride, sd.pride + 20)
      rec.secondWind = i
    end
    -- move played cards
    local played = i == 1 and uids or (b.selection or {})
    local returns = {}
    for _, uid in ipairs(r.returns) do returns[uid] = true end
    for _, uid in ipairs(played) do
      local c, idx = findInHand(sd, uid)
      if c then
        if returns[uid] then sd.nineUsed[uid] = true
        else
          table.remove(sd.hand, idx)
          sd.discard[#sd.discard + 1] = c
        end
        sd.scored[uid] = true
      end
    end
    sd.extraDraw = sd.extraDraw + r.extraDraw
  end
  -- traits that fired this exchange become known to the player
  rec.revealed = {}
  local function rev(id)
    if id and not util.contains(s.revealed, id) then
      table.insert(s.revealed, id)
      rec.revealed[#rec.revealed + 1] = id
    end
  end
  for _, st in ipairs(r2.steps) do
    if type(st.ref) == "string" and st.ref:sub(1, 6) == "trait:" then rev(st.ref:sub(7)) end
  end
  for _, st in ipairs(r1.steps) do
    if st.ref == "trait:dread" and b.mods.dread then rev("dread_" .. b.mods.dread) end
    if st.ref == "trait:superstitious" or st.ref == "trait:hydrophobic" then rev(st.ref:sub(7)) end
  end
  if rec.winner == 1 and b.mods.glassJaw then rev("glassjaw") end
  if rec.secondWind == 2 then rev("secondwind") end
  s.last = rec
  s.history[#s.history + 1] = { winner = rec.winner, totals = { r1.total, r2.total }, damage = rec.damage }
  if a.pride <= 0 or b.pride <= 0 or s.exchange >= M.MAX_EXCHANGES then
    s.over = true
    if a.pride <= 0 and b.pride <= 0 then s.result = rec.winner == 2 and "loss" or "win"
    elseif b.pride <= 0 then s.result = "win"
    elseif a.pride <= 0 then s.result = "loss"
    else s.result = a.pride >= b.pride and "win" or "loss" end
    return rec
  end
  s.exchange = s.exchange + 1
  for i = 1, 2 do
    local sd = s.sides[i]
    sd.redrawsLeft = M.REDRAWS + sd.mods.redraws
    rec["drawn" .. i] = refill(s, sd)
  end
  M.aiPrepare(s, 2, s.aiStyle)
  return rec
end

return M
