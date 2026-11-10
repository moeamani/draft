-- The Overseer: the flaming shadow cat behind the Four Hands, who keeps the Arena's ledger.
-- Drawn from the halftone frames baked by tools/art/bake_overseer.py: the flames cycle through
-- four frames, and now and then it blinks.
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}
M.FPS = 7
M.W, M.H = 640, 309 -- frame size
-- the eyes in frame pixels (left and right): centre and half size, for blinks
M.EYES = { { 271.5, 243.5 }, { 335, 243.5 } }
M.EYE_HALF = { 17, 13 }

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

-- Draw it with its bottom edge centred at (cx, bottom), w virtual pixels wide.
function M.draw(cx, bottom, w, t, alpha)
  local img = frameAt(t or 0)
  if not img then return 0 end
  local s = w / M.W
  local h = M.H * s
  local x, y = cx - w / 2, bottom - h
  lg.setColor(1, 1, 1, alpha or 1)
  lg.draw(img, x, y, 0, s, s)
  local shut = lids(t or 0)
  if shut > 0.02 then
    theme.set(theme.hex("#07080b"), alpha)
    for _, e in ipairs(M.EYES) do
      local ex, ey = x + (e[1] - M.EYE_HALF[1]) * s, y + (e[2] - M.EYE_HALF[2]) * s
      lg.rectangle("fill", ex, ey, M.EYE_HALF[1] * 2 * s, M.EYE_HALF[2] * 2 * s * shut)
    end
  end
  return h
end

-- Its face, cropped to a w x h box at (x, y): the eyes and the fire around them.
function M.face(x, y, w, h, t, alpha)
  local img = frameAt(t or 0)
  if not img then return end
  -- the crop in frame pixels, centred between the eyes
  local cw = 200
  local ch = cw * h / w
  local cx, cy = (M.EYES[1][1] + M.EYES[2][1]) / 2, M.EYES[1][2] - 20
  local s = w / cw
  local sx, sy, sw, sh = lg.getScissor()
  lg.setScissor(G.scissor(x, y, w, h))
  lg.setColor(1, 1, 1, alpha or 1)
  lg.draw(img, x - (cx - cw / 2) * s, y - (cy - ch / 2) * s, 0, s, s)
  if sx then lg.setScissor(sx, sy, sw, sh) else lg.setScissor() end
end

return M
