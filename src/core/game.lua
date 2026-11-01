-- Run and meta-progression: one run is one festival. Starter deck, matches, duel setup/resolution, fates, events, the Arena moving on.
local cards = require("src.core.cards")
local charms = require("src.core.charms")
local festival = require("src.core.festival")
local match = require("src.core.match")
local nemesis = require("src.core.nemesis")
local rng = require("src.core.rng")
local traits = require("src.core.traits")
local util = require("src.core.util")

local M = {}

M.DRAFT_PICKS = 10 -- random cats dealt into the starting pride

local function nid(save)
  save.nextId = save.nextId + 1
  return "n" .. save.nextId
end

local function chronicle(save, text)
  table.insert(save.chronicle, { run = save.runs, text = text })
  while #save.chronicle > 80 do table.remove(save.chronicle, 1) end
end
M.chronicle = chronicle

local function nemLog(save, n, text)
  table.insert(n.history, { run = save.runs, text = text })
  while #n.history > 20 do table.remove(n.history, 1) end
end

function M.newSave(playerName, seed)
  local save = {
    version = 2, playerName = playerName, rng = rng.new(seed or os.time()), hands = {}, fallen = {},
    chronicle = {}, runs = 0, victories = 0, nextId = 0, bestRing = 0, run = nil,
  }
  for rank = 1, 4 do save.hands[rank] = nemesis.generate(save.rng, nid(save), 5 - rank, 0) end
  chronicle(save, "The Four Hands rule the Arena: " .. table.concat(util.map(save.hands, function(h) return h.name end), ", ") .. ".")
  return save
end

function M.findNemesis(save, id)
  for _, n in ipairs(save.hands) do if n.id == id then return n end end
  for _, n in ipairs(save.fallen) do if n.id == id then return n end end
end

function M.rankOf(save, n) return util.indexOf(save.hands, n) or 0 end

local function cardInst(run, id, level)
  run.uidc = run.uidc + 1
  return { uid = "c" .. run.uidc, id = id, level = level or 1, xp = 0 }
end

function M.addCard(run, id, level) table.insert(run.deck, cardInst(run, id, level)) end

local RARITY_WEIGHTS = {
  [0] = { { "common", 62 }, { "rare", 30 }, { "epic", 7 }, { "legendary", 1 } },
  [1] = { { "common", 50 }, { "rare", 36 }, { "epic", 12 }, { "legendary", 2 } },
  [2] = { { "common", 20 }, { "rare", 50 }, { "epic", 24 }, { "legendary", 6 } },
  [3] = { { "common", 0 }, { "rare", 40 }, { "epic", 40 }, { "legendary", 20 } },
}

function M.rollCards(r, n, quality)
  local out, guard = {}, 0
  while #out < n and guard < 200 do
    guard = guard + 1
    local rarity = rng.weighted(r, RARITY_WEIGHTS[util.clamp(quality, 0, 3)])
    local pool = util.filter(cards.DRAFTABLE, function(c) return c.rarity == rarity and not util.contains(out, c.id) end)
    if #pool > 0 then out[#out + 1] = rng.pick(r, pool).id end
  end
  return out
end

function M.startRun(save)
  save.runs = save.runs + 1
  local run = {
    rng = rng.new(rng.int(save.rng, 1e9) + 1), number = save.runs, fish = 25, deck = {}, charms = {},
    phase = "hub", stallUsed = false, nextPride = 0, uidc = 0,
    stats = { won = 0, lost = 0, slain = 0, recruited = 0, branded = 0 },
  }
  M.dealStarterDeck(run)
  run.festival = festival.create(save, rng.int(run.rng, 1e9) + 1)
  save.run = run
  return run
end

