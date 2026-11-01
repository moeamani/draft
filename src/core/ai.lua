-- Heuristic duel AI: simulate every card on a cloned state, then decide using round context.
local cards = require("src.core.cards")
local duel = require("src.core.duel")

local M = {}

M.STYLES = {
  brute = { passLead = 14, concedeAt = 30 },
  schemer = { passLead = 8, concedeAt = 16 },
  zealot = { passLead = 11, concedeAt = 40 },
  coward = { passLead = 7, concedeAt = 12 },
  trickster = { passLead = 9, concedeAt = 20 },
  default = { passLead = 10, concedeAt = 22 },
}

local function evaluate(s, me)
  local opp = duel.other(me)
  local base = duel.score(s, me) - duel.score(s, opp)
  local handBefore = #s.sides[me].hand
  local out = {}
  for _, c in ipairs(s.sides[me].hand) do
    local c2 = duel.clone(s)
    duel.resolvePlay(c2, me, c.uid)
    local diff = duel.score(c2, me) - duel.score(c2, opp)
    local swing = #c2.sides[me].hand - (handBefore - 1)
    local d = cards.getDef(c)
    out[#out + 1] = {
      uid = c.uid, gain = diff - base, value = diff - base + swing * 4,
      special = d.kind == "special", legend = cards.isLegend(d),
    }
  end
  table.sort(out, function(a, b) return a.value > b.value end)
  return out
end

function M.choose(s, me, style)
  style = style or M.STYLES.default
  local opp = duel.other(me)
  local mine, theirs = s.sides[me], s.sides[opp]
  if #mine.hand == 0 then return { type = "pass" } end

  local lead = duel.score(s, me) - duel.score(s, opp)
  local mustWin = mine.gems == 1
  local theyMustWin = theirs.gems == 1
  local evals = evaluate(s, me)
  local best = evals[1]
  local passLead = mine.mods.arrogant and math.max(3, style.passLead - 6) or style.passLead

  if theirs.passed then
    if lead > 0 then return { type = "pass" } end
    local winners = {}
    for _, e in ipairs(evals) do if lead + e.gain > 0 then winners[#winners + 1] = e end end
    table.sort(winners, function(a, b) return a.gain < b.gain end)
    if winners[1] then
      local w = winners[1]
      if mustWin or theyMustWin or #mine.hand > 2 or w.gain <= 12 then return { type = "play", uid = w.uid } end
    end
    if mustWin and best.gain > 0 then return { type = "play", uid = best.uid } end
    local pos = {}
    for _, e in ipairs(evals) do if e.gain > 0 then pos[#pos + 1] = e end end
    if not mustWin and #pos >= 2 and #mine.hand >= 4 and lead + pos[1].gain + pos[2].gain > 0 then
      return { type = "play", uid = pos[1].uid }
    end
    if theyMustWin then
      for _, e in ipairs(evals) do if lead + e.gain == 0 then return { type = "play", uid = e.uid } end end
    end
    return { type = "pass" }
  end

  local cardAdv = #mine.hand - #theirs.hand
  if not mustWin then
    if lead >= passLead and (cardAdv >= -1 or lead > passLead + 8) then return { type = "pass" } end
    if lead <= -style.concedeAt and cardAdv <= 1 and not theyMustWin then return { type = "pass" } end
  end
  if best.value <= 0 and (lead > 0 or not mustWin) then return { type = "pass" } end

  if not mustWin and not theyMustWin then
    for _, e in ipairs(evals) do
      if not e.legend and not e.special and e.value > 0 then return { type = "play", uid = e.uid } end
    end
  end
  return { type = "play", uid = best.uid }
end

return M
