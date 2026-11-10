-- The credits: a slow scroll over the backdrop, with the Overseer watching from the corner.
local gfx = require("src.ui.gfx")
local overseer = require("src.ui.overseer")
local plates = require("src.ui.plates")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local S = {}
local C = theme.c
local T = theme.T
S.bg = { preset = "menu" }
S.music = "menu"

-- { kind, text }: "title" (serif), "head" (small caps), "line", "gap"
local LINES = {
  { "title", "Draft" },
  { "line", "Four Hands. One Arena." },
  { "gap" },
  { "head", "Design and direction" },
  { "line", "moeamani" },
  { "gap" },
  { "head", "Code, pixel art and sound" },
  { "line", "Written with Claude" },
  { "gap" },
  { "head", "Music" },
  { "line", "The teaser's theme opens the game." },
  { "line", "The soundtrack and effects are rendered in its key" },
  { "line", "by tools/audio/make_audio.py." },
  { "gap" },
  { "head", "Type" },
  { "line", "Ancizar Serif - Universidad Nacional de Colombia" },
  { "line", "Atkinson Hyperlegible - Braille Institute of America" },
  { "line", "Fusion Pixel - TakWolf" },
  { "line", "Coral Pixels - The Coral Pixels Project Authors" },
  { "line", "Jacquard 12, Jersey 15, Micro 5 - The Soft Type Project Authors" },
  { "line", "All under the SIL Open Font License 1.1." },
  { "gap" },
  { "head", "Made with" },
  { "line", "LÖVE (love2d.org), and LÖVE Potion on the Switch" },
  { "gap" },
  { "head", "The cast" },
  { "line", "Old Bedimew, the Crier, the Four Hands," },
  { "line", "forty-three cats and tricks," },
  { "line", "and the Overseer, who is still watching." },
  { "gap" },
  { "gap" },
  { "title", "Thank you for playing." },
}

local STEP = { title = 30, head = 14, line = 15, gap = 14 }

function S:enter()
  self.t = 0
  self.total = 0
  for _, l in ipairs(LINES) do self.total = self.total + STEP[l[1]] end
end

function S:update(dt) self.t = self.t + dt end

function S:draw()
  local t = self.t
  overseer.draw(110, theme.H + 8, 320, t, 0.9)
  gfx.panel(250, -8, 370, theme.H + 16, C.deep, { alpha = 0.92 })
  -- the scroll, clipped to the panel; it loops
  local span = self.total + theme.H
  local y = theme.H - (t * 22) % span
  love.graphics.setScissor(G.scissor(250, 4, 370, theme.H - 44))
  for _, l in ipairs(LINES) do
    local kind, text = l[1], l[2]
    if y > -30 and y < theme.H then
      if kind == "title" then plates.print(text, 24, 435, y, C.white, { align = "center", bg = C.deep })
      elseif kind == "head" then gfx.label(text, 435, y + 2, C.goldText, "center", { bg = C.deep })
      elseif kind == "line" then gfx.text(text, T.body(), 435, y, C.paper2, { align = "center", bg = C.deep }) end
    end
    y = y + STEP[kind]
  end
  love.graphics.setScissor()
  if widgets.button("cr_back", 512, 328, 100, 24, "Back", { focused = true }) then G.go("menu") end
end

function S:keypressed(k)
  if k == "escape" or k == "return" or k == "space" or k == "kpenter" then G.go("menu") end
end
function S:back() G.go("menu") end

return S
