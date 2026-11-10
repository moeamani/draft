-- Story mode: "Stray to Champion".
--
-- A nameless stray is taught the cushion duel by Old Bedimew (the prologue doubles as the
-- tutorial), then fights through five Arena festivals. Each chapter is a full festival with a
-- goal; the Four Hands are the villains, and their lines are spoken by whoever holds each rank
-- when the chapter is played (the nemesis system keeps running between chapters). Your pride,
-- your charms and the cats the Hands captured carry from chapter to chapter. Fail a chapter and
-- you can retry it from where you started it.
--
-- Above them all sits the Overseer, the flaming shadow cat who keeps the Arena's ledger. It
-- watches from the start, shows itself when you take the Gilded Saucer, and the last chapter is
-- one match at its own table, where it sees through every card back.
local cards = require("src.core.cards")
local festival = require("src.core.festival")
local game = require("src.core.game")
local rng = require("src.core.rng")
local util = require("src.core.util")

local M = {}

M.CHAPTERS = {
  { numeral = "I", title = "Midsummer", fest = 1, goal = "knockouts", goalText = "Reach the knockouts" },
  { numeral = "II", title = "The Harvest Moot", fest = 2, goal = "beatHand4", goalText = "Defeat the Fourth Hand" },
  { numeral = "III", title = "The Winter Yowl", fest = 4, goal = "semi", goalText = "Reach the semi-finals" },
  { numeral = "IV", title = "Moonlit Mews", fest = 6, goal = "final", goalText = "Reach the final" },
  { numeral = "V", title = "The Gilded Saucer", fest = 5, goal = "win", goalText = "Win the festival and dethrone the First Hand" },
  { numeral = "VI", title = "The High Table", boss = "overseer", goalText = "Beat the Overseer at its own table" },
}
M.LAST = #M.CHAPTERS

-- ---------------------------------------------------------------- the save

function M.newStory(seed)
  local save = game.newSave("Stray", seed or os.time())
  save.story = { chapter = 0, named = false, done = {}, failed = false }
  return save
end

function M.chapter(save) return save.story and M.CHAPTERS[save.story.chapter] end

function M.progressLine(save)
  local st = save.story
  if not st then return "Continue the story" end
  if st.chapter == 0 then return "Prologue: The Bin Yard" end
  if st.chapter > M.LAST then return ("Champion %s. The story is told."):format(save.playerName) end
  local ch = M.CHAPTERS[st.chapter]
  if ch.boss then return ("Chapter %s: %s"):format(ch.numeral, ch.title) end
  local live = save.run and save.run.phase ~= "over"
  return ("Chapter %s: %s%s"):format(ch.numeral, ch.title, live and " (in progress)" or "")
end

-- ---------------------------------------------------------------- chapters

local function copyDeck(deck)
  local out = {}
  for i, c in ipairs(deck) do out[i] = { uid = c.uid, id = c.id, level = c.level, xp = c.xp, def = c.def, print = c.print, fakeBack = c.fakeBack } end
  return out
end

-- Start (or restart) the current chapter's festival. The pride carries over from the last one.
function M.startChapter(save)
  local st = save.story
  local ch = M.CHAPTERS[st.chapter]
  local prev = save.run
  if st.failed and st.snapshot then
    -- a retry: the pride as it was when the chapter began, and the Hands give back what they took
    for _, n in ipairs(save.hands) do
      n.captives = util.filter(n.captives or {}, function(c) return c.chapter ~= st.chapter end)
    end
  end
  local snap = (st.failed and st.snapshot) or (prev and {
    deck = copyDeck(prev.deck), charms = util.deepcopy(prev.charms), fish = prev.fish, uidc = prev.uidc,
  }) or nil
  save.runs = save.runs + 1
  local run = {
    rng = rng.new(rng.int(save.rng, 1e9) + 1), number = save.runs, fish = 25, deck = {}, charms = {},
    phase = "hub", stallUsed = false, nextGoblets = 0, uidc = 0, cushions = { false, false, false },
    stats = { won = 0, lost = 0, slain = 0, recruited = 0, branded = 0 }, story = true,
  }
  if snap then
    run.deck, run.charms, run.uidc = copyDeck(snap.deck), util.deepcopy(snap.charms), snap.uidc or 0
    run.fish = math.max(25, math.floor((snap.fish or 0) * 0.5) + 25)
  else
    game.dealStarterDeck(run)
  end
  st.snapshot = { deck = copyDeck(run.deck), charms = util.deepcopy(run.charms), fish = run.fish, uidc = run.uidc }
  st.failed = false
  run.festival = festival.create(save, rng.int(run.rng, 1e9) + 1, ch.fest)
  run.storyTarget = save.hands[4] and save.hands[4].id
  save.run = run
  return run
