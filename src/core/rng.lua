-- Seedable xorshift32 RNG. State lives in a plain table so it can be saved and deep-copied.
local bit = require("bit")

local M = {}

function M.new(seed)
  seed = math.floor(seed or os.time()) % 4294967296
  if seed == 0 then seed = 2463534242 end
  return { s = bit.tobit(seed) }
end

function M.next(r)
  local x = r.s
  x = bit.bxor(x, bit.lshift(x, 13))
  x = bit.bxor(x, bit.rshift(x, 17))
  x = bit.bxor(x, bit.lshift(x, 5))
  r.s = x
  return (x % 4294967296) / 4294967296
end

function M.int(r, n) return math.floor(M.next(r) * n) end
function M.range(r, lo, hi) return lo + M.int(r, hi - lo + 1) end
function M.chance(r, p) return M.next(r) < p end
function M.pick(r, arr) return arr[M.int(r, #arr) + 1] end

function M.shuffle(r, arr)
  for i = #arr, 2, -1 do
    local j = M.int(r, i) + 1
    arr[i], arr[j] = arr[j], arr[i]
  end
  return arr
end

-- items = { {value, weight}, ... }
function M.weighted(r, items)
  local total = 0
  for _, it in ipairs(items) do total = total + it[2] end
  local x = M.next(r) * total
  for _, it in ipairs(items) do
    x = x - it[2]
    if x <= 0 then return it[1] end
  end
  return items[#items][1]
end

function M.hash(str)
  local h = 5381
  for i = 1, #str do h = (h * 33 + str:byte(i)) % 4294967296 end
  return h
end

return M
