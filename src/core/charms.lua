-- Charms: passive festival favours that bend the scoring rules. Up to 5 at once.
local M = {}

M.MAX = 5

M.CHARMS = {
  cream = { name = "Saucer of Cream", desc = "+6 Paws every exchange.", price = 40, icon = "cream" },
  collar = { name = "Lucky Collar", desc = "Your Black Cat hexes drain 4 more Paws.", price = 40, icon = "moon" },
  cloak = { name = "Oiled Cloak", desc = "Immune to the rival's weather tricks.", price = 35, icon = "umbrella" },
  bell = { name = "Brass Bell", desc = "Hold 1 extra card in hand.", price = 60, icon = "bell" },
  fishbone = { name = "Fishbone Charm", desc = "+8 fish after every win.", price = 35, icon = "fish" },
  banner_ember = { name = "Ember Banner", desc = "Your Ember cats score +4 Paws.", price = 45, icon = "banner", color = "ember" },
  banner_tide = { name = "Tide Banner", desc = "Your Tide cats score +4 Paws.", price = 45, icon = "banner", color = "tide" },
  banner_gilt = { name = "Gilt Banner", desc = "Your Gilt cats score +4 Paws.", price = 45, icon = "banner", color = "gilt" },
  whetstone = { name = "Whetstone", desc = "Pounce gives 12 more Paws.", price = 35, icon = "diamond" },
  crown = { name = "Paper Crown", desc = "+3 Cheer when a Legendary cat scores.", price = 50, icon = "crown" },
  yarn = { name = "Ball of Yarn", desc = "The rival's Cheer -1 every exchange.", price = 45, icon = "yarn" },
  spyglass = { name = "Spyglass", desc = "See the rival's formation coat before you play.", price = 40, icon = "eye" },
  catnip = { name = "Catnip Pouch", desc = "+1 redraw every exchange.", price = 50, icon = "leaf" },
  tally = { name = "Tally Stick", desc = "+1 Cheer for every exchange you've won this match.", price = 50, icon = "tally" },
  seal = { name = "Round Seal", desc = "Round Table formations score double.", price = 45, icon = "seal" },
  lucky = { name = "Lucky Tail", desc = "1 in 4 exchanges: x2 Cheer.", price = 45, icon = "star" },
  drum = { name = "Festival Drum", desc = "+4 Cheer on the first exchange of a match.", price = 40, icon = "drum" },
  candle = { name = "Witch's Candle", desc = "Coven formations get +3 Cheer.", price = 40, icon = "candle" },
}
M.IDS = {}
for k in pairs(M.CHARMS) do M.IDS[#M.IDS + 1] = k end
table.sort(M.IDS)

function M.apply(m, charms)
  for _, c in ipairs(charms) do
    if c == "cream" then m.flatPaws = m.flatPaws + 6
    elseif c == "collar" then m.hexBonus = m.hexBonus + 4
    elseif c == "cloak" then m.weatherImmune = true
    elseif c == "bell" then m.handSize = m.handSize + 1
    elseif c:sub(1, 7) == "banner_" then
      local coat = c:sub(8)
      m.coatPaws[coat] = (m.coatPaws[coat] or 0) + 4
    elseif c == "whetstone" then m.pounceBonus = m.pounceBonus + 12
    elseif c == "crown" then m.legendCheer = m.legendCheer + 3
    elseif c == "yarn" then m.rivalCheer = m.rivalCheer + 1
    elseif c == "spyglass" then m.seeCoat = true
    elseif c == "catnip" then m.redraws = m.redraws + 1
    elseif c == "tally" then m.tally = true
    elseif c == "seal" then m.sealRound = true
    elseif c == "lucky" then m.lucky = true
    elseif c == "drum" then m.drum = true
    elseif c == "candle" then m.covenCheer = m.covenCheer + 3
    end
  end
end

return M
