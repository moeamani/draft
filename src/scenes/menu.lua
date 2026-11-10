-- The main menu, staged like the Overseer's poster: links along the top, the logo in the middle,
-- a serif headline and the calls to action, and the flaming Overseer looming over a table with a
-- hand dealt face down. Mouse, keyboard (arrows / W S, Enter) and controller (d-pad, A) all drive
-- the same list.
local cardview = require("src.ui.cardview")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local overlays = require("src.ui.overlays")
local overseer = require("src.ui.overseer")
local plates = require("src.ui.plates")
local printer = require("src.ui.print")
local audio = require("src.audio")
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
  self.logo = plates.image(G.images.logo, 92)
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

-- Pick a Crest (once more than one is unlocked), then run onPick(crestId).
function S.pickCrest(onPick)
  local renown = require("src.core.renown")
  if #renown.crestsUnlocked(G.profile) <= 1 then return onPick("stray") end
  overlays.crests(onPick)
end

local function startFree()
  G.useMode("free")
  local s = G.save
  if s and s.run and s.run.phase ~= "over" then G.go("hub") return end
  if s then
    S.pickCrest(function(crest)
      if s.run then game.arenaMovesOn(s) end
      game.startRun(s, crest)
      G.persist()
      G.go("hub", { fresh = true })
    end)
    return
  end
  S.askName("A new festival", function(name)
    S.pickCrest(function(crest)
      G.setSave(game.newSave(name, os.time()))
      game.startRun(G.save, crest)
      G.persist()
      G.go("hub", { fresh = true })
    end)
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
    overlays.frame(180, 24, 280, 318, "Settings")
    local x, w, y = 196, 248, 62
    local sfxm = require("src.audio")
    if not G.platform.console then
      if widgets.button("set_fs", x, y, w, 28, "Fullscreen: " .. (love.window.getFullscreen() and "on" or "off")) then G.toggleFullscreen() end
      y = y + 34
    end
    if widgets.button("set_crt", x, y, w, 28, "CRT screen: " .. (G.crtOn() and "on" or "off"), { disabled = not require("src.ui.shaders").crt }) then
      G.cycleScreen()
    end
    y = y + 34
    if widgets.button("set_text", x, y, w, 28, "Text: " .. (G.settings.text == "smooth" and "smooth" or "pixel")) then G.cycleText() end
    y = y + 34
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
    gfx.textf("F11 or Alt+Enter toggles fullscreen (Ctrl+Cmd+F on a Mac). F2 toggles the CRT, F3 the sound.", T.small(), x, y, w, "left", C.muted, { bg = C.ink })
  end
  G.openOverlay(ov)
end

local ITEMS = {
  { id = "story", label = "Story", sub = storyLine, act = startStory },
  { id = "free", label = "Free Festival", sub = freeLine, act = startFree },
  { id = "renown", label = "Renown", sub = function()
    local renown = require("src.core.renown")
    local L = renown.level(G.profile.renown)
    local got, total = renown.featCount(G.profile)
    return ("Level %d: %s. Feats %d of %d"):format(L, renown.title(L), got, total)
  end, act = function() overlays.renown() end },
  { id = "cattery", label = "The Cattery", sub = function() return "Every cat you've met" end, act = cattery },
  { id = "rules", label = "How to Play", sub = function() return "The rules, the coats, the tricks" end, act = function() overlays.help() end },
  { id = "settings", label = "Settings", sub = function() return "CRT, text, sound, saves" end, act = S.settings },
  { id = "quit", label = "Quit", act = function() love.event.quit() end },
}

-- ---------------------------------------------------------------- drawing

local TABLE_Y = 312 -- where the table starts, below the Overseer
local LINKS = { "cattery", "rules", "settings", "quit" }
local LINK_LABEL = { cattery = "Cattery", rules = "How to Play", settings = "Settings", quit = "Quit" }

local function indexOf(id)
  for i, it in ipairs(ITEMS) do if it.id == id then return i end end
end

-- A text link in the top bar, underlined when pointed at or chosen.
local function link(self, id, x, y)
  local i = indexOf(id)
  local label = LINK_LABEL[id]
  local f = T.body()
  local w = f:getWidth(label)
  local clicked, over = widgets.click("menu_" .. id, x - 3, y - 3, w + 6, 18)
  if over then self.sel = i end
  local lit = over or self.sel == i
  gfx.text(label, f, x, y, lit and C.white or C.paper2, { bg = C.ink })
  if lit then
    theme.set(C.red)
    lg.rectangle("fill", math.floor(x), math.floor(y + 13), math.ceil(w), 1)
  end
  if clicked then audio.play("click"); ITEMS[i].act() end
  return x + w + 16
end

function S:draw()
  local t = self.t
  local renown = require("src.core.renown")
  -- the top bar: links on the left, the logo in the middle, Renown on the right
  local x = 22
  for _, id in ipairs(LINKS) do x = link(self, id, x, 24) end
  plates.draw(self.logo, 320 - self.logo:getWidth() / 2, 8)
  local L = renown.level(G.profile.renown)
  local rl = "Renown  Lv " .. L
  local rw = T.bold():getWidth(rl) + 22
  local ri = indexOf("renown")
  local rover = widgets.inside(618 - rw, 19, rw, 22)
  if rover then self.sel = ri end
  if widgets.button("menu_renown", 618 - rw, 19, rw, 22, rl, { color = C.red, focused = self.sel == ri }) then ITEMS[ri].act() end
  -- the headline
  local head = "A cat-knight card game where the Four Hands remember every match, and the Overseer keeps the ledger."
  gfx.textf(head, theme.serif(21), 140, 62, 360, "center", C.white, { bg = C.ink })
  -- the calls to action
  local si, fi = indexOf("story"), indexOf("free")
  local by = 146
  for _, b in ipairs({ { si, 150, C.red, G.saves.story and "Continue the story" or "Begin the story", storyLine() },
    { fi, 326, C.ink3, "Free festival", freeLine() } }) do
    local i, bx = b[1], b[2]
    if widgets.inside(bx, by, 164, 32) then self.sel = i end
    if widgets.button("menu_" .. ITEMS[i].id, bx, by, 164, 32, b[4], { color = b[3], sub = b[5], focused = self.sel == i }) then
      ITEMS[i].act()
    end
  end
  -- the Overseer looms over the table
  overseer.draw(320, TABLE_Y + 2, 330, t)
  local tbl = printer.tableLayer(TABLE_Y, G.VW, G.VH, G.OX, G.OY)
  if tbl then
    lg.setColor(1, 1, 1)
    lg.draw(tbl, -G.OX, -G.OY, 0, 1 / printer.SCALE, 1 / printer.SCALE)
  end
  -- a hand dealt face down on the table
  local backs = { "ember", "tide", "dark", "gilt", "plain" }
  for k, kind in ipairs(backs) do
    local off = k - 3
    local img = cardview.back(kind)
    local cx, cy = 320 + off * 34, TABLE_Y + 34 + math.abs(off) * 3
    theme.set(C.black, 0.4)
    lg.draw(img, cx + 2, cy + 3, off * 0.12, 1, 1, 28, 39)
    lg.setColor(1, 1, 1)
    lg.draw(img, cx, cy, off * 0.12, 1, 1, 28, 39)
  end
  local hint = G.platform.console and "D-pad choose   A select   B back" or "Arrow keys choose   Enter select   F11 fullscreen"
  local hw = T.small():getWidth(hint) + 12
  gfx.box(8, 340, hw, 14, C.black, 0.7)
  gfx.text(hint, T.small(), 14, 341, C.paper2, { bg = C.black })
end

function S:nav(d)
  self.sel = (self.sel - 1 + d) % #ITEMS + 1
  audio.play("hover", 1, 0.4)
end

function S:keypressed(k)
  if k == "up" or k == "w" or k == "left" or k == "a" then self:nav(-1)
  elseif k == "down" or k == "s" or k == "right" or k == "d" then self:nav(1)
  elseif k == "return" or k == "space" or k == "kpenter" then
    audio.play("click")
    ITEMS[self.sel].act()
  elseif k == "escape" then S.settings() end
end

return S
