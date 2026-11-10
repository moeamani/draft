-- Story mode's map: the road from the bins to the Gilded Saucer. Six pennants (the prologue and
-- five festival chapters) with the current one's goal, omen and your pride's state.
local art = require("src.ui.art")
local festival = require("src.core.festival")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local overlays = require("src.ui.overlays")
local overseer = require("src.ui.overseer")
local plates = require("src.ui.plates")
local sfx = require("src.ui.sfx")
local story = require("src.core.story")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c
local T = theme.T
S.bg = { preset = "menu" }

local FEST_NAMES = { "Midsummer Festival of Claws", "Harvest Moot", "Feast of Nine Lives", "Winter Yowl", "Tourney of the Gilded Saucer", "Moonlit Mews" }
local OMEN_OF = { "midsummer", "harvest", "feast", "frost", "saucer", "moonlit" }

function S:enter()
  if not G.save then
    G.setSave(story.newStory(os.time()))
    G.persist()
  end
  self.t = 0
end

function S:update(dt) self.t = self.t + dt end

-- ---------------------------------------------------------------- actions

local function playPrologue()
  G.go("cutscene", {
    lines = story.lines(G.save, "prologue_intro"), bg = { preset = "menu" },
    title = "Prologue", sub = "The Bin Yard",
    onDone = function() G.go("match", { tutorial = true }) end,
  })
end

local function beginChapter()
  local save = G.save
  story.startChapter(save)
  G.persist()
  local ch = story.chapter(save)
  G.go("cutscene", {
    lines = story.lines(save, "intro"), bg = { preset = "vs" },
    title = "Chapter " .. ch.numeral, sub = ch.title,
    onDone = function() G.go("hub", { fresh = true }) end,
  })
end

-- The last chapter is one match against the Overseer, after its own scene.
local function beginBoss()
  local save = G.save
  local ch = story.chapter(save)
  G.go("cutscene", {
    lines = story.lines(save, "intro"), bg = { preset = "vs", ramp = "blood" },
    title = "Chapter " .. ch.numeral, sub = ch.title,
    onDone = function() G.go("match", { boss = true }) end,
  })
end

-- Called when a story festival ends (from the summary screen).
function S.endChapter()
  local save = G.save
  local chapter = save.story.chapter
  local result = story.finishChapter(save)
  G.persist()
  if result == "won" then
    G.addRenown(30)
    if save.story.chapter > story.LAST then G.award({ "storyteller" }) end
  end
  G.go("cutscene", {
    lines = story.lines(save, result, chapter), bg = { preset = "vs", ramp = result == "won" and "felt" or "blood" },
    title = result == "won" and "Chapter complete" or "Chapter failed",
    sub = story.CHAPTERS[chapter].goalText,
    onDone = function() G.go("story") end,
  })
end

-- ---------------------------------------------------------------- drawing

local NODES = { { 30, 118 }, { 116, 94 }, { 202, 120 }, { 288, 92 }, { 374, 118 }, { 460, 90 }, { 560, 112 } }

local function pennant(x, y, col, label, lit, t)
  local flap = lit and math.floor(math.sin(t * 3) * 1.5 + 0.5) or 0
  theme.set(C.black)
  lg.rectangle("fill", x - 1, y - 30, 2, 54)
  theme.set(C.black)
  lg.polygon("fill", x + 1, y - 30, x + 31, y - 30, x + 31 + flap, y - 4, x + 16, y + 4, x + 1, y - 4)
  theme.set(col)
  lg.polygon("fill", x + 2, y - 29, x + 30, y - 29, x + 30 + flap, y - 5, x + 16, y + 2, x + 2, y - 5)
  theme.set(theme.shade(col, 0.25))
  lg.rectangle("fill", x + 2, y - 29, 28, 1)
  gfx.text(label, theme.serif(15), x + 16, y - 25, C.white, { align = "center", bg = col })
end

