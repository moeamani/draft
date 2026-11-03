local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local overlays = require("src.ui.overlays")
local plates = require("src.ui.plates")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c
local T = theme.T
-- The title is the Figma title frame: the two-tone logo centred on dithered ink green.
S.bg = { horizon = 0, light = { 0.5, 0.34 }, radius = 0.85, power = 0.9 }

function S:enter()
  self.t = 0
  self.naming = false
  self.name = "Sir Whiskers"
  self.logo = plates.image(G.images.logo, 300)
end

function S:update(dt)
  self.t = self.t + dt
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
  local lw, lh = self.logo:getDimensions()
  plates.draw(self.logo, 320 - lw / 2, 34)
  local cx, bw = 320, 210
  local bx = cx - bw / 2
  if self.naming then
    gfx.panel(bx - 30, 214, bw + 60, 120, C.ink2)
    plates.print("Name your champion", 20, cx, 218, C.white, { align = "center" })
    gfx.text("The Four Hands will learn this name.", T.body(), cx, 242, C.paper2, { align = "center" })
    gfx.panel(bx - 16, 262, bw + 32, 26, C.deep, { shadow = false })
    local cursor = (math.floor(self.t * 2) % 2 == 0) and "_" or ""
    gfx.text(self.name .. cursor, T.big(), cx, 264, C.paper, { align = "center" })
    if widgets.button("name_go", bx - 16, 296, bw + 32, 30, "Enter the Festival", { color = C.red }) then self:confirmName() end
  else
    local y = 214
    local s = G.save
    local live = s and s.run and s.run.phase ~= "over"
    if live then
      if widgets.button("t_cont", bx, y, bw, 28, "Continue festival", { color = C.red }) then G.go("hub") end
      y = y + 33
    end
    if widgets.button("t_new", bx, y, bw, 28, "New festival", { color = live and C.ink3 or C.red }) then startNew() end
    y = y + 33
    if s then
      if widgets.button("t_hands", bx, y, bw, 28, "The Four Hands") then overlays.hands() end
      y = y + 33
    end
    if widgets.button("t_help", bx, y, bw / 2 - 2, 24, "Rules") then overlays.help() end
    if widgets.button("t_quit", bx + bw / 2 + 2, y, bw / 2 - 2, 24, "Quit") then love.event.quit() end
    if s then
      gfx.text(("%s, %d festivals, %d crowns"):format(s.playerName, s.runs, s.victories), T.body(), 12, 340, C.muted)
    end
  end
  gfx.text("F11 fullscreen   F2 CRT   F3 sound", T.body(), 628, 340, C.muted, { align = "right" })
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
