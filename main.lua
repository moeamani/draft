-- Draft - Four Hands. One Arena.
-- A roguelike cat card battler with a nemesis system. Built with LÖVE 11; also runs on LÖVE Potion
-- (Nintendo Switch homebrew) through the platform layer.
local platform = require("src.platform") -- first: fills in what LÖVE Potion lacks
local bakes = require("src.ui.bakes")
local input = require("src.input")
local fx = require("src.ui.fx")
local sfx = require("src.ui.sfx")
local shaders = require("src.ui.shaders")
local theme = require("src.ui.theme")
local util = require("src.core.util")
local widgets = require("src.ui.widgets")
local cardview = require("src.ui.cardview")
local lg = love.graphics

G = {
  save = nil, scene = nil, sceneName = nil, overlay = nil, images = {}, time = 0,
  scenes = {}, trans = nil, settings = { screen = "plain", music = true },
}

local W, H, SC = theme.W, theme.H, theme.SCALE
local canvas
local SAVE_FILE = "save.lua"
local SETTINGS_FILE = "settings.lua"

local SCENES = { "title", "hub", "vs", "match", "result", "market", "event", "summary" }

function G.persist()
  if G.save then love.filesystem.write(SAVE_FILE, util.serialize(G.save)) end
end

function G.wipeSave()
  love.filesystem.remove(SAVE_FILE)
  G.save = nil
end

local function loadSave()
  if not love.filesystem.getInfo(SAVE_FILE) then return nil end
  local s = util.deserialize(love.filesystem.read(SAVE_FILE))
  if s and s.version == 2 then return s end
  return nil
end

-- Screen modes: plain (default, the crisp Figma dither) <-> CRT
local SCREEN_MODES = { plain = "crt", crt = "plain" }
function G.cycleScreen()
  G.settings.screen = SCREEN_MODES[G.settings.screen] or "plain"
  G.saveSettings()
end

function G.screenLabel()
  return G.settings.screen == "crt" and "CRT" or "plain"
end

function G.saveSettings() love.filesystem.write(SETTINGS_FILE, util.serialize(G.settings)) end

-- Scene switch with a dithered wipe.
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
-- scissor rectangles are in canvas pixels, not virtual pixels
function G.scissor(x, y, w, h) return x * SC, y * SC, w * SC, h * SC end
function G.closeOverlay() G.overlay = nil end

-- the canvas is W*SC x H*SC; this returns how it maps onto the window
local function viewport()
  local ww, wh = lg.getDimensions()
  local s = math.min(ww / (W * SC), wh / (H * SC))
  if s >= 1 then s = math.floor(s * 2) / 2 end -- prefer clean multiples when we can
  return s, math.floor((ww - W * SC * s) / 2), math.floor((wh - H * SC * s) / 2)
end

function G.toVirtual(x, y)
  local s, ox, oy = viewport()
  return (x - ox) / (s * SC), (y - oy) / (s * SC)
end

function love.load(args)
  platform.init(args)
  G.platform = platform
  lg.setDefaultFilter("nearest", "nearest")
  lg.setLineStyle("rough")
  love.keyboard.setKeyRepeat(true)
  if platform.shaders() then shaders.load() end
  sfx.load(platform.console)
  for _, n in ipairs({ "logo", "mascot", "mascot-silhouette", "shadow" }) do
    G.images[n] = platform.image("assets/img/" .. n .. ".png", true)
    G.images[n]:setFilter("linear", "linear")
  end
  if platform.console then input.mode = "pad" end
  cardview.images = G.images
  pcall(function()
    local id = love.image.newImageData("assets/img/mascot.png")
    love.window.setIcon(id)
  end)
  canvas = lg.newCanvas(W * SC, H * SC)
  canvas:setFilter("linear", "linear")
  if love.filesystem.getInfo(SETTINGS_FILE) then
    local s = util.deserialize(love.filesystem.read(SETTINGS_FILE))
    if s then for k, v in pairs(s) do G.settings[k] = v end end
    if not SCREEN_MODES[G.settings.screen] then G.settings.screen = "plain" end
  end
  if G.settings.muted then sfx.toggleMute() end
  for _, n in ipairs(SCENES) do G.scenes[n] = require("src.scenes." .. n) end
  G.save = loadSave()
  G.go("title", {}, true)
  sfx.startMusic()
  for i, a in ipairs(args or {}) do
    if a == "--autotest" then
      G.autotest = require("src.autotest")
      G.autotest.start(args[i + 1])
    end
  end
end

function love.update(dt)
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
    tr.t = tr.t + dt * 2.6
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
  fx.update(dt)
  widgets.updateStates(dt)
  widgets.layer = "scene"
  if G.scene and G.scene.update then G.scene:update(dt) end
  widgets.layer = "overlay"
  if G.overlay and G.overlay.update then G.overlay:update(dt) end
  if G.autotest then G.autotest.update(dt) end
end

local hex = theme.hex
local function rgb(h) local c = hex(h); return { c[1], c[2], c[3] } end
local stageImages = {}

