-- Card database. The first entries come from the Figma card sheet.
local M = {}

-- Abilities work while the cat sits on a cushion. Tricks are placed on a cushion too, but they
-- never duel: a cat facing a trick is unopposed, unless the trick puts it to sleep.
M.ABILITIES = {
  none = { name = "Steadfast", desc = "Wins ties, even when answering." },
  smite = { name = "Sword Hammer", desc = "Every swat knocks off 2 goblets." },
  inspire = { name = "Aural Orb", desc = "Your other Magic cats this bout get +2 Paws." },
  hex = { name = "Black Cat", desc = "The cat facing it loses 2 Paws." },
  litter = { name = "Litter", desc = "+2 Paws for each of your other cats of its coat this bout." },
  pounce = { name = "Pounce", desc = "With the coat edge, +3 more Paws." },
  ninelives = { name = "Nine Lives", desc = "Never loses a life, so it can't be captured. Comes back to your hand after the bout (once per match)." },
  stray = { name = "Stray", desc = "Unopposed, it knocks off 2 goblets." },
  groom = { name = "Groom", desc = "When it swats, set one of your goblets back up." },
  purr = { name = "Purr", desc = "The cats on the cushions beside it get +2 Paws." },
  yowl = { name = "War Yowl", desc = "Every rival cat this bout loses 1 Paw." },
  muster = { name = "Call the Pride", desc = "+1 Paw for each copy of this cat in your pride." },
  downpour = { name = "Downpour", desc = "Trick: every rival cat loses 2 Paws. Cats hate rain." },
  moonfog = { name = "Moonfog", desc = "Trick: the rival's strongest cat gets lost in the fog and doesn't fight." },
  sunbeam = { name = "Sunbeam", desc = "Trick: the cat facing it lies down for a nap. No duel, no swat." },
  warhorn = { name = "Rallying Yowl", desc = "Trick: your other cats this bout get +3 Paws." },
  box = { name = "Cardboard Box", desc = "Trick that fights: a 4-Paw cat whose coat beats the cat facing it." },
  hairball = { name = "Hairball", desc = "Trick: the cat facing it is too disgusted to fight, and the cats beside it lose 2 Paws." },
  phantom = { name = "Unknown", desc = "A face-down card." },
}

