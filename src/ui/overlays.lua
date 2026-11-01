-- Modal overlays: deck viewer, the Four Hands, how to play, pause menu, confirm, card chooser.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local nemesis = require("src.core.nemesis")
local picker = require("src.ui.picker")
local theme = require("src.ui.theme")
local traits = require("src.core.traits")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local M = {}
local C = theme.c

local function frame(x, y, w, h, title)
  gfx.panel(x, y, w, h, { 0.04, 0.09, 0.07, 0.98 }, { r = 20, depth = 10, border = { 1, 1, 1, 0.14 }, lw = 2 })
  if title then gfx.text(title, theme.font("bold", 40), x + 34, y + 22, C.paper) end
  if widgets.button("ov_close", x + w - 64, y + 18, 46, 46, "X", { size = 22, color = C.ink3 }) then G.closeOverlay() end
end
M.frame = frame

-- ---------------------------------------------------------------- nemesis card (shared)

function M.traitChips(n, x, y, maxW, font, revealed)
  local cx, cy = x, y
  local list = {}
  for _, t in ipairs(n.traits) do
    local known = t.known or (revealed and require("src.core.util").contains(revealed, t.id))
    list[#list + 1] = known and { traits.TRAITS[t.id].name, traits.TRAITS[t.id].kind, traits.TRAITS[t.id].desc } or { "???", "hidden", "Unknown trait. Gather intel to reveal it." }
  end
  if n.wins > 0 then list[#list + 1] = { "Grudge x" .. n.wins, "strength", traits.TRAITS.grudge.desc } end
  for _, l in ipairs(list) do
    local f = font or theme.font("mono", 13)
    local w = f:getWidth(l[1]) + 18
    if cx + w > x + maxW then cx = x; cy = cy + f:getHeight() + 12 end
    local over = widgets.inside(cx, cy, w, f:getHeight() + 6)
    gfx.chip(l[1], cx, cy, l[2], f)
    if over then
      local tx, ty = cx, cy + 30
      widgets.tooltip(function() widgets.infoBox(tx, ty, 300, { { text = l[1], font = theme.font("bold", 20), color = l[2] == "weakness" and C.green or l[2] == "strength" and C.red or C.muted }, { text = l[3] } }) end)
    end
    cx = cx + w + 8
  end
  return cy + (font or theme.font("mono", 13)):getHeight() + 6
end

function M.nemesisCard(n, rank, x, y, w, opts)
  opts = opts or {}
  local h = opts.h or (opts.compact and 330 or 420)
  local hot = opts.hot
  gfx.panel(x, y, w, h, hot and { 0.17, 0.06, 0.06 } or { 0.1, 0.05, 0.05 }, { r = 16, depth = 7, border = { C.red[1], C.red[2], C.red[3], hot and 0.9 or 0.45 }, lw = 2 })
  gfx.label(rank > 0 and nemesis.RANK_TITLES[rank] or n.status, x + 18, y + 16, C.red)
  local p = art.nemesis(n, rank)
  local ps = opts.compact and 96 or 128
  lg.setColor(0, 0, 0, 0.6)
  lg.rectangle("fill", x + 18 + 4, y + 42 + 6, ps, ps, 10)
  lg.setColor(1, 1, 1)
  p:setFilter("nearest", "nearest")
  lg.draw(p, x + 18, y + 42, 0, ps / 64, ps / 64)
  local tx = x + 18 + ps + 16
  local nf = theme.font("bold", opts.compact and 28 or 32)
  local name = n.name
  gfx.text(name, nf, tx, y + 44, C.paper)
  gfx.textf(n.epithet, theme.font("italic", 18), tx, y + 44 + nf:getHeight(), w - (tx - x) - 12, "left", C.muted, { shadow = false })
  local coat = cards.COATS[n.coat]
  local sy = y + 42 + ps + 12
  gfx.text("Lv " .. n.level, theme.font("monoBold", 15), x + 18, sy, C.paper, { shadow = 0 })
  gfx.text(coat.name, theme.font("monoBold", 15), x + 80, sy, coat.color, { shadow = 0 })
  icons.draw("skull", x + 170, sy + 9, 16, C.paper)
  gfx.text(tostring(n.wins), theme.font("monoBold", 15), x + 182, sy, C.paper, { shadow = 0 })
  icons.draw("sword", x + 220, sy + 9, 16, C.paper)
  gfx.text(tostring(n.losses), theme.font("monoBold", 15), x + 232, sy, C.paper, { shadow = 0 })
  local cy = M.traitChips(n, x + 18, sy + 28, w - 36, nil, opts.revealed)
  if not opts.compact then
    lg.setColor(1, 1, 1, 0.08)
    lg.rectangle("fill", x + 18, cy + 4, w - 36, 2)
    local hy = cy + 14
    for i = #n.history, math.max(1, #n.history - 2), -1 do
      local used = gfx.textf(n.history[i].text, theme.font("serif", 15), x + 18, hy, w - 36, "left", C.muted, { shadow = false })
      hy = hy + used + 2
      if hy > y + h - 20 then break end
    end
  end
  return h
end

-- ---------------------------------------------------------------- deck

function M.deck(deck, opts)
  opts = opts or {}
  local sorted = {}
  for _, c in ipairs(deck) do
    if not opts.filter or opts.filter(c) then sorted[#sorted + 1] = c end
  end
  table.sort(sorted, function(a, b)
    local da, db = cards.getDef(a), cards.getDef(b)
    if da.kind ~= db.kind then return da.kind == "unit" end
    if (da.type or "") ~= (db.type or "") then return (da.type or "") > (db.type or "") end
    return da.power + cards.levelBonus(a.level) > db.power + cards.levelBonus(b.level)
  end)
  local cols = 9
  local pk = picker.new(sorted, { x = 800, y = 250, scale = 0.56, gap = 14, cols = cols, rowGap = 14, dealFrom = { 800, 1100 } })
  local scroll = 0
  local ov = {}
  function ov:update(dt)
    for _, v in ipairs(pk.views) do v.baseY = v.baseY0 or v.baseY; v.baseY0 = v.baseY0 or v.baseY; v.baseY = v.baseY0 - scroll end
    pk:update(dt)
  end
  function ov:draw()
    frame(60, 50, 1480, 800, opts.title or ("Your Pride (" .. #deck .. ")"))
    if opts.hint then gfx.text(opts.hint, theme.font("serif", 20), 100, 100, C.muted, { shadow = 0 }) end
    lg.setScissor(G.scissor(60, 120, 1480, 720))
    local i = pk:draw()
    lg.setScissor()
    if i and opts.onPick then
      G.closeOverlay()
      opts.onPick(sorted[i])
    end
  end
  function ov:wheel(dy)
    local rows = math.ceil(#sorted / cols)
    scroll = math.max(0, math.min(math.max(0, rows * 172 - 560), scroll - dy * 60))
  end
  G.openOverlay(ov)
end

function M.chooseCard(title, deck, filter, onPick)
  M.deck(deck, { title = title, filter = filter, onPick = onPick, hint = "Click a cat." })
end

-- ---------------------------------------------------------------- the four hands

function M.hands()
  local save = G.save
  if not save then return end
  local ov = {}
  function ov:draw()
    frame(40, 40, 1520, 820, "The Four Hands")
    gfx.text("The Arena's ruling council. They remember every fight, grow when they beat you, and scheme between runs.", theme.font("serif", 19), 80, 108, C.muted, { shadow = 0 })
    for i, h in ipairs(save.hands) do
      M.nemesisCard(h, i, 76 + (i - 1) * 366, 150, 350, { h = 410 })
    end
    gfx.label("Chronicle", 80, 590)
    local y = 616
    for i = #save.chronicle, math.max(1, #save.chronicle - 7), -1 do
      local c = save.chronicle[i]
      gfx.text("Run " .. c.run, theme.font("mono", 13), 80, y + 3, C.muted, { shadow = 0 })
      y = y + gfx.textf(c.text, theme.font("serif", 17), 160, y, 900, "left", C.paper, { shadow = false }) + 4
      if y > 830 then break end
    end
    gfx.label("Fallen & gone", 1120, 590)
    local fy = 616
    local shown = 0
    for i = #save.fallen, 1, -1 do
      local n = save.fallen[i]
      if shown >= 8 then break end
      if n.met or n.status ~= "exiled" then
        gfx.text(n.name, theme.font("bold", 19), 1120, fy, C.paper, { shadow = 0 })
        gfx.text(n.status, theme.font("mono", 14), 1330, fy + 4, C.muted, { shadow = 0 })
        fy = fy + 26
        shown = shown + 1
      end
    end
    if shown == 0 then gfx.text("None yet.", theme.font("serif", 18), 1120, fy, C.muted, { shadow = 0 }) end
  end
  G.openOverlay(ov)
end

-- ---------------------------------------------------------------- help

local HELP_LEFT = {
  { "The duel", "Duels are best of three rounds. Each turn you play one card or pass. Once you pass you are out for the round. When both have passed, the higher total wins the round." },
  { "", "Your hand carries over between rounds and you draw only one card per round. Burning your whole hand to win round one is how you lose the duel." },
  { "Rows", "Physical cats fight in the Vanguard. Magic cats fight in the Arcane row. Weather hits one row at a time." },
  { "Coats", "Ember scorches Gilt, Gilt dams the Tide, Tide drowns Ember. A cat gets +2 while the enemy has a coat it beats in the same row. Shadow cats are the Black Cats." },
  { "Growing cats", "Cats you play in won duels gain XP: Knight at 2 XP (+2), Paladin at 5 XP (+4)." },
}
local HELP_RIGHT = {
  { "The run", "Draft 10 cats, then climb four rings. Each ring has two stops and ends with a Warlord. You have nine lives: a lost skirmish costs 2, a lost Warlord fight costs 3." },
  { "The Four Hands", "Four Warlords rule the Arena and persist between runs. Each hides strengths and weaknesses that you reveal by fighting, interrogating strays, bribing rats or carrying a Spyglass." },
  { "", "A Warlord who beats you levels up, holds a grudge and trains between runs. A stray who beats you may be promoted into the Hands." },
  { "", "Beat a Warlord and choose: Slay (it may return), Recruit after a flawless 2-0 (it joins your deck, but may betray you), or Brand (a weakness, and a grudge)." },
  { "Keys", "F11 fullscreen  |  F2 CRT (subtle / flat / off)  |  F3 sound  |  Esc menu" },
}

function M.help()
  local ov = {}
  function ov:draw()
    frame(60, 50, 1480, 800, "How to play Draft")
    for col, list in ipairs({ HELP_LEFT, HELP_RIGHT }) do
      local x, y = 100 + (col - 1) * 720, 120
      for _, e in ipairs(list) do
        if e[1] ~= "" then
          gfx.text(e[1], theme.font("bold", 26), x, y, C.gold)
          y = y + 36
        end
        y = y + gfx.textf(e[2], theme.font("serif", 20), x, y, 640, "left", C.paper, { shadow = false }) + 14
      end
    end
    if widgets.button("help_ok", 700, 760, 200, 56, "Got it", { color = C.red }) then G.closeOverlay() end
  end
  G.openOverlay(ov)
end

-- ---------------------------------------------------------------- pause / confirm

function M.pause()
  local ov = {}
  function ov:draw()
    frame(560, 200, 480, 500, "Paused")
    local y = 290
    if widgets.button("p_resume", 620, y, 360, 60, "Resume", { color = C.red }) then G.closeOverlay() end
    if widgets.button("p_help", 620, y + 76, 360, 60, "How to play") then M.help() end
    if widgets.button("p_crt", 620, y + 152, 360, 60, "CRT: " .. G.crtLabel()) then G.cycleCrt() end
    local sfx = require("src.ui.sfx")
    if widgets.button("p_snd", 620, y + 228, 360, 60, "Sound: " .. (sfx.muted and "off" or "on")) then
      G.settings.muted = sfx.toggleMute(); G.saveSettings()
    end
    if widgets.button("p_quit", 620, y + 304, 360, 60, "Save & quit to title") then
      G.persist(); G.closeOverlay(); G.go("title")
    end
  end
  G.openOverlay(ov)
end

function M.confirm(title, body, yes, onYes)
  local ov = {}
  function ov:draw()
    frame(500, 260, 600, 360, title)
    gfx.textf(body, theme.font("serif", 22), 540, 340, 520, "left", C.paper)
    if widgets.button("c_yes", 540, 530, 250, 60, yes, { color = C.red }) then G.closeOverlay(); onYes() end
    if widgets.button("c_no", 810, 530, 250, 60, "Cancel") then G.closeOverlay() end
  end
  G.openOverlay(ov)
end

function M.message(title, body, onClose, portrait)
  local ov = { dismissable = false }
  function ov:draw()
    frame(400, 220, 800, 440, title)
    local x = 440
    if portrait then
      lg.setColor(1, 1, 1)
      portrait:setFilter("nearest", "nearest")
      lg.draw(portrait, 440, 300, 0, 160 / 64, 160 / 64)
      x = 630
    end
    gfx.textf(body, theme.font("serif", 24), x, 300, 1160 - x, "left", C.paper)
    if widgets.button("m_ok", 700, 570, 200, 60, "Continue", { color = C.red }) then G.closeOverlay(); if onClose then onClose() end end
  end
  G.openOverlay(ov)
end

return M
