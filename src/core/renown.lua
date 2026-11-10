-- Renown and Feats: the progression that outlives every festival and both modes.
--
-- Every match earns Renown (more for wins, captures, rescues and Hot Seats). Feats are one-off
-- deeds worth a lump of Renown each. Renown levels give you a title and unlock Crests: starting
-- loadouts you pick when a Free Festival begins. The profile is one small table, saved on its
-- own file, so wiping a story or festival save never takes your Renown.
local cards = require("src.core.cards")
local match = require("src.core.match")

local M = {}

-- ---------------------------------------------------------------- feats

local function feat(id, name, desc, renown, group) return { id = id, name = name, desc = desc, renown = renown, group = group } end

M.FEATS = {
  -- at the table
  feat("hotseat", "Hot Seat", "Warm a cat to " .. match.HOT .. " Warmth.", 20, "table"),
  feat("throne", "Throne Warmer", "Warm a cat to " .. match.WARMTH_MAX .. " Warmth.", 40, "table"),
  feat("sweep", "Clean Sweep", "Win all three duels in one bout.", 25, "table"),
  feat("crush", "Flattened", "Win a duel by 10 Paws or more.", 20, "table"),
  feat("legendnap", "Legend Napper", "Capture a Legendary cat.", 50, "table"),
  feat("kidnapper", "Cat Burglar", "Capture 3 cats in one match.", 40, "table"),
  feat("untouchable", "Untouchable", "Win a match without losing a life.", 30, "table"),
  feat("comeback", "Last Goblet Standing", "Win a match with one goblet left.", 30, "table"),
  feat("blitz", "Blitz", "Win a match in 2 bouts.", 40, "table"),
  feat("homecoming", "Homecoming", "Win back a cat a Hand captured.", 30, "table"),
  -- the festival
  feat("prologue", "First Lesson", "Finish Old Bedimew's lesson.", 10, "festival"),
  feat("handslayer", "Hand Slayer", "Beat one of the Four Hands.", 30, "festival"),
  feat("kingslayer", "Kingslayer", "Beat the First Hand.", 60, "festival"),
  feat("oath", "Oathkeeper", "Recruit a beaten Hand.", 40, "festival"),
  feat("mercy", "Mercy", "Spare a beaten Hand with a brand.", 20, "festival"),
  feat("headsman", "No Quarter", "Strike down a beaten Hand.", 20, "festival"),
  feat("fatcat", "Fat Cat", "Hold 150 fish at once.", 25, "festival"),
  feat("knockouts", "Through the Gate", "Reach the knockouts.", 20, "festival"),
  feat("finalist", "Finalist", "Reach a festival final.", 40, "festival"),
  feat("champion", "Champion", "Win a festival.", 80, "festival"),
  -- a life of it
  feat("collector", "Collector", "Meet 40 different cats.", 40, "legend"),
  feat("dynasty", "Dynasty", "Win 3 festivals.", 120, "legend"),
  feat("crested", "Colours", "Win a festival under a new Crest.", 60, "legend"),
  feat("storyteller", "Stray No More", "Finish the story.", 100, "legend"),
  feat("overseen", "Over the Overseer", "Beat the Overseer at the High Table.", 150, "legend"),
  feat("inked", "Signed in Red", "Win a festival at Red Ink or higher.", 80, "legend"),
  feat("legend", "Living Legend", "Reach Renown level 10.", 0, "legend"),
}
M.FEAT = {}
for _, f in ipairs(M.FEATS) do M.FEAT[f.id] = f end

-- ---------------------------------------------------------------- crests

M.CRESTS = {
  { id = "stray", name = "Stray Crest", level = 1, desc = "A random pride, as the alley deals it." },
  { id = "ember", name = "Ember Crest", level = 2, desc = "Two more Ember cats and the Ember Banner.", coat = "ember", charm = "banner_ember" },
  { id = "tide", name = "Tide Crest", level = 3, desc = "Two more Tide cats and the Tide Banner.", coat = "tide", charm = "banner_tide" },
  { id = "gilt", name = "Gilt Crest", level = 4, desc = "Two more Gilt cats and the Gilt Banner.", coat = "gilt", charm = "banner_gilt" },
  { id = "moon", name = "Moon Crest", level = 5, desc = "Two more Shadow cats and the Witch's Candle.", coat = "shadow", charm = "candle" },
  { id = "velvet", name = "Velvet Crest", level = 6, desc = "A Velvet middle cushion and a Saucer of Cream.", cushion = { 2, "velvet" }, charm = "cream" },
  { id = "merchant", name = "Merchant Crest", level = 7, desc = "40 more fish and the Fishbone Charm.", fish = 40, charm = "fishbone" },
  { id = "lion", name = "Lion Crest", level = 9, desc = "An Epic cat at level 2 and the Scruff Ribbon.", rarity = "epic", charm = "scruff" },
  { id = "royal", name = "Royal Crest", level = 12, desc = "A Legendary cat and the Paper Crown.", rarity = "legendary", charm = "crown" },
}
M.CREST = {}
for _, c in ipairs(M.CRESTS) do M.CREST[c.id] = c end

