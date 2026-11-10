-- The title screen, staged like the Overseer's poster: links along the top, the lockup in the
-- middle, a serif headline and two calls to action, and the flaming Overseer looming over a
-- table with a hand dealt face down. Mouse, keyboard (arrows or W A S D, Enter) and controller
-- (d-pad, A) all drive the same list. Options live here too (the pause menu opens the same panel).
local audio = require("src.audio")
local cardview = require("src.ui.cardview")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local overlays = require("src.ui.overlays")
local overseer = require("src.ui.overseer")
local plates = require("src.ui.plates")
local printer = require("src.ui.print")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c
local T = theme.T
S.bg = { preset = "menu" }
S.music = "menu"
S.VERSION = "1.0"

function S:enter()
  self.t = 0
  self.sel = 1
  self.logo = plates.image(G.images.logo, 92)
end

function S:update(dt) self.t = self.t + dt end

-- ---------------------------------------------------------------- actions

local function storyLine()
  local s = G.saves.story
  if not s then return "The tale of a nameless stray" end
  return require("src.core.story").progressLine(s)
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
    overlays.frame(170, 104, 300, 152, title)
    gfx.textf("Choose a name for your cat. The Four Hands will learn it.", T.body(), 184, 142, 272, "left", C.paper2, { bg = C.ink })
    local clicked, over = widgets.click("name_box", 184, 174, 272, 26)
    gfx.plate(184, 174, 272, 26, over and C.ink2 or C.deep, { outline = C.ink4, hi = false })
    local cursor = (math.floor(self.t * 2) % 2 == 0) and "|" or ""
    gfx.text(self.name .. cursor, T.big(), 320, 179, C.white, { align = "center", bg = C.deep })
    if clicked and G.platform.console then pcall(love.keyboard.setTextInput, true) end
    if widgets.button("name_ok", 320 - 70, 216, 140, 28, "Begin", { kind = "primary" }) then self:done() end
  end
  G.openOverlay(ov)
end

-- Pick a Crest and a stake (once there is more than one of either), then run onPick(crest, stake).
function S.pickCrest(onPick)
  local renown = require("src.core.renown")
  if #renown.crestsUnlocked(G.profile) <= 1 and renown.stakeOpen(G.profile) <= 1 then return onPick("stray", 1) end
  overlays.crests(onPick)
end

local function startFree()
  G.useMode("free")
  local s = G.save
  if s and s.run and s.run.phase ~= "over" then G.go("hub") return end
  if s then
    S.pickCrest(function(crest, stake)
      if s.run then game.arenaMovesOn(s) end
      game.startRun(s, crest, stake)
      G.persist()
      G.go("hub", { fresh = true })
    end)
    return
  end
  S.askName("A new festival", function(name)
    S.pickCrest(function(crest, stake)
      G.setSave(game.newSave(name, os.time()))
      game.startRun(G.save, crest, stake)
      G.persist()
      G.go("hub", { fresh = true })
    end)
  end)
end

local function startStory()
  G.useMode("story")
  G.go("story")
end

-- ---------------------------------------------------------------- options

local SPEEDS = { 1, 1.5, 2 }

-- One panel for every setting; the pause menu opens it too.
function S.settings()
  local ov = {}
  function ov:draw()
    local desktop = not G.platform.console
    local x, w = 170, 300
    overlays.frame(x, 20, w, 324, "Options")
    local lx, cx, cw = x + 14, x + 150, w - 164
    local y = 58
    local function row(label, sub)
      gfx.text(label, T.bold(), lx, y + 5, C.paper, { bg = C.ink })
      if sub then gfx.text(sub, T.small(), lx, y + 17, C.muted, { bg = C.ink }) end
    end
    local function toggle(id, label, on, disabled)
      row(label)
      local hit = widgets.button(id, cx, y, cw, 22, on and "On" or "Off", { kind = on and "info" or "secondary", disabled = disabled })
      y = y + 28
      return hit
    end
    -- sound
    row("Music")
    local mv = widgets.slider("opt_music", cx, y + 4, cw, G.settings.music or 0.7)
    y = y + 26
    row("Effects")
    local sv = widgets.slider("opt_sfx", cx, y + 4, cw, G.settings.sfx or 0.8)
    y = y + 28
    if mv ~= G.settings.music or sv ~= G.settings.sfx then
      local effectsMoved = sv ~= G.settings.sfx
      G.settings.music, G.settings.sfx = mv, sv
      audio.setVolumes(mv, sv)
      G.saveSettings()
      if effectsMoved then audio.note(4) end
    end
    -- picture
    if toggle("opt_crt", "CRT screen", G.crtOn(), not require("src.ui.shaders").crt) then G.cycleScreen() end
    if toggle("opt_shake", "Shake and motion", G.settings.shake ~= false) then
      G.settings.shake = G.settings.shake == false
      G.saveSettings()
    end
    row("Text")
    if widgets.button("opt_text", cx, y, cw, 22, G.settings.text == "pixel" and "Pixel" or "Smooth") then G.cycleText() end
    y = y + 28
    row("Game speed")
    for i, sp in ipairs(SPEEDS) do
      local bw = math.floor((cw - 4) / 3)
      local on = (G.settings.speed or 1) == sp
      if widgets.button("opt_sp" .. i, cx + (i - 1) * (bw + 2), y, bw, 22, sp .. "x", { kind = on and "info" or "secondary" }) then
        G.settings.speed = sp
        G.saveSettings()
      end
    end
    y = y + 28
    if desktop then
      if toggle("opt_fs", "Fullscreen", love.window.getFullscreen()) then G.toggleFullscreen() end
    end
    -- saves
    gfx.rule(lx, y + 2, w - 28, C.ink3)
    y = y + 10
    local half = math.floor((w - 28 - 4) / 2)
    if widgets.button("opt_wipe_s", lx, y, half, 22, "Reset story", { kind = "danger", disabled = not G.saves.story }) then
      overlays.confirm("Reset the story?", "Your story save is deleted. The Four Hands forget you. Your Renown stays.", "Delete", function() G.wipeSave("story") end)
    end
    if widgets.button("opt_wipe_f", lx + half + 4, y, half, 22, "Reset festivals", { kind = "danger", disabled = not G.saves.free }) then
      overlays.confirm("Reset festivals?", "Your free-festival save is deleted. The Four Hands forget you. Your Renown stays.", "Delete", function() G.wipeSave("free") end)
    end
    y = y + 30
    if desktop then
      gfx.textf("F11 fullscreen, F2 CRT, F3 mute.", T.small(), lx, y, w - 28, "left", C.muted, { bg = C.ink })
    end
  end
  G.openOverlay(ov)
