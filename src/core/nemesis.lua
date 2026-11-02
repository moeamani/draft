-- The Four Hands: persistent nemeses with traits, memories and dialogue.
local cards = require("src.core.cards")
local rng = require("src.core.rng")
local traits = require("src.core.traits")
local util = require("src.core.util")

local M = {}

local PREFIX = { "Mor", "Gal", "Pell", "Bal", "Agra", "Grim", "Tor", "Mal", "Cal", "Fel", "Ur", "Vor", "Lyn", "Bri", "Gor", "Dag", "Sab", "Kit", "Tib", "Hro", "Ys", "Cad" }
local MIDDLE = { "ra", "e", "i", "o", "a", "ga", "li", "dre", "wa", "mi", "ne", "" }
local SUFFIX = { "mew", "purr", "claw", "tail", "fang", "whisk", "paw", "leus", "vane", "dred", "mog", "ius", "hiss", "mane", "grin", "bert", "ric" }

local EPITHETS = {
  ember = { "Cinder-Claw", "the Scorched", "Ash-Whisker", "the Kindling", "Hearth-Breaker" },
  tide = { "Rain-Drinker", "the Drowned", "Salt-Fang", "of the Undertow", "the Grey Wave" },
  gilt = { "the Gilded", "Gold-Tooth", "the Gleaming", "Crown-Licker", "the Polished" },
  shadow = { "the Unlucky", "of the Gutter", "the Hollow Purr", "Moon-Eater", "the Unblinking" },
}
local PERSONALITY_EPITHETS = {
  brute = { "Skull-Batter", "the Heavy", "Bone-Gnawer" },
  schemer = { "the Patient", "Whisper-Tail", "the Ledger" },
  zealot = { "the Devout", "Flame of the Arena", "the Sworn" },
  coward = { "the Slippery", "Quick-Tail", "the Survivor" },
  trickster = { "the Grin", "Fish-Thief", "the Prankster" },
}
local COATS = { "ember", "tide", "gilt", "shadow" }
local PERSONALITIES = { "brute", "schemer", "zealot", "coward", "trickster" }
local STYLES = { "smite", "hex", "yowl", "inspire", "groom", "pounce", "ninelives" }

M.RANK_TITLES = { "The First Hand", "The Second Hand", "The Third Hand", "The Fourth Hand" }
M.SCARS = { "a torn ear", "a scar across the eye", "a crooked tail", "a burned whisker-pad", "a missing fang" }

function M.name(r)
  local n = rng.pick(r, PREFIX) .. rng.pick(r, MIDDLE) .. rng.pick(r, SUFFIX)
  return n:sub(1, 1):upper() .. n:sub(2)
end

function M.fullName(n) return n.name .. " " .. n.epithet end

local function traitList(n) return util.map(n.traits, function(t) return t.id end) end