-- Every scene sits on one of the backdrop presets in src/ui/bakes.lua ("menu", "vs", "match"),
-- in ink green or blood red. With shaders it is computed live; without (LÖVE Potion) the same
-- picture is drawn from the PNG baked by tools/switch/bake_assets.py.
local function drawBackground()
  local bg = (G.scene and G.scene.bg) or {}
  local preset = bakes.STAGES[bg.preset or "menu"] or bakes.STAGES.menu
  local rampName = bakes.RAMPS[bg.ramp or "felt"] and (bg.ramp or "felt") or "felt"
  local ramp = bakes.RAMPS[rampName]
  local sh = shaders.stage
  if sh then
    sh:send("res", { W * SC, H * SC })
    sh:send("pix", SC)
    sh:send("horizon", preset.horizon)
    sh:send("light", preset.light)
    sh:send("radius", preset.radius)
    sh:send("power", preset.power)
    sh:send("voidc", rgb(ramp.voidc))
    sh:send("baseA", rgb(ramp.baseA))
    sh:send("baseB", rgb(ramp.baseB))
    sh:send("edge", rgb(ramp.edge))
    lg.setShader(sh)
    lg.setColor(1, 1, 1)
    lg.rectangle("fill", 0, 0, W * SC, H * SC)
    lg.setShader()
    return
  end
  local file = bakes.stageFile(bg.preset or "menu", rampName)
  if stageImages[file] == nil then
    local ok, img = pcall(lg.newImage, file)
    stageImages[file] = ok and img or false
    if ok then img:setFilter("nearest", "nearest") end
  end
  local img = stageImages[file]
  if img then
    lg.setColor(1, 1, 1)
    lg.draw(img, 0, 0, 0, W * SC / img:getWidth(), H * SC / img:getHeight())
  else
    theme.set(hex(ramp.baseA))
    lg.rectangle("fill", 0, 0, W * SC, H * SC)
  end
end

function love.draw()
  lg.setCanvas(canvas)
  lg.clear(theme.c.ink)
  drawBackground()
  lg.push()
  lg.scale(SC, SC)
  local sx, sy = fx.shakeOffset()
  lg.translate(sx, sy)
  widgets.layer = "scene"
  if G.scene and G.scene.draw then G.scene:draw() end
  if G.overlay then
    widgets.layer = "overlay"
    lg.setColor(0.01, 0.03, 0.02, 0.78)
    lg.rectangle("fill", -20, -20, W + 40, H + 40)
    G.overlay:draw()
  end
  widgets.layer = G.overlay and "overlay" or "scene"
  widgets.drawTooltip()
  fx.draw()
  input.draw()
  lg.pop()
  if G.trans then
    local p = math.min(1, G.trans.phase == "in" and G.trans.t or (1 - G.trans.t))
    if shaders.wipe then
      shaders.wipe:send("progress", p)
      shaders.wipe:send("tint", { 0.03, 0.06, 0.05 })
      lg.setShader(shaders.wipe)
      lg.rectangle("fill", 0, 0, W * SC, H * SC)
      lg.setShader()
    else
      lg.setColor(0.03, 0.06, 0.05, p)
      lg.rectangle("fill", 0, 0, W * SC, H * SC)
    end
  end
  lg.setCanvas()

  lg.clear(0, 0, 0)
  local s, ox, oy = viewport()
  if G.settings.screen == "crt" and shaders.post then
    shaders.post:send("res", { W * SC, H * SC })
    shaders.post:send("rows", H)
    shaders.post:send("curvature", 0.6)
    shaders.post:send("flash", fx.flash * 0.2)
    lg.setShader(shaders.post)
  end
  lg.setColor(1, 1, 1)
  lg.draw(canvas, ox, oy, 0, s, s)
  lg.setShader()
  widgets.endFrame()
  if G.autotest then G.autotest.afterDraw() end
end

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

-- Controllers: A clicks under the cursor, B backs out of overlays, + opens the menu,
-- X is Enter (Charge!, Fight!), Y clears your cushions, L/R scroll.
local function back()
  if G.overlay and G.overlay.dismissable ~= false then G.closeOverlay()
  elseif G.sceneName == "title" and G.scene.naming then love.keypressed("escape") end
end

function love.gamepadpressed(_, button)
  input.mode = "pad"
  if button == "a" then widgets.pressed, widgets.down = true, true
  elseif button == "b" then back()
  elseif input.KEYS[button] then love.keypressed(input.KEYS[button])
  elseif input.SCROLL[button] then love.wheelmoved(0, input.SCROLL[button]) end
end

function love.gamepadreleased(_, button)
  if button == "a" then widgets.released, widgets.down = true, false end
end

function love.keypressed(k)
  if k == "f11" or (k == "return" and love.keyboard.isDown("lalt", "ralt")) then
    love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
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
  if G.scene and G.scene.textinput then G.scene:textinput(t) end
end

function love.quit()
  G.persist()
end