-- Stakes: the Overseer's wager on a Free Festival. Each one adds its rule to those before it and
-- multiplies the Renown you earn; winning a festival at your highest stake opens the next.
M.STAKES = {
  { name = "Paper", desc = "The Arena as it is.", renown = 1.0 },
  { name = "Ink", desc = "Knockout rivals bring 1 more goblet.", renown = 1.2 },
  { name = "Red Ink", desc = "And the Four Hands' prides are a level higher.", renown = 1.4 },
  { name = "Gold Ink", desc = "And strays stop going easy in the groups.", renown = 1.6 },
  { name = "Overseer's Ink", desc = "And every rival cat has 1 more life.", renown = 2.0 },
}

M.TITLES = {
  "Nameless Stray", "Alley Cat", "Bin Baron", "Yard Scrapper", "Cushion Squire", "Cushion Knight",
  "Hearth Knight", "Banner Knight", "Arena Darling", "Festival Legend", "Paw of the Realm", "Lord of Cushions",
}

-- ---------------------------------------------------------------- the profile

function M.new()
  return {
    version = 1, renown = 0, feats = {}, crest = "stray", stake = 1, stakeWon = 0, seals = {},
    stats = { matches = 0, wins = 0, captures = 0, rescues = 0, hotSeats = 0, champions = 0, festivals = 0 },
  }
end

-- Fill in anything an older profile is missing.
function M.fix(p)
  if type(p) ~= "table" then return M.new() end
  local fresh = M.new()
  for k, v in pairs(fresh) do if p[k] == nil then p[k] = v end end
  for k, v in pairs(fresh.stats) do if p.stats[k] == nil then p.stats[k] = v end end
  if not M.CREST[p.crest] then p.crest = "stray" end
  p.stake = math.max(1, math.min(M.stakeOpen(p), p.stake or 1))
  return p
end

