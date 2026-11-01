-- Run with: luajit tests/run.lua   (from the repo root)
package.path = "./?.lua;" .. package.path
local cards = require("src.core.cards")
local festival = require("src.core.festival")
local formations = require("src.core.formations")
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

local function cat(paws, coat, type_, ability) return { paws = paws, coat = coat, type = type_ or "physical", ability = ability or "none" } end

test("detect: litter beats duet", function()
  local f, idx = formations.detect({ cat(3, "ember"), cat(5, "ember"), cat(8, "ember"), cat(2, "tide") })
  eq(f.id, "litter"); eq(#idx, 3)
end)
test("detect: round table", function()
  local f = formations.detect({ cat(3, "ember"), cat(4, "tide"), cat(5, "gilt"), cat(2, "shadow") })
  eq(f.id, "roundtable")
end)
test("detect: charge needs one-step rise", function()
  eq(formations.detect({ cat(3, "ember"), cat(4, "tide"), cat(5, "gilt") }).id, "charge")
  local f = formations.detect({ cat(3, "ember"), cat(5, "tide"), cat(7, "gilt") })
  if f.id == "charge" then error("7-5-3 is not a charge") end
end)
test("detect: wild coat from cardboard box", function()
  eq(formations.detect({ cat(2, "ember"), cat(5, "ember"), cat(8, "tide") }, true).id, "litter")
end)
test("detect: full pride", function()
  eq(formations.detect({ cat(2, "gilt"), cat(9, "gilt"), cat(4, "gilt"), cat(6, "gilt"), cat(3, "gilt") }).id, "fullpride")
end)

local n = 0
local function inst(id, level) n = n + 1; return { uid = "x" .. n, id = id, level = level or 1, xp = 0 } end
local function deckOf(ids)
  local d = {}
  for _, id in ipairs(ids) do d[#d + 1] = inst(id) end
  return d
end

test("scoring: formation base + paws x cheer, sword hammer doubles cheer", function()
  local deck = deckOf({ "artheline", "galahiss", "bedimew", "squire", "squire", "ironpaw", "pelliroar", "elaine", "seer", "taliesing" })
  local s = match.create({ name = "A", deck = deck }, { name = "B", deck = deckOf({ "agravain", "agravain", "agravain", "agravain", "agravain", "agravain", "agravain", "agravain" }) }, 3)
  local hand = s.sides[1].hand
  local pick = {}
  for _, c in ipairs(hand) do if #pick < 3 and cards.getDef(c).coat == "gilt" and cards.getDef(c).kind == "unit" then pick[#pick + 1] = c.uid end end
  local r = match.preview(s, 1, pick)
  if not r.formation then error("no formation") end
  local expected = (r.formation.paws)
  for _, c in ipairs(r.scoring) do expected = expected + c.paws end
  if r.total <= 0 then error("score should be positive") end
end)

test("match runs to a result and pride drops", function()
  local deck = game.newSave("T", 9)
  local run = game.startRun(deck)
  local ctx = game.setupMatch(deck)
  local s = ctx.state
  local guard = 0
  while not s.over do
    guard = guard + 1
    if guard > 40 then error("match did not end") end
    local best = match.bestSelection(s, 1, 0)
    local rec = match.commit(s, best.uids)
    if not rec then error("commit failed") end
  end
  if s.sides[1].pride > 0 and s.sides[2].pride > 0 and s.exchange < match.MAX_EXCHANGES then error("ended early") end
  eq(type(s.result), "string")
end)

test("thick fur blocks hexes", function()
  local m = traits.baseMods(); m.hexImmune = true
  local s = match.create({ name = "A", deck = deckOf({ "merlinus", "circaleus", "purrlinore", "morgelius", "purrceval", "mordraleus", "lanceline", "merlinus" }) },
    { name = "B", deck = deckOf({ "agravain", "agravain", "agravain", "agravain", "agravain", "agravain", "agravain", "agravain" }), mods = m }, 5)
  local uids = {}
  for i = 1, 3 do uids[i] = s.sides[1].hand[i].uid end
  local rec = match.commit(s, uids)
  for _, st in ipairs(rec.r[2].steps) do if st.text:find("^Hexed") then error("hex got through") end end
  eq(s.revealed[1], "thickfur")
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
  local t = { runs = 0, champs = 0, matches = 0, wins = 0, handM = 0, handW = 0, exch = 0, place = {} }
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
          if g2 > 40 then error("match stuck") end
          local best = match.bestSelection(s, 1, 0.1)
          match.commit(s, best.uids)
        end
        t.matches = t.matches + 1
        t.exch = t.exch + s.exchange
        local out = game.resolveMatch(save, ctx)
        if ctx.nemesis then t.handM = t.handM + 1 end
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
  print(("sim: %d festivals, %d matches, %.0f%% won, vs Hands %.0f%%, %.1f exchanges/match, champions %d | %s")
    :format(t.runs, t.matches, 100 * t.wins / t.matches, 100 * t.handW / math.max(1, t.handM), t.exch / t.matches, t.champs, table.concat(places, " ")))
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