function M.addTrait(r, n, kind)
  local pool = util.filter(kind == "strength" and traits.STRENGTHS or traits.WEAKNESSES, function(t)
    return not traits.conflicts(t, traitList(n))
  end)
  if #pool == 0 then return nil end
  local t = rng.pick(r, pool)
  n.traits[#n.traits + 1] = { id = t, known = false }
  return t
end

function M.generate(r, id, level, run)
  local coat = rng.pick(r, COATS)
  local personality = rng.pick(r, PERSONALITIES)
  local n = {
    id = id, name = M.name(r),
    epithet = rng.chance(r, 0.6) and rng.pick(r, EPITHETS[coat]) or rng.pick(r, PERSONALITY_EPITHETS[personality]),
    coat = coat,
    style = (coat == "shadow" and rng.chance(r, 0.6)) and "hex" or rng.pick(r, STYLES),
    personality = personality, level = level, traits = {}, scars = 0, wins = 0, losses = 0,
    met = false, status = "active", history = { { run = run, text = "Entered the Arena hierarchy." } },
    seed = rng.int(r, 1e9), growth = 0,
  }
  for _ = 1, 1 + math.min(2, math.floor(level / 2)) do M.addTrait(r, n, "strength") end
  M.addTrait(r, n, "weakness")
  if level <= 2 or rng.chance(r, 0.4) then M.addTrait(r, n, "weakness") end
  if personality == "brute" and not util.contains(traitList(n), "arrogant") and rng.chance(r, 0.4) then
    n.traits[#n.traits + 1] = { id = "arrogant", known = false }
  end
  return n
end

function M.traitIds(n)
  local ids = traitList(n)
  if n.wins > 0 and not util.contains(ids, "grudge") then ids[#ids + 1] = "grudge" end
  return ids
end

function M.revealRandom(r, n)
  local hidden = util.filter(n.traits, function(t) return not t.known end)
  if #hidden == 0 then return nil end
  local t = rng.pick(r, hidden)
  t.known = true
  return t.id
end

function M.hasSecrets(n)
  return util.count(n.traits, function(t) return not t.known end) > 0
end

function M.signatureCard(n)
  local magic = n.style == "hex" or n.style == "inspire" or n.style == "groom"
  return {
    _def = true, id = "sig_" .. n.id, name = n.name, kind = "unit", type = magic and "magic" or "physical",
    power = math.min(11, 6 + n.level), ability = n.style, rarity = "legendary", coat = n.coat,
    flavor = M.fullName(n) .. ". " .. (n.losses > 0 and "Bears the scars of your claws." or "Undefeated in the Arena."),
    signature = n.id, artSeed = n.seed, scars = n.scars,
  }
end

-- ---------------------------------------------------------------- decks

local enemyUid = 0
local function inst(id, level)
  enemyUid = enemyUid + 1
  return { uid = "e" .. enemyUid, id = id, level = level, xp = 0 }
end

function M.enemyDeck(r, o)
  local pool = {}
  for _, c in ipairs(cards.DRAFTABLE) do
    if c.rarity ~= "legendary" then
      local w = (c.rarity == "common" and 6 or c.rarity == "rare" and 3 or 1)
        * ((o.coat and c.coat == o.coat) and 2.5 or 1)
        * ((o.style and c.ability == o.style) and 2 or 1)
        * (c.kind == "special" and 0.6 or 1)
      pool[#pool + 1] = { c, w }
    end
  end
  local out, specials = {}, 0
  while #out < o.size do
    local c = rng.weighted(r, pool)
    local ok = true
    if c.kind == "special" then
      if specials >= 2 then ok = false else specials = specials + 1 end
    end
    if ok then
      local p = math.max(0, 0.1 * (o.tier - 1) + 0.08 * o.bonusLevels)
      local lvl = math.min(3, 1 + (rng.chance(r, p) and 1 or 0) + ((o.bonusLevels >= 3 and rng.chance(r, 0.3)) and 1 or 0))
      out[#out + 1] = inst(c.id, lvl)
      if (c.ability == "litter" or c.ability == "muster") and #out < o.size then out[#out + 1] = inst(c.id, lvl) end
    end
  end
  return rng.shuffle(r, out)
end

function M.nemesisDeck(r, n, tier)
  local deck = M.enemyDeck(r, { coat = n.coat, style = n.style, tier = tier, size = 12 + tier, bonusLevels = n.level - 1 })
  local sig = M.signatureCard(n)
  enemyUid = enemyUid + 1
  deck[#deck + 1] = { uid = "e" .. enemyUid, id = sig.id, level = 1, xp = 0, def = sig }
  if n.level >= 4 then
    local legends = util.filter(cards.DRAFTABLE, function(c) return c.rarity == "legendary" and (c.coat == n.coat or c.ability == n.style) end)
    if #legends > 0 then deck[#deck + 1] = inst(rng.pick(r, legends).id, 1) end
  end
  return rng.shuffle(r, deck)
end

-- ---------------------------------------------------------------- strays

local STRAY_TITLES = { "Alley Brawler", "Pit Fighter", "Gutter Knight", "Sellsword", "Dock Mouser", "Bin Raider", "Rooftop Duelist", "Hedge Squire" }

function M.stray(r, tier, elite)
  return {
    name = M.name(r), title = rng.pick(r, STRAY_TITLES), coat = rng.pick(r, COATS), level = tier,
    seed = rng.int(r, 1e9), personality = rng.pick(r, PERSONALITIES), elite = elite,
  }
end

function M.strayDeck(r, foe)
  return M.enemyDeck(r, {
    coat = foe.coat, style = nil, tier = foe.level,
    size = 11 + foe.level * 2 + (foe.elite and 2 or 0),
    bonusLevels = foe.elite and foe.level or foe.level - 2,
  })
end

function M.promoteStray(r, foe, id, run, playerName)
  local n = M.generate(r, id, math.max(1, foe.level), run)
  n.name, n.epithet, n.coat, n.personality, n.seed = foe.name, "Bane of " .. playerName, foe.coat, foe.personality, foe.seed
  n.wins, n.met, n.fromStray = 1, true, true
  n.history = { { run = run, text = "A nameless stray who beat " .. playerName .. " in the pits. Promoted for it." } }
  return n
end

-- ---------------------------------------------------------------- dialogue

local LINES = {
  first = {
    brute = { "Another little champion. I eat little champions.", "You smell like a house cat. Soft bed. Soft paws." },
    schemer = { "So you are {player}. I have heard... very little. Good.", "I have studied every cat who walked into this ring. You will be a short chapter." },
    zealot = { "The Arena chose me. It did not choose you.", "Kneel, and I will make it quick." },
    coward = { "Oh! Oh, you're bigger than they said. W-we can talk about this.", "Let us keep this civil, yes? Mostly civil." },
    trickster = { "A new toy! Do you squeak when you lose?", "Heh. They let anyone in these days." },
  },
  theyWon = {
    any = { "{player}! Back for another beating? I still remember how you squealed.", "I beat you {wins} time{s}. Let us make it {wins1}.", "Nine lives, they say. How many do you have left, {player}?" },
    brute = { "You again. I thought I broke you.", "Last time you ran with your tail between your legs." },
    schemer = { "I wrote down every mistake you made last time. It is a long list." },
    trickster = { "My favourite chew toy has returned!" },
  },
  youWon = {
    any = { "You did this to me, {player}. I have thought of nothing else.", "I remember your claws. Now remember mine.", "Look at this scar. Look at it! Today I return the favour." },
    coward = { "I-I have been practising since last time. A lot." },
    zealot = { "The Arena tested me with you. I will not fail it twice." },
  },
  returned = { any = { "You thought you finished me? The Arena does not let go of its own.", "I crawled out of the river for this, {player}.", "Dead? Me? You should have checked twice." } },
  traitor = { any = { "You trusted me, {player}. That was your first mistake.", "I fought for you once. I remember all your weaknesses." } },
  promoted = { any = { "They call me {rank} now. Thanks to you, {player}.", "Every win over you lifted me higher. Look where I stand." } },
  gloat = { any = { "Stay down, {player}.", "Go lick your wounds.", "That is one less life for you.", "Tell the others who did this." }, trickster = { "Squeak squeak! Hah!" }, brute = { "Crushed. Like a mouse." } },
  beaten = { any = { "This... is not over.", "Lucky. You were lucky.", "Hhhss... I will remember this." }, coward = { "Please! Please, mercy, I have kittens! Probably!" } },
  slain = { any = { "The Arena... will remember... me...", "Finish it, then." }, coward = { "Wait, wait, wai-" } },
  recruit = { any = { "You beat me without a scratch. Fine. My claws are yours.", "A champion like that... I would rather follow than fall." } },
  brand = { any = { "You... you mark me? Every cat in the Arena will see this.", "I will wear this brand until I pay it back." } },
}

function M.speak(r, n, situation, playerName, rank)
  local set = LINES[situation] or {}
  local opts = util.concat(set[n.personality] or {}, set.any or {})
  local line = #opts > 0 and rng.pick(r, opts) or "..."
  local safeName = playerName:gsub("%%", "%%%%")
  line = line:gsub("{player}", safeName):gsub("{wins1}", tostring(n.wins + 1)):gsub("{wins}", tostring(n.wins))
  line = line:gsub("{s}", n.wins == 1 and "" or "s"):gsub("{rank}", (M.RANK_TITLES[rank or 4] or ""):lower())
  return line
end

function M.situation(n)
  if n.traitor and not n.met then return "traitor" end
  if not n.met then return "first" end
  local last = n.history[#n.history] and n.history[#n.history].text or ""
  if last:find("^Returned") then return "returned" end
  if last:find("^Holds the rank") and n.wins > 0 then return "promoted" end
  if n.losses > 0 and n.losses >= n.wins then return "youWon" end
  if n.wins > 0 then return "theyWon" end
  return "first"
end

return M
