-- Run with: luajit tests/run.lua   (from the repo root)
package.path = "./?.lua;" .. package.path
local cards = require("src.core.cards")
local festival = require("src.core.festival")
local game = require("src.core.game")
local match = require("src.core.match")
local traits = require("src.core.traits")
local util = require("src.core.util")

local passed, failed = 0, 0
local function test(name, f)
  local ok, err = pcall(f)
  if ok then passed = passed + 1 else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end end

local n = 0
local function inst(id, level) n = n + 1; return { uid = "x" .. n, id = id, level = level or 1, xp = 0 } end
local function deckOf(ids)
  local d = {}
  for _, id in ipairs(ids) do d[#d + 1] = inst(id) end
  return d
end
local FILLER = { "agravain", "agravain", "agravain", "agravain", "agravain", "agravain", "agravain", "agravain" }

-- A bare match state with chosen hands, for checking the duel rules directly.
local function duelState(handA, handB, modsA, modsB)
  local s = match.create({ name = "A", deck = deckOf(FILLER), mods = modsA }, { name = "B", deck = deckOf(FILLER), mods = modsB }, 1)
  s.sides[1].hand, s.sides[2].hand = deckOf(handA), deckOf(handB)
  return s
end
local function bout(s, a, b, lead)
  local P = { {}, {} }
  for i = 1, 3 do
    P[1][i] = s.sides[1].hand[a[i]] or false
    P[2][i] = s.sides[2].hand[b[i]] or false
  end
  return match.compute(s, P, lead or 2, false)
end

test("duel: higher Paws swats a goblet", function()
  local s = duelState({ "lamoracat" }, { "kaytail" })
  local r = bout(s, { 1 }, { 1 })
  eq(r.duels[1].winner, 1); eq(r.deal[1], 1); eq(r.deal[2], 0)
end)
test("duel: coat edge is worth 3 Paws", function()
  -- Tide (Pikecat 3) beats Ember (Barn Brawler 5): 3 + 3 = 6 > 5
  local s = duelState({ "pikecat" }, { "barnbrawler" })
  local r = bout(s, { 1 }, { 1 })
  eq(r.info[1][1].paws, 6); eq(r.duels[1].winner, 1)
end)
test("duel: ties go to the leader, Steadfast wins ties", function()
  local s = duelState({ "kaytail" }, { "pikecat" }) -- 3 vs 3, but tide beats ember
  local s2 = duelState({ "gareth" }, { "barnbrawler" }) -- tide 4+3=7 vs ember 5
  local s3 = duelState({ "circaleus" }, { "merlinus" }) -- shadow 3 vs shadow 3
  eq(bout(s3, { 1 }, { 1 }, 1).duels[1].winner, 1)
  eq(bout(s3, { 1 }, { 1 }, 2).duels[1].winner, 2)
  local s4 = duelState({ "agravain" }, { "purrceval" }) -- 5 Steadfast vs 5 hex (hex makes it 3)
  eq(bout(s4, { 1 }, { 1 }, 2).duels[1].winner, 2)
  local s5 = duelState({ "agravain" }, { "morgelius" })
  local r = bout(s5, { 1 }, { 1 }, 2)
  eq(r.info[1][1].paws, 3, "hexed")
end)
test("unopposed cats swat; Stray swats 2 unopposed", function()
  local s = duelState({ "kaytail", "alleystray" }, {})
  local r = bout(s, { 1, 2 }, {})
  eq(r.duels[1].reason, "unopposed"); eq(r.deal[1], 3)
end)
test("sword hammer knocks off 2, groom restores", function()
  local s = duelState({ "artheline", "galahiss" }, { "pikecat", "pikecat" })
  local r = bout(s, { 1, 2 }, { 1, 2 })
  eq(r.deal[1], 3); eq(r.restore[1], 1)
end)
test("sunbeam puts the facing cat to sleep", function()
  local s = duelState({ "sunbeam", "kaytail" }, { "artheline", "kaytail" })
  local r = bout(s, { 1, 2 }, { 1, 2 }, 1)
  eq(r.info[2][1].status, "nap"); eq(r.duels[1].winner, 0); eq(r.deal[2], 0)
end)
test("tricks don't duel: the facing cat is unopposed", function()
  local s = duelState({ "warhorn", "kaytail", "kaytail" }, { "agravain", "agravain", "agravain" })
  local r = bout(s, { 1, 2, 3 }, { 1, 2, 3 }, 2)
  eq(r.duels[1].reason, "unopposed"); eq(r.info[1][2].paws, 3 + 3 + 2) -- yowl +3, litter +2
end)
test("purr helps neighbours, orb helps magic", function()
  local s = duelState({ "kaytail", "tristripe", "vivipurr" }, {})
  local r = bout(s, { 1, 2, 3 }, {})
  eq(r.info[1][1].paws, 3 + 2 + 2) -- purr + litter (tristripe is ember too)
  local s2 = duelState({ "merline", "hedgedruid" }, {})
  eq(bout(s2, { 1, 2 }, {}).info[1][2].paws, 3 + 2 + 2) -- orb + litter (both tide)
end)
test("thick fur blocks hexes and reveals itself", function()
  local m = traits.baseMods(); m.hexImmune = true
  local s = duelState({ "morgelius" }, { "agravain" }, nil, m)
  local r = bout(s, { 1 }, { 1 })
  eq(r.info[2][1].paws, 5); eq(r.fired.thickfur, true)
end)
test("moonfog loses the strongest rival cat", function()
  local s = duelState({ "moonfog", "kaytail" }, { "kaytail", "artheline" })
  local r = bout(s, { 1, 2 }, { 1, 2 })
  eq(r.info[2][2].status, "fog"); eq(r.duels[2].winner, 1)
end)
test("backs show coat; shadow and tricks look alike", function()
  eq(match.backOf(inst("kaytail")), "ember")
  eq(match.backOf(inst("agravain")), "dark")
  eq(match.backOf(inst("sunbeam")), "dark")
end)
test("cardboard box fights with the counter coat", function()
  local s = duelState({ "box" }, { "barnbrawler" })
  local r = bout(s, { 1 }, { 1 })
  eq(r.info[1][1].coat, "tide"); eq(r.info[1][1].paws, 7); eq(r.duels[1].winner, 1)
end)

test("match runs to a result and goblets fall", function()
  local save = game.newSave("T", 9)
  game.startRun(save)
  local ctx = game.setupMatch(save)
  local s = ctx.state
  local guard = 0
  while not s.over do
    guard = guard + 1
    if guard > 20 then error("match did not end") end
    local rec = match.commit(s, match.suggest(s, 1, 0))
    if not rec then error("commit failed") end
  end
  eq(type(s.result), "string")
  if s.sides[1].goblets > 0 and s.sides[2].goblets > 0 and s.bout < match.MAX_BOUTS then error("ended early") end
end)

test("lead alternates and the rival places when it leads", function()
  local save = game.newSave("L", 3)
  game.startRun(save)
  local s = game.setupMatch(save).state
  eq(s.lead, 2)
  local any = false
  for i = 1, 3 do if s.sides[2].placed[i] then any = true end end
  eq(any, true, "rival placed")
  match.commit(s, match.suggest(s, 1, 0))
  if not s.over then eq(s.lead, 1) end
end)

-- bonds, cushions and omens
local function setupState(handA, handB, extraA, extraB, omen)
  local a = { name = "A", deck = deckOf(FILLER) }
  local b = { name = "B", deck = deckOf(FILLER) }
  for k, v in pairs(extraA or {}) do a[k] = v end
  for k, v in pairs(extraB or {}) do b[k] = v end
  local s = match.create(a, b, 1, nil, omen)
  s.sides[1].hand, s.sides[2].hand = deckOf(handA), deckOf(handB)
  for si = 1, 2 do
    for _, c in ipairs(s.sides[si].hand) do c.lives = cards.maxLives(cards.getDef(c)) end
  end
  return s
end
local function modText(inf, text)
  for _, m in ipairs(inf.mods) do if m.text == text then return m.amount end end
end

test("bonds: side by side +2 each, apart nothing", function()
  local s = setupState({ "artheline", "merline", "agravain" }, {})
  local r = bout(s, { 1, 2 }, {})
  eq(modText(r.info[1][1], "Bond"), 2, "artheline"); eq(modText(r.info[1][2], "Bond"), 2, "merline")
  eq(#r.bonds, 1)
  local r2 = bout(s, { 1, nil, 2 }, {})
  eq(modText(r2.info[1][1], "Bond"), nil, "not adjacent")
  eq(cards.bonded("merline", "artheline"), "The Once and Future")
  for _, b in ipairs(cards.BONDS) do
    assert(cards.CARDS[b[1]] and cards.CARDS[b[2]], "bond names real cards: " .. b[1] .. "/" .. b[2])
  end
end)
test("cushions: velvet +1, thistle -1 to the facing cat, silk wins ties", function()
  local s = setupState({ "agravain", "agravain" }, { "barnbrawler", "barnbrawler" }, { cushions = { "velvet", "thistle", false } })
  local r = bout(s, { 1, 2 }, { 1, 2 })
  eq(r.info[1][1].paws, 6, "velvet"); eq(r.info[2][2].paws, 4, "thistle")
  -- 5 vs 5 Steadfast-free tie: circaleus (3) vs merlinus (3); silk on side 1 beats the leader
  local s2 = setupState({ "circaleus" }, { "merlinus" }, { cushions = { "silk", false, false } })
  local r2 = bout(s2, { 1 }, { 1 }, 2)
  eq(r2.duels[1].winner, 1, "silk"); eq(r2.duels[1].silk, true)
end)
test("omens: coat bonus, sharper edge, ties to the answerer, bigger hands, more goblets", function()
  local O = festival.OMENS
  local s = setupState({ "barnbrawler" }, { "agravain" }, nil, nil, O.midsummer)
  eq(bout(s, { 1 }, { 1 }).info[1][1].paws, 6, "midsummer")
  local s2 = setupState({ "pikecat" }, { "barnbrawler" }, nil, nil, O.frost)
  eq(bout(s2, { 1 }, { 1 }).info[1][1].paws, 7, "frost edge")
  local s3 = setupState({ "circaleus" }, { "merlinus" }, nil, nil, O.naps)
  eq(bout(s3, { 1 }, { 1 }, 2).duels[1].winner, 1, "naps: the answerer wins the tie")
  local s4 = match.create({ name = "A", deck = deckOf(FILLER) }, { name = "B", deck = deckOf(FILLER) }, 1, nil, O.feast)
  eq(#s4.sides[1].hand, 6, "feast hand")
  local s5 = match.create({ name = "A", deck = deckOf(FILLER) }, { name = "B", deck = deckOf(FILLER) }, 1, nil, O.saucer)
  eq(s5.sides[2].goblets, match.GOBLETS + 1, "saucer goblets")
  local save = game.newSave("T", 5)
  local run = game.startRun(save)
  assert(festival.omen(run.festival), "every festival has an omen")
end)
test("hands upholster cushions as they level", function()
  local c3 = game.handCushions({ level = 5, seed = 9 })
  local c5 = game.handCushions({ level = 7, seed = 9 })
  local n3, n5 = 0, 0
  for i = 1, 3 do if c3[i] then n3 = n3 + 1 end; if c5[i] then n5 = n5 + 1 end end
  eq(n3, 1); eq(n5, 2)
  eq(#game.handCushions({ level = 1, seed = 2 }), 3)
end)
test("market offers an upholstery the player doesn't have", function()
  local save = game.newSave("T", 6)
  local run = game.startRun(save)
  game.upholster(run, 2, "velvet")
  for _ = 1, 20 do
    local st = game.makeMarket(run)
    assert(st.cushion and not (st.cushion.slot == 2 and st.cushion.kind == "velvet"))
  end
end)

-- Stolen Lives
local function commitBout(s, a, b)
  -- place hand indices a (player) and b (rival) and resolve one bout through the real commit
  s.lead = 1
  local slots = {}
  for i = 1, 3 do slots[i] = a[i] and s.sides[1].hand[a[i]].uid or false end
  local P2 = {}
  for i = 1, 3 do P2[i] = b[i] and s.sides[2].hand[b[i]] or false end
  local aiPlace = match.aiPlace
  match.aiPlace = function(st, si) st.sides[si].placed = P2; return P2 end
  local rec = match.commit(s, slots)
  match.aiPlace = aiPlace
  return rec
end
test("lives: a lost duel costs a life, a crushing loss costs two, then the cat is captured", function()
  local s = setupState({ "kaytail", "kaytail" }, { "lamoracat", "agravain" })
  local k1 = s.sides[1].hand[1]
  eq(k1.lives, cards.maxLives(cards.CARDS.kaytail), "starts with full lives")
  -- Kaytail (3, ember) vs Agravain (5, shadow): loses by 2 -> 1 life
  local rec = commitBout(s, { 1 }, { 2 })
  eq(rec.wounds[1].cost, 1); eq(k1.lives, 1)
  -- the other Kaytail vs Lamoracat (7 + 3 tide edge = 10): crushed -> captured outright
  local s2 = setupState({ "kaytail" }, { "lamoracat" })
  local k2 = s2.sides[1].hand[1]
  local rec2 = commitBout(s2, { 1 }, { 1 })
  eq(rec2.wounds[1].crushed, true); eq(rec2.wounds[1].captured, true)
  eq(#s2.sides[1].lost, 1); eq(s2.sides[2].taken[1].uid, k2.uid)
  for _, c in ipairs(s2.sides[1].discard) do assert(c.uid ~= k2.uid, "a captured cat doesn't go to the discard pile") end
end)
test("lives: Nine Lives never loses one", function()
  local s = setupState({ "borscat" }, { "lamoracat" })
  local rec = commitBout(s, { 1 }, { 1 })
  eq(#rec.wounds, 0)
end)
test("stolen lives: Hands keep captives, field them at 1 life, and you rescue them", function()
  local save = game.newSave("T", 21)
  local run = game.startRun(save)
  local n = save.hands[4]
  local deckBefore = #run.deck
  local victim = run.deck[5]
  local ctx = { opp = { name = n.name, id = n.id }, nemesis = n, stage = "group", tier = 1,
    state = { result = "loss", history = {}, revealed = {}, sides = { { lost = { victim }, scored = {}, goblets = 0 }, { lost = {}, goblets = 3 } } } }
  local out = { }
  game.settleLives(save, ctx, out)
  eq(#run.deck, deckBefore - 1, "the cat leaves your pride")
  eq(#n.captives, 1); eq(n.captives[1].id, victim.id); eq(n.captives[1].captive, true)
  local deck = require("src.core.nemesis").nemesisDeck(run.rng, n, 1)
  local found
  for _, c in ipairs(deck) do if c.captive then found = c end end
  assert(found, "the captive fights for the Hand")
  local s = match.create({ name = "A", deck = deckOf(FILLER) }, { name = "B", deck = { found } }, 1)
  eq((s.sides[2].hand[1] or s.sides[2].deck[1]).lives, 1, "a captive is down to 1 life")
  -- beat it: it comes home
  local ctx2 = { opp = { name = n.name, id = n.id }, nemesis = n, stage = "group", tier = 1,
    state = { result = "loss", history = {}, revealed = {}, sides = { { lost = {}, scored = {} }, { lost = { found } } } } }
  local out2 = {}
  game.settleLives(save, ctx2, out2)
  eq(#out2.rescued, 1); eq(#n.captives, 0); eq(#run.deck, deckBefore)
end)
test("stolen lives: beating a Hand frees every captive; strays pawn theirs", function()
  local save = game.newSave("T", 22)
  local run = game.startRun(save)
  local n = save.hands[4]
  n.captives = { { id = "kaytail", level = 2, uid = "cap1", captive = true }, { id = "merline", level = 1, uid = "cap2", captive = true } }
  local before = #run.deck
  local ctx = { opp = { name = n.name, id = n.id }, nemesis = n, stage = "group", tier = 1,
    state = { result = "win", history = {}, revealed = {}, sides = { { lost = {}, scored = {} }, { lost = {} } } } }
  local out = {}
  game.settleLives(save, ctx, out)
  eq(#out.rescued, 2); eq(#n.captives, 0); eq(#run.deck, before + 2)
  local ctx2 = { opp = { name = "Stray", id = "s11" }, stage = "group", tier = 1,
    state = { result = "loss", history = {}, revealed = {}, sides = { { lost = { run.deck[1] }, scored = {} }, { lost = {} } } } }
  game.settleLives(save, ctx2, {})
  eq(#run.festival.pawnshop, 1)
end)

-- WCAG 2.x AA: every text colour reaches 4.5:1 on every dark ground, and plate labels on their plates
test("contrast: text tokens pass WCAG AA on every ground", function()
  local theme = require("src.ui.theme")
  local C = theme.c
  local grounds = { "deep", "ink", "ink2", "ink3", "night" }
  local texts = { "paper", "paper2", "muted", "goldText", "redText", "blueText", "cyan", "green", "pale", "steel" }
  for _, t in ipairs(texts) do
    for _, g in ipairs(grounds) do
      local r = theme.contrast(C[t], C[g])
      assert(r >= 4.5, ("%s on %s is %.2f:1"):format(t, g, r))
    end
  end
  for _, plate in ipairs({ "red", "blue", "redDark", "blueDark", "goldDark", "slate", "ink3" }) do
    assert(theme.contrast(C.white, C[plate]) >= 4.5, "white on " .. plate)
  end
  assert(theme.contrast(C.black, C.gold) >= 4.5, "black on gold")
  -- the automatic correction always lands on a passing colour
  local fixed = theme.readable(theme.hex("#e8483b"), C.ink3)
  assert(theme.contrast(fixed, C.ink3) >= 4.5, "readable() fixes a failing colour")
end)

test("festival: groups, table, knockout", function()
  local save = game.newSave("Fest", 11)
  local run = game.startRun(save)
  local f = run.festival
  eq(#f.groups, 4)
  for gi = 1, 4 do eq(#f.groups[gi], 4) end
  for _ = 1, 3 do festival.finishRound(f, { won = true, pd = 40 }) end
  eq(f.stage, "qf")
  local t = festival.table(f, 4)
  eq(t[1].id, festival.PLAYER)
  eq(t[1].pts, 9)
  eq(festival.playerOpponent(f) ~= nil, true)
end)

test("random starter deck is balanced", function()
  for seed = 1, 50 do
    local save = game.newSave("Deck", seed)
    local run = game.startRun(save)
    local phys, mag, spec, leg = 0, 0, 0, 0
    for _, c in ipairs(run.deck) do
      local d = cards.getDef(c)
      if d.kind == "special" then spec = spec + 1 elseif d.type == "physical" then phys = phys + 1 else mag = mag + 1 end
      if d.rarity == "legendary" then leg = leg + 1 end
    end
    if phys < 4 or mag < 4 or spec > 3 or leg > 1 then error(("bad deck p%d m%d s%d l%d"):format(phys, mag, spec, leg)) end
  end
end)

test("full festival simulation", function()
  local t = { runs = 0, champs = 0, matches = 0, wins = 0, handM = 0, handW = 0, exch = 0, place = {}, flawless = 0 }
  for r = 1, 30 do
    local save = game.newSave("Sim", 500 + r)
    for _ = 1, 3 do
      local run = game.startRun(save)
      t.runs = t.runs + 1
      local guard = 0
      while run.phase == "hub" do
        guard = guard + 1
        if guard > 20 then error("festival stuck") end
        local ctx = game.setupMatch(save)
        local s = ctx.state
        local g2 = 0
        while not s.over do
          g2 = g2 + 1
          if g2 > 20 then error("match stuck") end
          match.commit(s, match.suggest(s, 1, 0.3))
        end
        t.matches = t.matches + 1
        t.exch = t.exch + s.bout
        local out = game.resolveMatch(save, ctx)
        if ctx.nemesis then t.handM = t.handM + 1 end
        if out.flawless then t.flawless = t.flawless + 1 end
        if out.won then
          t.wins = t.wins + 1
          if ctx.nemesis then t.handW = t.handW + 1; game.decideFate(save, ctx.nemesis, out.flawless and "recruit" or "slay") end
          if out.cardChoices[1] then game.addCard(run, out.cardChoices[1]) end
          if out.charmChoices[1] then game.addCharm(run, out.charmChoices[1]) end
        end
        game.afterMatch(save)
      end
      local p = run.festival.placing or "?"
      t.place[p] = (t.place[p] or 0) + 1
      if p == "champion" then t.champs = t.champs + 1 end
      game.arenaMovesOn(save)
      eq(#save.hands, 4, "hands")
      local ids = {}
      for _, h in ipairs(save.hands) do
        eq(h.status, "active", "status")
        if ids[h.id] then error("duplicate hand") end
        ids[h.id] = true
      end
      local s2 = util.deserialize(util.serialize(save))
      eq(#s2.hands, 4)
    end
  end
  local places = {}
  for k, v in pairs(t.place) do places[#places + 1] = k .. "=" .. v end
  table.sort(places)
  print(("sim: %d festivals, %d matches, %.0f%% won, vs Hands %.0f%%, %.1f bouts/match, %.0f%% flawless, champions %d | %s")
    :format(t.runs, t.matches, 100 * t.wins / t.matches, 100 * t.handW / math.max(1, t.handM), t.exch / t.matches,
      100 * t.flawless / t.matches, t.champs, table.concat(places, " ")))
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
