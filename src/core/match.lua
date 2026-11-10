-- A festival match is fought over three cushions on the Arena table.
-- Each bout one side LEADS: it places up to 3 cards face-down on its cushions. The other side
-- ANSWERS, seeing only the card backs (a back shows the cat's coat; Shadow cats and tricks share
-- a dark back). Both reveal, and the two cards on each cushion duel: the higher Paws wins and
-- swats goblets off the loser's side of the table. Knock off all of the rival's goblets to win.
local cards = require("src.core.cards")
local rng = require("src.core.rng")
local traits = require("src.core.traits")
local util = require("src.core.util")

local M = {}

M.CUSHIONS = 3
M.HAND = 5
M.GOBLETS = 7
M.MAX_BOUTS = 12
M.COAT_EDGE = 3
-- Stolen Lives: losing a duel costs a life; losing it by this many Paws or more costs two
M.CRUSH = 5
-- Hold the Cushion: a cat that wins its duel stays seated, gaining a point of Warmth (+1 Paw)
-- for every bout it holds on. At HOT Warmth every swat knocks off one more goblet.
M.WARMTH_MAX = 5
M.HOT = 3

-- Cushion upholstery, bought at the market and kept for the festival (the Hands bring their own).
M.CUSHION_KINDS = {
  velvet = { name = "Velvet", desc = "The cat on it gets +1 Paw." },
  thistle = { name = "Thistle", desc = "The rival cat facing it loses 1 Paw." },
  silk = { name = "Silk", desc = "You win ties on this cushion." },
}
M.CUSHION_ORDER = { "velvet", "thistle", "silk" }
M.CUSHION_NAMES = { "Left", "Middle", "Right" }

local N = M.CUSHIONS
local function other(i) return 3 - i end
M.other = other

local function newSide(setup)
  local deck, counts = {}, {}
  local mods = setup.mods or traits.baseMods()
  for i, c in ipairs(setup.deck) do
    local d = c.def or cards.getDef(c)
    deck[i] = { uid = c.uid, id = c.id, level = c.level, xp = c.xp, def = c.def, captive = c.captive, owner = c.owner }
    -- Stolen Lives: every cat starts the match with its full lives (a captive is down to 1)
    deck[i].lives = c.captive and 1 or (cards.maxLives(d) + (mods.extraLives or 0))
    counts[c.id] = (counts[c.id] or 0) + 1
  end
  local omen = setup.omen or {}
  local g = math.max(1, M.GOBLETS + mods.goblets + (omen.goblets or 0))
  local cushions = {}
  for i = 1, M.CUSHIONS do cushions[i] = setup.cushions and setup.cushions[i] or false end
  return {
    name = setup.name, deck = deck, discard = {}, hand = {}, mods = mods, goblets = g, maxGoblets = g,
    cushions = cushions, omenHand = omen.hand or 0, lost = {}, taken = {}, seated = { false, false, false },
    nineUsed = {}, counts = counts, vengeance = false, secondWindUsed = false, boutsWon = 0, duelsWon = 0,
    scored = {}, placed = { false, false, false }, shown = {}, livesLost = 0, hotSeats = 0,
  }
end

