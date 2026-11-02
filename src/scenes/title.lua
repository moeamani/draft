local art = require("src.ui.art")
local cardview = require("src.ui.cardview")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local overlays = require("src.ui.overlays")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c
local T = theme.T
local HORIZON = 214
-- the title is the table before a match: the mascot looms in the dark beyond it
S.bg = { horizon = HORIZON / 360, light = { 0.66, 0.8 }, radius = 0.62, power = 1.0 }

local SHOWCASE = { "merlinus", "purrceval", "artheline", "merline", "morgana", "lanceline", "uther" }

function S:enter()
  self.t = 0
  self.naming = false
  self.name = "Sir Whiskers"
  self.views = {}
  for i, id in ipairs(SHOWCASE) do
    self.views[i] = cardview.new({ uid = "show" .. i, id = id, level = 1, xp = 0 }, 480, 460, 1)
  end
  self.logo = art.bake(G.images["logo-lockup"], 280)
  self.mascot = art.bake(G.images.mascot, 260)
  self.badge = art.bake(G.images.badge, 84)
end

function S:update(dt)
  self.t = self.t + dt
  local n = #self.views
  local hover
  for i = n, 1, -1 do
    if not hover and widgets.layer == widgets.top and self.views[i]:contains(widgets.mx, widgets.my) then hover = i end
  end
  for i, v in ipairs(self.views) do
    local k = i - (n + 1) / 2
    local x = 466 + k * 32
    local y = 276 + math.floor(math.abs(k) ^ 1.6 * 3) + math.floor(math.sin(self.t * 1.4 + i) * 2)
    v.hovered = i == hover
    v:setTarget(x, y + (v.hovered and -16 or 0), v.hovered and 1.2 or 1, k * 0.1)
    v:update(dt)
  end
  self.hover = hover
end

local function begin()
  game.startRun(G.save)
  G.persist()
  G.go("hub", { fresh = true })
end

local function startNew()
  if not G.save then
    S.naming = true
    return
  end
  if G.save.run and G.save.run.phase ~= "over" then
    overlays.confirm("Abandon festival?", "Your champion slinks out of the festival. The Four Hands will hear of it.", "Abandon", function()
      game.finishRun(G.save, "defeat")
      game.arenaMovesOn(G.save)
      begin()
    end)
  else
    if G.save.run then game.arenaMovesOn(G.save) end
    begin()
  end
end

function S:draw()
  local t = self.t
  -- the mascot looms over the far edge of the table
  lg.setScissor(G.scissor(0, 0, theme.W, HORIZON + 1))
  lg.setColor(0.34, 0.34, 0.38)
  lg.draw(self.mascot, 470, HORIZON + 60 + math.floor(math.sin(t * 0.8) * 2), -0.06 + math.sin(t * 0.5) * 0.02, 1, 1, 130, 230)
  lg.setScissor()
  lg.setColor(1, 1, 1)
  lg.draw(self.logo, 24, 18 + math.floor(math.sin(t * 1.2) * 2 + 0.5))
  lg.draw(self.badge, 548, 8)
  gfx.textf("A candle-lit card duel for medieval cats. Win the festival, and make enemies who remember you.", T.body(), 28, 178, 340, "left", C.paper2)
  if self.naming then
    gfx.panel(24, 218, 300, 128, C.deep, { border = C.goldDark })
    gfx.text("Name your champion", T.big(), 34, 222, C.paper)
    gfx.text("The Four Hands will learn this name.", T.body(), 34, 244, C.paper2)
    gfx.panel(34, 264, 280, 26, C.black, { shadow = false })
    local cursor = (math.floor(t * 2) % 2 == 0) and "_" or ""
    gfx.text(self.name .. cursor, T.big(), 174, 266, C.paper, { align = "center" })
    if widgets.button("name_go", 34, 302, 280, 32, "Enter the Festival", { color = C.red }) then self:confirmName() end
  else
    local y = 224
    local s = G.save
    if s and s.run and s.run.phase ~= "over" then
      if widgets.button("t_cont", 28, y, 196, 28, "Continue festival", { color = C.red }) then G.go("hub") end
      y = y + 33
    end
    if widgets.button("t_new", 28, y, 196, 28, "New festival", { color = (s and s.run and s.run.phase ~= "over") and C.ink3 or C.red }) then startNew() end
    y = y + 33
    if s then
      if widgets.button("t_hands", 28, y, 196, 28, "The Four Hands") then overlays.hands() end
      y = y + 33
    end
    if widgets.button("t_help", 28, y, 96, 24, "Rules", { font = T.body() }) then overlays.help() end
    if widgets.button("t_quit", 128, y, 96, 24, "Quit", { font = T.body() }) then love.event.quit() end
    if s then
      gfx.text(("%s, %d festivals, %d crowns"):format(s.playerName, s.runs, s.victories), T.body(), 28, 340, C.muted)
    end
  end
  gfx.text("F11 fullscreen   F2 screen   F3 sound", T.body(), 632, 340, C.muted, { align = "right" })
  for i, v in ipairs(self.views) do if i ~= self.hover then v:draw() end end
  if self.hover then self.views[self.hover]:draw() end
end

function S:confirmName()
  local name = self.name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then name = "Sir Whiskers" end
  G.save = game.newSave(name, os.time())
  begin()
end

function S:textinput(t)
  if self.naming and #self.name < 16 then self.name = self.name .. t end
end

function S:keypressed(k)
  if self.naming then
    if k == "backspace" then self.name = self.name:sub(1, -2)
    elseif k == "return" or k == "kpenter" then self:confirmName()
    elseif k == "escape" then self.naming = false end
  end
end

return S