-- A random but playable starting pride: basics plus 10 random cats, at least 4 Physical and
-- 4 Magic, at most 2 tricks and 1 Legendary. Litter/Call-the-Pride cats arrive in pairs.
function M.dealStarterDeck(run)
  for _, id in ipairs({ "squire", "squire", "hedgedruid", "sunbeam" }) do M.addCard(run, id) end
  local picks, physical, magic, specials, legends = 0, 0, 0, 0, 0
  local guard = 0
  while picks < M.DRAFT_PICKS and guard < 500 do
    guard = guard + 1
    local id = M.rollCards(run.rng, 1, 1)[1]
    local d = cards.CARDS[id]
    local remaining = M.DRAFT_PICKS - picks
    local ok = true
    if d.kind == "special" and specials >= 2 then ok = false end
    if d.rarity == "legendary" and legends >= 1 then ok = false end
    if d.kind == "unit" then
      local needP, needM = math.max(0, 4 - physical), math.max(0, 4 - magic)
      if d.type == "physical" and needM >= remaining then ok = false end
      if d.type == "magic" and needP >= remaining then ok = false end
    elseif (4 - physical) + (4 - magic) >= remaining then
      ok = false
    end
    if ok then
      M.addCard(run, id)
      if d.ability == "litter" or d.ability == "muster" then M.addCard(run, id) end
      picks = picks + 1
      if d.kind == "special" then specials = specials + 1 end
      if d.rarity == "legendary" then legends = legends + 1 end
      if d.type == "physical" then physical = physical + 1 elseif d.type == "magic" then magic = magic + 1 end
    end
  end
end

M.EVENT_IDS = { "rat", "sword", "bard", "discord", "sabotage", "milk", "basket", "bookie" }

function M.finishRun(save, outcome)
  local run = save.run
  run.phase = "over"
  run.outcome = outcome
  if outcome == "victory" then save.victories = save.victories + 1 end
  local f = run.festival
  if f and f.stage ~= "done" then festival.simulateRest(f) end
  save.bestPlacing = save.bestPlacing or "group"
end

-- The entrant the player faces next (table from festival.entrants), or nil.
function M.nextOpponent(save)
  local f = save.run.festival
  local id = festival.playerOpponent(f)
  return id and f.entrants[id] or nil
end

