-- The main menu: a festival night. Your champion faces the Four Hands under the Arena's bunting,
-- and the menu sits on the left. Mouse, keyboard (arrows / W S, Enter) and controller (d-pad, A)
-- all drive the same list.
local art = require("src.ui.art")
local fx = require("src.ui.fx")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local overlays = require("src.ui.overlays")
local plates = require("src.ui.plates")
local sfx = require("src.ui.sfx")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c
local T = theme.T
S.bg = { preset = "menu" }

function S:enter()
  self.t = 0
  self.sel = 1
  self.logo = plates.image(G.images.logo, 210)
end

function S:update(dt) self.t = self.t + dt end

-- ---------------------------------------------------------------- actions

local function storyLine()
  local s = G.saves.story
  if not s then return "Begin the tale of a nameless stray" end
  local story = require("src.core.story")
  return story.progressLine(s)
end

local function freeLine()
  local s = G.saves.free
  if not s then return "A festival with a random pride" end
  if s.run and s.run.phase ~= "over" then return ("Continue: %s"):format(s.run.festival.name) end
  return ("%d festivals, %d crowns"):format(s.runs, s.victories)
end

-- A name prompt as an overlay (the system keyboard opens on consoles).
function S.askName(title, onDone)
  local ov = { name = "", t = 0 }
  if G.platform.console then pcall(love.keyboard.setTextInput, true) end
  function ov:update(dt) self.t = self.t + dt end
  function ov:textinput(t)
    if G.platform.console then self.name = t:sub(1, 16); return end
    if #self.name < 16 then self.name = self.name .. t end
  end
  function ov:keypressed(k)
    if k == "backspace" then self.name = self.name:sub(1, -2); return true end
    if k == "return" or k == "kpenter" then self:done(); return true end
  end
  function ov:done()
    local n = self.name:gsub("^%s+", ""):gsub("%s+$", "")
    if n == "" then n = "Whiskers" end
    G.closeOverlay()
    pcall(love.keyboard.setTextInput, false)
    onDone(n)
  end
  function ov:draw()
    overlays.frame(170, 110, 300, 140, title)
    gfx.textf("Choose a name for your cat. The Four Hands will learn it.", T.body(), 184, 148, 272, "left", C.paper2, { bg = C.ink })
    local clicked, over = widgets.click("name_box", 184, 176, 272, 24)
    gfx.box(184, 176, 272, 24, C.black)
    gfx.box(185, 177, 270, 22, over and C.ink3 or C.deep)
    local cursor = (math.floor(self.t * 2) % 2 == 0) and "|" or ""
    gfx.text(self.name .. cursor, T.big(), 320, 180, C.white, { align = "center", bg = C.deep })
    if clicked and G.platform.console then pcall(love.keyboard.setTextInput, true) end
    if widgets.button("name_ok", 320 - 70, 210, 140, 26, "Begin", { color = C.red }) then self:done() end
  end
  G.openOverlay(ov)
end

local function startFree()
  G.useMode("free")
  local s = G.save
  if s and s.run and s.run.phase ~= "over" then G.go("hub") return end
  if s then
    if s.run then game.arenaMovesOn(s) end
    game.startRun(s)
    G.persist()
    G.go("hub", { fresh = true })
    return
  end
  S.askName("A new festival", function(name)
    G.setSave(game.newSave(name, os.time()))
    game.startRun(G.save)
    G.persist()
    G.go("hub", { fresh = true })
  end)
end

local function startStory()
  G.useMode("story")
  G.go("story")
end

local function cattery()
  overlays.cattery()
end

function S.settings()
  local ov = {}
  function ov:draw()
    overlays.frame(180, 70, 280, 230, "Settings")
    local x, w, y = 196, 248, 110
    local sfxm = require("src.ui.sfx")
    if not G.platform.console then
      if widgets.button("set_fs", x, y, w, 28, "Fullscreen: " .. (love.window.getFullscreen() and "on" or "off")) then G.toggleFullscreen() end
      y = y + 34
    end
    if widgets.button("set_snd", x, y, w, 28, "Sound: " .. (sfxm.muted and "off" or "on")) then
      G.settings.muted = sfxm.toggleMute(); G.saveSettings()
    end
    y = y + 34
    if widgets.button("set_shake", x, y, w, 28, "Screen shake: " .. (G.settings.shake == false and "off" or "on")) then
      G.settings.shake = G.settings.shake == false; G.saveSettings()
    end
    y = y + 34
    if widgets.button("set_wipe_s", x, y, w / 2 - 2, 24, "Reset story", { color = C.redDark, disabled = not G.saves.story }) then
      overlays.confirm("Reset story?", "Your story save is deleted. The Four Hands forget you.", "Delete", function() G.wipeSave("story") end)
    end
    if widgets.button("set_wipe_f", x + w / 2 + 2, y, w / 2 - 2, 24, "Reset festivals", { color = C.redDark, disabled = not G.saves.free }) then
      overlays.confirm("Reset festivals?", "Your free-festival save is deleted. The Four Hands forget you.", "Delete", function() G.wipeSave("free") end)
    end
    y = y + 32
    gfx.textf("F11 or Alt+Enter toggles fullscreen (Ctrl+Cmd+F on a Mac). F3 toggles sound.", T.small(), x, y, w, "left", C.muted, { bg = C.ink })
  end
  G.openOverlay(ov)
