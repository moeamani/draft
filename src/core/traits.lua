-- Nemesis traits and the per-side modifiers they produce in a duel.
local util = require("src.core.util")

local M = {}

function M.baseMods()
  return {
    thickfur = false, weatherImmune = false, weatherZero = false, weatherFloor = 1,
    vanguardBonus = 0, arcaneBonus = 0, extraDraw = 0, vengeful = false, bodyguard = false,
    secondWind = false, hexVuln = 0, pounceVuln = false, dread = nil, firstUnitBonus = 0,
    hexBonus = 0, pounceBonus = 0, legendBonus = 0, coatBonus = {}, arrogant = false,
    source = {},
  }
end

M.TRAITS = {
  thickfur = { name = "Thick Fur", kind = "strength", desc = "Their units are immune to Hex and Pounce." },
  rainsoaked = { name = "Rain-Soaked", kind = "strength", desc = "Their units ignore weather." },
  warlord = { name = "Warlord", kind = "strength", desc = "Their Vanguard units get +1." },
  archmage = { name = "Archmage", kind = "strength", desc = "Their Arcane units get +1." },
  hoarder = { name = "Hoarder", kind = "strength", desc = "They draw 1 extra card." },
  vengeful = { name = "Vengeful", kind = "strength", desc = "When one of their units dies, their strongest gains +2." },
  bodyguard = { name = "Bodyguard", kind = "strength", desc = "A 3-power Arena Guard joins them every round." },
  grudge = { name = "Grudge", kind = "strength", desc = "Their first unit each round gets +2 per win over you (max +6)." },
  secondwind = { name = "Second Wind", kind = "strength", desc = "If they lose a round, they draw 2 cards." },
  ninelives = { name = "Nine Lives", kind = "strength", desc = "Slaying them never sticks. They always come back." },
  hydrophobic = { name = "Hydrophobic", kind = "weakness", desc = "Weather drops their units to 0 instead of 1." },
  superstitious = { name = "Superstitious", kind = "weakness", desc = "Your Hexes deal 2 extra damage to them." },
  arrogant = { name = "Arrogant", kind = "weakness", desc = "They pass too early when they think they are ahead." },
  glassjaw = { name = "Glass Jaw", kind = "weakness", desc = "Your Pounces deal double damage to them." },
  dread_ember = { name = "Fears Fire", kind = "weakness", desc = "Your Ember units get +2 against them." },
  dread_tide = { name = "Fears Water", kind = "weakness", desc = "Your Tide units get +2 against them." },
  dread_gilt = { name = "Fears Gold", kind = "weakness", desc = "Your Gilt units get +2 against them." },
  sluggish = { name = "Sluggish", kind = "weakness", desc = "They draw 1 fewer card." },
  lazy = { name = "Lazy", kind = "weakness", desc = "Their first unit each round is played at -2." },
}

M.STRENGTHS, M.WEAKNESSES = {}, {}
for _, id in ipairs(util.keys(M.TRAITS)) do
  local t = M.TRAITS[id]
  if t.kind == "strength" and id ~= "grudge" then M.STRENGTHS[#M.STRENGTHS + 1] = id end
  if t.kind == "weakness" then M.WEAKNESSES[#M.WEAKNESSES + 1] = id end
end

local CONFLICTS = {
  { "rainsoaked", "hydrophobic" }, { "hoarder", "sluggish" }, { "thickfur", "glassjaw" },
  { "thickfur", "superstitious" }, { "dread_ember", "dread_tide" }, { "dread_ember", "dread_gilt" },
  { "dread_tide", "dread_gilt" },
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

function M.apply(m, traits, defeatsOfPlayer)
  for _, t in ipairs(traits) do
    if t == "thickfur" then m.thickfur = true; m.source.thickfur = t
    elseif t == "rainsoaked" then m.weatherImmune = true; m.source.weatherImmune = t
    elseif t == "warlord" then m.vanguardBonus = m.vanguardBonus + 1; m.source.vanguardBonus = t
    elseif t == "archmage" then m.arcaneBonus = m.arcaneBonus + 1; m.source.arcaneBonus = t
    elseif t == "hoarder" then m.extraDraw = m.extraDraw + 1; m.source.extraDraw = t
    elseif t == "sluggish" then m.extraDraw = m.extraDraw - 1; m.source.extraDraw = t
    elseif t == "vengeful" then m.vengeful = true; m.source.vengeful = t
    elseif t == "bodyguard" then m.bodyguard = true; m.source.bodyguard = t
    elseif t == "grudge" then
      m.firstUnitBonus = m.firstUnitBonus + math.min(6, 2 * math.max(1, defeatsOfPlayer or 1)); m.source.firstUnitBonus = t
    elseif t == "lazy" then m.firstUnitBonus = m.firstUnitBonus - 2; m.source.firstUnitBonus = t
    elseif t == "secondwind" then m.secondWind = true; m.source.secondWind = t
    elseif t == "hydrophobic" then m.weatherZero = true; m.source.weatherZero = t
    elseif t == "superstitious" then m.hexVuln = m.hexVuln + 2; m.source.hexVuln = t
    elseif t == "arrogant" then m.arrogant = true; m.source.arrogant = t
    elseif t == "glassjaw" then m.pounceVuln = true; m.source.pounceVuln = t
    elseif t:sub(1, 6) == "dread_" then m.dread = t:sub(7); m.source.dread = t
    end
  end
  return m
end

return M
