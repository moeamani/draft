-- Scripted walkthrough for headless verification: `love . --autotest shots`
-- Drives the real scenes and saves screenshots into the LÖVE save directory.
local cards = require("src.core.cards")
local game = require("src.core.game")
local match = require("src.core.match")
local overlays = require("src.ui.overlays")

local M = { steps = {}, i = 0, wait = 0, dir = "shots", mx = nil, my = nil, pendingShot = nil }

local function step(delay, fn) M.steps[#M.steps + 1] = { delay = delay, fn = fn } end
local function tick(fn, shotAfter) M.steps[#M.steps + 1] = { delay = 0, tick = fn, shotAfter = shotAfter } end
local function shot(name) M.pendingShot = name end

-- keep playing suggested placements until the match scene is gone (or a time limit)
local function autoMatch(limit)
  local elapsed = 0
  return function(dt)
    elapsed = elapsed + dt
    local sc = G.scene
    if G.sceneName ~= "match" then return true end
    if not sc.busy and not sc.finished then
      sc:applySuggestion()
      sc:charge()
    end
    return limit and elapsed > limit
  end
end

local function waitScene(name, limit)
  local elapsed = 0
  return function(dt)
    elapsed = elapsed + dt
    return G.sceneName == name or elapsed > (limit or 30)
  end
end

function M.start(dir)
  M.dir = dir or "shots"
  love.filesystem.createDirectory(M.dir)
  local save
  step(0.4, function()
    -- a fresh Renown profile with a few levels, so the Renown and Crest screens have something to show
    G.profile = require("src.core.renown").new()
    G.profile.renown = 640
    G.profile.stakeWon, G.profile.stake, G.profile.seals = 2, 3, { stray = 2, ember = 1 }
    save = game.newSave("Sir Whiskers", 4242)
    G.useMode("free")
    G.setSave(save)
    G.go("menu", {}, true)
  end)
  step(1.2, function() M.mx, M.my = 482, 268; end)
  step(0.6, function() shot("01_title"); M.mx = nil end)
  step(0.2, function()
    game.startRun(save)
    game.upholster(save.run, 1, "velvet")
    game.upholster(save.run, 3, "silk")
    G.go("hub", { fresh = true }, true)
  end)
  step(1.2, function() shot("02_hub") end)
  step(0.2, function() G.go("vs", {}, true) end)
  step(1.6, function() shot("03_vs") end)
  step(0.2, function() G.go("match", {}, true) end)
  step(2.6, function()
    local sc = G.scene
    sc:applySuggestion()
    local hand = sc:handList()
    local v = hand[1] and sc.views[hand[1].uid]
    if v then M.mx, M.my = v.x, v.y - 10 end
  end)
  step(0.8, function() shot("04_match_place"); M.mx = nil end)
  step(0.1, function() G.scene:charge() end)
  step(3.2, function() shot("05_match_duel") end)
  -- bout 2: you lead
  tick(function() return G.sceneName ~= "match" or (not G.scene.busy) end, nil)
  step(0.3, function()
    local sc = G.scene
    if G.sceneName ~= "match" then return end
    sc:applySuggestion()
    local v = sc.slots[2] and sc.views[sc.slots[2]]
    if v then M.mx, M.my = v.x, v.y end
  end)
  step(0.6, function() shot("06_match_lead"); M.mx = nil end)
  tick(autoMatch(), nil)
  tick(waitScene("result"), nil)
  step(1.0, function() shot("07_result") end)
  step(0.2, function()
    local sc = G.scene
    if sc.step == "fate" then game.decideFate(save, sc.n, "brand"); sc.step = "cards"; sc:makeCards() end
  end)
  step(0.8, function() shot("08_result_cards") end)
  step(0.2, function() G.scene:continue() end)
  tick(waitScene("hub"), nil)
  step(1.0, function() shot("09_hub_after") end)
  step(0.2, function() G.go("market", {}, true) end)
  step(1.2, function() shot("10_market") end)
  step(0.2, function() G.go("event", { event = "discord" }, true) end)
  step(0.8, function() shot("11_fortune") end)
  step(0.2, function() G.go("hub", {}, true); overlays.standings(save.run.festival) end)
  step(0.8, function() shot("12_standings") end)
  step(0.2, function() G.closeOverlay(); overlays.hands() end)
  step(0.8, function() shot("13_hands") end)
  step(0.2, function() G.closeOverlay(); overlays.deck(save.run.deck) end)
  step(1.2, function() shot("14_deck") end)
  step(0.2, function() G.closeOverlay(); overlays.help() end)
  step(0.6, function() G.overlay.tab = 2 end)
  step(0.4, function() shot("15_rules") end)
  -- fast-forward the rest of the group stage in the engine
  step(0.2, function()
    G.closeOverlay()
    local guard = 0
    while save.run.festival.stage == "group" and save.run.phase ~= "over" and guard < 10 do
      guard = guard + 1
      local ctx = game.setupMatch(save)
      local s = ctx.state
      while not s.over do match.autoplay(s, 0) end
      local out = game.resolveMatch(save, ctx)
      if out.won and ctx.nemesis then game.decideFate(save, ctx.nemesis, "brand") end
      game.afterMatch(save)
    end
    if save.run.phase == "over" then G.go("summary", {}, true) else G.go("hub", {}, true) end
  end)
  step(1.0, function() shot("16_hub_knockout") end)
  step(0.2, function()
    if save.run.phase ~= "over" then
      game.finishRun(save, "defeat")
      save.run.festival.placing = save.run.festival.placing or "qf"
    end
    G.go("summary", {}, true)
  end)
  step(1.2, function() shot("17_summary") end)
  step(0.2, function() G.scene.news = game.arenaMovesOn(save) end)
  step(1.0, function() shot("18_news") end)
  step(0.2, function() G.go("menu", {}, true) end)
  step(0.6, function() overlays.renown() end)
  step(0.8, function() shot("23_renown") end)
  step(0.2, function() G.closeOverlay(); overlays.crests(function() end) end)
  step(0.8, function() shot("24_crests") end)
  step(0.2, function() G.closeOverlay(); G.scenes.menu.settings() end)
  step(0.8, function() shot("28_options") end)
  step(0.2, function()
    G.closeOverlay()
    for i = 1, 30 do game.noteSeen(save, cards.DRAFTABLE[i].id) end
    G.go("menu", {}, true)
    overlays.cattery()
    G.overlay.sel = cards.CARDS.merline
  end)
  step(1.0, function() shot("19_cattery") end)
  step(0.4, function() print("AUTOTEST DONE"); love.event.quit() end)
end

function M.mouse(mx, my)
  if M.mx then return M.mx, M.my end
  return mx, my
end

function M.update(dt)
  local s = M.steps[M.i + 1]
  if not s then return end
  if s.tick then
    local ok, done = pcall(s.tick, dt)
    if not ok then print("AUTOTEST STEP ERROR: " .. tostring(done)); love.event.quit(1); return end
    if done then
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
