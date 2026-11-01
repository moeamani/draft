-- Modal overlays: deck, the Four Hands, standings, rules, pause, confirm, message.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local festival = require("src.core.festival")
local formations = require("src.core.formations")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local nemesis = require("src.core.nemesis")
local picker = require("src.ui.picker")
local theme = require("src.ui.theme")
local traits = require("src.core.traits")
local util = require("src.core.util")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local M = {}
local C = theme.c

function M.frame(x, y, w, h, title)
  gfx.panel(x, y, w, h, C.ink, { border = C.ink3 })
  if title then gfx.text(title, theme.T.head(), x + 10, y + 4, C.paper) end
  if widgets.button("ov_close", x + w - 22, y + 6, 16, 16, "x", { font = theme.T.num(), color = C.redDark }) then G.closeOverlay() end
end

-- ---------------------------------------------------------------- shared nemesis pieces

function M.traitChips(n, x, y, maxW, revealed)
  local cx, cy = x, y
  local list = {}
  for _, t in ipairs(n.traits) do
    local known = t.known or (revealed and util.contains(revealed, t.id))
    local info = traits.TRAITS[t.id]
    list[#list + 1] = known and { info.name, info.kind, info.desc } or { "???", "hidden", "Hidden trait. Beat strays, bribe rats or fight them to learn it." }
  end
  if n.wins > 0 then list[#list + 1] = { "Grudge x" .. n.wins, "strength", traits.TRAITS.grudge.desc } end
  local font = theme.T.tiny()
  for _, l in ipairs(list) do
    local w = font:getWidth(l[1]) + 6
    if cx + w > x + maxW then cx = x; cy = cy + 12 end
    local over = widgets.inside(cx, cy, w, 10)
    gfx.chip(l[1], cx, cy, l[2])
    if over then
      local tx, ty = cx, cy + 12
      widgets.tooltip(function() widgets.infoBox(tx, ty, 150, { { text = l[1], color = l[2] == "weakness" and C.green or l[2] == "strength" and C.red or C.muted }, { text = l[3] } }) end)
    end
    cx = cx + w + 3
  end
  return cy + 12
end

function M.nemesisCard(n, rank, x, y, w, h)
  gfx.panel(x, y, w, h, C.deep, { border = C.redDark })
  gfx.label(rank > 0 and nemesis.RANK_TITLES[rank] or n.status, x + 6, y + 4, C.red)
  local p = art.nemesis(n, rank, 48)
  gfx.box(x + 5, y + 14, 50, 50, C.black)
  lg.setColor(1, 1, 1)
  lg.draw(p, x + 6, y + 15)
  gfx.text(n.name, theme.T.headS(), x + 60, y + 13, C.paper)
  gfx.textf(n.epithet, theme.T.tiny(), x + 60, y + 27, w - 64, "left", C.muted)
  local coat = cards.COATS[n.coat]
  gfx.text("LV " .. n.level, theme.T.tiny(), x + 60, y + 44, C.paper)
  gfx.text(coat.name:upper(), theme.T.tiny(), x + 82, y + 44, coat.color)
  icons.draw("skull", x + 64, y + 58, C.paper)
  gfx.text(tostring(n.wins), theme.T.tiny(), x + 70, y + 54, C.paper)
  icons.draw("sword", x + 90, y + 58, C.paper)
  gfx.text(tostring(n.losses), theme.T.tiny(), x + 96, y + 54, C.paper)
  local cy = M.traitChips(n, x + 6, y + 68, w - 12)
  if h > 110 then
    local hy = cy + 2
    for i = #n.history, math.max(1, #n.history - 2), -1 do
      if hy > y + h - 12 then break end
      hy = hy + gfx.textf(n.history[i].text, theme.T.tiny(), x + 6, hy, w - 12, "left", C.muted) + 2
    end
  end
end

-- ---------------------------------------------------------------- deck

function M.deck(deck, opts)
  opts = opts or {}
  local list = {}
  for _, c in ipairs(deck) do if not opts.filter or opts.filter(c) then list[#list + 1] = c end end
  table.sort(list, function(a, b)
    local da, db = cards.getDef(a), cards.getDef(b)
    if da.kind ~= db.kind then return da.kind == "unit" end
    if da.coat ~= db.coat then return da.coat < db.coat end
    return cards.paws(a) > cards.paws(b)
  end)
  local pk = picker.new(list, { x = 320, y = 82, scale = 1, gap = 4, cols = 10, rowGap = 6, dealFrom = { 320, 420 } })
  local ov = {}
  function ov:update(dt) pk:update(dt) end
  function ov:draw()
    M.frame(12, 12, theme.W - 24, theme.H - 24, opts.title or ("Your Pride (" .. #deck .. ")"))
    if opts.hint then gfx.text(opts.hint, theme.T.body(), 200, 16, C.muted) end
    lg.setScissor(G.scissor(14, 40, theme.W - 28, theme.H - 54))
    local i = pk:draw()
    lg.setScissor()
    if i and opts.onPick then
      G.closeOverlay()
      opts.onPick(list[i])
    end
  end
  function ov:wheel(dy)
    local rows = math.ceil(#list / 10)
    pk.scroll = math.max(0, math.min(math.max(0, rows * 78 - 280), pk.scroll - dy * 30))
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
    M.frame(8, 8, theme.W - 16, theme.H - 16, "The Four Hands")
    gfx.text("The Arena's council. They enter every festival, remember every match, and scheme between them.", theme.T.body(), 140, 18, C.muted)
    for i, h in ipairs(save.hands) do M.nemesisCard(h, i, 14 + (i - 1) * 154, 36, 150, 200) end
    gfx.label("Chronicle", 16, 244)
    local y = 256
    for i = #save.chronicle, math.max(1, #save.chronicle - 7), -1 do
      local c = save.chronicle[i]
      gfx.text("Fest " .. c.run, theme.T.tiny(), 16, y, C.muted)
      y = y + gfx.textf(c.text, theme.T.tiny(), 56, y, 400, "left", C.paper) + 1
      if y > 336 then break end
    end
    gfx.label("Fallen & gone", 470, 244)
    local fy, shown = 256, 0
    for i = #save.fallen, 1, -1 do
      local n = save.fallen[i]
      if shown >= 7 then break end
      if n.met or n.status ~= "exiled" then
        gfx.text(n.name, theme.T.body(), 470, fy, C.paper)
        gfx.text(n.status, theme.T.tiny(), 570, fy, C.muted)
        fy = fy + 11
        shown = shown + 1
      end
    end
    if shown == 0 then gfx.text("None yet.", theme.T.body(), 470, fy, C.muted) end
  end
  G.openOverlay(ov)
end

-- ---------------------------------------------------------------- standings

function M.groupTable(f, gi, x, y, w)
  local rows = festival.table(f, gi)
  local myGroup = festival.groupOf(f, festival.PLAYER) == gi
  gfx.panel(x, y, w, 62, myGroup and C.ink2 or C.deep, { border = myGroup and C.goldDark or nil })
  gfx.text("GROUP " .. festival.GROUPS[gi], theme.T.tiny(), x + 5, y + 3, myGroup and C.gold or C.pale)
  gfx.text("W L  PD PTS", theme.T.tiny(), x + w - 5, y + 3, C.muted, { align = "right" })
  for i, r in ipairs(rows) do
    local e = f.entrants[r.id]
    local ry = y + 3 + i * 12
    local col = e.kind == "player" and C.gold or e.kind == "hand" and C.red or C.paper
    if f.withdrawn[r.id] then col = C.muted end
    if i <= 2 then
      theme.set(C.green, 0.8)
      lg.rectangle("fill", x + 2, ry + 1, 1, 7)
    end
    local name = e.name
    if e.kind == "hand" then icons.draw("crown", x + 10, ry + 4, C.red) end
    local nx = x + (e.kind == "hand" and 16 or 6)
    local f8 = theme.T.tiny()
    local maxW = w - 64 - (nx - x)
    while f8:getWidth(name) > maxW and #name > 3 do name = name:sub(1, -2) end
    gfx.text(name, f8, nx, ry, col)
    gfx.text(("%d %d %+3d %2d"):format(r.w, r.l, r.pd, r.pts), f8, x + w - 5, ry, col, { align = "right" })
  end
end

function M.bracket(f, x, y, w, h)
  gfx.panel(x, y, w, h, C.deep, { border = C.ink3 })
  local colW = math.floor((w - 12) / 3)
  local stages = { "qf", "sf", "final" }
  local labels = { "QUARTER-FINALS", "SEMI-FINALS", "FINAL" }
  for si, st in ipairs(stages) do
    local list = f.bracket[st] or {}
    local n = ({ 4, 2, 1 })[si]
    local cx = x + 6 + (si - 1) * colW
    gfx.text(labels[si], theme.T.tiny(), cx + 2, y + 4, C.pale)
    local slotH = math.floor((h - 18) / n)
    for i = 1, n do
      local m = list[i]
      local my = y + 16 + (i - 1) * slotH + math.floor(slotH / 2) - 12
      local involved = m and (m.a == festival.PLAYER or m.b == festival.PLAYER)
      gfx.panel(cx, my, colW - 6, 24, involved and C.ink3 or C.ink2, { border = involved and C.goldDark or nil })
      for k, key in ipairs({ "a", "b" }) do
        local id = m and m[key]
        local e = id and f.entrants[id]
        local name = e and e.name or "..."
        local col = not e and C.muted or (e.kind == "player" and C.gold or e.kind == "hand" and C.red or C.paper)
        if m and m.winner and id ~= m.winner then col = theme.mix(col, C.ink, 0.6) end
        local f8 = theme.T.tiny()
        while f8:getWidth(name) > colW - 22 and #name > 3 do name = name:sub(1, -2) end
        gfx.text(name, f8, cx + 4, my + 2 + (k - 1) * 10, col)
        if m and m.winner == id then icons.draw("star", cx + colW - 14, my + 6 + (k - 1) * 10, C.gold) end
      end
    end
  end
  if f.champion then
    gfx.text("CHAMPION: " .. f.entrants[f.champion].name, theme.T.body(), x + w - 6, y + h - 12, C.gold, { align = "right" })
  end
end

function M.standings(f)
  local ov = {}
  function ov:draw()
    M.frame(8, 8, theme.W - 16, theme.H - 16, f.name)
    for gi = 1, 4 do M.groupTable(f, gi, 16 + ((gi - 1) % 2) * 152, 40 + math.floor((gi - 1) / 2) * 68, 148) end
    M.bracket(f, 324, 40, 300, 300)
  end
  G.openOverlay(ov)
end

-- ---------------------------------------------------------------- rules

function M.help()
  local ov = { tab = 1 }
  function ov:draw()
    M.frame(8, 8, theme.W - 16, theme.H - 16, "How to play")
    if widgets.button("h_t1", 200, 12, 80, 16, "Matches", { font = theme.T.num(), color = self.tab == 1 and C.red or C.ink3 }) then self.tab = 1 end
    if widgets.button("h_t2", 284, 12, 80, 16, "Formations", { font = theme.T.num(), color = self.tab == 2 and C.red or C.ink3 }) then self.tab = 2 end
    if widgets.button("h_t3", 368, 12, 80, 16, "Festival", { font = theme.T.num(), color = self.tab == 3 and C.red or C.ink3 }) then self.tab = 3 end
    local x, y, w = 20, 40, 600
    local function para(t, col) y = y + gfx.textf(t, theme.T.body(), x, y, w, "left", col or C.paper) + 5 end
    local function head(t) gfx.text(t, theme.T.headS(), x, y, C.gold); y = y + 15 end
    if self.tab == 1 then
      head("An exchange")
      para("You hold 8 cards. Pick up to 5 and press PLAY. Your best Formation among them scores; the rest just come along.")
      para("Score = Paws x Cheer. Paws come from the Formation plus every scoring cat's number. Cheer comes from the Formation, abilities, tricks and charms.")
      para("Your rival picks in secret. Both reveal; the higher score wins the exchange and the loser loses Pride: 16 for a close call, up to 48 for a crushing one. First to 0 Pride loses the match.")
      head("Redraws, tricks and coats")
      para("Twice per exchange you may REDRAW: toss up to 5 selected cards for new ones.")
      para("Tricks (Sunbeam, Downpour, Hairball...) ride along with your cats and bend the scoring. A Cardboard Box lets one cat count as any coat.")
      para("Coats: Ember scorches Gilt, Gilt dams the Tide, Tide drowns Ember. If your Formation's coat beats theirs: +2 Cheer.")
    elseif self.tab == 2 then
      head("Formations")
      local fy = y
      for i, f in ipairs(formations.LIST) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local fx, ry = x + col * 300, fy + row * 46
        gfx.panel(fx, ry, 294, 42, C.ink2)
        gfx.text(f.name, theme.T.big(), fx + 6, ry + 4, C.paper)
        gfx.text(f.paws .. " x " .. f.cheer, theme.T.numL(), fx + 288, ry + 2, C.gold, { align = "right" })
        gfx.textf(f.desc, theme.T.tiny(), fx + 6, ry + 26, 240, "left", C.muted)
      end
    else
      head("The festival")
      para("16 cats enter. You play 3 group matches; a win is worth 3 points and Pride difference breaks ties. The top 2 of each group reach the knockouts: quarter-final, semi-final, final. Lose a knockout and you're out.")
      para("Between matches you may visit ONE stall: the Mews Market, the Fortune Teller or the Training Yard.")
      head("The Four Hands")
      para("The Arena's four Warlords enter every festival and remember you. They hide strengths and weaknesses: beat strays, pay informants, carry a Spyglass, or watch traits fire mid-match to learn them.")
      para("A Hand who beats you grows stronger and holds a grudge. Beat one and decide their fate: Slay (they forfeit, and may return), Recruit after a flawless win (they join your pride, and may betray you) or Brand (a weakness, and a grudge). Between festivals the Hands scheme, and festival winners can take a seat.")
      para("Keys: F11 fullscreen, F2 CRT mode, F3 sound, Esc menu.", C.muted)
    end
  end
  G.openOverlay(ov)
end

-- ---------------------------------------------------------------- pause / confirm / message

function M.pause()
  local ov = {}
  function ov:draw()
    M.frame(220, 70, 200, 222, "Paused")
    local y = 104
    if widgets.button("p_resume", 236, y, 168, 24, "Resume", { color = C.red }) then G.closeOverlay() end
    if widgets.button("p_help", 236, y + 30, 168, 24, "How to play") then M.help() end
    if widgets.button("p_crt", 236, y + 60, 168, 24, "CRT: " .. G.crtLabel()) then G.cycleCrt() end
    local sfx = require("src.ui.sfx")
    if widgets.button("p_snd", 236, y + 90, 168, 24, "Sound: " .. (sfx.muted and "off" or "on")) then
      G.settings.muted = sfx.toggleMute(); G.saveSettings()
    end
    if widgets.button("p_quit", 236, y + 120, 168, 24, "Save & quit") then
      G.persist(); G.closeOverlay(); G.go("title")
    end
  end
  G.openOverlay(ov)
end

function M.confirm(title, body, yes, onYes)
  local ov = {}
  function ov:draw()
    M.frame(170, 100, 300, 150, title)
    gfx.textf(body, theme.T.body(), 182, 136, 276, "left", C.paper)
    if widgets.button("c_yes", 182, 212, 132, 26, yes, { color = C.red }) then G.closeOverlay(); onYes() end
    if widgets.button("c_no", 326, 212, 132, 26, "Cancel") then G.closeOverlay() end
  end
  G.openOverlay(ov)
end

function M.message(title, body, onClose, portrait)
  local ov = { dismissable = false }
  function ov:draw()
    M.frame(140, 90, 360, 180, title)
    local x = 152
    if portrait then
      gfx.box(151, 125, 98, 98, C.black)
      lg.setColor(1, 1, 1)
      lg.draw(portrait, 152, 126)
      x = 256
    end
    gfx.textf(body, theme.T.body(), x, 128, 488 - x, "left", C.paper)
    if widgets.button("m_ok", 256, 236, 128, 24, "Continue", { color = C.red }) then
      G.closeOverlay()
      if onClose then onClose() end
    end
  end
  G.openOverlay(ov)
end

return M
