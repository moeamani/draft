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
S.bg = { C.ink, C.ink2, C.red, spin = 1.4 }

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
    local x = 482 + k * 30
    local y = 272 + math.floor(math.abs(k) ^ 1.6 * 3) + math.floor(math.sin(self.t * 1.4 + i) * 2)
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
  lg.setColor(1, 1, 1, 0.14)
  lg.draw(self.mascot, 520, 150, -0.1 + math.sin(t * 0.5) * 0.03, 1, 1, 130, 130)
  lg.setColor(1, 1, 1)
  lg.draw(self.logo, 24, 26 + math.floor(math.sin(t * 1.2) * 2 + 0.5))
  lg.draw(self.badge, 548, 8)
  gfx.textf("A pixel card battle for medieval cats.\nForm your pride, win the festival, and make enemies who remember you.", theme.T.body(), 28, 186, 300, "left", C.paper2)
  if self.naming then
    gfx.panel(24, 216, 280, 120, C.deep, { border = C.goldDark })
    gfx.text("Name your champion", theme.T.headS(), 34, 222, C.paper)
    gfx.text("The Four Hands will learn this name.", theme.T.tiny(), 34, 238, C.muted)
    gfx.panel(34, 252, 260, 24, C.black, { shadow = false })
    local cursor = (math.floor(t * 2) % 2 == 0) and "_" or ""
    gfx.text(self.name .. cursor, theme.T.numL(), 164, 254, C.paper, { align = "center" })
    if widgets.button("name_go", 34, 288, 260, 30, "Enter the Festival", { color = C.red }) then self:confirmName() end
  else
    local y = 220
    local s = G.save
    if s and s.run and s.run.phase ~= "over" then
      if widgets.button("t_cont", 28, y, 180, 28, "Continue festival", { color = C.red }) then G.go("hub") end
      y = y + 34
    end
    if widgets.button("t_new", 28, y, 180, 28, "New festival", { color = (s and s.run and s.run.phase ~= "over") and C.ink3 or C.red }) then startNew() end
    y = y + 34
    if s then
      if widgets.button("t_hands", 28, y, 180, 28, "The Four Hands") then overlays.hands() end
      y = y + 34
    end
    if widgets.button("t_help", 28, y, 87, 24, "Rules", { font = theme.T.num() }) then overlays.help() end
    if widgets.button("t_quit", 121, y, 87, 24, "Quit", { font = theme.T.num() }) then love.event.quit() end
    if s then
      gfx.text(("%s  -  %d festivals  -  %d crowns"):format(s.playerName, s.runs, s.victories), theme.T.tiny(), 28, 346, C.muted)
    end
  end
  gfx.text("F11 FULLSCREEN   F2 CRT   F3 SOUND", theme.T.tiny(), 634, 348, C.muted, { align = "right" })
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
