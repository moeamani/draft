-- Run with: luajit tests/run.lua   (from the repo root)
package.path = "./?.lua;" .. package.path
local ai = require("src.core.ai")
local cards = require("src.core.cards")
local duel = require("src.core.duel")
local game = require("src.core.game")
local traits = require("src.core.traits")

local passed, failed = 0, 0
local function test(name, f)
  local ok, err = pcall(f)
  if ok then passed = passed + 1 else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end end

local n = 0
local function c(id) n = n + 1; return { uid = "x" .. n, id = id, level = 1, xp = 0 } end
local function deckOf(ids)
  local d = {}
  for _, id in ipairs(ids) do d[#d + 1] = c(id) end
  while #d < 8 do d[#d + 1] = c("agravain") end
  return d
end
local function mk(a, b, first, mods2)
  return duel.create({ name = "A", deck = deckOf(a) }, { name = "B", deck = deckOf(b), mods = mods2 }, 7, first or 1)
end
local function huid(s, side, id)
  for _, x in ipairs(s.sides[side].hand) do if x.id == id then return x.uid end end
  error("no " .. id .. " in hand")
end

test("rows by type", function()
  local s = mk({ "barnbrawler", "candlewitch" }, {})
  duel.playCard(s, 1, huid(s, 1, "barnbrawler")); duel.pass(s, 2)
  duel.playCard(s, 1, huid(s, 1, "candlewitch"))
  eq(s.sides[1].rows.vanguard[1].def.id, "barnbrawler")
  eq(s.sides[1].rows.arcane[1].def.id, "candlewitch")
end)
test("litter", function()
  local s = mk({ "kaytail", "kaytail" }, {})
  duel.playCard(s, 1, huid(s, 1, "kaytail")); duel.pass(s, 2); duel.playCard(s, 1, huid(s, 1, "kaytail"))
  eq(duel.unitPower(s, 1, "vanguard", s.sides[1].rows.vanguard[1]), 6)
end)
test("downpour vs legendary", function()
  local s = mk({ "lamoracat", "artheline" }, { "downpour" })
  duel.playCard(s, 1, huid(s, 1, "lamoracat")); duel.playCard(s, 2, huid(s, 2, "downpour")); duel.playCard(s, 1, huid(s, 1, "artheline"))
  eq(duel.unitPower(s, 1, "vanguard", s.sides[1].rows.vanguard[1]), 1)
  eq(duel.unitPower(s, 1, "vanguard", s.sides[1].rows.vanguard[2]), 20)
end)
test("smite", function()
  local s = mk({ "artheline" }, { "lamoracat" }, 2)
  duel.playCard(s, 2, huid(s, 2, "lamoracat")); duel.playCard(s, 1, huid(s, 1, "artheline"))
  eq(#s.sides[2].rows.vanguard, 0)
end)
test("hex scales", function()
  local s = mk({ "merlinus", "circaleus" }, { "lamoracat" }, 2)
  duel.playCard(s, 2, huid(s, 2, "lamoracat")); duel.playCard(s, 1, huid(s, 1, "merlinus"))
  duel.playCard(s, 2, huid(s, 2, "agravain")); duel.playCard(s, 1, huid(s, 1, "circaleus"))
  local lam
  for _, u in ipairs(s.sides[2].rows.vanguard) do if u.def.id == "lamoracat" then lam = u end end
  eq(duel.unitPower(s, 2, "vanguard", lam), 4)
end)
test("coat advantage", function()
  local s = mk({ "pikecat" }, { "barnbrawler" }, 2)
  duel.playCard(s, 2, huid(s, 2, "barnbrawler")); duel.playCard(s, 1, huid(s, 1, "pikecat"))
  eq(duel.unitPower(s, 1, "vanguard", s.sides[1].rows.vanguard[1]), 5)
end)
test("thick fur", function()
  local m = traits.baseMods(); m.thickfur = true; m.source.thickfur = "thickfur"
  local s = mk({ "merlinus" }, { "lamoracat" }, 2, m)
  duel.playCard(s, 2, huid(s, 2, "lamoracat")); duel.playCard(s, 1, huid(s, 1, "merlinus"))
  eq(duel.unitPower(s, 2, "vanguard", s.sides[2].rows.vanguard[1]), 7)
  eq(s.revealed[2][1], "thickfur")
end)

local function autoplay(s)
  local guard = 0
  while not s.over do
    guard = guard + 1
    if guard > 400 then error("duel did not terminate") end
    local side = s.turn
    local a = ai.choose(s, side)
    if a.type == "pass" then duel.pass(s, side) elseif not duel.playCard(s, side, a.uid) then error("illegal AI play") end
  end
end

test("full-run simulation", function()
  local t = { victories = 0, duels = 0, wins = 0, wd = 0, ww = 0 }
  for r = 1, 40 do
    local save = game.newSave("Tester", 1000 + r)
    for _ = 1, 3 do
      local run = game.startRun(save)
      while run.phase == "draft" do game.draftPick(save, run.draftOptions[1]) end
      local guard = 0
      while run.phase == "map" do
        guard = guard + 1
        if guard > 100 then error("run stuck") end
        local node
        for _, o in ipairs(run.options) do if o.kind == "warlord" or o.kind == "skirmish" or o.kind == "pit" then node = o; break end end
        node = node or run.options[1]
        if node.kind == "market" or node.kind == "tavern" then
          game.advance(save)
        elseif node.kind == "shrine" then
          local ev = game.EVENTS[node.event]
          ev.text(save)
          for _, ch in ipairs(ev.choices) do if ch.enabled(save) then ch.apply(save); break end end
          if run.lives <= 0 then game.finishRun(save, "defeat") else game.advance(save) end
        else
          local ctx = game.setupDuel(save, node)
          autoplay(ctx.state)
          t.duels = t.duels + 1
          if node.kind == "warlord" then t.wd = t.wd + 1 end
          local out = game.resolveDuel(save, ctx)
          if out.result == "win" then
            t.wins = t.wins + 1
            if out.cardChoices[1] then game.addCard(run, out.cardChoices[1]) end
            if ctx.nemesis then t.ww = t.ww + 1; game.decideFate(save, ctx.nemesis, out.flawless and "recruit" or "slay") end
            game.advance(save)
          elseif out.runOver then game.finishRun(save, "defeat")
          else run.options = game.genOptions(save) end
        end
      end
      if run.outcome == "victory" then t.victories = t.victories + 1 end
      game.arenaMovesOn(save)
      eq(#save.hands, 4, "hands")
      local ids = {}
      for _, h in ipairs(save.hands) do
        eq(h.status, "active", "status")
        if ids[h.id] then error("duplicate hand") end
        ids[h.id] = true
      end
    end
  end
  print(("sim: %d duels, %.0f%% won, warlords %.0f%%, run victories %d/120"):format(t.duels, 100 * t.wins / t.duels, 100 * t.ww / t.wd, t.victories))
end)

test("save roundtrip", function()
  local util = require("src.core.util")
  local save = game.newSave("Roundtrip", 5)
  game.startRun(save)
  local s2 = util.deserialize(util.serialize(save))
  eq(s2.playerName, "Roundtrip")
  eq(#s2.hands, 4)
  eq(#s2.run.deck, #save.run.deck)
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
