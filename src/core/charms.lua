local M = {}

M.MAX = 5

M.CHARMS = {
  cream = { name = "Saucer of Cream", desc = "Your first unit each round gets +2.", price = 45, icon = "cream" },
  collar = { name = "Lucky Collar", desc = "Your Hexes deal +1 damage.", price = 40, icon = "moon" },
  cloak = { name = "Oiled Cloak", desc = "Weather drops your units to 2 instead of 1.", price = 40, icon = "umbrella" },
  bell = { name = "Brass Bell", desc = "Draw 1 extra card at the start of every duel.", price = 60, icon = "bell" },
  fishbone = { name = "Fishbone Charm", desc = "+8 fish after every victory.", price = 35, icon = "fish" },
  banner_ember = { name = "Ember Banner", desc = "Your Ember units get +1.", price = 45, icon = "banner", color = "ember" },
  banner_tide = { name = "Tide Banner", desc = "Your Tide units get +1.", price = 45, icon = "banner", color = "tide" },
  banner_gilt = { name = "Gilt Banner", desc = "Your Gilt units get +1.", price = 45, icon = "banner", color = "gilt" },
  whetstone = { name = "Whetstone", desc = "Your Pounces deal +2 damage.", price = 35, icon = "diamond" },
  crown = { name = "Paper Crown", desc = "Your Legendary units get +2.", price = 50, icon = "crown" },
  yarn = { name = "Ball of Yarn", desc = "The enemy's first unit each round is distracted: -2.", price = 45, icon = "yarn" },
  spyglass = { name = "Spyglass", desc = "Reveal a hidden trait of every Warlord you face.", price = 40, icon = "eye" },
  catnip = { name = "Catnip Pouch", desc = "If you lose a round, draw 2 cards.", price = 50, icon = "leaf" },
}
M.IDS = {}
for k in pairs(M.CHARMS) do M.IDS[#M.IDS + 1] = k end
table.sort(M.IDS)

function M.apply(me, enemy, charms)
  for _, c in ipairs(charms) do
    if c == "cream" then me.firstUnitBonus = me.firstUnitBonus + 2
    elseif c == "collar" then me.hexBonus = me.hexBonus + 1
    elseif c == "cloak" then me.weatherFloor = 2
    elseif c == "bell" then me.extraDraw = me.extraDraw + 1
    elseif c:sub(1, 7) == "banner_" then
      local coat = c:sub(8)
      me.coatBonus[coat] = (me.coatBonus[coat] or 0) + 1
    elseif c == "whetstone" then me.pounceBonus = me.pounceBonus + 2
    elseif c == "crown" then me.legendBonus = me.legendBonus + 2
    elseif c == "yarn" then enemy.firstUnitBonus = enemy.firstUnitBonus - 2
    elseif c == "catnip" then me.secondWind = true
    end
  end
end

return M
