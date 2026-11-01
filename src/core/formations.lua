-- Formations: the scoring shapes a played group of cats can make.
-- Score of an exchange = (formation Paws + cat Paws + bonuses) x (formation Cheer + bonuses).
local M = {}

M.LIST = {
  { id = "lone", name = "Lone Paw", paws = 5, cheer = 1, desc = "Your single best cat." },
  { id = "duet", name = "Duet", paws = 10, cheer = 2, desc = "2 cats of the same coat." },
  { id = "vanguard", name = "Vanguard", paws = 15, cheer = 2, desc = "3 to 5 Physical cats." },
  { id = "conclave", name = "Conclave", paws = 15, cheer = 2, desc = "3 to 5 Magic cats." },
  { id = "litter", name = "Litter", paws = 25, cheer = 3, desc = "3 cats of the same coat." },
  { id = "charge", name = "Charge", paws = 30, cheer = 3, desc = "3 cats whose Paws rise one step at a time (3-4-5)." },
  { id = "coven", name = "Coven", paws = 30, cheer = 4, desc = "3 to 5 Black Cats." },
  { id = "roundtable", name = "Round Table", paws = 40, cheer = 4, desc = "One cat of each coat: Ember, Tide, Gilt and Shadow." },
  { id = "pride", name = "Pride", paws = 45, cheer = 4, desc = "4 cats of the same coat." },
  { id = "grandcharge", name = "Grand Charge", paws = 60, cheer = 5, desc = "5 cats whose Paws rise one step at a time." },
  { id = "fullpride", name = "Full Pride", paws = 60, cheer = 6, desc = "5 cats of the same coat." },
}
M.BY_ID = {}
for _, f in ipairs(M.LIST) do M.BY_ID[f.id] = f end

-- cats: list of { paws, coat, type, ability }. wild: index of a cat that may count as any coat.
local function sameCoat(cats, wild)
  local coat
  for i, c in ipairs(cats) do
    if i ~= wild then
      if coat and c.coat ~= coat then return false end
      coat = c.coat
    end
  end
  return true
end

local function allOf(cats, field, value)
  for _, c in ipairs(cats) do if c[field] ~= value then return false end end
  return true
end

local function rising(cats)
  local v = {}
  for i, c in ipairs(cats) do v[i] = c.paws end
  table.sort(v)
  for i = 2, #v do if v[i] ~= v[i - 1] + 1 then return false end end
  return true
end

local function roundTable(cats, wild)
  local seen, n = {}, 0
  for i, c in ipairs(cats) do
    if i ~= wild then
      if seen[c.coat] then return false end
      seen[c.coat] = true
      n = n + 1
    end
  end
  return n + (wild and 1 or 0) == 4
end

local TESTS = {
  lone = function(c) return #c == 1 end,
  duet = function(c, w) return #c == 2 and sameCoat(c, w) end,
  vanguard = function(c) return #c >= 3 and allOf(c, "type", "physical") end,
  conclave = function(c) return #c >= 3 and allOf(c, "type", "magic") end,
  litter = function(c, w) return #c == 3 and sameCoat(c, w) end,
  charge = function(c) return #c == 3 and rising(c) end,
  coven = function(c) return #c >= 3 and allOf(c, "ability", "hex") end,
  roundtable = function(c, w) return #c == 4 and roundTable(c, w) end,
  pride = function(c, w) return #c == 4 and sameCoat(c, w) end,
  grandcharge = function(c) return #c == 5 and rising(c) end,
  fullpride = function(c, w) return #c == 5 and sameCoat(c, w) end,
}

-- Dominant coat of a group (nil when there is no majority, e.g. a Round Table).
function M.coatOf(cats, fid)
  if fid == "roundtable" then return nil end
  local count, best, bestN = {}, nil, 0
  for _, c in ipairs(cats) do
    count[c.coat] = (count[c.coat] or 0) + 1
    if count[c.coat] > bestN then best, bestN = c.coat, count[c.coat] end
  end
  if bestN * 2 < #cats and #cats > 1 then return nil end
  return best
end

-- Best formation that uses exactly these cats (no subsets). Used by the AI's search.
function M.exact(cats, hasWild)
  local sum = 0
  for _, c in ipairs(cats) do sum = sum + c.paws end
  local bestF, bestV
  for _, f in ipairs(M.LIST) do
    local ok = TESTS[f.id](cats, nil)
    if not ok and hasWild then
      for w = 1, #cats do if TESTS[f.id](cats, w) then ok = true; break end end
    end
    if ok then
      local v = (f.paws + sum) * f.cheer
      if not bestV or v > bestV then bestF, bestV = f, v end
    end
  end
  return bestF, bestV
end

-- Find the best formation inside the selected cats. Returns formation, list of scoring indices.
function M.detect(cats, hasWild)
  local n = #cats
  if n == 0 then return nil, {} end
  local bestF, bestIdx, bestV = nil, {}, -1
  for mask = 1, 2 ^ n - 1 do
    local sub, idx = {}, {}
    local m, i = mask, 1
    while m > 0 do
      if m % 2 == 1 then sub[#sub + 1] = cats[i]; idx[#idx + 1] = i end
      m = math.floor(m / 2)
      i = i + 1
    end
    local sum = 0
    for _, c in ipairs(sub) do sum = sum + c.paws end
    local wilds = hasWild and #sub or 0
    for _, f in ipairs(M.LIST) do
      local ok = TESTS[f.id](sub, nil)
      if not ok and wilds > 0 then
        for w = 1, wilds do if TESTS[f.id](sub, w) then ok = true; break end end
      end
      if ok then
        local v = (f.paws + sum) * f.cheer
        if v > bestV then bestF, bestIdx, bestV = f, idx, v end
      end
    end
  end
  return bestF, bestIdx
end

return M