M.COATS = {
  ember = { name = "Ember", color = { 0.91, 0.28, 0.23 }, beats = "gilt", desc = "Ginger fire-coats. Ember scorches Gilt." },
  gilt = { name = "Gilt", color = { 0.83, 0.64, 0.0 }, beats = "tide", desc = "Golden noble-coats. Gilt dams the Tide." },
  tide = { name = "Tide", color = { 0.14, 0.47, 0.97 }, beats = "ember", desc = "Blue-grey sea-coats. Tide drowns Ember." },
  shadow = { name = "Shadow", color = { 0.55, 0.6, 0.66 }, beats = nil, desc = "Black cats. No edge either way, and their backs look like tricks." },
}

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
  u("artheline", "Artheline", "physical", 12, "smite", "legendary", "gilt", "Drew the Sword Hammer from the scratching post. The once and future queen of the alley."),
  u("merline", "Merline", "magic", 10, "inspire", "legendary", "tide", "Her Aural Orb hums at the frequency of a contented purr."),
  u("lanceline", "Lanceline", "magic", 7, "hex", "epic", "shadow", "Crosses your path on purpose."),
  u("morgelius", "Morgelius", "magic", 5, "hex", "rare", "shadow", "Knocked a goblet off the Round Table. Unrepentant."),
  u("circaleus", "Circaleus", "magic", 3, "hex", "common", "shadow", "Walks in circles. Curses in circles."),
  u("purrceval", "Purrceval", "magic", 5, "hex", "rare", "shadow", "Quests for the Holy Grail. Will settle for the holy gravy."),
  u("purrlinore", "Purrlinore", "magic", 4, "hex", "common", "shadow", "Hunts the Questing Mouse, forever."),
  u("mordraleus", "Mordraleus", "magic", 8, "hex", "epic", "shadow", "His shadow arrives a second before he does."),
  u("merlinus", "Merlinus", "magic", 3, "hex", "common", "shadow", "An apprentice of bad luck. Studying hard."),
  -- Vanguard
  u("uther", "Uther Pawndragon", "physical", 10, "yowl", "legendary", "ember", "When he yowls, the whole line stands taller."),
  u("greenmouser", "The Green Mouser", "physical", 9, "ninelives", "legendary", "tide", "Lost his head once. Grew it back."),
  u("mewdred", "Mewdred", "physical", 8, "pounce", "epic", "ember", "Rightful heir to absolutely nothing."),
  u("galahiss", "Galahiss the Pure", "physical", 7, "groom", "epic", "gilt", "So clean. So very clean."),
  u("gawpaw", "Sir Gawpaw", "physical", 6, "pounce", "rare", "ember", "Strongest at noon, sleepiest at 12:01."),
  u("bedimew", "Sir Bedimew", "physical", 5, "groom", "rare", "gilt", "Licks wounds. Everyone's."),
  u("borscat", "Sir Borscat", "physical", 5, "ninelives", "rare", "tide", "Has died four times. Still has five to go."),
  u("lamoracat", "Lamoracat", "physical", 7, "none", "rare", "tide", "Big. Fluffy. Unmovable."),
  u("pelliroar", "King Pelliroar", "physical", 5, "yowl", "rare", "gilt", "His roar is mostly a squeak, but it works."),
  u("tristripe", "Sir Tristripe", "physical", 5, "purr", "rare", "ember", "Purrs in harmony with whoever is losing."),
  u("alleystray", "Alley Stray", "physical", 5, "stray", "rare", "shadow", "Goes wherever the fish are."),
  u("kaytail", "Sir Kaytail", "physical", 3, "litter", "common", "ember", "There are always more of him."),
  u("pikecat", "Tabby Pikecat", "physical", 3, "litter", "common", "tide", "Holds the line. Mostly holds the snacks."),
  u("squire", "Squire Kitten", "physical", 2, "muster", "common", "gilt", "Where one squeaks, the whole litter follows."),
  u("gareth", "Gareth the Scullion", "physical", 4, "purr", "common", "tide", "Kitchen-trained. Knows where the cream is."),
  u("agravain", "Agravain", "physical", 5, "none", "common", "shadow", "Grumpy. Effective."),
  u("ironpaw", "Ironpaw Sergeant", "physical", 4, "pounce", "common", "gilt", "Pounces by the book."),
  u("barnbrawler", "Barn Brawler", "physical", 5, "none", "common", "ember", "Raised on mice and bad decisions."),
  -- Arcane
  u("nimew", "Nimew of the Lake", "magic", 10, "groom", "legendary", "tide", "Hands out swords from the water. Hates getting wet."),
  u("morgana", "Morgana le Fur", "magic", 10, "hex", "legendary", "shadow", "The blackest cat of all. Luck flees from her."),
  u("vivipurr", "Vivipurr", "magic", 5, "inspire", "rare", "tide", "Her orb glows brighter for every friend nearby."),
  u("taliesing", "Taliesing the Bard", "magic", 4, "yowl", "rare", "gilt", "Sings the songs that make knights double-brave."),
  u("seer", "Crystal Seer", "magic", 4, "stray", "rare", "gilt", "Saw her future in the enemy camp. Went there."),
  u("hedgedruid", "Hedge Druid", "magic", 3, "litter", "common", "tide", "Druids come in circles."),
  u("emberadept", "Ember Adept", "magic", 4, "pounce", "common", "ember", "Throws fireballs. Mostly hairballs, on fire."),
  u("elaine", "Elaine of Astocat", "magic", 3, "purr", "common", "gilt", "Weaves tapestries of everyone's naps."),
  u("novice", "Orb Novice", "magic", 2, "muster", "common", "tide", "Never studies alone."),
  u("candlewitch", "Candle Witch", "magic", 5, "none", "common", "ember", "Keeps the flame lit and the tail clear of it."),
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

