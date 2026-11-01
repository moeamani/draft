local cards = require("src.core.cards")
local cardview = require("src.ui.cardview")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local hud = require("src.ui.hud")
local overlays = require("src.ui.overlays")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c
S.bg = { C.ink, C.ink2, C.red, spin = 1.6 }

local SHOWCASE = { "merlinus", "purrceval", "artheline", "merline", "morgana", "lanceline", "uther" }

function S:enter()
  self.t = 0
  self.naming = false
  self.name = "Sir Whiskers"
  self.views = {}
  for i, id in ipairs(SHOWCASE) do
    local v = cardview.new({ uid = "show" .. i, id = id, level = 1, xp = 0 }, 1180, 1200, 0.62)
    self.views[i] = v
  end
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
    local x = 1150 + k * 92
    local y = 640 + math.abs(k) ^ 1.6 * 12 + math.sin(self.t * 1.4 + i) * 6
    v.hovered = i == hover
    v:setTarget(x, y + (v.hovered and -50 or 0), v.hovered and 0.78 or 0.62, k * 0.09)
    v:update(dt)
  end
  self.hover = hover
end

local function startNew()
  if not G.save then
    S.naming = true
    return
  end
  local function go()
    game.startRun(G.save)
    G.persist()
    G.go("draft")
  end
  if G.save.run then
    overlays.confirm("Abandon this run?", "Your champion flees the Arena. The Four Hands will hear of it.", "Abandon", function()
      game.finishRun(G.save, "defeat")
      game.arenaMovesOn(G.save)
      go()
    end)
  else
    go()
  end
end

function S:draw()
  local t = self.t
  -- mascot ghost
  local m = G.images.mascot
  lg.setColor(1, 1, 1, 0.1)
  lg.draw(m, 1240, 330, -0.12 + math.sin(t * 0.5) * 0.03, 0.85, 0.85, m:getWidth() / 2, m:getHeight() / 2)
  -- logo
  local logo = G.images["logo-lockup"]
  local ls = 0.5
  lg.push()
  lg.translate(420, 240 + math.sin(t * 1.2) * 6)
  lg.rotate(math.sin(t * 0.8) * 0.015)
  lg.setColor(0, 0, 0, 0.4)
  lg.draw(logo, 8, 12, 0, ls, ls, logo:getWidth() / 2, logo:getHeight() / 2)
  lg.setColor(1, 1, 1)
  lg.draw(logo, 0, 0, 0, ls, ls, logo:getWidth() / 2, logo:getHeight() / 2)
  lg.pop()
  local badge = G.images.badge
  lg.setColor(1, 1, 1)
  lg.draw(badge, 1490, 110, math.sin(t * 0.9) * 0.08, 0.36, 0.36, badge:getWidth() / 2, badge:getHeight() / 2)

  gfx.textf("A roguelike deck-drafting card battle for medieval cats.\nDraft your pride. Climb the Arena. Make enemies that remember you.", theme.font("serif", 21), 120, 478, 760, "left", C.paper2)

  if self.naming then
    gfx.panel(110, 540, 620, 300, { 0.03, 0.07, 0.05, 0.95 }, { border = C.gold, lw = 2 })
    gfx.text("Name your champion", theme.font("bold", 32), 140, 560, C.paper)
    gfx.text("The Four Hands will learn this name.", theme.font("serif", 18), 140, 602, C.muted, { shadow = 0 })
    gfx.panel(140, 640, 560, 64, C.black, { r = 10, depth = 0, border = C.gold, lw = 2, sheen = false })
    local cursor = (math.floor(t * 2) % 2 == 0) and "|" or ""
    gfx.text(self.name .. cursor, theme.font("bold", 34), 420, 650, C.paper, { align = "center" })
    if widgets.button("name_go", 140, 730, 560, 64, "Enter the Arena", { color = C.red }) then self:confirmName() end
  else
    local y = 560
    local s = G.save
    if s and s.run then
      if widgets.button("t_cont", 120, y, 380, 64, "Continue run", { color = C.red }) then
        if s.run.phase == "draft" then G.go("draft") elseif s.run.phase == "over" then G.go("summary") else G.go("map") end
      end
      y = y + 80
    end
    if widgets.button("t_new", 120, y, 380, 64, s and s.run and "New run" or "New run", { color = (s and s.run) and C.ink3 or C.red }) then startNew() end
    y = y + 80
    if s then
      if widgets.button("t_hands", 120, y, 380, 64, "The Four Hands", { color = C.ink3 }) then overlays.hands() end
      y = y + 80
    end
    if widgets.button("t_help", 120, y, 185, 56, "How to play", { color = C.ink3, size = 20 }) then overlays.help() end
    if widgets.button("t_quit", 315, y, 185, 56, "Quit", { color = C.ink3, size = 20 }) then love.event.quit() end
    if s then
      gfx.text(("Champion %s  |  Runs %d  |  Victories %d  |  Furthest ring %s"):format(s.playerName, s.runs, s.victories, hud.roman(math.max(1, math.min(4, s.bestRing + 1)))),
        theme.font("mono", 15), 120, 866, C.muted, { shadow = 0 })
    end
  end
  gfx.text("F11 fullscreen  |  F2 CRT  |  F3 sound", theme.font("mono", 13), 1570, 872, C.muted, { align = "right", shadow = 0 })

  for i, v in ipairs(self.views) do if i ~= self.hover then v:draw() end end
  if self.hover then self.views[self.hover]:draw() end
end

function S:confirmName()
  local name = self.name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then name = "Sir Whiskers" end
  G.save = game.newSave(name, os.time())
  game.startRun(G.save)
  G.persist()
  G.go("draft")
end

function S:textinput(t)
  if self.naming and #self.name < 18 then self.name = self.name .. t end
end

function S:keypressed(k)
  if self.naming then
    if k == "backspace" then self.name = self.name:sub(1, -2)
    elseif k == "return" or k == "kpenter" then self:confirmName()
    elseif k == "escape" then self.naming = false end
  end
end

return S
