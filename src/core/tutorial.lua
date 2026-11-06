-- The prologue's practice match against Old Bedimew: a real match with dealt hands and a
-- scripted first bout, so every lesson lands. Steps wait for the player to do the thing they
-- describe (put the Tide cat facing the Ember back, press Charge...), then move on.
local cards = require("src.core.cards")
local match = require("src.core.match")
local traits = require("src.core.traits")

local M = {}
M.__index = M

local n = 0
local function inst(id)
  n = n + 1
  return { uid = "tut" .. n, id = id, level = 1, xp = 0 }
end

-- The match: four goblets each, fixed hands. Bedimew leads bout 1 with an Ember, a Gilt and a
-- dark-backed trick, so the coat edge and the crushing capture both show up.
function M.setup()
  local mods1, mods2 = traits.baseMods(), traits.baseMods()
  mods1.goblets, mods2.goblets = -3, -3
  local myHand = { inst("pikecat"), inst("barnbrawler"), inst("gareth"), inst("hedgedruid"), inst("agravain") }
  local myDeck = { inst("candlewitch"), inst("seer"), inst("artheline"), inst("kaytail"), inst("ironpaw"), inst("novice") }
  local hisHand = { inst("kaytail"), inst("squire"), inst("sunbeam"), inst("agravain"), inst("gawpaw") }
  local hisDeck = { inst("pelliroar"), inst("mewdred"), inst("circaleus"), inst("lamoracat"), inst("purrlinore"), inst("kaytail") }
  local s = match.create({ name = "You", deck = {}, mods = mods1 }, { name = "Old Bedimew", deck = {}, mods = mods2 }, 7, match.STYLES.default)
  local function prep(list)
    for _, c in ipairs(list) do c.lives = cards.maxLives(cards.getDef(c)) end
    return list
  end
  s.sides[1].hand, s.sides[1].deck = prep(myHand), prep(myDeck)
  s.sides[2].hand, s.sides[2].deck = prep(hisHand), prep(hisDeck)
  for si = 1, 2 do
    local counts = {}
    for _, list in ipairs({ s.sides[si].hand, s.sides[si].deck }) do
      for _, c in ipairs(list) do counts[c.id] = (counts[c.id] or 0) + 1 end
    end
    s.sides[si].counts = counts
  end
  -- bout 1: Bedimew leads Kaytail (Ember), Squire Kitten (Gilt) and a Sunbeam (dark back)
  s.sides[2].placed = { s.sides[2].hand[1], s.sides[2].hand[2], s.sides[2].hand[3] }
  s.sides[2].shown = {}
  s.tutorial = true
  return { opp = { name = "Old Bedimew", id = "bedimew", kind = "mentor", coat = "gilt", title = "Retired Knight" }, state = s, stage = "practice", tier = 1, personality = "default" }
end

-- ---------------------------------------------------------------- steps

local function slotHas(scene, i, id)
  local uid = scene.slots[i]
  if not uid then return false end
  local v = scene.views[uid]
  return v and v.def.id == id
end

M.STEPS = {
  { text = "Welcome to the table. I lead this bout: I've put three cards face down on my cushions. You answer them.", next = true },
  { text = "A card's back shows its coat. Ember beats Gilt, Gilt beats Tide, Tide beats Ember, and the winning coat gets +3 Paws.", next = true },
  { text = "My left card has an Ember back. Drag your Tide cat, Tabby Pikecat, onto your left cushion.", target = { "cushion", 1 }, card = "pikecat",
    done = function(sc) return slotHas(sc, 1, "pikecat") end },
  { text = "My middle card is Gilt, and Ember beats Gilt. Put Barn Brawler on your middle cushion.", target = { "cushion", 2 }, card = "barnbrawler",
    done = function(sc) return slotHas(sc, 2, "barnbrawler") end },
  { text = "A dark back is a Shadow cat or a trick: you can't tell which. Put Agravain on your right cushion.", target = { "cushion", 3 }, card = "agravain",
    done = function(sc) return slotHas(sc, 3, "agravain") end },
  { text = "Now press Charge!", target = { "charge" }, charge = true, done = function(sc) return sc.s.bout >= 2 and not sc.busy end },
  { text = "See the hearts on each card? Those are its lives. A lost duel costs one; lose by 5 or more and it costs two. You crushed my Squire Kitten, so you captured it.", next = true },
  { text = "Out of lives, a cat changes sides. In the Arena, the Four Hands keep the cats they capture, and send them back at you. Mind your hearts.", next = true },
  { text = "And my Sunbeam put your Agravain to sleep. Tricks don't fight, but they spoil the cat facing them.", next = true },
  { text = "Now you lead. I'll only see your card backs. Put down any cats you like and Charge!", target = { "charge" }, charge = true,
    done = function(sc) return sc.s.bout >= 3 or sc.s.over end },
  { text = "That's the whole game. Hover any card to read it in full. Now knock off my last goblets!", next = true, last = true },
}

function M.new(scene)
  return setmetatable({ scene = scene, i = 1, t = 0 }, M)
end

function M:step() return M.STEPS[self.i] end
function M:active() return self.i <= #M.STEPS end

-- Charge is only allowed when the step says so (or once the lessons are over).
function M:allowCharge()
  local st = self:step()
  return not st or st.charge or false
end

function M:update(dt)
  self.t = self.t + dt
  local st = self:step()
  if st and st.done and st.done(self.scene) then self:advance() end
end

function M:advance()
  self.i = self.i + 1
  self.t = 0
end

return M
