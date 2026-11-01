-- Draft - Four Hands. One Arena.
-- A roguelike cat card battler with a nemesis system. Built with LÖVE 11.
local fx = require("src.ui.fx")
local sfx = require("src.ui.sfx")
local shaders = require("src.ui.shaders")
local theme = require("src.ui.theme")
local util = require("src.core.util")
local widgets = require("src.ui.widgets")
local cardview = require("src.ui.cardview")
local lg = love.graphics

G = {
  save = nil, scene = nil, sceneName = nil, overlay = nil, images = {}, crt = true, time = 0,
  scenes = {}, trans = nil, settings = { crt = true, crtCurve = "subtle", music = true },
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

-- CRT modes: subtle curve -> flat screen -> off
function G.cycleCrt()
  local st = G.settings
  if st.crt and st.crtCurve ~= "flat" then st.crtCurve = "flat"
  elseif st.crt then st.crt = false
  else st.crt = true; st.crtCurve = "subtle" end
  G.saveSettings()
end

function G.crtLabel()
  if not G.settings.crt then return "off" end
  return G.settings.crtCurve == "flat" and "flat" or "subtle curve"
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
function G.scissor(x, y, w, h) return x, y, w, h end
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
  lg.setDefaultFilter("nearest", "nearest")
  lg.setLineStyle("rough")
  love.keyboard.setKeyRepeat(true)
  shaders.load()
  sfx.load()
  for _, n in ipairs({ "logo-lockup", "wordmark", "tagline", "mascot", "shadow", "badge" }) do
    G.images[n] = lg.newImage("assets/img/" .. n .. ".png", { mipmaps = true })
    G.images[n]:setFilter("linear", "linear")
    G.images[n]:setMipmapFilter("linear")
  end
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
  local mx, my = G.toVirtual(love.mouse.getPosition())
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

local function drawBackground()
  local bg = (G.scene and G.scene.bg) or { theme.c.ink, theme.c.ink2, theme.c.red }
  local sh = shaders.background
  if sh then
    sh:send("time", G.time)
    sh:send("res", { W * SC, H * SC })
    sh:send("colA", { bg[1][1] * 0.85, bg[1][2] * 0.85, bg[1][3] * 0.85 })
    sh:send("colB", { bg[2][1], bg[2][2], bg[2][3] })
    sh:send("colC", { bg[3][1] * 0.55, bg[3][2] * 0.55, bg[3][3] * 0.55 })
    sh:send("spin", bg.spin or 1.2)
    sh:send("pix", SC * 2)
    lg.setShader(sh)
  end
  lg.setColor(1, 1, 1)
  lg.rectangle("fill", 0, 0, W * SC, H * SC)
  lg.setShader()
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
  lg.pop()
  if G.trans and shaders.wipe then
    local p = G.trans.phase == "in" and G.trans.t or (1 - G.trans.t)
    shaders.wipe:send("progress", math.min(1, p))
    shaders.wipe:send("tint", { 0.03, 0.06, 0.05 })
    lg.setShader(shaders.wipe)
    lg.rectangle("fill", 0, 0, W * SC, H * SC)
    lg.setShader()
  end
  lg.setCanvas()

  lg.clear(0, 0, 0)
  local s, ox, oy = viewport()
  if G.settings.crt and shaders.crt then
    shaders.crt:send("res", { W * SC, H * SC })
    shaders.crt:send("rows", H)
    shaders.crt:send("time", G.time)
    shaders.crt:send("strength", 1)
    shaders.crt:send("curvature", G.settings.crtCurve == "flat" and 0 or 1)
    shaders.crt:send("flash", fx.flash * 0.25)
    lg.setShader(shaders.crt)
  end
  lg.setColor(1, 1, 1)
  lg.draw(canvas, ox, oy, 0, s, s)
  lg.setShader()
  widgets.endFrame()
  if G.autotest then G.autotest.afterDraw() end
end

function love.mousepressed(_, _, b)
  if b == 1 then widgets.pressed = true; widgets.down = true end
end

function love.mousereleased(_, _, b)
  if b == 1 then widgets.released = true; widgets.down = false end
  if b == 2 and G.overlay and G.overlay.dismissable ~= false then G.closeOverlay() end
end

function love.keypressed(k)
  if k == "f11" or (k == "return" and love.keyboard.isDown("lalt", "ralt")) then
    love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
    return
  end
  if k == "f2" then
    G.cycleCrt()
    fx.toast("CRT: " .. G.crtLabel())
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
