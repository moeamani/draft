-- The Arena Festival: 16 entrants, four groups of four (round-robin, 3 points a win),
-- the top two of each group go to an 8-cat knockout: quarter-finals, semi-finals, final.
local nemesis = require("src.core.nemesis")
local rng = require("src.core.rng")
local util = require("src.core.util")

local M = {}

M.GROUPS = { "A", "B", "C", "D" }
M.PLAYER = "you"
-- Each festival has an omen: one rule twist for every match in it, matching its name.
M.OMENS = {
  midsummer = { name = "Midsummer Sun", short = "Midsummer", coat = "ember", desc = "Ember cats get +1 Paw." },
  harvest = { name = "Harvest Gold", short = "Harvest", coat = "gilt", desc = "Gilt cats get +1 Paw." },
  feast = { name = "Feast Day", short = "Feast", hand = 1, desc = "Everyone holds 6 cards." },
  frost = { name = "Hard Frost", short = "Frost", edge = 1, desc = "The coat edge is +4 Paws." },
  saucer = { name = "Heavy Goblets", short = "Saucer", goblets = 1, desc = "Everyone starts with 1 more goblet." },
  moonlit = { name = "New Moon", short = "New Moon", coat = "shadow", desc = "Shadow cats get +1 Paw." },
  regatta = { name = "Spring Tide", short = "Spring Tide", coat = "tide", desc = "Tide cats get +1 Paw." },
  naps = { name = "Long Naps", short = "Naps", tiesToAnswer = true, desc = "Ties go to the side that answers." },
}
local FESTIVALS = {
  { "Midsummer Festival of Claws", "midsummer" }, { "Harvest Moot", "harvest" }, { "Feast of Nine Lives", "feast" },
  { "Winter Yowl", "frost" }, { "Tourney of the Gilded Saucer", "saucer" }, { "Moonlit Mews", "moonlit" },
  { "Spring Tide Regatta", "regatta" }, { "Festival of Long Naps", "naps" },
}
function M.omen(f) return f and f.omen and M.OMENS[f.omen] or nil end
-- round-robin pairings by group slot
local ROUNDS = { { { 1, 2 }, { 3, 4 } }, { { 1, 3 }, { 2, 4 } }, { { 1, 4 }, { 2, 3 } } }