-- The highest stake you may play at: one above the highest you've won a festival at.
function M.stakeOpen(p) return math.max(1, math.min(#M.STAKES, (p.stakeWon or 0) + 1)) end

-- A festival was won at this crest and stake. Returns the stake it opened, if any.
function M.noteStake(p, crest, stake)
  stake = stake or 1
  p.seals = p.seals or {}
  p.seals[crest or "stray"] = math.max(p.seals[crest or "stray"] or 0, stake)
  local before = M.stakeOpen(p)
  p.stakeWon = math.max(p.stakeWon or 0, stake)
  local after = M.stakeOpen(p)
  return after > before and after or nil
end

-- Renown needed to reach a level: 0, 60, 150, 270, 420, 600, 810...
function M.threshold(level)
  if level <= 1 then return 0 end
  return 15 * (level - 1) * (level + 2)
end

-- Level, Renown into this level, Renown this level needs.
function M.level(renown)
  local L = 1
  while renown >= M.threshold(L + 1) do L = L + 1 end
  return L, renown - M.threshold(L), M.threshold(L + 1) - M.threshold(L)
end

function M.title(level) return M.TITLES[math.min(level, #M.TITLES)] end

function M.featCount(p)
  local n = 0
  for _, f in ipairs(M.FEATS) do if p.feats[f.id] then n = n + 1 end end
  return n, #M.FEATS
end

function M.unlocked(p, crestId)
  local c = M.CREST[crestId]
  return c ~= nil and M.level(p.renown) >= c.level
end

function M.crestsUnlocked(p)
  local out = {}
  for _, c in ipairs(M.CRESTS) do if M.unlocked(p, c.id) then out[#out + 1] = c end end
  return out
end

-- Add Renown. Returns the levels gained, each with what it unlocked.
function M.gain(p, amount)
  local before = M.level(p.renown)
  p.renown = p.renown + math.max(0, math.floor(amount))
  local after = M.level(p.renown)
  local ups = {}
  for L = before + 1, after do
    local up = { level = L, title = M.title(L), crests = {} }
    for _, c in ipairs(M.CRESTS) do if c.level == L then up.crests[#up.crests + 1] = c end end
    ups[#ups + 1] = up
  end
  return ups
end

-- Earn a feat (once). Returns the feat and any level-ups, or nil if it was already earned.
function M.earn(p, id)
  local f = M.FEAT[id]
  if not f or p.feats[id] then return nil end
  p.feats[id] = true
  local ups = M.gain(p, f.renown)
  if M.level(p.renown) >= 10 and not p.feats.legend then
    p.feats.legend = true
    ups.legend = true
  end
  return f, ups
end

-- ---------------------------------------------------------------- what qualifies
-- These only look at a match or save; the caller earns the feats. The player is side 1.

function M.boutFeats(s, rec)
  local out = {}
  if s.tutorial then return out end
  local swept = 0
  for i = 1, match.CUSHIONS do
    local w = rec.stays and rec.stays[1][i]
    if w and w >= match.HOT then out[#out + 1] = "hotseat" end
    if w and w >= match.WARMTH_MAX then out[#out + 1] = "throne" end
    local d = rec.duels[i]
    if d and d.reason == "duel" and d.winner == 1 then
      swept = swept + 1
      if (d.margin or 0) >= 10 then out[#out + 1] = "crush" end
    end
  end
  if swept == match.CUSHIONS then out[#out + 1] = "sweep" end
  for _, w in ipairs(rec.wounds or {}) do
    if w.side == 2 and w.captured and not w.rescued then
      local inf = rec.info[2][w.slot]
      if inf and inf.def and inf.def.rarity == "legendary" then out[#out + 1] = "legendnap" end
    end
  end
  return out
end

function M.matchFeats(ctx, out, save)
  local ids = {}
  local s = ctx.state
  local me = s.sides[1]
  if out.won then
    if (me.livesLost or 0) == 0 then ids[#ids + 1] = "untouchable" end
    if me.goblets == 1 then ids[#ids + 1] = "comeback" end
    if s.bout <= 2 then ids[#ids + 1] = "blitz" end
    if ctx.nemesis then
      ids[#ids + 1] = "handslayer"
      if save.hands[1] == ctx.nemesis then ids[#ids + 1] = "kingslayer" end
    end
  end
  local taken = 0
  for _, c in ipairs(me.taken) do if not c.captive then taken = taken + 1 end end
  if taken >= 3 then ids[#ids + 1] = "kidnapper" end
  if ctx.nemesis and #(out.rescued or {}) > 0 then ids[#ids + 1] = "homecoming" end
  if save.run and save.run.fish >= 150 then ids[#ids + 1] = "fatcat" end
  local seen = 0
  for id in pairs(save.seen or {}) do if cards.CARDS[id] then seen = seen + 1 end end
  if seen >= 40 then ids[#ids + 1] = "collector" end
  return ids
end

M.FATE_FEAT = { recruit = "oath", brand = "mercy", slay = "headsman" }

function M.runFeats(p, save)
  local ids = {}
  local f = save.run and save.run.festival
  if not f then return ids end
  local reached = ({ group = 0, qf = 1, sf = 2, runnerup = 3, champion = 4 })[f.placing or "group"] or 0
  if reached >= 1 then ids[#ids + 1] = "knockouts" end
  if reached >= 3 then ids[#ids + 1] = "finalist" end
  if reached >= 4 then
    ids[#ids + 1] = "champion"
    if (p.stats.champions or 0) >= 3 then ids[#ids + 1] = "dynasty" end
    if save.run.crest and save.run.crest ~= "stray" then ids[#ids + 1] = "crested" end
    if (save.run.stake or 1) >= 3 then ids[#ids + 1] = "inked" end
  end
  return ids
end

-- ---------------------------------------------------------------- Renown for a match

-- Renown for one finished match, as a total and the lines that make it up.
function M.matchRenown(ctx, out)
  local s = ctx.state
  local me = s.sides[1]
  local lines = {}
  local function add(n, text) if n > 0 then lines[#lines + 1] = { n = n, text = text } end end
  if out.won then
    add(12, "Victory")
    add(({ qf = 4, sf = 6, final = 10 })[ctx.stage] or 0, "Knockout match")
    add(ctx.nemesis and 8 or 0, "Beat a Hand")
    add(out.flawless and 5 or 0, "Never lost a bout")
  else
    add(4, "A brave showing")
  end
  local taken = 0
  for _, c in ipairs(me.taken) do if not c.captive then taken = taken + 1 end end
  add(taken * 3, taken .. " captured")
  add(#(out.rescued or {}) * 4, "Brought cats home")
  add((me.hotSeats or 0) * 2, "Hot Seats")
  local total = 0
  for _, l in ipairs(lines) do total = total + l.n end
  return total, lines
end

-- Renown for where a festival ended.
function M.runRenown(save)
  local f = save.run and save.run.festival
  if not f then return 0 end
  return ({ group = 0, qf = 10, sf = 20, runnerup = 30, champion = 50 })[f.placing or "group"] or 0
end

-- Book a finished match into the profile's lifetime stats.
function M.noteMatch(p, ctx, out)
  local st = p.stats
  st.matches = st.matches + 1
  if out.won then st.wins = st.wins + 1 end
  local me = ctx.state.sides[1]
  for _, c in ipairs(me.taken) do if not c.captive then st.captures = st.captures + 1 end end
  st.rescues = st.rescues + #(out.rescued or {})
  st.hotSeats = st.hotSeats + (me.hotSeats or 0)
end

function M.noteRun(p, save)
  local f = save.run and save.run.festival
  p.stats.festivals = p.stats.festivals + 1
  if f and f.placing == "champion" then p.stats.champions = p.stats.champions + 1 end
end

return M