end

-- How far the player got in this festival: 0 groups, 1 quarter-finals, 2 semis, 3 final, 4 champion.
function M.reached(f)
  if f.placing then return ({ group = 0, qf = 1, sf = 2, runnerup = 3, champion = 4 })[f.placing] or 0 end
  return ({ group = 0, qf = 1, sf = 2, final = 3, done = 3 })[f.stage] or 0
end

function M.goalMet(save)
  local ch = M.chapter(save)
  local run = save.run
  if not ch or not run then return false end
  local r = M.reached(run.festival)
  if ch.goal == "knockouts" then return r >= 1
  elseif ch.goal == "beatHand4" then return (run.beatHands or {})[run.storyTarget] == true
  elseif ch.goal == "semi" then return r >= 2
  elseif ch.goal == "final" then return r >= 3
  elseif ch.goal == "win" then return r >= 4 end
  return false
end

-- The festival ended: move the story on (or mark the chapter for a retry). Returns "won" or "lost".
function M.finishChapter(save)
  local st = save.story
  local won = M.goalMet(save)
  if won then
    st.done[st.chapter] = true
    st.chapter = st.chapter + 1
    st.failed = false
    st.snapshot = nil
  else
    st.failed = true
  end
  game.arenaMovesOn(save)
  return won and "won" or "lost"
end

-- ---------------------------------------------------------------- the High Table

M.BOSS = { name = "The Overseer", id = "overseer", kind = "overseer", coat = "shadow", title = "Keeper of the Ledger" }
-- How strong the Overseer's table is. tests/run.lua reports how often the AI beats it.
-- Its eye is worth a lot: with these, the AI wins about a third of the time with a late pride.
M.BOSS_TUNING = { sigLevel = 1, rarity = "rare", count = 10, level = 1, goblets = 1, style = "default" }

