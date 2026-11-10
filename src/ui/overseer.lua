-- The Overseer: the flaming shadow cat behind the Four Hands, who keeps the Arena's ledger.
-- Drawn from the pixel-art halftone frames baked by tools/art/bake_overseer.py: the flames
-- cycle through four frames, and now and then it blinks.
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
M.FPS = 7
M.W, M.H = 320, 155 -- frame size, in game pixels (drawn at whole-number scales only)
-- the eyes in frame pixels (left and right): centre and half size, for blinks
M.EYES = { { 135.5, 122 }, { 167.5, 122 } }
M.EYE_HALF = { 9, 7 }

local function frames()
  local imgs = G and G.images and G.images.overseer
  return imgs
end

local function frameAt(t)
  local imgs = frames()
  if not imgs or #imgs == 0 then return nil end
  return imgs[math.floor(t * M.FPS) % #imgs + 1]
end

-- How shut the eyes are at time t (0 open, 1 shut): a blink every few seconds.
local function lids(t)
  local cycle = 5.3
  local p = t % cycle
  if p > cycle - 0.16 then return math.sin((p - (cycle - 0.16)) / 0.16 * math.pi) end
  return 0
end

-- Draw it with its bottom edge centred at (cx, bottom). w picks the scale: the nearest whole
-- multiple of its 320 pixels (so 320 draws it 1:1, 640 doubles every pixel).
function M.draw(cx, bottom, w, t, alpha)
  local img = frameAt(t or 0)
  if not img then return 0 end
  local s = math.max(1, math.floor((w or M.W) / M.W + 0.5))
  local h = M.H * s
  local x, y = math.floor(cx - M.W * s / 2), math.floor(bottom - h)
  lg.setColor(1, 1, 1, alpha or 1)
  lg.draw(img, x, y, 0, s, s)
  local shut = lids(t or 0)
  if shut > 0.02 then
    theme.set(theme.hex("#07080b"), alpha)
    for _, e in ipairs(M.EYES) do
      local ex, ey = x + (e[1] - M.EYE_HALF[1]) * s, y + (e[2] - M.EYE_HALF[2]) * s
      lg.rectangle("fill", math.floor(ex), math.floor(ey), M.EYE_HALF[1] * 2 * s, math.floor(M.EYE_HALF[2] * 2 * s * shut + 0.5))
    end
  end
  return h
end

-- Its face, 1:1, cropped to a w x h box at (x, y): the eyes and the fire around them.
function M.face(x, y, w, h, t, alpha)
  local img = frameAt(t or 0)
  if not img then return end
  local cx, cy = (M.EYES[1][1] + M.EYES[2][1]) / 2, M.EYES[1][2] - 6
  local sx, sy, sw, sh = lg.getScissor()
  lg.setScissor(G.scissor(x, y, w, h))
  lg.setColor(1, 1, 1, alpha or 1)
  lg.draw(img, math.floor(x + w / 2 - cx), math.floor(y + h / 2 - cy))
  if sx then lg.setScissor(sx, sy, sw, sh) else lg.setScissor() end
end

return M
