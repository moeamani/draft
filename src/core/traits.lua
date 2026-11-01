-- Nemesis traits and the per-side match modifiers they produce.
local util = require("src.core.util")

local M = {}

function M.baseMods()
  return {
    pride = 0, handSize = 0, redraws = 0, flatPaws = 0, flatCheer = 0,
    hexImmune = false, weatherImmune = false, weatherDouble = false, hexVuln = false,
    physPaws = 0, magicCheer = 0, vengeful = false, grudge = 0, secondWind = false,
    showsCoat = false, glassJaw = false, dread = nil, lazy = false,
    -- charm effects
    hexBonus = 0, pounceBonus = 0, coatPaws = {}, legendCheer = 0, rivalCheer = 0,
    tally = false, sealRound = false, lucky = false, drum = false, covenCheer = 0, seeCoat = false,
    source = {},
  }
end

M.TRAITS = {
  thickfur = { name = "Thick Fur", kind = "strength", desc = "Immune to Black Cat hexes." },
  rainsoaked = { name = "Rain-Soaked", kind = "strength", desc = "Immune to weather tricks (Downpour, Moonfog)." },
  warlord = { name = "Warlord", kind = "strength", desc = "+12 Paws when their formation has 3+ Physical cats." },
  archmage = { name = "Archmage", kind = "strength", desc = "+2 Cheer when their formation has 3+ Magic cats." },
  hoarder = { name = "Hoarder", kind = "strength", desc = "Holds 1 extra card in hand." },
  vengeful = { name = "Vengeful", kind = "strength", desc = "After losing an exchange, +3 Cheer on the next." },
  bodyguard = { name = "Bodyguard", kind = "strength", desc = "Starts every match with +25 Pride." },
  grudge = { name = "Grudge", kind = "strength", desc = "+1 Cheer for every win over you (max +3)." },
  secondwind = { name = "Second Wind", kind = "strength", desc = "Once per match, heals 20 Pride when below 30." },
  ninelives = { name = "Nine Lives", kind = "strength", desc = "Slaying them never sticks. They always come back." },
  hydrophobic = { name = "Hydrophobic", kind = "weakness", desc = "Weather tricks hit them twice as hard." },
  superstitious = { name = "Superstitious", kind = "weakness", desc = "Your hexes hit them twice." },
  arrogant = { name = "Arrogant", kind = "weakness", desc = "Shows off: you see their formation's coat before you play." },
  glassjaw = { name = "Glass Jaw", kind = "weakness", desc = "Takes 25% more damage." },
  dread_ember = { name = "Fears Fire", kind = "weakness", desc = "Your Ember formations get +2 Cheer against them." },
  dread_tide = { name = "Fears Water", kind = "weakness", desc = "Your Tide formations get +2 Cheer against them." },
  dread_gilt = { name = "Fears Gold", kind = "weakness", desc = "Your Gilt formations get +2 Cheer against them." },
  sluggish = { name = "Sluggish", kind = "weakness", desc = "Holds 1 fewer card in hand." },
  lazy = { name = "Lazy", kind = "weakness", desc = "Their first exchange of every match scores half." },
}

M.STRENGTHS, M.WEAKNESSES = {}, {}
for _, id in ipairs(util.keys(M.TRAITS)) do
  local t = M.TRAITS[id]
  if t.kind == "strength" and id ~= "grudge" then M.STRENGTHS[#M.STRENGTHS + 1] = id end
  if t.kind == "weakness" then M.WEAKNESSES[#M.WEAKNESSES + 1] = id end
end

local CONFLICTS = {
  { "rainsoaked", "hydrophobic" }, { "hoarder", "sluggish" }, { "thickfur", "superstitious" },
  { "dread_ember", "dread_tide" }, { "dread_ember", "dread_gilt" }, { "dread_tide", "dread_gilt" },
}

function M.conflicts(a, list)
  for _, b in ipairs(list) do
    if a == b then return true end
    for _, c in ipairs(CONFLICTS) do
      if (c[1] == a and c[2] == b) or (c[1] == b and c[2] == a) then return true end
    end
  end
  return false
end

function M.apply(m, traits, winsOverPlayer)
  for _, t in ipairs(traits) do
    if t == "thickfur" then m.hexImmune = true
    elseif t == "rainsoaked" then m.weatherImmune = true
    elseif t == "warlord" then m.physPaws = m.physPaws + 12
    elseif t == "archmage" then m.magicCheer = m.magicCheer + 2
    elseif t == "hoarder" then m.handSize = m.handSize + 1
    elseif t == "sluggish" then m.handSize = m.handSize - 1
    elseif t == "vengeful" then m.vengeful = true
    elseif t == "bodyguard" then m.pride = m.pride + 25
    elseif t == "grudge" then m.grudge = math.min(3, math.max(1, winsOverPlayer or 1))
    elseif t == "secondwind" then m.secondWind = true
    elseif t == "hydrophobic" then m.weatherDouble = true
    elseif t == "superstitious" then m.hexVuln = true
    elseif t == "arrogant" then m.showsCoat = true
    elseif t == "glassjaw" then m.glassJaw = true
    elseif t:sub(1, 6) == "dread_" then m.dread = t:sub(7)
    elseif t == "lazy" then m.lazy = true
    end
  end
  return m
end

return M
