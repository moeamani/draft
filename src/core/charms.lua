-- Charms: passive festival favours that bend the scoring rules. Up to 5 at once.
local M = {}

M.MAX = 5

M.CHARMS = {
  cream = { name = "Saucer of Cream", desc = "Your cat on the middle cushion gets +2 Paws.", price = 40, icon = "cream" },
  collar = { name = "Lucky Collar", desc = "Your Black Cat hexes take 2 more Paws.", price = 40, icon = "moon" },
  cloak = { name = "Oiled Cloak", desc = "Immune to the rival's weather tricks.", price = 35, icon = "umbrella" },
  bell = { name = "Brass Bell", desc = "Hold 1 extra card in hand.", price = 60, icon = "bell" },
  fishbone = { name = "Fishbone Charm", desc = "+8 fish after every win.", price = 35, icon = "fish" },
  banner_ember = { name = "Ember Banner", desc = "Your Ember cats get +1 Paw.", price = 45, icon = "banner", color = "ember" },
  banner_tide = { name = "Tide Banner", desc = "Your Tide cats get +1 Paw.", price = 45, icon = "banner", color = "tide" },
  banner_gilt = { name = "Gilt Banner", desc = "Your Gilt cats get +1 Paw.", price = 45, icon = "banner", color = "gilt" },
  whetstone = { name = "Whetstone", desc = "Pounce gives 2 more Paws.", price = 35, icon = "diamond" },
  crown = { name = "Paper Crown", desc = "Your Legendary cats get +2 Paws.", price = 50, icon = "crown" },
  yarn = { name = "Ball of Yarn", desc = "The rival's cat on the left cushion chases it: -2 Paws.", price = 45, icon = "yarn" },
  spyglass = { name = "Spyglass", desc = "When the rival leads, peek at one of their cards.", price = 40, icon = "eye" },
  catnip = { name = "Catnip Pouch", desc = "When you answer, your cats get +1 Paw.", price = 45, icon = "leaf" },
  tally = { name = "Tally Stick", desc = "Your cats get +1 Paw for each bout you've won this match (max +3).", price = 50, icon = "tally" },
  seal = { name = "Round Seal", desc = "Three cats of three different coats: +2 Paws each.", price = 45, icon = "seal" },
  lucky = { name = "Lucky Tail", desc = "You win every tie.", price = 45, icon = "star" },
  drum = { name = "Festival Drum", desc = "When you lead, your cats get +1 Paw.", price = 40, icon = "drum" },
  candle = { name = "Witch's Candle", desc = "Your Shadow cats get +1 Paw.", price = 40, icon = "candle" },
  scruff = { name = "Scruff Ribbon", desc = "Your cats have 1 more life, so they're harder to capture.", price = 50, icon = "heart" },
}
M.IDS = {}
for k in pairs(M.CHARMS) do M.IDS[#M.IDS + 1] = k end
table.sort(M.IDS)

function M.apply(m, charms)
  for _, c in ipairs(charms) do
    if c == "cream" then m.cream = m.cream + 2
    elseif c == "collar" then m.hexBonus = m.hexBonus + 2
    elseif c == "cloak" then m.weatherImmune = true
    elseif c == "bell" then m.handSize = m.handSize + 1
    elseif c:sub(1, 7) == "banner_" then
      local coat = c:sub(8)
      m.coatPaws[coat] = (m.coatPaws[coat] or 0) + 1
    elseif c == "whetstone" then m.pounceBonus = m.pounceBonus + 2
    elseif c == "crown" then m.legendPaws = m.legendPaws + 2
    elseif c == "yarn" then m.yarn = m.yarn + 2
    elseif c == "spyglass" then m.peek = true
    elseif c == "catnip" then m.catnip = true
    elseif c == "tally" then m.tally = true
    elseif c == "seal" then m.seal = true
    elseif c == "lucky" then m.lucky = true
    elseif c == "drum" then m.drum = true
    elseif c == "candle" then m.coatPaws.shadow = (m.coatPaws.shadow or 0) + 1
    elseif c == "scruff" then m.extraLives = m.extraLives + 1
    end
  end
end

return M
