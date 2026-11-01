-- Card database. The first entries come from the Figma card sheet.
local M = {}

-- Abilities trigger when the cat is scored as part of a Formation.
-- Specials ("Tricks") are played alongside cats; they never count toward the Formation.
M.ABILITIES = {
  none = { name = "Steadfast", desc = "No ability. Just a very good cat." },
  smite = { name = "Sword Hammer", desc = "When scored: x2 Cheer." },
  inspire = { name = "Aural Orb", desc = "When scored: +2 Cheer for each other Magic cat scored." },
  hex = { name = "Black Cat", desc = "When scored: the rival loses 6 Paws." },
  litter = { name = "Litter", desc = "When scored: +6 Paws for each other scored cat of the same coat." },
  pounce = { name = "Pounce", desc = "When scored: +12 Paws if your coat beats the rival's coat." },
  ninelives = { name = "Nine Lives", desc = "Returns to your hand after scoring (once per match)." },
  stray = { name = "Stray", desc = "When played: draw 2 extra cards next exchange." },
  groom = { name = "Groom", desc = "When scored: heal 6 Pride." },
  purr = { name = "Purr", desc = "When scored: +3 Paws for every other scored cat." },
  yowl = { name = "War Yowl", desc = "When scored: your strongest other scored cat scores again." },
  muster = { name = "Call the Pride", desc = "When scored: +1 Cheer for each copy of this cat in your deck." },
  downpour = { name = "Downpour", desc = "Trick: the rival's Cheer -2 this exchange. Cats hate rain." },
  moonfog = { name = "Moonfog", desc = "Trick: the rival's strongest scored cat is lost in the fog." },
  sunbeam = { name = "Sunbeam", desc = "Trick: +3 Cheer." },
  warhorn = { name = "Rallying Yowl", desc = "Trick: x1.5 Cheer." },
  box = { name = "Cardboard Box", desc = "Trick: one of your cats counts as any coat. If it fits, it sits." },
  hairball = { name = "Hairball", desc = "Trick: the rival's Cheer is halved this exchange." },
}

M.COATS = {
  ember = { name = "Ember", color = { 0.91, 0.28, 0.23 }, beats = "gilt", desc = "Ginger fire-coats. Ember scorches Gilt." },
  gilt = { name = "Gilt", color = { 0.83, 0.64, 0.0 }, beats = "tide", desc = "Golden noble-coats. Gilt dams the Tide." },
  tide = { name = "Tide", color = { 0.14, 0.47, 0.97 }, beats = "ember", desc = "Blue-grey sea-coats. Tide drowns Ember." },
  shadow = { name = "Shadow", color = { 0.55, 0.6, 0.66 }, beats = nil, desc = "Black cats. No advantage, but they Hex." },
}
M.COAT_ADVANTAGE = 2

M.RARITY_COLOR = {
  common = { 0.86, 0.84, 0.78 },
  rare = { 0.14, 0.47, 0.97 },
  epic = { 0.91, 0.28, 0.23 },
  legendary = { 0.83, 0.64, 0.0 },
}

local function u(id, name, type_, power, ability, rarity, coat, flavor)
  return { _def = true, id = id, name = name, kind = "unit", type = type_, power = power, ability = ability, rarity = rarity, coat = coat, flavor = flavor }
end
local function sp(id, name, ability, rarity, flavor)
  return { _def = true, id = id, name = name, kind = "special", power = 0, ability = ability, rarity = rarity, coat = "none", flavor = flavor }
end