local function handSize(sd) return util.clamp(M.HAND + sd.mods.handSize + (sd.omenHand or 0), 3, 8) end
M.handSize = handSize

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
  local drawn = {}
  while #sd.hand < handSize(sd) do
    local c = drawOne(s, sd)
    if not c then break end
    drawn[#drawn + 1] = c
  end
  return drawn
end

local function findInHand(sd, uid)
  for i, c in ipairs(sd.hand) do if c.uid == uid then return c, i end end
end

local function defOf(c) return c.def or cards.getDef(c) end

-- What the other side sees of a face-down card: its coat, or "dark" for Shadow cats and tricks.
function M.backOf(inst)
  local d = defOf(inst)
  if d.kind ~= "unit" or d.coat == "shadow" or d.coat == "none" then return "dark" end
  return d.coat
end

local function beats(a, b) return a and b and cards.COATS[a] and cards.COATS[a].beats == b end
M.beats = beats

-- The coat edge this match (an omen can sharpen it), and who wins plain ties.
function M.edge(s) return M.COAT_EDGE + (s.omen and s.omen.edge or 0) end
function M.tiesTo(s, lead)
  lead = lead or s.lead
  if s.omen and s.omen.tiesToAnswer then return other(lead) end
  return lead
end

-- The coat that beats `c` (for the Cardboard Box).
local function counterOf(c)
  for k, v in pairs(cards.COATS) do if v.beats == c then return k end end
end

-- ---------------------------------------------------------------- resolution

local BLOCKERS = { sunbeam = true, hairball = true }

-- Work out a bout without changing the state. P = { {c,c,c}, {c,c,c} } (cards or false).
-- soft: duels involving a phantom (a guessed card) return expected swats instead of a verdict.
local function compute(s, P, lead, soft)
  local rec = { lead = lead, cards = P, info = { {}, {} }, duels = {}, deal = { 0, 0 }, restore = { 0, 0 }, fired = {} }
  local function fire(si, src)
    if si == 2 and type(src) == "string" and src:sub(1, 6) == "trait:" then rec.fired[src:sub(7)] = true end
  end
  for si = 1, 2 do
    for i = 1, N do
      local c = P[si][i]
      local inf = { mods = {}, paws = 0, kind = "empty", status = "empty" }
      if c then
        local d = defOf(c)
        inf.def, inf.inst = d, c
        if d.kind == "unit" then
          inf.kind, inf.coat, inf.status = "cat", d.coat, "fight"
          inf.paws = cards.paws(c)
        elseif d.ability == "box" then
          inf.kind, inf.status, inf.paws = "box", "fight", 4
        else
          inf.kind, inf.status = "trick", "trick"
        end
        inf.base = inf.paws
      end
      rec.info[si][i] = inf
    end
  end
  local function add(si, i, amount, text, src)
    local inf = rec.info[si][i]
    if amount == 0 or (inf.kind ~= "cat" and inf.kind ~= "box") then return end
    inf.paws = inf.paws + amount
    inf.mods[#inf.mods + 1] = { amount = amount, text = text, src = src }
    fire(si, src)
  end
  local function note(si, i, text, src)
    local inf = rec.info[si][i]
    inf.notes = inf.notes or {}
    inf.notes[#inf.notes + 1] = { text = text, src = src }
    fire(si, src)
  end
  local function isFighter(inf) return inf.kind == "cat" or inf.kind == "box" end

  -- the Cardboard Box takes whichever coat beats the cat facing it
  for si = 1, 2 do
    for i = 1, N do
      local inf, opp = rec.info[si][i], rec.info[other(si)][i]
      if inf.kind == "box" then inf.coat = opp.kind == "cat" and counterOf(opp.coat) or nil end
    end
  end

  -- own side: charms, traits, abilities and tricks that help your own cats
  for si = 1, 2 do
    local sd, foe = s.sides[si], s.sides[other(si)]
    local m = sd.mods
    local I = rec.info[si]
    for i = 1, N do
      local inf = I[i]
      if inf.kind == "cat" then
        local d = inf.def
        if (m.coatPaws[d.coat] or 0) > 0 then add(si, i, m.coatPaws[d.coat], "Banner", "charm:banner") end
        if m.physPaws > 0 and d.type == "physical" then add(si, i, m.physPaws, "Warlord", "trait:warlord") end
        if m.magicPaws > 0 and d.type == "magic" then add(si, i, m.magicPaws, "Archmage", "trait:archmage") end
        if m.grudge > 0 then add(si, i, m.grudge, "Grudge", "trait:grudge") end
        if sd.vengeance then add(si, i, 2, "Vengeance", "trait:vengeful") end
        if foe.mods.dread and foe.mods.dread == d.coat then
          add(si, i, 2, "Feared", "dread")
          if si == 1 then rec.fired["dread_" .. d.coat] = true end
        end
        if m.legendPaws > 0 and d.rarity == "legendary" then add(si, i, m.legendPaws, "Crown", "charm:crown") end
        if m.cream > 0 and i == 2 then add(si, i, m.cream, "Cream", "charm:cream") end
        if m.drum and lead == si then add(si, i, 1, "Drum", "charm:drum") end
        if m.catnip and lead ~= si then add(si, i, 1, "Catnip", "charm:catnip") end
        if m.tally and sd.boutsWon > 0 then add(si, i, math.min(3, sd.boutsWon), "Tally", "charm:tally") end
        if m.lazy and s.bout == 1 then add(si, i, -2, "Lazy", "trait:lazy") end
        if s.omen and s.omen.coat == d.coat then add(si, i, s.omen.bonus or 1, s.omen.short, "omen") end
        if sd.cushions[i] == "velvet" then add(si, i, 1, "Velvet", "cushion:velvet") end
        if (inf.inst.warmth or 0) > 0 then add(si, i, inf.inst.warmth, "Warmth", "warmth") end
      end
    end
    -- Bonds: named pairs sitting side by side
    for i = 1, N - 1 do
      local a, b = I[i], I[i + 1]
      if a.kind == "cat" and b.kind == "cat" and cards.bonded(a.def.id, b.def.id) then
        add(si, i, cards.BOND_PAWS, "Bond", "bond")
        add(si, i + 1, cards.BOND_PAWS, "Bond", "bond")
        rec.bonds = rec.bonds or {}
        rec.bonds[#rec.bonds + 1] = { side = si, a = i, b = i + 1 }
      end
    end
    if m.seal then
      local seen, n = {}, 0
      for i = 1, N do
        local inf = I[i]
        if inf.kind == "cat" and inf.coat and not seen[inf.coat] then seen[inf.coat] = true; n = n + 1 end
      end
      if n >= 3 then for i = 1, N do add(si, i, 2, "Round Seal", "charm:seal") end end
    end
    for i = 1, N do
      local inf = I[i]
      local ab = inf.def and inf.def.ability
      if inf.kind == "cat" then
        if ab == "inspire" then
          for j = 1, N do if j ~= i and I[j].kind == "cat" and I[j].def.type == "magic" then add(si, j, 2, "Orb", inf.inst.uid) end end
        elseif ab == "purr" then
          for j = i - 1, i + 1, 2 do if I[j] then add(si, j, 2, "Purr", inf.inst.uid) end end
        elseif ab == "litter" then
          local n = 0
          for j = 1, N do if j ~= i and I[j].kind == "cat" and I[j].coat == inf.coat then n = n + 1 end end
          add(si, i, 2 * n, "Litter", inf.inst.uid)
        elseif ab == "muster" then
          add(si, i, sd.counts[inf.def.id] or 1, "Rally", inf.inst.uid)
        end
      elseif inf.kind == "trick" and ab == "warhorn" then
        for j = 1, N do if j ~= i then add(si, j, 3, "Yowl!", inf.inst.uid) end end
      end
    end
  end

  -- across the table: coat edge, hexes, yowls, weather, naps
  for si = 1, 2 do
    local sd, foe = s.sides[si], s.sides[other(si)]
    local m, fm = sd.mods, foe.mods
    local o = other(si)
    local weather = fm.weatherImmune and 0 or (fm.weatherDouble and 2 or 1)
    local immuneSrc = o == 2 and "trait:rainsoaked" or "charm:cloak"
    local doubleSrc = (o == 2 and fm.weatherDouble) and "trait:hydrophobic" or nil
    for i = 1, N do
      local inf, opp = rec.info[si][i], rec.info[o][i]
      local ab = inf.def and inf.def.ability
      if sd.cushions[i] == "thistle" and isFighter(opp) then add(o, i, -1, "Thistle", "cushion:thistle") end
      if isFighter(inf) and isFighter(opp) and beats(inf.coat, opp.coat) then
        add(si, i, M.edge(s), "Coat edge", "coat")
        if ab == "pounce" then add(si, i, 3 + m.pounceBonus, "Pounce!", inf.inst.uid) end
      end
      if inf.kind == "cat" and ab == "hex" and isFighter(opp) then
        if fm.hexImmune then note(o, i, "Thick fur", "trait:thickfur")
        else
          local amt = (2 + m.hexBonus) * (fm.hexVuln and 2 or 1)
          add(o, i, -amt, "Hexed", fm.hexVuln and o == 2 and "trait:superstitious" or inf.inst.uid)
        end
      elseif inf.kind == "cat" and ab == "yowl" then
        for j = 1, N do add(o, j, -1, "Yowled", inf.inst.uid) end
      elseif inf.kind == "trick" and ab == "downpour" then
        for j = 1, N do
          if isFighter(rec.info[o][j]) then
            if weather == 0 then note(o, j, "Stays dry", immuneSrc) else add(o, j, -2 * weather, "Soaked", doubleSrc or inf.inst.uid) end
          end
        end
      elseif inf.kind == "trick" and BLOCKERS[ab] then
        if isFighter(opp) then opp.status = "nap"; opp.napBy = ab end
        if ab == "hairball" then
          for j = i - 1, i + 1, 2 do if rec.info[o][j] then add(o, j, -2, "Hrrk!", inf.inst.uid) end end
        end
      end
    end
    if m.yarn > 0 then add(o, 1, -m.yarn, "Yarn!", "charm:yarn") end
  end
  -- Moonfog last: the rival's strongest fighters lose their way
  for si = 1, 2 do
    local o = other(si)
    local fm = s.sides[o].mods
    for i = 1, N do
      local inf = rec.info[si][i]
      if inf.kind == "trick" and inf.def.ability == "moonfog" then
        if fm.weatherImmune then
          for j = 1, N do if rec.info[o][j].status == "fight" then note(o, j, "Sees through fog", o == 2 and "trait:rainsoaked" or "charm:cloak") end end
        else
          for _ = 1, (fm.weatherDouble and 2 or 1) do
            local best
            for j = 1, N do
              local x = rec.info[o][j]
              if x.status == "fight" and (not best or x.paws > rec.info[o][best].paws) then best = j end
            end
            if best then
              rec.info[o][best].status = "fog"
              if fm.weatherDouble and o == 2 then fire(2, "trait:hydrophobic") end
            end
          end
        end
      end
    end
  end

  -- the duels, left to right
  for i = 1, N do
    local a, b = rec.info[1][i], rec.info[2][i]
    local fa, fb = a.status == "fight", b.status == "fight"
    local d = { winner = 0, swats = 0, reason = "empty", p = 0 }
    local function swatsFor(si, inf, unopposed)
      local n = 1
      local ab = inf.def and inf.def.ability
      if ab == "smite" then n = 2 end
      if unopposed and ab == "stray" then n = 2 end
      if inf.inst and (inf.inst.warmth or 0) >= M.HOT then n = n + 1 end -- the Hot Seat
      return n
    end
    local pa, pb = math.max(0, a.paws), math.max(0, b.paws)
    if fa and fb then
      d.reason = "duel"
      d.margin = math.abs(pa - pb)
      local function tieWinner()
        local la, lb = s.sides[1].mods.lucky, s.sides[2].mods.lucky
        if la ~= lb then return la and 1 or 2 end
        local ka, kb = s.sides[1].cushions[i] == "silk", s.sides[2].cushions[i] == "silk"
        if ka ~= kb then d.silk = true; return ka and 1 or 2 end
        local sa = a.kind == "cat" and a.def.ability == "none"
        local sb = b.kind == "cat" and b.def.ability == "none"
        if sa ~= sb then return sa and 1 or 2 end
        return M.tiesTo(s, lead)
      end
      local w
      if pa > pb then w = 1 elseif pb > pa then w = 2 else w = tieWinner(); d.tie = true end
      local phantom = soft and ((a.inst and a.inst.phantom) or (b.inst and b.inst.phantom))
      if phantom then
        -- expected outcome against a guess
        local diff = pa - pb + (w == 1 and 0.5 or -0.5) * (d.tie and 1 or 0)
        local p = 1 / (1 + math.exp(-diff / 2.2))
        d.p = p
        -- the chance each side is crushed (loses by M.CRUSH or more)
        d.pCrush = { 1 / (1 + math.exp(-(-diff - (M.CRUSH - 0.5)) / 2.2)), 1 / (1 + math.exp(-(diff - (M.CRUSH - 0.5)) / 2.2)) }
        local sw1, sw2 = swatsFor(1, a, false), swatsFor(2, b, false)
        rec.deal[1] = rec.deal[1] + p * sw1
        rec.deal[2] = rec.deal[2] + (1 - p) * sw2
        d.winner, d.swats = w, w == 1 and sw1 or sw2
      else
        d.winner = w
        local winner, loser = w == 1 and a or b, w == 1 and b or a
        d.swats = swatsFor(w, winner, false)
        if s.sides[other(w)].mods.glassJaw and d.margin >= 5 then
          d.swats = d.swats + 1
          d.crush = true
          if other(w) == 2 then rec.fired.glassjaw = true end
        end
        rec.deal[w] = rec.deal[w] + d.swats
      end
    elseif fa or fb then
      local w = fa and 1 or 2
      local inf = fa and a or b
      d.reason = "unopposed"
      d.winner = w
      d.swats = swatsFor(w, inf, true)
      rec.deal[w] = rec.deal[w] + d.swats
      d.p = w == 1 and 1 or 0
    else
      if a.status == "nap" or b.status == "nap" or a.status == "fog" or b.status == "fog" then d.reason = "nap" end
    end
    if d.winner > 0 then
      local winf = d.winner == 1 and a or b
      if winf.kind == "cat" and winf.def.ability == "groom" then
        local share = (soft and d.reason == "duel") and (d.winner == 1 and d.p or 1 - d.p) or 1
        rec.restore[d.winner] = rec.restore[d.winner] + share
        d.groom = true
      end
    end
    rec.duels[i] = d
  end
  return rec
end
M.compute = compute

-- ---------------------------------------------------------------- applying a bout

local function apply(s, rec)
  local before = { s.sides[1].goblets, s.sides[2].goblets }
  rec.gobletsBefore = before
  rec.lost, rec.healed = { 0, 0 }, { 0, 0 }
  for si = 1, 2 do
    local sd = s.sides[si]
    local lost = math.min(sd.goblets, rec.deal[other(si)])
    sd.goblets = sd.goblets - lost
    rec.lost[si] = lost
  end
  for si = 1, 2 do
    local sd = s.sides[si]
    if rec.restore[si] > 0 and sd.goblets > 0 then
      local h = math.min(rec.restore[si], sd.maxGoblets - sd.goblets)
      sd.goblets = sd.goblets + h
      rec.healed[si] = h
    end
    if sd.mods.secondWind and not sd.secondWindUsed and sd.goblets == 1 then
      sd.secondWindUsed = true
      sd.goblets = math.min(sd.maxGoblets, sd.goblets + 2)
      rec.secondWind = si
      if si == 2 then rec.fired.secondwind = true end
    end
  end
  local w = 0
  if rec.deal[1] > rec.deal[2] then w = 1 elseif rec.deal[2] > rec.deal[1] then w = 2 end
  rec.winner = w
  if w > 0 then s.sides[w].boutsWon = s.sides[w].boutsWon + 1 end
  for si = 1, 2 do
    local sd = s.sides[si]
    sd.vengeance = sd.mods.vengeful and rec.deal[other(si)] > rec.deal[si]
  end
  -- Stolen Lives: a cat that loses a duel loses a life; out of lives, the winner captures it.
  -- A captive (one of your cats fighting for a Hand) is at 1 life: beat it and it comes home.
  rec.wounds = {}
  local captured = {}
  for i = 1, N do
    local d = rec.duels[i]
    if d.reason == "duel" and d.winner > 0 then
      local l = other(d.winner)
      local inf = rec.info[l][i]
      if inf.kind == "cat" and inf.def.ability ~= "ninelives" then
        local c = inf.inst
        local cost = (d.margin or 0) >= M.CRUSH and 2 or 1
        c.lives = (c.lives or cards.maxLives(inf.def)) - cost
        s.sides[l].livesLost = (s.sides[l].livesLost or 0) + cost
        local w = { side = l, uid = c.uid, slot = i, left = math.max(0, c.lives), cost = cost, crushed = cost == 2 }
        if c.lives <= 0 then
          w.captured = true
          w.rescued = c.captive and l == 2 or nil
          captured[c.uid] = true
          s.sides[l].lost[#s.sides[l].lost + 1] = c
          s.sides[d.winner].taken[#s.sides[d.winner].taken + 1] = c
        end
        d.wound = w
        rec.wounds[#rec.wounds + 1] = w
      end
    end
  end
  -- duel winners earn experience; cards leave the cushions
  rec.returns = {}
  for i = 1, N do
    local d = rec.duels[i]
    if d.winner > 0 then
      local inf = rec.info[d.winner][i]
      if inf.kind == "cat" then
        s.sides[d.winner].scored[inf.inst.uid] = true
        s.sides[d.winner].duelsWon = s.sides[d.winner].duelsWon + 1
      end
    end
  end
  -- Hold the Cushion: winning cats stay seated and warm up; everyone else leaves the table
  rec.stays = { {}, {} }
  for si = 1, 2 do
    local sd = s.sides[si]
    for i = 1, N do
      local c = rec.cards[si][i]
      local inf = rec.info[si][i]
      if c and rec.duels[i].winner == si and inf.kind == "cat" and not captured[c.uid] then
        local was = c.warmth or 0
        c.warmth = math.min(M.WARMTH_MAX, was + 1)
        c.held = (c.held or 0) + 1
        if was < M.HOT and c.warmth >= M.HOT then sd.hotSeats = (sd.hotSeats or 0) + 1 end
        sd.seated[i] = c
        rec.stays[si][i] = c.warmth
      else
        if c then c.warmth, c.held = nil, nil end
        sd.seated[i] = false
      end
    end
  end
  for si = 1, 2 do
    local sd = s.sides[si]
    for i = 1, N do
      local c = rec.cards[si][i]
      if c and rec.stays[si][i] then
        local _, idx = findInHand(sd, c.uid)
        if idx then table.remove(sd.hand, idx) end
      elseif c then
        local _, idx = findInHand(sd, c.uid)
        if idx then table.remove(sd.hand, idx) end
        if captured[c.uid] then
          -- carried off the table: it doesn't go back to the discard pile
        elseif defOf(c).ability == "ninelives" and not sd.nineUsed[c.uid] then
          sd.nineUsed[c.uid] = true
          sd.hand[#sd.hand + 1] = c
          rec.returns[#rec.returns + 1] = c.uid
        else
          sd.discard[#sd.discard + 1] = c
        end
      end
    end
  end
  -- traits that fired become known to the player
  rec.revealed = {}
  for id in pairs(rec.fired) do
    if traits.TRAITS[id] and not util.contains(s.revealed, id) then
      table.insert(s.revealed, id)
      rec.revealed[#rec.revealed + 1] = id
    end
  end
  table.sort(rec.revealed)
end

-- ---------------------------------------------------------------- AI

M.STYLES = {
  brute = { noise = 0.35, conserve = 0.0, caution = 0.8 },
  schemer = { noise = 0.08, conserve = 0.05, caution = 1.0 },
  zealot = { noise = 0.25, conserve = 0.02, caution = 0.9 },
  coward = { noise = 0.5, conserve = 0.06, caution = 1.3 },
  trickster = { noise = 0.45, conserve = 0.03, caution = 1.0 },
  default = { noise = 0.3, conserve = 0.03, caution = 1.0 },
}

local phantomN = 0
local function phantom(coat, paws)
  phantomN = phantomN + 1
  return {
    uid = "ph" .. phantomN, id = "phantom", level = 1, phantom = true,
    def = { kind = "unit", type = "physical", power = math.floor(paws + 0.5), ability = "phantom", rarity = "common", coat = coat, name = "?" },
  }
end

-- Average Paws of a side's cats, per back colour, as the other side would guess it.
local function estimates(sd)
  local sum, n = {}, {}
  local all, alln = 0, 0
  local function add(c)
    local d = defOf(c)
    if d.kind ~= "unit" then return end
    local back = M.backOf(c)
    local p = cards.paws(c)
    sum[back] = (sum[back] or 0) + p
    n[back] = (n[back] or 0) + 1
    all, alln = all + p, alln + 1
  end
  for _, list in ipairs({ sd.deck, sd.hand, sd.discard }) do for _, c in ipairs(list) do add(c) end end
  local avg = alln > 0 and all / alln or 4
  local out = { all = avg }
  for _, b in ipairs({ "ember", "tide", "gilt", "dark" }) do out[b] = n[b] and sum[b] / n[b] or avg end
  return out
end

-- Every way to put up to 3 hand cards on the cushions, filling as many cushions as the hand allows.
-- Every way to put hand cards on the free cushions (those keep[] doesn't hold), filling as many
-- free cushions as the hand allows.
local function placements(hand, keep)
  keep = keep or { false, false, false }
  local free = 0
  for i = 1, N do if not keep[i] then free = free + 1 end end
  local out = {}
  local k = math.min(free, #hand)
  local cur = { keep[1], keep[2], keep[3] }
  local used = {}
  local function rec(slot, placed, freeLeft)
    if slot > N then
      if placed == k then out[#out + 1] = { cur[1], cur[2], cur[3] } end
      return
    end
    if keep[slot] then return rec(slot + 1, placed, freeLeft) end
    if placed + freeLeft - 1 >= k then
      cur[slot] = false
      rec(slot + 1, placed, freeLeft - 1)
    end
    for i, c in ipairs(hand) do
      if not used[i] and placed < k then
        used[i] = true
        cur[slot] = c
        rec(slot + 1, placed + 1, freeLeft - 1)
        used[i] = false
      end
    end
    cur[slot] = false
  end
  rec(1, 0, free)
  return out
end

-- What side `si` can see of the other side's cushions, as cards or phantoms. Seated cats are
-- face-up, so they're always known.
local function visibleFoe(s, si, foePlaced)
  local o = other(si)
  local fs = s.sides[o]
  local est = estimates(fs)
  local view = {}
  -- the Overseer's eye: it sees through card backs
  local sees = s.sides[si].mods.allSeeing
  for i = 1, N do
    local c = foePlaced and foePlaced[i]
    if fs.seated[i] then view[i] = fs.seated[i]
    elseif not foePlaced then view[i] = phantom(nil, est.all)
    elseif not c then view[i] = false
    elseif fs.shown[i] or sees then view[i] = c
    else
      local back = M.backOf(c)
      view[i] = phantom(back == "dark" and "shadow" or back, est[back])
    end
  end
  return view
end

M.visibleFoeForTest = visibleFoe

-- A cold copy of a seated cat (as it would be back in hand: no Warmth).
local function cold(c)
  return { uid = c.uid, id = c.id, level = c.level, xp = c.xp, def = c.def, lives = c.lives, captive = c.captive, owner = c.owner }
end

-- The best placement for side si, deciding too which seated cats to pull back to hand.
-- Returns the placement (real card objects) and the list of cushions to retreat.
local function choose(s, si, foeView, style, leading)
  style = style or M.STYLES.default
  local sd = s.sides[si]
  local seatIdx = {}
  for i = 1, N do if sd.seated[i] then seatIdx[#seatIdx + 1] = i end end
  local best, bestV, bestRetreat
  for mask = 0, 2 ^ #seatIdx - 1 do
    local keep = { false, false, false }
    local pool, retreat, real = {}, {}, {}
    for _, c in ipairs(sd.hand) do pool[#pool + 1] = c end
    for b, i in ipairs(seatIdx) do
      if math.floor(mask / 2 ^ (b - 1)) % 2 == 1 then
        local cc = cold(sd.seated[i])
        real[cc] = sd.seated[i]
        pool[#pool + 1] = cc
        retreat[#retreat + 1] = i
      else
        keep[i] = sd.seated[i]
      end
    end
    for _, pl in ipairs(placements(pool, keep)) do
      local P = si == 1 and { pl, foeView } or { foeView, pl }
      local r = compute(s, P, s.lead, true)
      local v = r.deal[si] - r.deal[other(si)] * style.caution + r.restore[si] * 0.8
      for i = 1, N do
        local c = pl[i]
        if c then
          local d = defOf(c)
          local du = r.duels[i]
          -- a cat that could run out of lives risks capture: weigh that chance
          local lives = c.lives or cards.maxLives(d)
          if d.kind == "unit" and lives <= 2 and d.ability ~= "ninelives" and du.reason == "duel" then
            local capP
            if du.pCrush then
              local loseP = si == 1 and (1 - du.p) or du.p
              capP = lives <= 1 and loseP or du.pCrush[si]
            else
              local lost = du.winner ~= si
              capP = (lost and (lives <= 1 or (du.margin or 0) >= M.CRUSH)) and 1 or 0
            end
            v = v - (style.guard or 1.2) * capP
          end
          if d.kind == "unit" then
            if not keep[i] then v = v - style.conserve * cards.paws(c) end
            if leading and not keep[i] and M.backOf(c) ~= "dark" then v = v - 0.15 end
            if d.ability == "ninelives" then v = v + 0.2 end
            -- a warm seat is worth keeping: it only gets hotter
            if keep[i] then v = v + 0.12 * (c.warmth or 0) end
          end
        end
      end
      v = v + (rng.next(s.rng) - 0.5) * style.noise
      if not bestV or v > bestV then
        local resolved = {}
        for i = 1, N do resolved[i] = pl[i] and (real[pl[i]] or pl[i]) or false end
        best, bestV, bestRetreat = resolved, v, retreat
      end
    end
  end
  return best or { sd.seated[1], sd.seated[2], sd.seated[3] }, bestRetreat or {}
end

-- Pull a seated cat back to its side's hand. It loses its Warmth.
function M.retreat(s, si, i)
  local sd = s.sides[si]
  local c = sd.seated[i]
  if not c then return false end
  c.warmth, c.held = nil, nil
  sd.seated[i] = false
  if sd.placed[i] == c then sd.placed[i] = false end
  sd.hand[#sd.hand + 1] = c
  return true
end

-- Place side si's cards (AI). Leading: nothing is known about the other side's new cards yet.
function M.aiPlace(s, si, style)
  local leading = s.lead == si
  local view = visibleFoe(s, si, (not leading) and s.sides[other(si)].placed or nil)
  local pl, retreat = choose(s, si, view, style, leading)
  for _, i in ipairs(retreat) do M.retreat(s, si, i) end
  s.sides[si].placed = { pl[1], pl[2], pl[3] }
  return pl
end

-- A suggested move for the player (the autotest and the balance simulation): the slots to
-- commit (uids, or false) and the seated cushions to pull back first.
function M.suggest(s, si, noise)
  local leading = s.lead == si
  local view = visibleFoe(s, si, (not leading) and s.sides[other(si)].placed or nil)
  local style = { noise = noise or 0, conserve = 0.03, caution = 1.0 }
  local pl, retreat = choose(s, si, view, style, leading)
  return util.map({ 1, 2, 3 }, function(i) return pl[i] and pl[i].uid or false end), retreat
end

-- Play the player's suggested move: pull back, then commit. Returns the bout record.
function M.autoplay(s, noise)
  local slots, retreat = M.suggest(s, 1, noise)
  for _, i in ipairs(retreat) do M.retreat(s, 1, i) end
  return M.commit(s, slots)
end

-- ---------------------------------------------------------------- bouts

local function startBout(s)
  for si = 1, 2 do
    local sd = s.sides[si]
    sd.placed = { sd.seated[1], sd.seated[2], sd.seated[3] }
    sd.shown = {}
  end
  if s.lead == 2 then
    local b = s.sides[2]
    M.aiPlace(s, 2, s.aiStyle)
    -- an Arrogant rival shows off its best card; a Spyglass peeks at one
    local filled = {}
    for i = 1, N do if b.placed[i] then filled[#filled + 1] = i end end
    if b.mods.showsCard and #filled > 0 then
      local top
      for _, i in ipairs(filled) do
        if not top or cards.paws(b.placed[i]) > cards.paws(b.placed[top]) then top = i end
      end
      b.shown[top] = "arrogant"
    end
    if s.sides[1].mods.peek and #filled > 0 then
      local hidden = util.filter(filled, function(i) return not b.shown[i] end)
      if #hidden > 0 then b.shown[rng.pick(s.rng, hidden)] = "spyglass" end
    end
  end
end

-- omen (optional): the festival's rule twist, from festival.OMENS.
function M.create(a, b, seed, aiStyle, omen)
  a.omen, b.omen = omen, omen
  local s = {
    sides = { newSide(a), newSide(b) }, rng = rng.new(seed), bout = 1, lead = 2, over = false, result = nil,
    history = {}, last = nil, aiStyle = aiStyle, revealed = {}, omen = omen,
  }
  for i = 1, 2 do
    rng.shuffle(s.rng, s.sides[i].deck)
    refill(s, s.sides[i])
  end
  startBout(s)
  return s
end

-- Preview the player's numbers for a tentative placement. The rival's face-down cards count as
-- guesses of their back's coat, so the coat edge shows up before the reveal.
function M.preview(s, slots)
  local P1 = {}
  local seated = s.sides[1].seated
  for i = 1, N do P1[i] = seated[i] or (slots[i] and findInHand(s.sides[1], slots[i])) or false end
  local P2 = s.lead == 2 and visibleFoe(s, 1, s.sides[2].placed) or { false, false, false }
  return compute(s, { P1, P2 }, s.lead, true)
end

-- The player commits their cushions (uids or false). Resolves the bout and returns its record.
function M.commit(s, slots)
  if s.over then return nil end
  local a, b = s.sides[1], s.sides[2]
  local P1, seen = {}, {}
  for i = 1, N do
    if a.seated[i] then
      P1[i] = a.seated[i] -- a seated cat holds its cushion (pull it back first to replace it)
    else
      local uid = slots[i]
      local c = uid and findInHand(a, uid)
      if uid and (not c or seen[uid]) then return nil end
      if uid then seen[uid] = true end
      P1[i] = c or false
    end
  end
  a.placed = P1
  if s.lead == 1 then M.aiPlace(s, 2, s.aiStyle) end
  local P2 = { b.placed[1], b.placed[2], b.placed[3] }
  local rec = compute(s, { P1, P2 }, s.lead, false)
  rec.bout = s.bout
  rec.shown = b.shown
  apply(s, rec)
  s.last = rec
  s.history[#s.history + 1] = { winner = rec.winner, deal = { rec.deal[1], rec.deal[2] }, lead = s.lead }
  if a.goblets <= 0 or b.goblets <= 0 or s.bout >= M.MAX_BOUTS then
    s.over = true
    if a.goblets <= 0 and b.goblets <= 0 then
      if rec.deal[1] ~= rec.deal[2] then s.result = rec.deal[1] > rec.deal[2] and "win" or "loss"
      else s.result = s.lead == 1 and "win" or "loss" end
    elseif b.goblets <= 0 then s.result = "win"
    elseif a.goblets <= 0 then s.result = "loss"
    else s.result = a.goblets >= b.goblets and "win" or "loss" end
    return rec
  end
  s.bout = s.bout + 1
  s.lead = other(s.lead)
  for i = 1, 2 do rec["drawn" .. i] = refill(s, s.sides[i]) end
  startBout(s)
  return rec
end

return M