end

local ITEMS = {
  { id = "story", label = "Story", sub = storyLine, act = startStory },
  { id = "free", label = "Free Festival", sub = freeLine, act = startFree },
  { id = "cattery", label = "The Cattery", sub = function() return "Every cat you've met" end, act = cattery },
  { id = "rules", label = "How to Play", sub = function() return "The rules, the coats, the tricks" end, act = function() overlays.help() end },
  { id = "settings", label = "Settings", sub = function() return "Fullscreen, sound, saves" end, act = S.settings },
  { id = "quit", label = "Quit", act = function() love.event.quit() end },
}

-- ---------------------------------------------------------------- drawing

-- Strings of festival pennants across the top of the night.
local function bunting(t)
  local cols = { C.red, C.gold, C.blue, C.paper }
  for row = 0, 1 do
    local y0 = 6 + row * 26
    local sag = 10
    local n = 18
    local x0 = -G.OX - 10
    local span = G.VW + 20
    for i = 0, n do
      local u = i / n
      local x = x0 + u * span
      local y = y0 + math.sin(u * math.pi) * sag + row * 3
      local nx = x0 + (i + 1) / n * span
      local ny = y0 + math.sin((i + 1) / n * math.pi) * sag + row * 3
      theme.set(C.black, 0.6)
      lg.setLineWidth(1)
      lg.line(x, y, nx, ny)
      if i < n then
        local mx, my = (x + nx) / 2, (y + ny) / 2
        local flap = math.sin(t * 2 + i + row) * 1
        theme.set(C.black)
        lg.polygon("fill", mx - 5, my, mx + 5, my, mx + flap, my + 11)
        theme.set(cols[(i + row) % #cols + 1])
        lg.polygon("fill", mx - 4, my + 1, mx + 4, my + 1, mx + flap, my + 9)
      end
    end
  end
end

function S:draw()
  local t = self.t
  bunting(t)
  -- the scene: your champion faces the Four Hands
  local save = G.saves.story or G.saves.free
  local hands = save and save.hands
  for i = 4, 1, -1 do
    local x = 372 + (4 - i) * 64
    local y = 56 + (4 - i) * 4 + math.floor(math.sin(t * 1.3 + i) * 1.5 + 0.5)
    if hands and hands[i] then
      lg.setColor(0.55, 0.55, 0.6)
      lg.draw((art.nemesis(hands[i], i, 64, true)), x, y)
    else
      -- silhouettes until you've met them
      lg.setColor(0.07, 0.09, 0.08)
      lg.draw((art.stray({ seed = i * 131, coat = "shadow", elite = true }, 64, true)), x, y)
    end
  end
  gfx.text("The Four Hands", T.small(), 500, 46, C.muted, { align = "center", bg = C.ink })
  local me = art.player(save and save.playerName or "Whiskers", 150, true)
  lg.setColor(1, 1, 1)
  lg.draw(me, 410, 186 + math.floor(math.sin(t * 1.6) * 1.5 + 0.5))
  -- the logo and the menu
  plates.draw(self.logo, 30, 28)
  local x, y, w = 28, 28 + self.logo:getHeight() + 10, 240
  for i, it in ipairs(ITEMS) do
    local h = it.sub and 26 or 20
    local focused = self.sel == i
    local over = widgets.inside(x, y, w, h)
    if over then self.sel = i end
    if widgets.button("menu_" .. it.id, x, y, w, h, it.label, { color = i == 1 and C.red or C.ink3, sub = it.sub and it.sub() or nil, focused = focused }) then
      it.act()
    end
    y = y + h + 5
  end
  local hint = G.platform.console and "D-pad choose   A select   B back" or "Arrow keys choose   Enter select   F11 fullscreen"
  gfx.text(hint, T.small(), 628, 346, C.muted, { align = "right", bg = C.ink })
  gfx.text("v5", T.small(), 12, 346, C.muted, { bg = C.ink })
end

function S:nav(d)
  self.sel = (self.sel - 1 + d) % #ITEMS + 1
  sfx.play("hover", 1, 0.4)
end

function S:keypressed(k)
  if k == "up" or k == "w" then self:nav(-1)
  elseif k == "down" or k == "s" then self:nav(1)
  elseif k == "return" or k == "space" or k == "kpenter" then
    sfx.play("click")
    ITEMS[self.sel].act()
  elseif k == "escape" then S.settings() end
end

return S
