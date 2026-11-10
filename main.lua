-- Draft - Four Hands. One Arena.
-- A roguelike cat-knight card game with a nemesis system. Built with LÖVE 11; also runs on
-- LÖVE Potion (Nintendo Switch homebrew) through the platform layer.
--
-- Rendering: the game is laid out on a 640x360 virtual grid (the "safe area"). The window can be
-- any shape: the virtual area grows to fill it (the backdrop covers the extra margin, so there
-- are never black bars), and the safe area sits in the middle. Everything is drawn into one
-- canvas at K canvas pixels per virtual pixel (K = the window scale, rounded up), so pixel art
-- stays crisp and text is rasterised at the real screen resolution. The canvas is then shown
-- at exactly the window's size.
local platform = require("src.platform") -- first: fills in what LÖVE Potion lacks
local bakes = require("src.ui.bakes")
local input = require("src.input")
local fx = require("src.ui.fx")
local sfx = require("src.ui.sfx")
local printer = require("src.ui.print")
local shaders = require("src.ui.shaders")
local theme = require("src.ui.theme")
local util = require("src.core.util")
local widgets = require("src.ui.widgets")
local cardview = require("src.ui.cardview")
local lg = love.graphics

G = {
  save = nil, saves = {}, mode = nil, scene = nil, sceneName = nil, overlay = nil, images = {}, time = 0,
  scenes = {}, trans = nil,
  settings = { muted = false, fullscreen = false, shake = true, crt = true, text = "smooth", look = 8 },
  -- the visible virtual area and where the 640x360 safe area sits in it
  VW = 640, VH = 360, OX = 0, OY = 0, K = 2,
}

local W, H = theme.W, theme.H
local SETTINGS_FILE = "settings.lua"
local SAVE_FILES = { story = "story.lua", free = "festival.lua" }
local PROFILE_FILE = "renown.lua"
G.SAVE_VERSION = 3

G.SCENE_LIST = { "menu", "story", "cutscene", "hub", "vs", "match", "result", "market", "event", "summary" }

-- ---------------------------------------------------------------- saves

-- Two save slots: the story campaign and free festivals. G.save is the active one.
function G.useMode(mode)
  G.mode = mode
  G.save = G.saves[mode]
end

function G.setSave(save)
  G.saves[G.mode] = save
  G.save = save
end

function G.persist()
  if G.save and G.mode then
    require("src.core.game").noteDeck(G.save)
    love.filesystem.write(SAVE_FILES[G.mode], util.serialize(G.save))
  end
end

function G.wipeSave(mode)
  mode = mode or G.mode
  love.filesystem.remove(SAVE_FILES[mode])
  G.saves[mode] = nil
  if G.mode == mode then G.save = nil end
end

local function loadSave(mode)
  local file = SAVE_FILES[mode]
  if not love.filesystem.getInfo(file) then return nil end
  local s = util.deserialize(love.filesystem.read(file))
  if s and s.version == G.SAVE_VERSION then return s end
  return nil
end

function G.saveSettings() love.filesystem.write(SETTINGS_FILE, util.serialize(G.settings)) end

-- ---------------------------------------------------------------- Renown
-- One profile for both modes: Renown, feats and lifetime stats (see src/core/renown.lua).
local renown = require("src.core.renown")

local function loadProfile()
  if love.filesystem.getInfo(PROFILE_FILE) then
    local ok, p = pcall(util.deserialize, love.filesystem.read(PROFILE_FILE))
    if ok and p then return renown.fix(p) end
  end
  return renown.new()
end

function G.saveProfile() if G.profile then love.filesystem.write(PROFILE_FILE, util.serialize(G.profile)) end end

local function announceLevels(ups)
  for _, up in ipairs(ups or {}) do
    local unlock = up.crests[1] and ("You are " .. up.title .. " now. Unlocked: " .. up.crests[1].name .. ".") or ("You are " .. up.title .. " now.")
    fx.medal("Level " .. up.level, unlock, "level")
  end
end

