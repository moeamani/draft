-- Mouse, touchscreen and controller folded into one pointer for the immediate-mode widgets.
--   mouse:      as usual
--   touch:      tap to click, drag to drag (LÖVE Potion sends touch events, never mouse events)
--   controller: a cursor on the left stick or d-pad; A clicks and drags
-- Other buttons map to the game's keyboard shortcuts.
local theme = require("src.ui.theme")

local M = { mode = "mouse", x = 320, y = 200, tx = nil, ty = nil, lift = nil, step = 0, held = false }
local W, H = theme.W, theme.H

-- LÖVE gamepad button names. LÖVE Potion maps the Switch's A/B/X/Y by label, + to "start", - to "back".
M.KEYS = { start = "escape", back = "escape", x = "return", y = "backspace" }
M.SCROLL = { leftshoulder = 1, rightshoulder = -1 }

local DEAD, SPEED, NUDGE = 0.22, 460, 6

function M.pad()
  if not love.joystick or not love.joystick.getJoysticks then return nil end
  for _, j in ipairs(love.joystick.getJoysticks()) do
    local ok, isPad = pcall(function() return j:isGamepad() end)
    if not ok or isPad then return j end
  end
end

local function axis(j, name)
  local ok, v = pcall(j.getGamepadAxis, j, name)
  return ok and v or 0
end

local function held(j, name)
  local ok, v = pcall(j.isGamepadDown, j, name)
  return ok and v
end

function M.update(dt)
  -- a lifted finger keeps its position for the frame that handles the release, then leaves
  if M.lift then
    M.lift = M.lift - 1
    if M.lift <= 0 then M.tx, M.ty, M.lift = nil, nil, nil end
  end
  local j = M.pad()
  if not j then return end
  local ax, ay = axis(j, "leftx"), axis(j, "lefty")
  local mag = math.sqrt(ax * ax + ay * ay)
  if mag > DEAD then
    local k = math.min(1, (mag - DEAD) / (1 - DEAD)) ^ 1.7
    local v = 30 + SPEED * k
    M.x, M.y = M.x + ax / mag * v * dt, M.y + ay / mag * v * dt
    M.mode = "pad"
  end
  local dx = (held(j, "dpright") and 1 or 0) - (held(j, "dpleft") and 1 or 0)
  local dy = (held(j, "dpdown") and 1 or 0) - (held(j, "dpup") and 1 or 0)
  if dx ~= 0 or dy ~= 0 then
    M.step = M.step - dt
    if M.step <= 0 then
      M.x, M.y = M.x + dx * NUDGE, M.y + dy * NUDGE
      M.step = M.held and 0.035 or 0.22
      M.held = true
      M.mode = "pad"
    end
  else
    M.held, M.step = false, 0
  end
  M.x = math.max(0, math.min(W - 1, M.x))
  M.y = math.max(0, math.min(H - 1, M.y))
end

-- The pointer in virtual pixels, given where the mouse is.
function M.position(mx, my)
  if M.mode == "pad" then return M.x, M.y end
  if M.mode == "touch" then return M.tx or -100, M.ty or -100 end
  return mx, my
end

function M.touch(kind, vx, vy)
  M.mode = "touch"
  M.tx, M.ty = vx, vy
  M.x, M.y = vx, vy
  M.lift = kind == "released" and 2 or nil
end

-- Draw the controller cursor (only while a controller is driving).
function M.draw()
  if M.mode ~= "pad" then return end
  local icons = require("src.ui.icons")
  icons.draw("pointer", math.floor(M.x) + 4, math.floor(M.y) + 5, theme.c.white)
end

return M