-- The final match: your pride as the Gilded Saucer left it, against the Overseer's deck (the
-- Four Hands' signature cats and the Arena's best rares), an extra goblet, and the Overseer's
-- eye: when it answers, it sees your cards face up.
function M.bossMatch(save)
  local match = require("src.core.match")
  local nemesis = require("src.core.nemesis")
  local traits = require("src.core.traits")
  local charms = require("src.core.charms")
  local run = save.run or {}
  local mine = copyDeck(run.deck or {})
  if #mine == 0 then
    local tmp = { deck = {}, uidc = 0, rng = rng.new(save.nextId + 7) }
    game.dealStarterDeck(tmp)
    mine = tmp.deck
  end
  local deck, uid = {}, 0
  local function add(id, def, level)
    uid = uid + 1
    deck[#deck + 1] = { uid = "ov" .. uid, id = id, def = def, level = level or 2, xp = 0 }
  end
  local tune = M.BOSS_TUNING
  for _, n in ipairs(save.hands) do
    local d = nemesis.signatureCard(n)
    add(d.id, d, tune.sigLevel)
  end
  local best = util.filter(cards.DRAFTABLE, function(d) return d.kind == "unit" and d.rarity == tune.rarity end)
  table.sort(best, function(a, b) if a.power ~= b.power then return a.power > b.power end return a.id < b.id end)
  for i = 1, math.min(tune.count, #best) do add(best[i].id, nil, tune.level) end
  add("moonfog", nil, 1)
  add("hairball", nil, 1)
  local pm, em = traits.baseMods(), traits.baseMods()
  charms.apply(pm, run.charms or {})
  em.goblets = em.goblets + tune.goblets
  em.allSeeing = true
  local state = match.create({ name = save.playerName, deck = mine, mods = pm, cushions = run.cushions },
    { name = M.BOSS.name, deck = deck, mods = em }, rng.int(save.rng, 1e9) + 1, match.STYLES[tune.style])
  return { opp = M.BOSS, state = state, stage = "final", tier = 7, personality = "schemer", boss = true }
end

-- The High Table is settled: win, and the story is told; lose, and you climb the stairs again.
function M.finishBoss(save, won)
  local st = save.story
  if won then
    st.done[st.chapter] = true
    st.chapter = st.chapter + 1
    st.failed = false
  else
    st.failed = true
  end
  return won and "won" or "lost"
end

-- ---------------------------------------------------------------- the script
-- Lines are { who, text }. who: "bedimew", "crier", "you", "narrator", "overseer", "hand1".."hand4".
-- {name} is the player's name, {hand1}..{hand4} the Hands' names, {omen} the festival's omen.

local SCRIPT = {
  prologue_intro = {
    { "narrator", "Rain over the Arena city. Somewhere behind the fish market, a stray is losing a fight with a bin lid." },
    { "bedimew", "You there. Yes, you, with the lid. You've got a knight's claws and the manners of a bin." },
    { "you", "Mrrp?" },
    { "bedimew", "I'm Bedimew. Knight of the Round Cushion, once. Now I keep the straw yard and remember things." },
    { "bedimew", "The Midsummer Festival opens at dawn. Sixteen cats, one Arena, and the Four Hands sitting on top of it all." },
    { "bedimew", "You want in? Then show me you can sit on a cushion without falling off it. Practice match. Now." },
    { "narrator", "High above the straw yard, in a box nobody sits in, two red eyes open." },
    { "overseer", "Another stray at my gates. Let's see how long this one lasts." },
  },
  prologue_outro = {
    { "bedimew", "Not bad for a bin cat. Not bad at all." },
    { "bedimew", "Remember the lives. A lost duel costs a cat one. Lose by five or more and it costs two." },
    { "bedimew", "Run out, and the rival carries your cat off. The Four Hands keep what they catch, and they'll send your own cats at you." },
    { "bedimew", "But a captive fights at one life. Beat it, and it comes home. Beat the Hand who holds it, and they all come home." },
    { "bedimew", "Now. A knight needs a name. What do they call you?", ask = "name" },
    { "bedimew", "{name}. Good. I'll get you through the gate. The rest is claws." },
    { "overseer", "{name}. I'll write that down." },
  },
  [1] = {
    intro = {
      { "crier", "Hear ye! The Midsummer Festival of Claws is open! Sixteen cats! Four groups! One Arena!" },
      { "crier", "Under the {omen}: {omendesc}" },
      { "hand4", "A stray? In MY group? The Arena really has let itself go." },
      { "bedimew", "That's {hand4}, the Fourth Hand. Lowest of the four, loudest by far. Ignore the noise. Finish in the top two of your group." },
    },
    won = {
      { "crier", "{name} the stray goes through to the knockouts! The crowd doesn't know that name yet. They will!" },
      { "hand4", "Lucky paws. Next festival, I'll be ready for you." },
      { "bedimew", "They will be. So will we." },
      { "overseer", "Through the gate. The ledger has a new line in it." },
    },
    lost = {
      { "bedimew", "Out in the groups. It happens to every knight once." },
      { "bedimew", "Lick your wounds. We go again." },
    },
  },
  [2] = {
    intro = {
      { "crier", "Hear ye! The Harvest Moot! Under the {omen}: {omendesc}" },
      { "hand4", "You again. I've been training. I've been training SO hard." },
      { "bedimew", "{hand4} is in your group again. Beat them. A Hand who loses to a stray loses face, and the other three will notice." },
    },
    won = {
      { "hand4", "Impossible. A STRAY." },
      { "hand3", "Interesting. The Fourth Hand falls to a bin cat. I'll be watching you, {name}." },
      { "bedimew", "That was {hand3}, the Third Hand. Clever, cold and patient. Now they know your name." },
      { "overseer", "The Fourth Hand falls to a stray. I do enjoy a reshuffle." },
    },
    lost = {
      { "hand4", "Back to the bins with you!" },
      { "bedimew", "They have to beat you every time. You only have to beat them once. Again." },
    },
  },
  [3] = {
    intro = {
      { "crier", "Hear ye! The Winter Yowl! Under the {omen}: {omendesc}" },
      { "hand3", "Every festival you climb a little higher, {name}. Let's see how you like the cold up here." },
      { "bedimew", "Reach the semi-finals. Pick your coats with care: in the cold, the edge cuts deeper." },
      { "bedimew", "And {name}... the Hands didn't build this Arena. Something put them on those cushions. Don't look up at the high box." },
    },
    won = {
      { "crier", "{name} reaches the semi-finals! Somebody fetch this stray a proper cushion!" },
      { "hand2", "The semi-finals. Cute. The Second Hand doesn't do cute." },
      { "bedimew", "{hand2}. Second Hand, first in cruelty. Mind your lives around that one." },
    },
    lost = {
      { "bedimew", "The cold got into your paws. Warm up, and we go again." },
    },
  },
  [4] = {
    intro = {
      { "crier", "Hear ye! The Moonlit Mews! Under the {omen}: {omendesc}" },
      { "hand2", "I've kept a cushion warm for you, {name}. Right next to all the cats I've taken from strays like you." },
      { "bedimew", "Reach the final. After that, there's only one Hand above you." },
    },
    won = {
      { "crier", "{name} in the final! A stray in the final! The fish sellers are weeping with joy!" },
      { "hand1", "So you're the stray. I've heard the purring. Come to the Gilded Saucer, and I'll end it there." },
      { "bedimew", "{hand1}. The First Hand. They've held the Arena since before your whiskers grew." },
      { "overseer", "One Hand left above you, little stray. And then there's me." },
    },
    lost = {
      { "bedimew", "So close. The moon will rise again. So will you." },
    },
  },
  [5] = {
    intro = {
      { "crier", "Hear ye! The Tourney of the Gilded Saucer! The finest cats in the land, under the {omen}: {omendesc}" },
      { "hand1", "Every cat in this Arena bows to me, {name}. Today you'll learn why." },
      { "bedimew", "Win it all. Then the Arena bows to you." },
    },
    won = {
      { "crier", "Hear ye, hear ye! The champion of the Gilded Saucer is... {name}! The stray from the bins!" },
      { "hand1", "...Well fought. Enjoy the crown. It's heavier than it looks." },
      { "bedimew", "From a bin lid to the Gilded Saucer. Sir {name}. I always knew. Mostly." },
      { "narrator", "The lamps gutter. The crowd goes quiet. In the high box, fire." },
      { "overseer", "Bravo. Truly. A stray on the Gilded Saucer." },
      { "overseer", "Did you think the Four Hands ruled my Arena? They keep my cushions warm. Nothing more." },
      { "overseer", "Come up to the High Table, champion. One match. Win, and the Arena is yours." },
      { "bedimew", "The Overseer. So it's real. {name}, whatever happens up there, you've already done what no stray has." },
    },
    lost = {
      { "hand1", "Bow, stray." },
      { "bedimew", "Not today. But you're the only cat who's ever made the First Hand sweat. We go again." },
    },
  },
}

SCRIPT[6] = {
  intro = {
    { "narrator", "Up the stairs nobody climbs, to the high box over the Arena. The table is already laid." },
    { "overseer", "Sit. Mind the flames." },
    { "overseer", "I see every card you hold, {name}. Backs, fronts, the lot. I always have." },
    { "bedimew", "Then hide nothing. Play it straight, hold your cushions, and keep them warm." },
  },
  won = {
    { "overseer", "...Well. The ledger says you won." },
    { "overseer", "Keep the Arena, champion. I'll be watching. I'm always watching." },
    { "narrator", "And so a stray beat the Overseer at its own table. The Four Hands bow, the crowd roars, and high above, two red eyes close, amused." },
    { "narrator", "Free Festivals are open from the main menu. The Hands are waiting, and so is the ledger." },
  },
  lost = {
    { "overseer", "Back down the stairs, little stray. The table will be here when you're braver." },
    { "bedimew", "It sees your cards. It doesn't see what you'll do with them. Again." },
  },
}

local function fill(save, text)
  local omen = save.run and festival.omen(save.run.festival)
  text = text:gsub("{name}", save.playerName)
  for r = 1, 4 do
    local n = save.hands[r]
    text = text:gsub("{hand" .. r .. "}", n and n.name or ("the " .. ({ "First", "Second", "Third", "Fourth" })[r] .. " Hand"))
  end
  text = text:gsub("{omen}", omen and omen.name or "festival sky")
  text = text:gsub("{omendesc}", omen and omen.desc or "")
  return text
end

-- The lines for a moment: "prologue_intro", "prologue_outro", or "intro" / "won" / "lost" for
-- the current chapter. A chapter intro also reminds you of the cats the Hands are holding.
function M.lines(save, moment, chapter)
  chapter = chapter or (save.story and save.story.chapter)
  local src = SCRIPT[moment] or (SCRIPT[chapter] and SCRIPT[chapter][moment]) or {}
  local out = {}
  for _, l in ipairs(src) do out[#out + 1] = { who = l[1], text = l[2], ask = l.ask } end
  if moment == "intro" then
    for r, n in ipairs(save.hands) do
      local caps = n.captives or {}
      if #caps > 0 then
        local names = {}
        for i = 1, math.min(2, #caps) do names[i] = cards.getDef(caps[i]).name end
        local more = #caps > 2 and (" and " .. (#caps - 2) .. " more") or ""
        out[#out + 1] = { who = "bedimew", text = ("And %s still holds your %s. Beat them, and they come home."):format(n.name, table.concat(names, " and ") .. more) }
        break
      end
    end
  end
  return out
end

M.fill = fill

-- Who a speaker is, for the cutscene: name, plate colour key, portrait kind.
function M.speaker(save, who)
  if who == "bedimew" then return "Old Bedimew", "gold" end
  if who == "crier" then return "The Crier", "blue" end
  if who == "you" then return save.story and save.story.named and save.playerName or "The Stray", "ink" end
  if who == "narrator" then return nil, "night" end
  if who == "overseer" then return "The Overseer", "night" end
  local r = tonumber(who:match("hand(%d)"))
  if r and save.hands[r] then return save.hands[r].name, "red", save.hands[r], r end
  return who, "ink"
end

return M