-- Earn feats by id (each only once). Shows a medal for each new one.
function G.award(ids)
  if not G.profile then return {} end
  local got = {}
  for _, id in ipairs(ids or {}) do
    local f, ups = renown.earn(G.profile, id)
    if f then
      got[#got + 1] = f
      fx.medal(f.name, f.desc .. (f.renown > 0 and (" +" .. f.renown .. " Renown.") or ""), "feat")
      sfx.play("win", 1.3, 0.6)
      announceLevels(ups)
      if ups.legend then
        local lf = renown.FEAT.legend
        got[#got + 1] = lf
        fx.medal(lf.name, lf.desc, "feat")
      end
    end
  end
  if #got > 0 then G.saveProfile() end
  return got
end

-- Add Renown; returns the levels gained.
function G.addRenown(n)
  if not G.profile then return {} end
  local ups = renown.gain(G.profile, n)
  announceLevels(ups)
  if renown.level(G.profile.renown) >= 10 then G.award({ "legend" }) end
  G.saveProfile()
  return ups
end

-- The CRT screen (on by default; needs shaders, so never on LÖVE Potion).
local CRT_CURVE = 0.07
function G.crtOn() return G.settings.crt ~= false and shaders.crt ~= nil end
function G.cycleScreen()
  G.settings.crt = not G.crtOn()
  G.saveSettings()
end
-- Smooth, screen-resolution type (default) or pixel fonts on the art grid.
function G.cycleText()
  G.settings.text = G.settings.text == "smooth" and "pixel" or "smooth"
  theme.setTextStyle(G.settings.text)
  G.saveSettings()
end

function G.screenLabel()
  if not shaders.crt then return "plain" end
  return G.crtOn() and "CRT" or "plain"
end

-- ---------------------------------------------------------------- the window

local canvas
local view = { s = 2, k = 2, dpi = 1 }

local function layout()
  local pw, ph = lg.getPixelDimensions()
  local dpi = (lg.getDPIScale and lg.getDPIScale()) or 1
  local s = math.min(pw / W, ph / H)
  local k = math.max(1, math.ceil(s - 0.001))
  local vw, vh = pw / s, ph / s
  G.VW, G.VH = vw, vh
  G.OX, G.OY = math.floor((vw - W) / 2), math.floor((vh - H) / 2)
  G.K = k
  theme.setScale(k)
  local cw, ch = math.ceil(vw * k), math.ceil(vh * k)
  if not canvas or canvas:getWidth() ~= cw or canvas:getHeight() ~= ch then
    if canvas then canvas:release() end
    local ok, cv = pcall(lg.newCanvas, cw, ch, { dpiscale = 1 })
    canvas = ok and cv or lg.newCanvas(cw, ch)
  end
  view.exact = math.abs(k - s) < 0.001
  view.s, view.k, view.dpi = s, k, dpi
end

function love.resize() layout() end

function G.toggleFullscreen(on)
  if on == nil then on = not love.window.getFullscreen() end
  love.window.setFullscreen(on, "desktop")
  G.settings.fullscreen = on
  G.saveSettings()
  layout()
end

-- window units (mouse, touch) -> virtual safe-area coordinates (through the CRT's curve)
function G.toVirtual(x, y)
  local px, py = x * view.dpi, y * view.dpi
  if G.crtOn() then
    local pw, ph = lg.getPixelDimensions()
    local u, v = shaders.warp(px / pw, py / ph, CRT_CURVE)
    px, py = u * pw, v * ph
  end
  return px / view.s - G.OX, py / view.s - G.OY
end

-- scissor rectangles are in canvas pixels
function G.scissor(x, y, w, h)
  local k = view.k
  return math.floor((x + G.OX) * k), math.floor((y + G.OY) * k), math.ceil(w * k), math.ceil(h * k)
end

-- ---------------------------------------------------------------- scenes

-- Scene switch with a clean stepped wipe.
function G.go(name, params, instant)
  if instant or not G.scene then
    G.overlay = nil
    G.sceneName = name
    G.scene = G.scenes[name]
    fx.reset()
    if G.scene.enter then G.scene:enter(params or {}) end
    return
  end
  if G.trans then return end
  sfx.play("whoosh", 1, 0.6)
  G.trans = { t = 0, phase = "in", name = name, params = params }
end

function G.openOverlay(ov) G.overlay = ov end
function G.closeOverlay() G.overlay = nil end

function love.load(args)
  platform.init(args)
  G.platform = platform
  lg.setDefaultFilter("nearest", "nearest")
  lg.setLineStyle("rough")
  love.keyboard.setKeyRepeat(true)
  if platform.shaders() then shaders.load() end
  sfx.load(platform.console)
  for _, n in ipairs({ "logo", "mascot", "mascot-silhouette" }) do
    G.images[n] = platform.image("assets/img/" .. n .. ".png", true)
    G.images[n]:setFilter("linear", "linear")
  end
  -- the Overseer's flickering frames (tools/art/bake_overseer.py)
  G.images.overseer = {}
  for i = 0, 3 do
    local img = platform.image("assets/img/overseer-" .. i .. ".png", true)
    img:setFilter("linear", "linear")
    G.images.overseer[#G.images.overseer + 1] = img
  end
  if platform.console then input.mode = "pad" end
  cardview.images = G.images
  pcall(function()
    local id = love.image.newImageData("assets/img/mascot.png")
    love.window.setIcon(id)
  end)
  if love.filesystem.getInfo(SETTINGS_FILE) then
    local s = util.deserialize(love.filesystem.read(SETTINGS_FILE))
    if s then for k, v in pairs(s) do G.settings[k] = v end end
    -- round 8 made smooth type the default again; older settings files still say "pixel"
    if (G.settings.look or 0) < 8 then G.settings.text, G.settings.look = "smooth", 8 end
  end
  theme.setTextStyle(G.settings.text)
  if G.settings.fullscreen and not platform.console then pcall(love.window.setFullscreen, true, "desktop") end
  layout()
  if G.settings.muted then sfx.toggleMute() end
  for _, n in ipairs(G.SCENE_LIST) do G.scenes[n] = require("src.scenes." .. n) end
  G.saves.story, G.saves.free = loadSave("story"), loadSave("free")
  G.profile = loadProfile()
  G.go("menu", {}, true)
  sfx.startMusic()
  for i, a in ipairs(args or {}) do
    if a == "--autotest" then
      G.autotest = require("src.autotest")
      G.autotest.start(args[i + 1])
    end
  end
end

-- ---------------------------------------------------------------- the safety net
-- An error inside a frame doesn't end the game: it's written to crash.log (in the save folder),
-- progress is saved, and you're taken back to the menu with a message. Only an error that keeps
-- repeating falls through to LÖVE's error screen.
local crashes = {}
function G.recover(err)
  print("[crash] " .. tostring(err))
  pcall(function()
    local old = love.filesystem.getInfo("crash.log") and love.filesystem.read("crash.log") or ""
    local entry = os.date("%Y-%m-%d %H:%M:%S") .. "  scene=" .. tostring(G.sceneName) .. "\n" .. tostring(err) .. "\n\n"
    love.filesystem.write("crash.log", (old .. entry):sub(-60000))
  end)
  local now = love.timer.getTime()
  crashes[#crashes + 1] = now
  while crashes[1] and now - crashes[1] > 3 do table.remove(crashes, 1) end
  if #crashes >= 4 then error(err, 0) end
  for _ = 1, 64 do if not pcall(lg.pop) then break end end
  pcall(lg.setCanvas)
  pcall(lg.setShader)
  pcall(lg.setScissor)
  pcall(lg.setBlendMode, "alpha")
  pcall(G.persist)
  G.overlay, G.trans = nil, nil
  widgets.pressed, widgets.released, widgets.down = false, false, false
  local ok = pcall(G.go, "menu", {}, true)
  if not ok then error(err, 0) end
  fx.toast("Something went wrong, so you're back at the menu. Your progress is saved (details in crash.log).", "bad")
end

local function safely(fn, ...)
  local ok, err = xpcall(fn, debug.traceback, ...)
  if not ok then G.recover(err) end
end

local update, draw

function love.update(dt) safely(update, dt) end
function love.draw() safely(draw) end

function update(dt)
  dt = math.min(dt, 1 / 30)
  G.time = G.time + dt
  input.update(dt)
  local mx, my = input.position(G.toVirtual(love.mouse.getPosition()))
  if G.autotest then mx, my = G.autotest.mouse(mx, my) end
  widgets.beginFrame(mx, my)
  widgets.top = G.overlay and "overlay" or "scene"
  if G.trans then
    widgets.top = "none"
    local tr = G.trans
    tr.t = tr.t + dt * 3
    if tr.phase == "in" and tr.t >= 1 then
      G.overlay = nil
      G.sceneName = tr.name
      G.scene = G.scenes[tr.name]
      fx.reset()
      if G.scene.enter then G.scene:enter(tr.params or {}) end
      tr.phase, tr.t = "out", 0
    elseif tr.phase == "out" and tr.t >= 1 then
      G.trans = nil
    end
  end
  -- hit-stop: a big moment (a capture, a crushing win) freezes the table for a beat
  local sdt = dt
  if (G.hitstop or 0) > 0 then
    G.hitstop = G.hitstop - dt
    sdt = dt * 0.06
  end
  fx.update(sdt)
  widgets.updateStates(dt)
  widgets.layer = "scene"
  if G.scene and G.scene.update then G.scene:update(sdt) end
  widgets.layer = "overlay"
  if G.overlay and G.overlay.update then G.overlay:update(dt) end
  if G.autotest then G.autotest.update(dt) end
end

-- ---------------------------------------------------------------- the backdrop

local hex = theme.hex
local stageImages = {}

-- Every scene sits on one of the backdrop presets in src/ui/bakes.lua ("menu", "vs", "match"),
-- in ink green or blood red: the only dithered surface in the game. It fills the whole window.
local function drawBackground(cw, ch)
  local bg = (G.scene and G.scene.bg) or {}
  local rampName = bakes.RAMPS[bg.ramp or "felt"] and (bg.ramp or "felt") or "felt"
  local ramp = bakes.RAMPS[rampName]
  -- the print backdrop: grain, a halftone light, a table for matches; baked per window shape
  local img = printer.image(bg, G.VW, G.VH, G.OX, G.OY)
  if img then
    lg.setColor(1, 1, 1)
    lg.draw(img, 0, 0, 0, view.k / printer.SCALE, view.k / printer.SCALE)
    return
  end
  -- no ImageData on this platform: the pre-baked PNGs
  local file = bakes.stageFile(bg.preset or "menu", rampName)
  if stageImages[file] == nil then
    local ok, im = pcall(lg.newImage, file)
    stageImages[file] = ok and im or false
    if ok then im:setFilter("nearest", "nearest") end
  end
  local im = stageImages[file]
  if im then
    lg.setColor(1, 1, 1)
    lg.draw(im, 0, 0, 0, cw / im:getWidth(), ch / im:getHeight())
  else
    theme.set(hex(ramp.baseA))
    lg.rectangle("fill", 0, 0, cw, ch)
  end
end

-- A stepped wipe: columns of ink drop in, staggered left to right.
local function drawWipe(p, cw, ch)
  local cols = 16
  local colW = math.ceil(cw / cols)
  theme.set(theme.c.deep)
  for c = 0, cols - 1 do
    local pc = math.max(0, math.min(1, p * 1.6 - c / cols * 0.6))
    local h = math.floor(pc * ch / view.k + 0.5) * view.k
    lg.rectangle("fill", c * colW, 0, colW, h)
  end
end

function draw()
  local cw, ch = canvas:getWidth(), canvas:getHeight()
  lg.setCanvas(canvas)
  lg.clear(theme.c.ink)
  drawBackground(cw, ch)
  lg.push()
  lg.scale(view.k, view.k)
  lg.translate(G.OX, G.OY)
  local sx, sy = fx.shakeOffset()
  if G.settings.shake == false then sx, sy = 0, 0 end
  lg.translate(sx, sy)
  widgets.layer = "scene"
  if G.scene and G.scene.draw then G.scene:draw() end
  if G.overlay then
    widgets.layer = "overlay"
    require("src.ui.gfx").dim(0.78)
    G.overlay:draw()
  end
  widgets.layer = G.overlay and "overlay" or "scene"
  widgets.drawTooltip()
  fx.draw()
  input.draw()
  lg.pop()
  if G.trans then
    drawWipe(math.min(1, G.trans.phase == "in" and G.trans.t or (1 - G.trans.t)), cw, ch)
  end
  lg.setCanvas()
  lg.clear(0, 0, 0)
  lg.setColor(1, 1, 1)
  local crt = G.crtOn() and shaders.crt
  canvas:setFilter((view.exact and not crt) and "nearest" or "linear", "linear")
  if crt then
    local pw, ph = lg.getPixelDimensions()
    crt:send("screen", { pw, ph })
    crt:send("rows", G.VH)
    crt:send("time", G.time % 1000)
    crt:send("curve", CRT_CURVE)
    crt:send("amount", 1)
    lg.setShader(crt)
  end
  lg.draw(canvas, 0, 0, 0, view.s / view.k / view.dpi)
  lg.setShader()
  widgets.endFrame()
  if G.autotest then G.autotest.afterDraw() end
end

-- ---------------------------------------------------------------- input

function love.mousemoved(_, _, _, _, istouch)
  if not istouch then input.mode = "mouse" end
end

function love.mousepressed(_, _, b, istouch)
  if istouch then return end -- touches arrive through love.touchpressed
  input.mode = "mouse"
  if b == 1 then widgets.pressed = true; widgets.down = true end
end

function love.mousereleased(_, _, b, istouch)
  if istouch then return end
  if b == 1 then widgets.released = true; widgets.down = false end
  if b == 2 and G.overlay and G.overlay.dismissable ~= false then G.closeOverlay() end
end

-- Touchscreen (Switch handheld, tablets): a tap is a click, a drag is a drag.
function love.touchpressed(_, x, y)
  input.touch("pressed", G.toVirtual(x, y))
  widgets.mx, widgets.my = input.x, input.y
  widgets.pressed, widgets.down = true, true
end

function love.touchmoved(_, x, y)
  input.touch("moved", G.toVirtual(x, y))
end

function love.touchreleased(_, x, y)
  input.touch("released", G.toVirtual(x, y))
  widgets.released, widgets.down = true, false
end

-- Controllers: A clicks under the cursor, B backs out, + opens the menu, X is Enter, Y clears.
local function back()
  if G.overlay and G.overlay.dismissable ~= false then G.closeOverlay()
  elseif G.scene and G.scene.back then G.scene:back() end
end

function love.gamepadpressed(_, button)
  input.mode = "pad"
  if button == "a" then widgets.pressed, widgets.down = true, true
  elseif button == "b" then back()
  elseif input.KEYS[button] then love.keypressed(input.KEYS[button])
  elseif input.SCROLL[button] then love.wheelmoved(0, input.SCROLL[button])
  elseif button == "dpup" or button == "dpdown" then
    if G.scene and G.scene.nav and not G.overlay then G.scene:nav(button == "dpup" and -1 or 1) end
  end
end

function love.gamepadreleased(_, button)
  if button == "a" then widgets.released, widgets.down = true, false end
end

function love.keypressed(k)
  local mac = love.keyboard.isDown("lgui", "rgui") and love.keyboard.isDown("lctrl", "rctrl") and k == "f"
  if k == "f11" or mac or (k == "return" and love.keyboard.isDown("lalt", "ralt")) then
    G.toggleFullscreen()
    return
  end
  if k == "f2" then
    G.cycleScreen()
    fx.toast("Screen: " .. G.screenLabel())
    return
  end
  if k == "f3" then
    G.settings.muted = sfx.toggleMute()
    G.saveSettings()
    fx.toast(G.settings.muted and "Sound off" or "Sound on")
    return
  end
  if G.overlay and G.overlay.keypressed and G.overlay:keypressed(k) then return end
  if k == "escape" and G.overlay and G.overlay.dismissable ~= false then G.closeOverlay(); return end
  if G.scene and G.scene.keypressed then G.scene:keypressed(k) end
end

function love.wheelmoved(_, dy)
  if G.overlay and G.overlay.wheel then G.overlay:wheel(dy)
  elseif G.scene and G.scene.wheel then G.scene:wheel(dy) end
end

function love.textinput(t)
  if G.overlay and G.overlay.textinput then G.overlay:textinput(t) return end
  if G.scene and G.scene.textinput then G.scene:textinput(t) end
end

function love.quit()
  G.persist()
end