function S:draw()
  local save = G.save
  local st = save.story
  local t = self.t
  plates.header(8, 8, 624, 34, C.red, "Stray to Champion", { size = 24, streak = 0.43 })
  -- the road
  theme.set(C.goldDark)
  for i = 1, #NODES - 1 do
    local a, b = NODES[i], NODES[i + 1]
    for k = 0, 10 do
      local u = k / 10
      lg.rectangle("fill", math.floor(a[1] + (b[1] - a[1]) * u) + 14, math.floor(a[2] + (b[2] - a[2]) * u) + 28, 3, 2)
    end
  end
  for i, n in ipairs(NODES) do
    local ch = i - 1
    local done = st.done[ch] or ch < st.chapter
    local current = ch == st.chapter
    local col = done and C.goldDark or (current and C.red or C.ink3)
    pennant(n[1], n[2], col, ch == 0 and "P" or story.CHAPTERS[ch].numeral, current, t)
    local label = ch == 0 and "The Bin Yard" or story.CHAPTERS[ch].title
    gfx.text(label, T.small(), n[1] + 16, n[2] + 30, current and C.white or (done and C.goldText or C.muted), { align = "center", bg = C.ink })
    if done then icons.draw("star", n[1] + 16, n[2] - 40, C.goldText) end
    if ch > 0 and story.CHAPTERS[ch].boss then
      -- the High Table: the Overseer's eyes over its pennant
      overseer.face(n[1] - 14, n[2] - 74, 60, 34, t, done and 0.5 or 1)
    end
  end
  -- the current chapter
  local px, py, pw = 8, 170, 400
  gfx.panel(px, py, pw, 182, C.deep)
  local run = save.run
  local live = run and run.story and run.phase ~= "over"
  if st.chapter == 0 then
    plates.print("Prologue: The Bin Yard", 20, px + 10, py + 6, C.white, { bg = C.deep })
    gfx.textf("A nameless stray, a rainy alley and an old knight who's seen it all. Learn the cushion duel from Old Bedimew.", T.body(), px + 10, py + 34, pw - 20, "left", C.paper2, { bg = C.deep })
    gfx.text("Goal: finish the practice match", T.bold(), px + 10, py + 92, C.goldText, { bg = C.deep })
    if widgets.button("st_go", px + 10, py + 140, 200, 32, "Begin the prologue", { color = C.red }) then playPrologue() end
  elseif st.chapter > story.LAST then
    plates.print("Champion " .. save.playerName, 22, px + 10, py + 6, C.goldText, { bg = C.deep })
    gfx.textf("From a bin lid to the High Table. The story is told, but the Four Hands remember everything, and the Overseer is still watching. Try a Free Festival from the main menu.", T.body(), px + 10, py + 38, pw - 20, "left", C.paper2, { bg = C.deep })
  elseif story.CHAPTERS[st.chapter].boss then
    local ch = story.CHAPTERS[st.chapter]
    plates.print("Chapter " .. ch.numeral .. ": " .. ch.title, 20, px + 10, py + 6, C.white, { bg = C.deep })
    gfx.textf("The Overseer waits in the high box with your name in its ledger. One match at its table, an extra goblet on its side, and it sees every card you hold.", T.body(), px + 10, py + 34, pw - 20, "left", C.paper2, { bg = C.deep })
    gfx.text("Goal: " .. ch.goalText, T.bold(), px + 10, py + 92, C.goldText, { bg = C.deep })
    if st.failed then gfx.text("It won last time. Your pride is as the Gilded Saucer left it.", T.body(), px + 10, py + 110, C.redText, { bg = C.deep }) end
    if widgets.button("st_go", px + 10, py + 140, 200, 32, st.failed and "Climb the stairs again" or "Climb to the High Table", { color = C.red }) then beginBoss() end
  else
    local ch = story.CHAPTERS[st.chapter]
    plates.print("Chapter " .. ch.numeral .. ": " .. ch.title, 20, px + 10, py + 6, C.white, { bg = C.deep })
    local omen = festival.OMENS[OMEN_OF[ch.fest]]
    gfx.text(FEST_NAMES[ch.fest] or "", T.body(), px + 10, py + 34, C.paper2, { bg = C.deep })
    if omen then gfx.text("Omen: " .. omen.name .. ". " .. omen.desc, T.body(), px + 10, py + 50, C.muted, { bg = C.deep }) end
    gfx.text("Goal: " .. ch.goalText, T.bold(), px + 10, py + 72, C.goldText, { bg = C.deep })
    if live then
      local met = story.goalMet(save)
      gfx.text(met and "Goal reached. Finish the festival to end the chapter." or "Festival in progress.", T.body(), px + 10, py + 90, met and C.green or C.paper2, { bg = C.deep })
      if widgets.button("st_go", px + 10, py + 140, 200, 32, "Continue the festival", { color = C.red }) then G.go("hub") end
    else
      if st.failed then gfx.text("You fell short last time. Your pride is back as it was when the chapter began.", T.body(), px + 10, py + 90, C.redText, { bg = C.deep }) end
      if widgets.button("st_go", px + 10, py + 140, 200, 32, st.failed and "Retry the chapter" or "Begin the chapter", { color = C.red }) then beginChapter() end
    end
  end
  -- you and your pride
  local qx = 416
  gfx.panel(qx, py, 216, 182, C.deep)
  local me = art.player(save.playerName, 64)
  gfx.box(qx + 8, py + 8, 66, 66, C.black)
  lg.setColor(1, 1, 1)
  lg.draw(me, qx + 9, py + 9)
  plates.print(st.named and save.playerName or "The Stray", 18, qx + 82, py + 10, C.white, { bg = C.deep })
  local deck = (save.run and save.run.deck) or {}
  gfx.text(#deck > 0 and (#deck .. " cats in your pride") or "No pride yet", T.body(), qx + 82, py + 34, C.paper2, { bg = C.deep })
  local held = 0
  for _, n in ipairs(save.hands) do held = held + game.captiveCount(n) end
  gfx.text(held > 0 and (held .. " held by the Hands") or "None captured", T.body(), qx + 82, py + 50, held > 0 and C.redText or C.muted, { bg = C.deep })
  if #deck > 0 and widgets.button("st_pride", qx + 8, py + 84, 200, 24, "View your pride") then overlays.deck(deck) end
  if widgets.button("st_hands", qx + 8, py + 114, 200, 24, "The Four Hands") then overlays.hands() end
  if widgets.button("st_back", qx + 8, py + 148, 200, 26, "Main menu") then G.go("menu") end
end

function S:keypressed(k)
  if k == "escape" then G.go("menu") end
end
function S:back() G.go("menu") end

return S
