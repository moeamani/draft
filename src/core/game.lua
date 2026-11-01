-- Run and meta-progression: drafting, map, duel setup/resolution, fates, events, the Arena moving on.
local cards = require("src.core.cards")
local charms = require("src.core.charms")
local duel = require("src.core.duel")
local nemesis = require("src.core.nemesis")
local rng = require("src.core.rng")
local traits = require("src.core.traits")
local util = require("src.core.util")

local M = {}

M.START_LIVES = 9
M.RINGS = 4
M.STEPS = 3
M.DRAFT_PICKS = 10
M.RING_NAMES = { "The Gutter Ring", "The Yard", "The Rooftops", "The Moon Court" }

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
    rng = rng.new(rng.int(save.rng, 1e9) + 1), number = save.runs, ring = 1, step = 0,
    lives = M.START_LIVES, fish = 20, deck = {}, charms = {}, phase = "draft",
    draftPicks = 0, draftOptions = {}, options = {}, detour = false, bossIds = {}, uidc = 0,
    stats = { won = 0, lost = 0, slain = 0, recruited = 0, branded = 0 },
  }
  for i = 4, 1, -1 do run.bossIds[#run.bossIds + 1] = save.hands[i].id end
  for _, id in ipairs({ "squire", "squire", "hedgedruid", "sunbeam" }) do M.addCard(run, id) end
  run.draftOptions = M.rollCards(run.rng, 3, 1)
  save.run = run
  return run
end

function M.draftPick(save, id)
  local run = save.run
  M.addCard(run, id)
  local d = cards.CARDS[id]
  local sibling = d and (d.ability == "litter" or d.ability == "muster")
  if sibling then M.addCard(run, id) end
  run.draftPicks = run.draftPicks + 1
  if run.draftPicks >= M.DRAFT_PICKS then
    run.phase = "map"
    run.options = M.genOptions(save)
    return true, sibling
  end
  run.draftOptions = M.rollCards(run.rng, 3, run.draftPicks % 4 == 3 and 2 or 1)
  return false, sibling
end

function M.currentBoss(save)
  local run = save.run
  return M.findNemesis(save, run.bossIds[run.ring])
end

function M.atWarlord(run) return run.step >= M.STEPS - 1 and not run.detour end

M.EVENT_IDS = { "rat", "sword", "bard", "discord", "sabotage", "milk", "basket", "bookie" }

function M.genOptions(save)
  local run = save.run
  if M.atWarlord(run) then return { { kind = "warlord" } } end
  local tier = run.ring
  local opts = { { kind = "skirmish", foe = nemesis.stray(run.rng, tier, false) } }
  local extra = rng.shuffle(run.rng, { "pit", "market", "shrine", "tavern", "shrine", "market" })
  for _, k in ipairs(extra) do
    if #opts >= 3 then break end
    if not util.find(opts, function(o) return o.kind == k end) and not (k == "tavern" and run.lives >= M.START_LIVES) then
      if k == "pit" then opts[#opts + 1] = { kind = "pit", foe = nemesis.stray(run.rng, tier, true) }
      elseif k == "shrine" then opts[#opts + 1] = { kind = "shrine", event = rng.pick(run.rng, M.EVENT_IDS) }
      else opts[#opts + 1] = { kind = k } end
    end
  end
  return rng.shuffle(run.rng, opts)
end

function M.finishRun(save, outcome)
  local run = save.run
  run.phase = "over"
  run.outcome = outcome
  if outcome == "victory" then save.victories = save.victories + 1 end
end

function M.advance(save)
  local run = save.run
  if run.detour then run.detour = false else run.step = run.step + 1 end
  if run.step >= M.STEPS then
    run.ring = run.ring + 1
    run.step = 0
    save.bestRing = math.max(save.bestRing, run.ring - 1)
    if run.ring > M.RINGS then
      M.finishRun(save, "victory")
      return
    end
  end
  run.options = M.genOptions(save)
end

-- ---------------------------------------------------------------- duels

function M.setupDuel(save, node)
  local run = save.run
  local pm, em = traits.baseMods(), traits.baseMods()
  local deck, foeName, n, personality, spyglass
  if node.kind == "warlord" then
    n = M.currentBoss(save)
    traits.apply(em, nemesis.traitIds(n), n.wins)
    deck = nemesis.nemesisDeck(run.rng, n, run.ring)
    foeName, personality = n.name, n.personality
    if util.contains(run.charms, "spyglass") then spyglass = nemesis.revealRandom(run.rng, n) end
  else
    local foe = node.foe
    deck = nemesis.strayDeck(run.rng, foe)
    foeName, personality = foe.name, foe.personality
    if foe.elite then traits.apply(em, { rng.pick(run.rng, { "warlord", "archmage", "hoarder", "vengeful" }) }, 0) end
    if run.ring <= 2 then em.extraDraw = em.extraDraw - 1 end
  end
  charms.apply(pm, em, run.charms)
  local state = duel.create({ name = save.playerName, deck = run.deck, mods = pm }, { name = foeName, deck = deck, mods = em },
    rng.int(run.rng, 1e9) + 1, rng.chance(run.rng, 0.5) and 1 or 2)
  return { node = node, foeName = foeName, nemesis = n, state = state, personality = personality, spyglass = spyglass }
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

function M.resolveDuel(save, ctx)
  local run = save.run
  local s = ctx.state
  local result = s.result or "loss"
  local flawless = result == "win" and s.sides[1].gems == 2
  local out = { result = result, flawless = flawless, fish = 0, livesLost = 0, levelUps = {}, intel = {}, line = "", cardChoices = {}, charmChoices = {}, runOver = false }
  local n = ctx.nemesis
  if n then
    for _, t in ipairs(s.revealed[2]) do
      local kt = util.find(n.traits, function(x) return x.id == t end)
      if kt and not kt.known then
        kt.known = true
        out.intel[#out.intel + 1] = "Learned: " .. n.name .. " has " .. traits.TRAITS[t].name .. "."
      end
    end
    if ctx.spyglass then out.intel[#out.intel + 1] = "Spyglass: " .. n.name .. " has " .. traits.TRAITS[ctx.spyglass].name .. "." end
    n.met = true
  end

  if result == "win" then
    run.stats.won = run.stats.won + 1
    local k = ctx.node.kind
    local base = k == "warlord" and (30 + 10 * run.ring) or k == "pit" and (22 + 5 * run.ring) or (12 + 4 * run.ring)
    out.fish = base + (util.contains(run.charms, "fishbone") and 8 or 0) + (flawless and 5 or 0)
    run.fish = run.fish + out.fish
    local played = {}
    for _, uid in ipairs(s.sides[1].played) do played[uid] = true end
    for _, c in ipairs(run.deck) do
      if played[c.uid] and cards.getDef(c).kind == "unit" and c.level < 3 then
        c.xp = c.xp + 1
        if c.xp >= cards.XP_FOR_LEVEL[c.level + 1] then
          c.level = c.level + 1
          out.levelUps[#out.levelUps + 1] = { name = cards.getDef(c).name, level = c.level, uid = c.uid }
        end
      end
    end
    local quality = k == "warlord" and 3 or k == "pit" and 2 or (run.ring >= 3 and 1 or 0)
    out.cardChoices = M.rollCards(run.rng, 3, quality)
    if k == "warlord" then
      out.charmChoices = M.charmOffer(run, 2)
      out.line = nemesis.speak(run.rng, n, "beaten", save.playerName)
    else
      local targets = util.filter(save.hands, nemesis.hasSecrets)
      if #targets > 0 then
        local target = rng.pick(run.rng, targets)
        local t = nemesis.revealRandom(run.rng, target)
        if t then out.intel[#out.intel + 1] = ('The beaten stray squeals: "%s has %s! %s"'):format(target.name, traits.TRAITS[t].name, traits.TRAITS[t].desc) end
      end
    end
  else
    run.stats.lost = run.stats.lost + 1
    out.livesLost = result == "draw" and 1 or (ctx.node.kind == "warlord" and 3 or 2)
    run.lives = math.max(0, run.lives - out.livesLost)
    if n then
      n.wins = n.wins + 1
      n.level = n.level + 1
      n.growth = (n.growth or 0) + 1
      nemLog(save, n, "Defeated " .. save.playerName .. " in ring " .. run.ring .. ".")
      if not n.epithet:find("^Bane") then n.epithet = "Bane of " .. save.playerName end
      out.line = nemesis.speak(run.rng, n, "gloat", save.playerName)
      chronicle(save, n.name .. " defeated " .. save.playerName .. " and grows in power (level " .. n.level .. ").")
      run.detour = true
    elseif ctx.node.foe then
      out.line = "The stray licks its paw, unimpressed."
      if run.lives <= 0 or rng.chance(run.rng, 0.25) then
        local promoted = nemesis.promoteStray(run.rng, ctx.node.foe, nid(save), save.runs, save.playerName)
        local ousted = table.remove(save.hands)
        ousted.status = "exiled"
        nemLog(save, ousted, "Ousted from the Fourth Hand by " .. promoted.name .. ".")
        table.insert(save.fallen, ousted)
        table.insert(save.hands, promoted)
        out.promoted = promoted.name .. " is promoted to the Fourth Hand for beating you! " .. ousted.name .. " is cast out."
        chronicle(save, out.promoted)
        local bi = util.indexOf(run.bossIds, ousted.id)
        if bi then run.bossIds[bi] = promoted.id end
      end
    end
    if run.lives <= 0 then
      run.killedBy = n and n.id or nil
      out.runOver = true
    end
  end
  return out
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
  return survives and (n.name .. " falls into the river... the body is never found.") or (n.name .. " is slain. A Hand is empty.")
end

-- ---------------------------------------------------------------- market

M.CARD_PRICE = { common = 14, rare = 28, epic = 48, legendary = 85 }
M.REMOVE_PRICE, M.UPGRADE_PRICE = 20, 25

function M.makeMarket(run)
  local stock = { cards = {}, charms = {}, removed = false, upgraded = false }
  for _, id in ipairs(M.rollCards(run.rng, 4, run.ring >= 3 and 2 or 1)) do
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
    if save.run then
      local bi = util.indexOf(save.run.bossIds, loser.id)
      if bi then save.run.bossIds[bi] = fresh.id end
    end
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
  local boss = M.currentBoss(save)
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
      { label = "Pull the sword", hint = "35%: a Legendary. Otherwise lose 2 lives.", enabled = function(s) return s.run.lives > 2 end,
        apply = function(s)
          if rng.chance(s.run.rng, 0.35) then
            local c = rng.pick(s.run.rng, util.filter(cards.DRAFTABLE, function(x) return x.rarity == "legendary" end))
            M.addCard(s.run, c.id)
            return "It slides free! " .. c.name .. " answers your call."
          end
          s.run.lives = s.run.lives - 2
          return 'You pull until something in your back goes "pop". Lose 2 lives.'
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
      local b = M.currentBoss(s)
      return "You find the kitchen where " .. (b and b.name or "the Warlord") .. "'s supper is prepared. There is a suspicious bottle of Essence of Cucumber."
    end,
    choices = {
      { label = "Poison the supper", hint = "20 fish. Your Warlord gains a weakness, loses a level.", enabled = function(s) return s.run.fish >= 20 and M.currentBoss(s) ~= nil end,
        apply = function(s)
          s.run.fish = s.run.fish - 20
          local n = M.currentBoss(s)
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
      { label = "Drink deeply", hint = "Gain 2 lives", enabled = function(s) return s.run.lives < M.START_LIVES end,
        apply = function(s) s.run.lives = math.min(M.START_LIVES, s.run.lives + 2); return "Warm. Creamy. You feel two lives younger." end },
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
  if run and run.outcome == "defeat" and run.killedBy then
    local k = M.findNemesis(save, run.killedBy)
    if k then news[#news + 1] = k.name .. " boasts of ending your run. Their legend grows." end
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
