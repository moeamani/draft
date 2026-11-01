local M = {}

-- Deep copy that shares card definitions (tables flagged with _def) instead of copying them.
function M.deepcopy(v, seen)
  if type(v) ~= "table" then return v end
  if v._def then return v end
  seen = seen or {}
  if seen[v] then return seen[v] end
  local out = {}
  seen[v] = out
  for k, x in pairs(v) do out[k] = M.deepcopy(x, seen) end
  return out
end

function M.indexOf(arr, x)
  for i, v in ipairs(arr) do if v == x then return i end end
  return nil
end

function M.removeValue(arr, x)
  local i = M.indexOf(arr, x)
  if i then table.remove(arr, i) end
  return i
end

function M.contains(arr, x) return M.indexOf(arr, x) ~= nil end

function M.filter(arr, f)
  local out = {}
  for _, v in ipairs(arr) do if f(v) then out[#out + 1] = v end end
  return out
end

function M.map(arr, f)
  local out = {}
  for i, v in ipairs(arr) do out[i] = f(v, i) end
  return out
end

function M.find(arr, f)
  for i, v in ipairs(arr) do if f(v) then return v, i end end
  return nil
end

function M.count(arr, f)
  local n = 0
  for _, v in ipairs(arr) do if f(v) then n = n + 1 end end
  return n
end

function M.keys(t)
  local out = {}
  for k in pairs(t) do out[#out + 1] = k end
  table.sort(out)
  return out
end

function M.concat(a, b)
  local out = {}
  for _, v in ipairs(a) do out[#out + 1] = v end
  for _, v in ipairs(b) do out[#out + 1] = v end
  return out
end

function M.clamp(x, a, b) return math.max(a, math.min(b, x)) end
function M.lerp(a, b, t) return a + (b - a) * t end

-- Serialize plain data (no functions/cycles) as Lua source.
local function ser(v, out, indent)
  local t = type(v)
  if t == "table" then
    out[#out + 1] = "{"
    local n = #v
    for i = 1, n do
      ser(v[i], out, indent)
      out[#out + 1] = ","
    end
    for k, x in pairs(v) do
      if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
          out[#out + 1] = k .. "="
        else
          out[#out + 1] = "["
          ser(k, out, indent)
          out[#out + 1] = "]="
        end
        ser(x, out, indent)
        out[#out + 1] = ","
      end
    end
    out[#out + 1] = "}"
  elseif t == "string" then
    out[#out + 1] = string.format("%q", v)
  elseif t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then out[#out + 1] = "0"
    elseif v % 1 == 0 then out[#out + 1] = string.format("%d", v)
    else out[#out + 1] = string.format("%.17g", v) end
  elseif t == "boolean" then
    out[#out + 1] = tostring(v)
  else
    out[#out + 1] = "nil"
  end
end

function M.serialize(v)
  local out = { "return " }
  ser(v, out, "")
  return table.concat(out)
end

function M.deserialize(s)
  local f = loadstring(s)
  if not f then return nil end
  setfenv(f, {})
  local ok, v = pcall(f)
  if ok then return v end
  return nil
end

return M
