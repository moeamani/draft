-- Scripted walkthrough used for headless verification: `love . --autotest shots`
-- Drives the real scenes and saves screenshots into the LÖVE save directory.
local game = require("src.core.game")
local overlays = require("src.ui.overlays")

local M = { steps = {}, i = 0, wait = 0, dir = "shots", mx = nil, my = nil, pendingShot = nil, log = {} }

local function step(delay, fn) M.steps[#M.steps + 1] = { delay = delay, fn = fn } end
local function shot(name) M.pendingShot = name end

local function playDuelUntilDone(maxTime)
  -- returns a step function that keeps pressing until the reward scene shows
  local elapsed = 0
  return function(dt)
    elapsed = elapsed + dt
    local sc = G.scene
    if G.sceneName ~= "duel" then return true end
    if sc.phase == "mulligan" then sc:startPlay() end
    if sc.lock <= 0 and #sc.timeline == 0 and require("src.core.duel").canPlay(sc.s, 1) then
      local hand = sc.s.sides[1].hand
      local me, foe = require("src.core.duel").score(sc.s, 1), require("src.core.duel").score(sc.s, 2)
      if #hand > 0 and (me <= foe or #hand > 5) then sc:playHand(hand[1]) else sc:pass() end
    end
    return elapsed > maxTime
  end
end

function M.start(dir)
  M.dir = dir or "shots"
  love.filesystem.createDirectory(M.dir)
  local save
  step(0.5, function()
    save = game.newSave("Sir Whiskers", 4242)
    G.save = save
    G.go("title", {}, true)
  end)
  step(1.2, function() shot("01_title") end)
  step(0.3, function() game.startRun(save); G.go("map", { dealt = true }, true) end)
  step(1.2, function() shot("03_map") end)
  step(0.2, function()
    local node
    for _, o in ipairs(save.run.options) do if o.kind == "skirmish" then node = o end end
    G.go("duel", { node = node }, true)
  end)
  step(1.6, function() shot("04_mulligan") end)
  step(0.1, function() G.scene:startPlay() end)
  M.steps[#M.steps + 1] = { delay = 0, tick = playDuelUntilDone(9), shotAfter = "05_duel" }
  step(0.1, function()
    local hand = G.scene.s and G.scene.s.sides[1].hand
    if hand and hand[1] then
      local v = G.scene.hand[hand[1].uid]
      if v then M.mx, M.my = v.x + 20, v.y - 30 end
    end
  end)
  step(0.8, function() shot("06_duel_hover"); M.mx, M.my = nil, nil end)
  M.steps[#M.steps + 1] = { delay = 0, tick = playDuelUntilDone(120) }
  step(2.0, function() shot("07_reward") end)
  step(0.2, function()
    save.run.options = { { kind = "warlord" } }
    save.run.step = 2
    save.run.detour = false
    G.go("encounter", { node = { kind = "warlord" } }, true)
  end)
  step(2.0, function() shot("08_encounter") end)
  step(0.2, function() G.go("duel", { node = { kind = "warlord" } }, true) end)
  step(0.2, function() G.scene:startPlay() end)
  M.steps[#M.steps + 1] = { delay = 0, tick = playDuelUntilDone(6), shotAfter = "09_warlord_duel" }
  step(0.2, function() G.go("market", {}, true) end)
  step(1.4, function() shot("10_market") end)
  step(0.2, function() G.go("event", { event = "discord" }, true) end)
  step(1.0, function() shot("11_event") end)
  step(0.2, function() G.go("map", {}, true); overlays.hands() end)
  step(1.0, function() shot("12_hands") end)
  step(0.2, function() G.closeOverlay(); overlays.deck(save.run.deck) end)
  step(1.2, function() shot("13_deck") end)
  step(0.2, function()
    G.closeOverlay()
    save.run.phase = "over"
    save.run.outcome = "defeat"
    save.run.killedBy = save.hands[4].id
    G.go("summary", {}, true)
  end)
  step(1.2, function() shot("14_summary") end)
  step(0.2, function() G.scene.news = game.arenaMovesOn(save) end)
  step(1.0, function() shot("15_news") end)
  step(0.5, function() print("AUTOTEST DONE"); love.event.quit() end)
end

function M.mouse(mx, my)
  if M.mx then return M.mx, M.my end
  return mx, my
end

function M.update(dt)
  local s = M.steps[M.i + 1]
  if not s then return end
  if s.tick then
    if s.tick(dt) then
      M.i = M.i + 1
      if s.shotAfter then shot(s.shotAfter) end
    end
    return
  end
  M.wait = M.wait + dt
  if M.wait >= s.delay then
    M.wait = 0
    M.i = M.i + 1
    local ok, err = pcall(s.fn)
    if not ok then print("AUTOTEST STEP ERROR: " .. tostring(err)); love.event.quit(1) end
  end
end

function M.afterDraw()
  if M.pendingShot then
    local name = M.pendingShot
    M.pendingShot = nil
    love.graphics.captureScreenshot(function(img)
      img:encode("png", M.dir .. "/" .. name .. ".png")
      print("shot " .. name)
    end)
  end
end

return M