-- Bonds: legendary pairs from the old stories. Side by side on your cushions, each gets +2 Paws.
M.BOND_PAWS = 2
M.BONDS = {
  { "artheline", "merline", "The Once and Future" },
  { "uther", "artheline", "The Pawndragon Line" },
  { "nimew", "merline", "The Lady of the Lake" },
  { "galahiss", "purrceval", "The Grail Seekers" },
  { "lanceline", "galahiss", "Father and Son" },
  { "elaine", "lanceline", "The Lily Maid" },
  { "gawpaw", "greenmouser", "The Green Bargain" },
  { "gawpaw", "gareth", "Brothers of Orkney" },
  { "agravain", "mordraleus", "The Plotters" },
  { "morgana", "mordraleus", "Mother of Mischief" },
  { "mewdred", "uther", "The Contested Crown" },
  { "lamoracat", "pelliroar", "Pelliroar's Pride" },
  { "bedimew", "kaytail", "The First Companions" },
  { "tristripe", "taliesing", "Harp and Song" },
  { "vivipurr", "merlinus", "The Apprentice's Folly" },
  { "hedgedruid", "seer", "The Old Ways" },
  { "squire", "ironpaw", "Drill and Drum" },
  { "emberadept", "candlewitch", "Kindred Flames" },
  { "barnbrawler", "alleystray", "Gutter Kin" },
  { "pikecat", "borscat", "The Tide Watch" },
  { "purrlinore", "morgelius", "Goblet Thieves" },
  { "novice", "circaleus", "The Study Circle" },
}
local bondIndex = {}
for _, b in ipairs(M.BONDS) do
  bondIndex[b[1]] = bondIndex[b[1]] or {}
  bondIndex[b[2]] = bondIndex[b[2]] or {}
  bondIndex[b[1]][b[2]] = b[3]
  bondIndex[b[2]][b[1]] = b[3]
end
function M.bonded(a, b) return bondIndex[a] ~= nil and bondIndex[a][b] or nil end
-- { {partner id, bond name}, ... } for a card id
function M.bondsOf(id)
  local out = {}
  for _, b in ipairs(M.BONDS) do
    if b[1] == id then out[#out + 1] = { b[2], b[3] } elseif b[2] == id then out[#out + 1] = { b[1], b[3] } end
  end
  return out
end

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

-- Stolen Lives: how many lost duels a cat survives in one match before the rival captures it.
M.LIVES = { common = 2, rare = 2, epic = 3, legendary = 3 }
function M.maxLives(d)
  if d.kind ~= "unit" then return 0 end
  return M.LIVES[d.rarity] or 2
end

-- Printings: how one particular copy of a cat came off the Overseer's press. Most copies are
-- plain. A printing belongs to the copy (inst.print), not to the card, and only cats have them.
M.PRINTS = {
  proof = { name = "Proof", desc = "A first pull on heavier stock: 1 more life." },
  gold = { name = "Gold Leaf", desc = "Earns 4 fish in every match where it wins a duel." },
  misprint = { name = "Misprint", desc = "+2 Paws, and its back shows the wrong coat." },
}
M.PRINT_ORDER = { "proof", "gold", "misprint" }
M.MISPRINT_PAWS, M.GOLD_FISH = 2, 4
M.BACKS = { "ember", "tide", "gilt", "dark" }

-- The back a copy would honestly show: its coat, or "dark" for Shadow cats and tricks.
function M.trueBack(d)
  if d.kind ~= "unit" or d.coat == "shadow" or d.coat == "none" then return "dark" end
  return d.coat
end

-- The lives this copy brings into a match.
function M.livesOf(inst)
  local d = M.getDef(inst)
  if d.kind ~= "unit" then return 0 end
  return M.maxLives(d) + (inst.print == "proof" and 1 or 0)
end

function M.paws(inst)
  local d = M.getDef(inst)
  return d.power + M.levelBonus(inst.level or 1) + (inst.print == "misprint" and M.MISPRINT_PAWS or 0)
end

return M