function M.create(save, seed)
  local r = rng.new(seed)
  local fest = FESTIVALS[(save.runs - 1) % #FESTIVALS + 1]
  local f = {
    name = "The " .. fest[1], omen = fest[2], entrants = {}, groups = {}, results = {},
    stage = "group", round = 1, bracket = { qf = {}, sf = {}, final = {} }, champion = nil,
    eliminated = false, placing = nil, rng = r, withdrawn = {},
  }
  local function add(e) f.entrants[e.id] = e; return e.id end
  -- Hands seed the groups: First Hand in A ... Fourth Hand in D (the player's group).
  for gi = 1, 4 do f.groups[gi] = {} end
  for rank = 1, 4 do
    local n = save.hands[rank]
    f.groups[rank][1] = add({ id = n.id, kind = "hand", name = n.name, coat = n.coat, rating = 12 + n.level * 3, seed = n.seed })
  end
  -- player goes into group D, slot 1; the Fourth Hand moves to slot 4 so you meet them last
  local hand4 = f.groups[4][1]
  f.groups[4][1] = add({ id = M.PLAYER, kind = "player", name = save.playerName, coat = "gilt", rating = 14 })
  f.groups[4][4] = hand4
  for gi = 1, 4 do
    for slot = 1, 4 do
      if not f.groups[gi][slot] then
        local elite = rng.chance(r, 0.25)
        local foe = nemesis.stray(r, 1, elite)
        f.groups[gi][slot] = add({ id = "s" .. gi .. slot, kind = "stray", name = foe.name, title = foe.title, coat = foe.coat,
          rating = 8 + rng.int(r, 6) + (elite and 4 or 0), seed = foe.seed, foe = foe })
      end
    end
  end
  return f
end

function M.groupOf(f, id)
  for gi, g in ipairs(f.groups) do
    for slot, eid in ipairs(g) do if eid == id then return gi, slot end end
  end
end

-- ---------------------------------------------------------------- standings

function M.table(f, gi)
  local rows, byId = {}, {}
  for _, id in ipairs(f.groups[gi]) do
    local row = { id = id, p = 0, w = 0, l = 0, pd = 0, pts = 0 }
    rows[#rows + 1] = row
    byId[id] = row
  end
  for _, m in ipairs(f.results) do
    if m.stage == "group" and m.group == gi then
      local a, b = byId[m.a], byId[m.b]
      local wr, lr = m.winner == m.a and a or b, m.winner == m.a and b or a
      wr.p, lr.p = wr.p + 1, lr.p + 1
      wr.w, lr.l = wr.w + 1, lr.l + 1
      wr.pts = wr.pts + 3
      wr.pd, lr.pd = wr.pd + m.pd, lr.pd - m.pd
    end
  end
  table.sort(rows, function(x, y)
    local wx, wy = f.withdrawn[x.id] and 1 or 0, f.withdrawn[y.id] and 1 or 0
    if wx ~= wy then return wx < wy end
    if x.pts ~= y.pts then return x.pts > y.pts end
    if x.pd ~= y.pd then return x.pd > y.pd end
    return f.entrants[x.id].rating > f.entrants[y.id].rating
  end)
  return rows
end

-- ---------------------------------------------------------------- simulation

local function simWinner(f, a, b)
  if f.withdrawn[a] and not f.withdrawn[b] then return b, 50 end
  if f.withdrawn[b] and not f.withdrawn[a] then return a, 50 end
  local ra, rb = f.entrants[a].rating, f.entrants[b].rating
  local w = rng.chance(f.rng, ra / (ra + rb)) and a or b
  return w, 10 + rng.int(f.rng, 60)
end

local function record(f, m) f.results[#f.results + 1] = m end

-- The pairings for the current round, as { a, b } lists.
function M.currentPairings(f)
  if f.stage == "group" then
    local out = {}
    for gi, g in ipairs(f.groups) do
      for _, p in ipairs(ROUNDS[f.round]) do out[#out + 1] = { a = g[p[1]], b = g[p[2]], group = gi } end
    end
    return out
  end
  return f.bracket[f.stage]
end

function M.playerOpponent(f)
  if f.eliminated or f.stage == "done" then return nil end
  for _, p in ipairs(M.currentPairings(f)) do
    if p.a == M.PLAYER then return p.b end
    if p.b == M.PLAYER then return p.a end
  end
end

local function buildKnockout(f)
  local t = {}
  for gi = 1, 4 do t[gi] = M.table(f, gi) end
  local q = function(gi, pos) return t[gi][pos].id end
  f.bracket.qf = {
    { a = q(1, 1), b = q(2, 2) }, { a = q(3, 1), b = q(4, 2) },
    { a = q(2, 1), b = q(1, 2) }, { a = q(4, 1), b = q(3, 2) },
  }
  local inKo = false
  for _, m in ipairs(f.bracket.qf) do if m.a == M.PLAYER or m.b == M.PLAYER then inKo = true end end
  if not inKo then
    f.eliminated = true
    f.placing = "group"
  end
end

local NEXT = { qf = "sf", sf = "final", final = "done" }

local function advanceKnockout(f)
  local cur = f.bracket[f.stage]
  if f.stage == "final" then
    f.champion = cur[1].winner
    f.stage = "done"
    return
  end
  local nxt = {}
  for i = 1, #cur, 2 do nxt[#nxt + 1] = { a = cur[i].winner, b = cur[i + 1].winner } end
  f.stage = NEXT[f.stage]
  f.bracket[f.stage] = nxt
end

-- Play out every non-player match of the current round, then advance. Returns notable results.
function M.finishRound(f, playerResult)
  local notes = {}
  for _, p in ipairs(M.currentPairings(f)) do
    local m = { stage = f.stage, group = p.group, round = f.round, a = p.a, b = p.b }
    if p.a == M.PLAYER or p.b == M.PLAYER then
      if playerResult then
        m.winner = playerResult.won and M.PLAYER or (p.a == M.PLAYER and p.b or p.a)
        m.pd = playerResult.pd
      else
        m.winner, m.pd = simWinner(f, p.a, p.b)
      end
    else
      m.winner, m.pd = simWinner(f, p.a, p.b)
      local loser = m.winner == p.a and p.b or p.a
      local we, le = f.entrants[m.winner], f.entrants[loser]
      if le.kind == "hand" and we.kind == "stray" then
        notes[#notes + 1] = we.name .. " upsets " .. le.name .. "!"
      elseif we.kind == "hand" and f.stage ~= "group" then
        notes[#notes + 1] = we.name .. " knocks out " .. le.name .. "."
      end
    end
    p.winner = m.winner
    record(f, m)
  end
  if f.stage == "group" then
    if f.round < 3 then f.round = f.round + 1
    else
      f.stage = "qf"
      f.round = 1
      buildKnockout(f)
    end
  else
    local pm = playerResult and not playerResult.won
    if pm then
      f.eliminated = true
      f.placing = f.stage == "qf" and "qf" or f.stage == "sf" and "sf" or "runnerup"
    end
    local wasFinal = f.stage == "final"
    advanceKnockout(f)
    if wasFinal and f.champion == M.PLAYER then f.placing = "champion" end
  end
  return notes
end

-- After the player is out, play the rest of the festival instantly.
function M.simulateRest(f)
  local guard = 0
  while f.stage ~= "done" and guard < 20 do
    guard = guard + 1
    M.finishRound(f, nil)
  end
end

function M.withdraw(f, id) f.withdrawn[id] = true end

M.STAGE_NAMES = { group = "Group Stage", qf = "Quarter-final", sf = "Semi-final", final = "The Final", done = "Festival over" }
M.PLACING_NAMES = { group = "Out in the groups", qf = "Quarter-finalist", sf = "Semi-finalist", runnerup = "Runner-up", champion = "Festival Champion" }

function M.stageLabel(f)
  if f.stage == "group" then return "Group Stage - Round " .. f.round .. " of 3" end
  return M.STAGE_NAMES[f.stage]
end

-- 1 for the first group round ... 6 for the final; used for difficulty and rewards.
function M.tier(f)
  if f.stage == "group" then return f.round end
  return ({ qf = 4, sf = 5, final = 6 })[f.stage] or 6
end

return M