-- The Hand the player is most likely to meet next (for shrine events).
function M.nextHand(save)
  local opp = M.nextOpponent(save)
  if opp and opp.kind == "hand" then return M.findNemesis(save, opp.id) end
  local f = save.run.festival
  local gi = festival.groupOf(f, festival.PLAYER)
  for _, id in ipairs(f.groups[gi] or {}) do
    local e = f.entrants[id]
    if e.kind == "hand" and not f.withdrawn[id] then return M.findNemesis(save, id) end
  end
  return save.hands[#save.hands]
end

-- ---------------------------------------------------------------- matches

function M.setupMatch(save)
  local run = save.run
  local f = run.festival
  local opp = M.nextOpponent(save)
  local tier = festival.tier(f)
  local pm, em = traits.baseMods(), traits.baseMods()
  charms.apply(pm, run.charms)
  pm.pride = pm.pride + (run.nextPride or 0)
  local deck, n, personality, spyglass
  if opp.kind == "hand" then
    n = M.findNemesis(save, opp.id)
    traits.apply(em, nemesis.traitIds(n), n.wins)
    deck = nemesis.nemesisDeck(run.rng, n, math.ceil(tier / 2) + 1)
    personality = n.personality
    if pm.seeCoat then spyglass = nemesis.revealRandom(run.rng, n) end
  else
    local foe = opp.foe
    foe.level = math.max(1, math.floor((tier + 1) / 2) + (foe.elite and 1 or 0))
    deck = nemesis.strayDeck(run.rng, foe)
    personality = foe.personality
    if foe.elite then traits.apply(em, { rng.pick(run.rng, { "warlord", "archmage", "hoarder", "vengeful", "bodyguard" }) }, 0) end
    if tier <= 2 then em.handSize = em.handSize - 1 end
  end
  -- the festival gets meaner as it goes: knockout rivals and the Hands bring extra Pride
  if tier >= 4 then em.pride = em.pride + (tier - 3) * 12 end
  if n then em.pride = em.pride + n.level * 5 end
  local style = match.STYLES[personality] or match.STYLES.default
  local state = match.create({ name = save.playerName, deck = run.deck, mods = pm }, { name = opp.name, deck = deck, mods = em },
    rng.int(run.rng, 1e9) + 1, style)
  return { opp = opp, nemesis = n, state = state, personality = personality, spyglass = spyglass, stage = f.stage, tier = tier }
end

function M.charmOffer(run, n)
  local pool = util.filter(charms.IDS, function(c) return not util.contains(run.charms, c) end)
  rng.shuffle(run.rng, pool)
  local out = {}
  for i = 1, math.min(n, #pool) do out[i] = pool[i] end
  return out
end

function M.addCharm(run, c)
  if #run.charms >= charms.MAX or util.contains(run.charms, c) then return false end
  table.insert(run.charms, c)
  return true
end

-- Record a finished match: festival table, rewards, nemesis memory. Returns an outcome for the UI.
function M.resolveMatch(save, ctx)
  local run = save.run
  local f = run.festival
  local s = ctx.state
  local won = s.result == "win"
  local lostAny = false
  for _, h in ipairs(s.history) do if h.winner == 2 then lostAny = true end end
  local me, them = s.sides[1], s.sides[2]
  local out = {
    result = s.result, won = won, flawless = won and not lostAny, fish = 0, levelUps = {}, intel = {}, line = "",
    cardChoices = {}, charmChoices = {}, notes = {}, stage = ctx.stage, opp = ctx.opp,
  }
  run.nextPride = 0
  local n = ctx.nemesis
  if n then n.met = true end
  local pd = math.max(5, math.abs(math.max(0, me.pride) - math.max(0, them.pride)))

  if won then
    run.stats.won = run.stats.won + 1
    local base = ({ group = 14, qf = 24, sf = 30, final = 40 })[ctx.stage] or 14
    out.fish = base + (n and 10 or 0) + (util.contains(run.charms, "fishbone") and 8 or 0) + (out.flawless and 5 or 0)
    run.fish = run.fish + out.fish
    for _, c in ipairs(run.deck) do
      if me.scored[c.uid] and cards.getDef(c).kind == "unit" and c.level < 3 then
        c.xp = c.xp + 1
        if c.xp >= cards.XP_FOR_LEVEL[c.level + 1] then
          c.level = c.level + 1
          out.levelUps[#out.levelUps + 1] = { name = cards.getDef(c).name, level = c.level, uid = c.uid }
        end
      end
    end
    local quality = n and 3 or (ctx.stage ~= "group" and 2 or (ctx.tier >= 2 and 1 or 0))
    out.cardChoices = M.rollCards(run.rng, 3, quality)
    if n or ctx.stage ~= "group" then out.charmChoices = M.charmOffer(run, 2) end
    if n then
      out.line = nemesis.speak(run.rng, n, "beaten", save.playerName)
    else
      local targets = util.filter(save.hands, nemesis.hasSecrets)
      if #targets > 0 then
        local target = rng.pick(run.rng, targets)
        local t = nemesis.revealRandom(run.rng, target)
        if t then out.intel[#out.intel + 1] = ('The beaten stray squeals: "%s has %s! %s"'):format(target.name, traits.TRAITS[t].name, traits.TRAITS[t].desc) end
      end
      out.line = rng.pick(run.rng, { "Lucky paws, champion. Lucky paws.", "Fine. Go on, then. The crowd loves you.", "I'll be back next festival. With sharper claws.", "Tell the Hands I sent you. They won't care." })
    end
  else
    run.stats.lost = run.stats.lost + 1
    run.fish = run.fish + 5
    if n then
      n.wins = n.wins + 1
      n.level = n.level + 1
      n.growth = (n.growth or 0) + 1
      nemLog(save, n, "Beat " .. save.playerName .. " at " .. f.name .. ".")
      if not n.epithet:find("^Bane") then n.epithet = "Bane of " .. save.playerName end
      out.line = nemesis.speak(run.rng, n, "gloat", save.playerName)
      chronicle(save, n.name .. " beat " .. save.playerName .. " at " .. f.name .. ".")
    else
      out.line = rng.pick(run.rng, { "Back to your cushion, house cat.", "And they call YOU a champion?", "Remember my name. Everyone will soon.", "Hah! The fish are on me tonight." })
      ctx.opp.beatPlayer = true
    end
    if ctx.stage ~= "group" then run.knockedOutBy = ctx.opp.id end
  end
  -- reveal-on-sight: traits shown during the match become known
  if n then
    for _, kt in ipairs(n.traits) do
      local seen = util.contains(s.revealed, kt.id) or kt.id == "arrogant" or kt.id == "bodyguard" or kt.id == "hoarder" or kt.id == "sluggish"
      if not kt.known and seen then
        kt.known = true
        out.intel[#out.intel + 1] = "Learned: " .. n.name .. " has " .. traits.TRAITS[kt.id].name .. "."
      end
    end
    if ctx.spyglass then out.intel[#out.intel + 1] = "Spyglass: " .. n.name .. " has " .. traits.TRAITS[ctx.spyglass].name .. "." end
  end

  out.notes = festival.finishRound(f, { won = won, pd = pd })
  run.stallUsed = false
  if f.eliminated then
    out.eliminated = true
    festival.simulateRest(f)
  elseif f.stage == "done" then
    out.champion = f.champion == festival.PLAYER
  end
  return out
end

-- After the result screen: either the festival goes on, or the run ends.
function M.afterMatch(save)
  local f = save.run.festival
  if f.eliminated then M.finishRun(save, "defeat")
  elseif f.stage == "done" then M.finishRun(save, f.champion == festival.PLAYER and "victory" or "defeat") end
end

local function moveToFallen(save, n)
  util.removeValue(save.hands, n)
  if not util.contains(save.fallen, n) then table.insert(save.fallen, n) end
end

function M.decideFate(save, n, fate)
  local run = save.run
  n.losses = n.losses + 1
  if fate == "recruit" then
    local card = nemesis.signatureCard(n)
    run.uidc = run.uidc + 1
    table.insert(run.deck, { uid = "c" .. run.uidc, id = card.id, level = 1, xp = 0, def = card })
    n.status = "recruited"
    if run.festival then festival.withdraw(run.festival, n.id) end
    nemLog(save, n, "Swore loyalty to " .. save.playerName .. " after a flawless defeat.")
    moveToFallen(save, n)
    run.stats.recruited = run.stats.recruited + 1
    chronicle(save, n.name .. " bends the knee and joins " .. save.playerName .. ".")
    return n.name .. " joins your pride as a Legendary card."
  elseif fate == "brand" then
    n.level = math.max(1, n.level - 1)
    local w = nemesis.addTrait(run.rng, n, "weakness")
    if w then util.find(n.traits, function(t) return t.id == w end).known = true end
    n.scars = n.scars + 1
    n.epithet = "the Branded"
    nemLog(save, n, "Branded and spared by " .. save.playerName .. ".")
    run.stats.branded = run.stats.branded + 1
    chronicle(save, save.playerName .. " spared " .. n.name .. " but left a brand.")
    return n.name .. " is branded" .. (w and (" and is now " .. traits.TRAITS[w].name .. ".") or ".") .. " They will remember."
  end
  run.stats.slain = run.stats.slain + 1
  if run.festival then festival.withdraw(run.festival, n.id) end
  local survives = util.find(n.traits, function(t) return t.id == "ninelives" end) or rng.chance(run.rng, 0.25)
  if survives then
    n.status = "returning"
    n.scars = n.scars + 1
    nemLog(save, n, "Struck down by " .. save.playerName .. "... but the body was never found.")
  else
    n.status = "slain"
    nemLog(save, n, "Slain by " .. save.playerName .. ".")
  end
  moveToFallen(save, n)
  chronicle(save, save.playerName .. " struck down " .. nemesis.fullName(n) .. ".")
  return survives and (n.name .. " is dragged from the arena... the body is never found.") or (n.name .. " is slain. A Hand is empty, and they forfeit the festival.")
end

-- ---------------------------------------------------------------- market

M.CARD_PRICE = { common = 14, rare = 28, epic = 48, legendary = 85 }
M.REMOVE_PRICE, M.UPGRADE_PRICE = 20, 25

function M.makeMarket(run)
  local stock = { cards = {}, charms = {}, removed = false, upgraded = false }
  for _, id in ipairs(M.rollCards(run.rng, 4, festival.tier(run.festival) >= 4 and 2 or 1)) do
    stock.cards[#stock.cards + 1] = { id = id, price = M.CARD_PRICE[cards.CARDS[id].rarity], sold = false }
  end
  for _, id in ipairs(M.charmOffer(run, 2)) do
    stock.charms[#stock.charms + 1] = { id = id, price = charms.CHARMS[id].price, sold = false }
  end
  return stock
end

function M.upgradeCard(run, uid)
  local c = util.find(run.deck, function(x) return x.uid == uid end)
  if not c or c.level >= 3 or cards.getDef(c).kind ~= "unit" then return false end
  c.level = c.level + 1
  c.xp = cards.XP_FOR_LEVEL[c.level]
  return true
end

function M.removeCard(run, uid)
  local _, i = util.find(run.deck, function(x) return x.uid == uid end)
  if not i or #run.deck <= 10 then return false end
  table.remove(run.deck, i)
  return true
end

-- ---------------------------------------------------------------- power struggles

local function powerStruggle(save, winner, loser, exile)
  winner.level = winner.level + 1
  nemLog(save, winner, "Defeated " .. loser.name .. " in a power struggle.")
  local wi, li = util.indexOf(save.hands, winner), util.indexOf(save.hands, loser)
  local text
  if exile then
    loser.status = "exiled"
    nemLog(save, loser, "Exiled after losing to " .. winner.name .. ".")
    table.remove(save.hands, li)
    table.insert(save.fallen, loser)
    if li < wi then
      util.removeValue(save.hands, winner)
      table.insert(save.hands, li, winner)
    end
    local fresh = nemesis.generate(save.rng, nid(save), 1, save.runs)
    table.insert(save.hands, fresh)
    nemLog(save, fresh, "Claimed the empty seat after " .. loser.name .. "'s exile.")
    text = winner.name .. " mauls " .. loser.name .. ", who is exiled. " .. fresh.name .. " claims the empty seat."
    if save.run and save.run.festival then festival.withdraw(save.run.festival, loser.id) end
  else
    if li < wi then save.hands[li], save.hands[wi] = winner, loser end
    text = winner.name .. " defeats " .. loser.name .. " in a duel for rank."
  end
  chronicle(save, text)
  return text
end

-- ---------------------------------------------------------------- shrine events

local function randomSecretHand(save)
  local pool = util.filter(save.hands, nemesis.hasSecrets)
  if #pool == 0 then return nil end
  return rng.pick(save.run.rng, pool)
end

local function discordPair(save)
  local boss = M.nextHand(save)
  local pool = util.filter(save.hands, function(h) return h ~= boss end)
  return pool[#pool] or save.hands[4], pool[#pool - 1] or save.hands[3]
end

local leave = { label = "Walk away", enabled = function() return true end, apply = function() return "You leave with your tail high." end }

M.EVENTS = {
  rat = {
    title = "The Whispering Gutter",
    text = function() return 'A rat informant peeks out of a drain. "Secrets, champion. Secrets about the Hands. Only 15 fish."' end,
    choices = {
      { label = "Pay 15 fish", hint = "Reveal 2 hidden Warlord traits", enabled = function(s) return s.run.fish >= 15 end,
        apply = function(s)
          s.run.fish = s.run.fish - 15
          local out = {}
          for _ = 1, 2 do
            local h = randomSecretHand(s)
            local t = h and nemesis.revealRandom(s.run.rng, h)
            if t then out[#out + 1] = h.name .. ": " .. traits.TRAITS[t].name .. " - " .. traits.TRAITS[t].desc end
          end
          return #out > 0 and ("The rat whispers:\n" .. table.concat(out, "\n")) or "The rat has nothing new. It keeps your fish anyway."
        end },
      leave,
    },
  },
  sword = {
    title = "The Sword in the Scratching Post",
    text = function() return "A gleaming blade is stuck deep in an old scratching post. Many paws have tried." end,
    choices = {
      { label = "Pull the sword", hint = "35%: a Legendary. Otherwise -25 Pride next match.", enabled = function() return true end,
        apply = function(s)
          if rng.chance(s.run.rng, 0.35) then
            local c = rng.pick(s.run.rng, util.filter(cards.DRAFTABLE, function(x) return x.rarity == "legendary" end))
            M.addCard(s.run, c.id)
            return "It slides free! " .. c.name .. " answers your call."
          end
          s.run.nextPride = (s.run.nextPride or 0) - 25
          return 'You pull until something in your back goes "pop". -25 Pride next match.'
        end },
      leave,
    },
  },
  bard = {
    title = "A Wandering Bard",
    text = function() return "A scruffy bard with a lute made from a sardine tin offers to sing of your deeds." end,
    choices = {
      { label = "Hear a ballad", hint = "A random cat gains a level",
        enabled = function(s) return util.find(s.run.deck, function(c) return c.level < 3 and cards.getDef(c).kind == "unit" end) ~= nil end,
        apply = function(s)
          local c = rng.pick(s.run.rng, util.filter(s.run.deck, function(x) return x.level < 3 and cards.getDef(x).kind == "unit" end))
          M.upgradeCard(s.run, c.uid)
          return cards.getDef(c).name .. " is so inspired they reach level " .. c.level .. "."
        end },
      { label = "Ask for rumours", hint = "Reveal a Warlord trait", enabled = function() return true end,
        apply = function(s)
          local h = randomSecretHand(s)
          local t = h and nemesis.revealRandom(s.run.rng, h)
          return t and ('"They say ' .. h.name .. " is " .. traits.TRAITS[t].name .. ". " .. traits.TRAITS[t].desc .. '"') or "The bard only knows songs about fish."
        end },
    },
  },
  discord = {
    title = "Sow Discord",
    text = function(s)
      local a, b = discordPair(s)
      return "A forged letter could convince " .. a.name .. " that " .. b.name .. " is plotting against them. Cats are very easily offended."
    end,
    choices = {
      { label = "Forge the letter", hint = "25 fish. Two Hands fight; the loser is exiled.", enabled = function(s) return s.run.fish >= 25 end,
        apply = function(s)
          s.run.fish = s.run.fish - 25
          local a, b = discordPair(s)
          local aWins = rng.chance(s.run.rng, a.level / (a.level + b.level))
          if aWins then return powerStruggle(s, a, b, true) end
          return powerStruggle(s, b, a, true)
        end },
      leave,
    },
  },
  sabotage = {
    title = "The Warlord's Supper",
    text = function(s)
      local b = M.nextHand(s)
      return "You find the kitchen where " .. (b and b.name or "the Warlord") .. "'s supper is prepared. There is a suspicious bottle of Essence of Cucumber."
    end,
    choices = {
      { label = "Poison the supper", hint = "20 fish. Your next Hand gains a weakness, -1 level.", enabled = function(s) return s.run.fish >= 20 and M.nextHand(s) ~= nil end,
        apply = function(s)
          s.run.fish = s.run.fish - 20
          local n = M.nextHand(s)
          local w = nemesis.addTrait(s.run.rng, n, "weakness")
          if w then util.find(n.traits, function(t) return t.id == w end).known = true end
          n.level = math.max(1, n.level - 1)
          nemLog(s, n, "Was poisoned by " .. s.playerName .. " with cucumber essence.")
          return n.name .. " sees a cucumber and panics for a week." .. (w and (" They are now " .. traits.TRAITS[w].name .. ".") or "")
        end },
      leave,
    },
  },
  milk = {
    title = "Fountain of Warm Milk",
    text = function() return "An ancient fountain bubbles with warm milk. It smells... mostly fine." end,
    choices = {
      { label = "Drink deeply", hint = "+25 Pride next match", enabled = function() return true end,
        apply = function(s) s.run.nextPride = (s.run.nextPride or 0) + 25; return "Warm. Creamy. You start your next match with +25 Pride." end },
      { label = "Bottle it to sell", hint = "Gain 25 fish", enabled = function() return true end,
        apply = function(s) s.run.fish = s.run.fish + 25; return 'A merchant pays 25 fish for "artisanal fountain milk".' end },
    },
  },
  basket = {
    title = "Kittens in a Basket",
    text = function() return "Three kittens tumble out of a basket and look at you with enormous eyes." end,
    choices = {
      { label = "Adopt them", hint = "Add 2 Squire Kittens", enabled = function() return true end,
        apply = function(s) M.addCard(s.run, "squire"); M.addCard(s.run, "squire"); return "The squires swear an oath. It is mostly squeaking." end },
      leave,
    },
  },
  bookie = {
    title = "The Arena Bookmaker",
    text = function() return 'A fat tabby with a ledger offers odds on your next fight. "Double or nothing, champ."' end,
    choices = {
      { label = "Bet 20 fish", hint = "50%: win 20 more", enabled = function(s) return s.run.fish >= 20 end,
        apply = function(s)
          if rng.chance(s.run.rng, 0.5) then s.run.fish = s.run.fish + 20; return "The ledger says you win. Somehow. +20 fish." end
          s.run.fish = s.run.fish - 20
          return "The ledger says you lose. The ledger is never wrong. -20 fish."
        end },
      leave,
    },
  },
}

-- ---------------------------------------------------------------- between runs

function M.arenaMovesOn(save)
  local run = save.run
  local news = {}
  local r = save.rng
  local f = run and run.festival
  if f then
    local champ = f.champion and f.entrants[f.champion]
    if champ and champ.kind == "player" then
      news[#news + 1] = save.playerName .. " is crowned champion of " .. f.name .. "!"
    elseif champ and champ.kind == "hand" then
      local h = M.findNemesis(save, champ.id)
      if h then
        h.level = h.level + 1
        nemLog(save, h, "Won " .. f.name .. ".")
        local i = util.indexOf(save.hands, h)
        if i and i > 1 then save.hands[i], save.hands[i - 1] = save.hands[i - 1], h end
        news[#news + 1] = h.name .. " wins " .. f.name .. " and climbs the hierarchy."
      end
    elseif champ and champ.kind == "stray" then
      local promoted = nemesis.promoteStray(r, champ.foe, nid(save), save.runs, save.playerName)
      promoted.wins = champ.beatPlayer and 1 or 0
      if not champ.beatPlayer then promoted.epithet = "the Festival Champion" end
      promoted.history = { { run = save.runs, text = "A nameless stray who won " .. f.name .. "." } }
      local ousted = table.remove(save.hands)
      ousted.status = "exiled"
      table.insert(save.fallen, ousted)
      table.insert(save.hands, promoted)
      news[#news + 1] = "Nobody saw it coming: " .. champ.name .. " wins the festival and takes " .. ousted.name .. "'s seat among the Hands!"
    end
    -- a stray that knocked you out (and didn't win) may also be noticed
    local ko = run.knockedOutBy and f.entrants[run.knockedOutBy]
    if ko and ko.kind == "stray" and ko.id ~= f.champion and rng.chance(r, 0.5) then
      local promoted = nemesis.promoteStray(r, ko.foe, nid(save), save.runs, save.playerName)
      local ousted = table.remove(save.hands)
      ousted.status = "exiled"
      table.insert(save.fallen, ousted)
      table.insert(save.hands, promoted)
      news[#news + 1] = ko.name .. " is promoted to the Fourth Hand for knocking you out. " .. ousted.name .. " is cast out."
    elseif ko and ko.kind == "hand" then
      local k = M.findNemesis(save, ko.id)
      if k then news[#news + 1] = k.name .. " boasts of knocking you out. Their legend grows." end
    end
  end
  for _, n in ipairs(util.map(save.fallen, function(x) return x end)) do
    if n.status == "returning" then
      n.status = "active"
      n.level = n.level + 1
      nemesis.addTrait(r, n, "strength")
      n.epithet = "the Returned"
      nemLog(save, n, "Returned from the dead, bearing " .. rng.pick(r, nemesis.SCARS) .. ".")
      util.removeValue(save.fallen, n)
      local ousted
      if #save.hands >= 4 then
        ousted = table.remove(save.hands)
        ousted.status = "exiled"
        table.insert(save.fallen, ousted)
      end
      table.insert(save.hands, n)
      news[#news + 1] = n.name .. " has returned from the dead" .. (ousted and (", throwing " .. ousted.name .. " out of the Fourth Hand") or "") .. "."
    elseif n.status == "recruited" then
      if rng.chance(r, 0.3) then
        n.status, n.traitor, n.met, n.epithet = "active", true, false, "the Traitor"
        n.level = n.level + 1
        nemLog(save, n, "Betrayed " .. save.playerName .. " and clawed back into the hierarchy.")
        util.removeValue(save.fallen, n)
        if #save.hands >= 4 then
          local o = table.remove(save.hands)
          o.status = "exiled"
          table.insert(save.fallen, o)
        end
        table.insert(save.hands, n)
        news[#news + 1] = n.name .. ", once sworn to you, has betrayed you and rejoined the Hands!"
      else
        n.status = "exiled"
        news[#news + 1] = n.name .. " retires from the Arena, loyal to the end."
      end
    end
  end
  for _, h in ipairs(save.hands) do
    if (h.growth or 0) > 0 then
      local t = nemesis.addTrait(r, h, "strength")
      if t then news[#news + 1] = h.name .. " trained hard after beating you, and gained " .. traits.TRAITS[t].name .. "." end
      h.growth = 0
    end
  end
  while #save.hands < 4 do
    local fresh = nemesis.generate(r, nid(save), 1 + rng.int(r, 2), save.runs)
    table.insert(save.hands, fresh)
    news[#news + 1] = fresh.name .. " " .. fresh.epithet .. " claims a seat among the Hands."
  end
  if rng.chance(r, 0.5) then
    local i = 2 + rng.int(r, 3)
    local challenger, holder = save.hands[i], save.hands[i - 1]
    local wins = rng.chance(r, 0.4 + 0.1 * (challenger.level - holder.level))
    news[#news + 1] = powerStruggle(save, wins and challenger or holder, wins and holder or challenger, false)
  end
  local names = { "First", "Second", "Third", "Fourth" }
  for i, h in ipairs(save.hands) do
    local tag = "Holds the rank of " .. names[i] .. " Hand."
    local last = h.history[#h.history]
    if not last or last.text ~= tag then nemLog(save, h, tag) end
  end
  for _, t in ipairs(news) do chronicle(save, t) end
  while #save.fallen > 30 do table.remove(save.fallen, 1) end
  save.run = nil
  return news
end

return M
