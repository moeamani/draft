-- The intro: the teaser, played by the game itself, over the teaser's music.
--
-- A point of white light opens in the dark green and grows, ringed in cyan, blue, magenta and
-- orange like a lens flare, until the screen is white. The "Draft" lockup resolves out of a
-- red and blue fringe on the music's chime, the tagline follows, and the iris closes on the menu.
-- Any key, click or button skips it.
local audio = require("src.audio")
local theme = require("src.ui.theme")
local lg = love.graphics

local S = {}
local C = theme.c
S.bg = { preset = "menu", flow = 0 }

-- the teaser's timing, in seconds (the chime that brings the logo in lands at about 8.5)
local GROW_FROM, WHITE_AT, LOGO_AT, TAG_AT, END_AT = 0.6, 5.4, 8.3, 9.9, 11.6

-- the lens rings from the orb outwards: where (in orb radii) and what colour
local RINGS = {
  { 2.6, theme.hex("#ff8a3a"), 0.10 }, { 2.25, theme.hex("#ff5a6e"), 0.14 }, { 1.95, theme.hex("#e040c8"), 0.18 },
  { 1.7, theme.hex("#7a3ff0"), 0.22 }, { 1.48, theme.hex("#1f3fd0"), 0.3 }, { 1.3, theme.hex("#1f66e8"), 0.38 },
  { 1.16, theme.hex("#52e3f6"), 0.5 }, { 1.07, theme.hex("#b8f7ff"), 0.7 }, { 1.0, theme.hex("#ffffff"), 1.0 },
}

local fonts = {}
local function bigFont(size)
  local px = math.floor(size * theme.K + 0.5)
  if not fonts[px] then
    local ok, f = pcall(lg.newFont, "assets/fonts/AncizarSerif-Regular.ttf", px)
    if not ok then f = lg.newFont(px) end
    f:setFilter("linear", "linear")
    fonts[px] = f
  end
  return fonts[px]
end

function S:enter()
  self.t = 0
  self.leaving = false
  self.length = audio.sting("teaser")
end

function S:skip()
  if self.leaving then return end
  self.leaving = true
  G.go("menu")
end

function S:update(dt)
  self.t = self.t + dt
  if self.t >= END_AT then self:skip() end
end

local function easeIn(t) return t * t * t end
local function smooth(t) t = math.max(0, math.min(1, t)); return t * t * (3 - 2 * t) end

function S:draw()
  local t = self.t
  local cx, cy = theme.W / 2, theme.H / 2
  local far = math.sqrt((G.VW / 2) ^ 2 + (G.VH / 2) ^ 2)
  -- darkness first, so the light has something to open in
  theme.set(C.black, 0.55 * (1 - smooth((t - GROW_FROM) / 2)))
  lg.rectangle("fill", -G.OX - 2, -G.OY - 2, G.VW + 4, G.VH + 4)
  -- the orb
  local g = math.max(0, math.min(1, (t - GROW_FROM) / (WHITE_AT - GROW_FROM)))
  local r = 2 + easeIn(g) * far * 1.05 + smooth(g * 3) * 26 + math.sin(t * 5) * (1 - g)
  if t > GROW_FROM * 0.5 then
    local a = smooth((t - GROW_FROM * 0.5) / 0.6)
    for _, ring in ipairs(RINGS) do
      theme.set(ring[2], ring[3] * a)
      lg.circle("fill", cx, cy, r * ring[1], 48)
    end
  end
  -- white, once the orb has swallowed the screen
  local white = smooth((t - (WHITE_AT - 0.5)) / 0.6)
  if white > 0 then
    lg.setColor(1, 1, 1, white)
    lg.rectangle("fill", -G.OX - 2, -G.OY - 2, G.VW + 4, G.VH + 4)
  end
  -- the lockup: a red D and a blue "raft", resolving out of a colour fringe
  if t > LOGO_AT then
    local a = smooth((t - LOGO_AT) / 0.9)
    local split = (1 - smooth((t - LOGO_AT) / 1.4)) * 7 + 0.6
    local f = bigFont(64)
    local k = theme.K
    lg.setFont(f)
    local wD, wAll = f:getWidth("D") / k, f:getWidth("Draft") / k
    local x, y = math.floor(cx - wAll / 2), math.floor(cy - f:getHeight() / k / 2 - 6)
    local function word(dx, colD, colR, alpha)
      theme.set(colD, alpha)
      lg.print("D", x + dx, y, 0, 1 / k, 1 / k)
      theme.set(colR, alpha)
      lg.print("raft", x + wD + dx, y, 0, 1 / k, 1 / k)
    end
    word(-split, theme.hex("#ff5a4d"), theme.hex("#ff5a4d"), 0.45 * a)
    word(split, theme.hex("#35d6f5"), theme.hex("#35d6f5"), 0.45 * a)
    word(0, theme.hex("#e8483b"), theme.hex("#2471fc"), a)
    if t > TAG_AT then
      -- the tagline, letter-spaced like the teaser's small caps
      local ta = smooth((t - TAG_AT) / 0.6)
      local lf = theme.T.label()
      local real = lf:real()
      lg.setFont(real)
      local str = "FOUR HANDS.  ONE ARENA."
      local gap = 2.4
      local tw = 0
      for i = 1, #str do tw = tw + real:getWidth(str:sub(i, i)) / k + gap end
      local tx = cx - tw / 2
      local ty = y + f:getHeight() / k + 2
      theme.set(theme.hex("#5f7fb8"), ta)
      for i = 1, #str do
        local ch = str:sub(i, i)
        lg.print(ch, math.floor(tx * k + 0.5) / k, ty, 0, 1 / k, 1 / k)
        tx = tx + real:getWidth(ch) / k + gap
      end
    end
  end
  -- skipping: a click or a tap anywhere
  local widgets = require("src.ui.widgets")
  if widgets.released and t > 0.3 then self:skip() end
end

function S:keypressed() self:skip() end
function S:back() self:skip() end
function S:nav() self:skip() end

return S