end

-- ---------------------------------------------------------------- the list

local ITEMS = {
  { id = "story", act = startStory },
  { id = "free", act = startFree },
  { id = "renown", act = function() overlays.renown() end },
  { id = "cattery", label = "Cattery", act = function() overlays.cattery() end },
  { id = "rules", label = "Rules", act = function() overlays.help() end },
  { id = "options", label = "Options", act = S.settings },
  { id = "credits", label = "Credits", act = function() G.go("credits") end },
  { id = "quit", label = "Quit", act = function() love.event.quit() end },
}
local LINKS = { "cattery", "rules", "options", "credits", "quit" }

local function indexOf(id)
  for i, it in ipairs(ITEMS) do if it.id == id then return i end end
end

-- ---------------------------------------------------------------- drawing

local TABLE_Y = 312 -- where the table starts, below the Overseer

-- A text link in the top bar, underlined in red when pointed at or chosen.
local function link(self, id, x, y)
  local i = indexOf(id)
  local label = ITEMS[i].label
  local f = T.body()
  local w = f:getWidth(label)
  local clicked, over = widgets.click("menu_" .. id, x - 4, y - 4, w + 8, 20)
  if over then self.sel = i end
  local lit = over or self.sel == i
  gfx.text(label, f, x, y, lit and C.white or C.paper2, { bg = C.ink })
  if lit then
    theme.set(C.red)
    lg.rectangle("fill", math.floor(x), math.floor(y + 13), math.ceil(w), 2)
  end
  if clicked then audio.play("click"); ITEMS[i].act() end
  return x + w + 16
end

function S:draw()
  local t = self.t
  local renown = require("src.core.renown")
  -- the top bar: links on the left, the lockup in the middle, Renown on the right
  local x = 22
  for _, id in ipairs(LINKS) do x = link(self, id, x, 24) end
  plates.draw(self.logo, 320 - self.logo:getWidth() / 2, 8)
  local L = renown.level(G.profile.renown)
  local rl = "Renown  Lv " .. L
  local rw = math.ceil(T.bold():getWidth(rl)) + 24
  local ri = indexOf("renown")
  if widgets.inside(618 - rw, 18, rw, 24) then self.sel = ri end
  if widgets.button("menu_renown", 618 - rw, 18, rw, 24, rl, { kind = "primary", focused = self.sel == ri }) then ITEMS[ri].act() end
  -- the headline
  local head = "A cat-knight card game where the Four Hands remember every match, and the Overseer keeps the ledger."
  gfx.textf(head, T.title(), 140, 62, 360, "center", C.white, { bg = C.ink })
  -- the calls to action
  local si, fi = indexOf("story"), indexOf("free")
  local by = 146
  local calls = {
    { si, 150, "primary", G.saves.story and "Continue the story" or "Begin the story", storyLine() },
    { fi, 326, "secondary", "Free festival", freeLine() },
  }
  for _, b in ipairs(calls) do
    local i, bx = b[1], b[2]
    if widgets.inside(bx, by, 164, 36) then self.sel = i end
    if widgets.button("menu_" .. ITEMS[i].id, bx, by, 164, 36, b[4], { kind = b[3], sub = b[5], focused = self.sel == i, size = 12 }) then
      ITEMS[i].act()
    end
  end
  -- the Overseer looms over the table
  overseer.draw(320, TABLE_Y + 2, 320, t)
  printer.tableFront(TABLE_Y)
  -- a hand dealt face down on the table
  local backs = { "ember", "tide", "dark", "gilt", "plain" }
  for k, kind in ipairs(backs) do
    local off = k - 3
    local img = cardview.back(kind)
    local cx, cy = 320 + off * 34, TABLE_Y + 34 + math.abs(off) * 3 + math.floor(math.sin(t * 1.4 + k) * 1.2 + 0.5)
    theme.set(C.black, 0.4)
    lg.draw(img, cx + 2, cy + 3, off * 0.12, 1, 1, 28, 39)
    lg.setColor(1, 1, 1)
    lg.draw(img, cx, cy, off * 0.12, 1, 1, 28, 39)
  end
  local hint = G.platform.console and "D-pad choose   A select" or "Arrows choose   Enter select"
  local hw = math.ceil(T.small():getWidth(hint)) + 12
  gfx.plate(8, 338, hw, 16, C.deep, { hi = false })
  gfx.text(hint, T.small(), 14, 340, C.muted, { bg = C.deep })
  gfx.text("v" .. S.VERSION, T.small(), 630, 340, C.inkText, { align = "right", raw = true })
end

function S:nav(d)
  self.sel = (self.sel - 1 + d) % #ITEMS + 1
  audio.play("hover", 1, 0.5)
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