M.LIST = {
  -- From the Figma sheet
  u("artheline", "Artheline", "physical", 20, "smite", "legendary", "gilt", "Drew the Sword Hammer from the scratching post. The once and future queen of the alley."),
  u("merline", "Merline", "magic", 15, "inspire", "legendary", "tide", "Her Aural Orb hums at the frequency of a contented purr."),
  u("lanceline", "Lanceline", "magic", 7, "hex", "epic", "shadow", "Crosses your path on purpose."),
  u("morgelius", "Morgelius", "magic", 5, "hex", "rare", "shadow", "Knocked a goblet off the Round Table. Unrepentant."),
  u("circaleus", "Circaleus", "magic", 3, "hex", "common", "shadow", "Walks in circles. Curses in circles."),
  u("purrceval", "Purrceval", "magic", 5, "hex", "rare", "shadow", "Quests for the Holy Grail. Will settle for the holy gravy."),
  u("purrlinore", "Purrlinore", "magic", 4, "hex", "common", "shadow", "Hunts the Questing Mouse, forever."),
  u("mordraleus", "Mordraleus", "magic", 8, "hex", "epic", "shadow", "His shadow arrives a second before he does."),
  u("merlinus", "Merlinus", "magic", 2, "hex", "common", "shadow", "An apprentice of bad luck. Studying hard."),
  -- Vanguard
  u("uther", "Uther Pawndragon", "physical", 12, "yowl", "legendary", "ember", "When he yowls, the whole line stands taller."),
  u("greenmouser", "The Green Mouser", "physical", 11, "ninelives", "legendary", "tide", "Lost his head once. Grew it back."),
  u("mewdred", "Mewdred", "physical", 9, "pounce", "epic", "ember", "Rightful heir to absolutely nothing."),
  u("galahiss", "Galahiss the Pure", "physical", 8, "groom", "epic", "gilt", "So clean. So very clean."),
  u("gawpaw", "Sir Gawpaw", "physical", 6, "pounce", "rare", "ember", "Strongest at noon, sleepiest at 12:01."),
  u("bedimew", "Sir Bedimew", "physical", 4, "groom", "rare", "gilt", "Licks wounds. Everyone's."),
  u("borscat", "Sir Borscat", "physical", 5, "ninelives", "rare", "tide", "Has died four times. Still has five to go."),
  u("lamoracat", "Lamoracat", "physical", 7, "none", "rare", "tide", "Big. Fluffy. Unmovable."),
  u("pelliroar", "King Pelliroar", "physical", 4, "yowl", "rare", "gilt", "His roar is mostly a squeak, but it works."),
  u("tristripe", "Sir Tristripe", "physical", 5, "purr", "rare", "ember", "Purrs in harmony with whoever is losing."),
  u("alleystray", "Alley Stray", "physical", 6, "stray", "rare", "shadow", "Goes wherever the fish are."),
  u("kaytail", "Sir Kaytail", "physical", 3, "litter", "common", "ember", "There are always more of him."),
  u("pikecat", "Tabby Pikecat", "physical", 3, "litter", "common", "tide", "Holds the line. Mostly holds the snacks."),
  u("squire", "Squire Kitten", "physical", 2, "muster", "common", "gilt", "Where one squeaks, the whole litter follows."),
  u("gareth", "Gareth the Scullion", "physical", 4, "purr", "common", "tide", "Kitchen-trained. Knows where the cream is."),
  u("agravain", "Agravain", "physical", 5, "none", "common", "shadow", "Grumpy. Effective."),
  u("ironpaw", "Ironpaw Sergeant", "physical", 3, "pounce", "common", "gilt", "Pounces by the book."),
  u("barnbrawler", "Barn Brawler", "physical", 5, "none", "common", "ember", "Raised on mice and bad decisions."),
  -- Arcane
  u("nimew", "Nimew of the Lake", "magic", 12, "groom", "legendary", "tide", "Hands out swords from the water. Hates getting wet."),
  u("morgana", "Morgana le Fur", "magic", 13, "hex", "legendary", "shadow", "The blackest cat of all. Luck flees from her."),
  u("vivipurr", "Vivipurr", "magic", 4, "inspire", "rare", "tide", "Her orb glows brighter for every friend nearby."),
  u("taliesing", "Taliesing the Bard", "magic", 3, "yowl", "rare", "gilt", "Sings the songs that make knights double-brave."),
  u("seer", "Crystal Seer", "magic", 3, "stray", "rare", "gilt", "Saw her future in the enemy camp. Went there."),
  u("hedgedruid", "Hedge Druid", "magic", 3, "litter", "common", "tide", "Druids come in circles."),
  u("emberadept", "Ember Adept", "magic", 4, "pounce", "common", "ember", "Throws fireballs. Mostly hairballs, on fire."),
  u("elaine", "Elaine of Astocat", "magic", 3, "purr", "common", "gilt", "Weaves tapestries of everyone's naps."),
  u("novice", "Orb Novice", "magic", 2, "muster", "common", "tide", "Never studies alone."),
  u("candlewitch", "Candle Witch", "magic", 6, "none", "common", "ember", "Keeps the flame lit and the tail clear of it."),
  -- Specials
  sp("downpour", "Downpour", "downpour", "rare", "The single most effective weapon against cats."),
  sp("moonfog", "Moonfog", "moonfog", "rare", "Nobody can see their orbs in this."),
  sp("sunbeam", "Sunbeam", "sunbeam", "common", "Everyone stops fighting to lie down in it."),
  sp("warhorn", "Rallying Yowl", "warhorn", "rare", "A sound that wakes the whole street."),
  sp("box", "Cardboard Box", "box", "common", "If it fits, it sits. If it sits, it hides."),
  sp("hairball", "Hairball", "hairball", "epic", "Hrrk. Hrrrk. HRRRK."),
}
local guard = u("guard", "Arena Guard", "physical", 3, "none", "common", "shadow", "Paid in fish. Loyal until the fish run out.")
guard.token = true
M.LIST[#M.LIST + 1] = guard

M.CARDS = {}
M.DRAFTABLE = {}
for _, c in ipairs(M.LIST) do
  M.CARDS[c.id] = c
  if not c.token then M.DRAFTABLE[#M.DRAFTABLE + 1] = c end
end

function M.getDef(inst)
  if type(inst) == "string" then return M.CARDS[inst] end
  return inst.def or M.CARDS[inst.id]
end

function M.levelBonus(level) return (level - 1) * 2 end
M.XP_FOR_LEVEL = { [1] = 0, [2] = 2, [3] = 5 }
M.LEVEL_TITLES = { [1] = "", [2] = "Knight", [3] = "Paladin" }

function M.isLegend(d) return d.rarity == "legendary" end

-- Short name for tiny card faces.
function M.shortName(d)
  local n = d.name:gsub("^Sir ", ""):gsub("^The ", ""):gsub("^King ", "")
  n = n:gsub(" of .*$", ""):gsub(" the .*$", ""):gsub(" le .*$", "")
  return n
end

function M.paws(inst)
  local d = M.getDef(inst)
  return d.power + M.levelBonus(inst.level or 1)
end

return M
