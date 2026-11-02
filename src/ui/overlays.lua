-- Modal overlays: deck, the Four Hands, standings, rules, pause, confirm, message.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local festival = require("src.core.festival")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local match = require("src.core.match")
local nemesis = require("src.core.nemesis")
local picker = require("src.ui.picker")
local theme = require("src.ui.theme")
local traits = require("src.core.traits")
local util = require("src.core.util")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local M = {}
local C = theme.c
local T = theme.T

local function fit(font, str, w)
  while font:getWidth(str) > w and #str > 3 do str = str:sub(1, -2) end
  return str
end
M.fit = fit

function M.frame(x, y, w, h, title)
  gfx.panel(x, y, w, h, C.ink, { border = C.goldDark })
  if title then gfx.text(title, T.title(), x + 10, y + 3, C.gold) end
  if widgets.button("ov_close", x + w - 24, y + 6, 18, 18, "x", { font = T.body(), color = C.redDark }) then G.closeOverlay() end
end

-- ---------------------------------------------------------------- shared nemesis pieces

function M.traitChips(n, x, y, maxW, revealed)
  local cx, cy = x, y
  local list = {}
  for _, t in ipairs(n.traits) do
    local known = t.known or (revealed and util.contains(revealed, t.id))
    local info = traits.TRAITS[t.id]
    list[#list + 1] = known and { info.name, info.kind, info.desc } or { "???", "hidden", "A hidden trait. Beat strays, bribe the rat or watch it fire in a match to learn it." }
  end
  if n.wins > 0 then list[#list + 1] = { "Grudge x" .. n.wins, "strength", traits.TRAITS.grudge.desc } end
  local font = T.small()
  for _, l in ipairs(list) do
    local w = font:getWidth(l[1]) + 8
    if cx + w > x + maxW then cx = x; cy = cy + gfx.CHIP_H + 2 end
    local over = widgets.inside(cx, cy, w, gfx.CHIP_H)
    gfx.chip(l[1], cx, cy, l[2])
    if over then
      local tx, ty = cx, cy + gfx.CHIP_H + 2
      widgets.tooltip(function()
        widgets.infoBox(tx, ty, 190, { { text = l[1], font = T.big(), color = l[2] == "weakness" and C.green or l[2] == "strength" and C.red or C.muted }, { text = l[3] } })
      end)
    end
    cx = cx + w + 3
  end
  return cy + gfx.CHIP_H
end

function M.nemesisCard(n, rank, x, y, w, h)
  gfx.panel(x, y, w, h, C.deep, { border = C.redDark })
  gfx.label(rank > 0 and nemesis.RANK_TITLES[rank] or n.status, x + 6, y + 4, C.red)
  local p = art.nemesis(n, rank, 48)
  gfx.box(x + 5, y + 15, 50, 50, C.black)
  lg.setColor(1, 1, 1)
  lg.draw(p, x + 6, y + 16)
  local nf = T.big():getWidth(n.name) <= w - 64 and T.big() or T.body()
  gfx.text(n.name, nf, x + 60, y + 13, C.paper)
  gfx.textf(n.epithet, T.body(), x + 60, y + 34, w - 64, "left", C.muted)
  local coat = cards.COATS[n.coat]
  gfx.text("Level " .. n.level, T.body(), x + 6, y + 68, C.paper)
  gfx.text(coat.name .. " coat", T.body(), x + 62, y + 68, coat.color)
  icons.draw("skull", x + w - 40, y + 8, C.paper)
  gfx.text(tostring(n.wins), T.small(), x + w - 33, y + 2, C.paper)
  icons.draw("sword", x + w - 18, y + 8, C.paper)
  gfx.text(tostring(n.losses), T.small(), x + w - 11, y + 2, C.paper)
  local cy = M.traitChips(n, x + 6, y + 88, w - 12)
  if h > 130 then
    local hy = cy + 4
    for i = #n.history, math.max(1, #n.history - 2), -1 do
      local th = gfx.wrapHeight(n.history[i].text, T.body(), w - 12)
      if hy + th > y + h - 4 then break end
      gfx.textf(n.history[i].text, T.body(), x + 6, hy, w - 12, "left", C.muted)
      hy = hy + th + 2
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
  local pk = picker.new(list, { x = 320, y = 92, scale = 1, gap = 4, cols = 10, rowGap = 6, dealFrom = { 320, 420 } })
  local ov = {}
  function ov:update(dt) pk:update(dt) end
  function ov:draw()
    M.frame(12, 12, theme.W - 24, theme.H - 24, opts.title or ("Your Pride (" .. #deck .. ")"))
    if opts.hint then gfx.text(opts.hint, T.body(), theme.W - 44, 17, C.paper2, { align = "right" }) end
    lg.setScissor(G.scissor(14, 44, theme.W - 28, theme.H - 58))
    local i = pk:draw()
    lg.setScissor()
    if i and opts.onPick then
      G.closeOverlay()
      opts.onPick(list[i])
    end
  end
  function ov:wheel(dy)
    local rows = math.ceil(#list / 10)
    pk.scroll = math.max(0, math.min(math.max(0, rows * 84 - 270), pk.scroll - dy * 30))
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
    gfx.text("They enter every festival and remember every match.", T.body(), 230, 13, C.paper2)
    for i, h in ipairs(save.hands) do M.nemesisCard(h, i, 14 + (i - 1) * 154, 38, 150, 196) end
    gfx.label("Chronicle", 16, 242, C.gold)
    local y = 252
    for i = #save.chronicle, math.max(1, #save.chronicle - 5), -1 do
      local c = save.chronicle[i]
      local th = gfx.wrapHeight(c.text, T.body(), 400)
      if y + th > 344 then break end
      gfx.text("Fest " .. c.run, T.body(), 16, y, C.muted)
      gfx.textf(c.text, T.body(), 62, y, 400, "left", C.paper)
      y = y + th + 1
    end
    gfx.label("Fallen and gone", 476, 242, C.gold)
    local fy, shown = 252, 0
    for i = #save.fallen, 1, -1 do
      local n = save.fallen[i]
      if shown >= 5 then break end
      if n.met or n.status ~= "exiled" then
        gfx.text(fit(T.body(), n.name, 86), T.body(), 476, fy, C.paper)
        gfx.text(n.status, T.body(), 626, fy, C.muted, { align = "right" })
        fy = fy + 17
        shown = shown + 1
      end
    end
    if shown == 0 then gfx.text("None yet.", T.body(), 476, fy, C.muted) end
  end
  G.openOverlay(ov)
end

-- ---------------------------------------------------------------- standings

-- A group's table. Rows are 17px of readable text; the panel is 22 + 4 * 17 px tall.
M.GROUP_H = 22 + 4 * 17
function M.groupTable(f, gi, x, y, w)
  local rows = festival.table(f, gi)
  local myGroup = festival.groupOf(f, festival.PLAYER) == gi
  gfx.panel(x, y, w, M.GROUP_H, myGroup and C.ink2 or C.deep, { border = myGroup and C.goldDark or C.ink3 })
  gfx.label("Group " .. festival.GROUPS[gi], x + 6, y + 5, myGroup and C.gold or C.pale)
  local cols = { w - 70, w - 54, w - 30, w - 7 }
  for k, h in ipairs({ "W", "L", "PD", "PTS" }) do gfx.label(h, x + cols[k], y + 5, C.muted, "right") end
  local font = T.body()
  for i, r in ipairs(rows) do
    local e = f.entrants[r.id]
    local ry = y + 3 + i * 17
    local col = e.kind == "player" and C.gold or e.kind == "hand" and C.red or C.paper
    if f.withdrawn[r.id] then col = C.muted end
    if i <= 2 then
      theme.set(C.green, 0.8)
      lg.rectangle("fill", x + 2, ry + 3, 2, 10)
    end
    local nx = x + 7
    if e.kind == "hand" then icons.draw("crown", x + 12, ry + 8, C.red); nx = x + 19 end
    gfx.text(fit(font, e.name, x + cols[1] - 22 - nx), font, nx, ry, col)
    local vals = { tostring(r.w), tostring(r.l), (r.pd >= 0 and "+" or "") .. r.pd, tostring(r.pts) }
    for k, v in ipairs(vals) do gfx.text(v, font, x + cols[k], ry, col, { align = "right" }) end
  end
end

function M.bracket(f, x, y, w, h, font)
  font = font or T.small()
  gfx.panel(x, y, w, h, C.deep, { border = C.ink3 })
  local colW = math.floor((w - 12) / 3)
  local stages = { "qf", "sf", "final" }
  local labels = { "Quarters", "Semis", "Final" }
  local lh = font:getHeight()
  for si, st in ipairs(stages) do
    local list = f.bracket[st] or {}
    local n = ({ 4, 2, 1 })[si]
    local cx = x + 6 + (si - 1) * colW
    gfx.label(labels[si], cx + 2, y + 5, C.pale)
    local slotH = math.floor((h - 18) / n)
    local bh = lh * 2 + 2
    for i = 1, n do
      local m = list[i]
      local my = y + 16 + (i - 1) * slotH + math.floor((slotH - bh) / 2)
      local involved = m and (m.a == festival.PLAYER or m.b == festival.PLAYER)
      gfx.panel(cx, my, colW - 6, bh, involved and C.ink3 or C.ink2, { border = involved and C.goldDark or nil })
      for k, key in ipairs({ "a", "b" }) do
        local id = m and m[key]
        local e = id and f.entrants[id]
        local name = e and e.name or "..."
        local col = not e and C.muted or (e.kind == "player" and C.gold or e.kind == "hand" and C.red or C.paper)
        if m and m.winner and id ~= m.winner then col = theme.mix(col, C.ink, 0.6) end
        gfx.text(fit(font, name, colW - 22), font, cx + 4, my + 2 + (k - 1) * lh, col)
        if m and m.winner == id then icons.draw("star", cx + colW - 14, my + 2 + (k - 1) * lh + math.floor(lh / 2), C.gold) end
      end
    end
  end
  if f.champion then
    gfx.text("Champion: " .. f.entrants[f.champion].name, T.body(), x + w - 6, y + h - 18, C.gold, { align = "right" })
  end
end

function M.standings(f)
  local ov = {}
  function ov:draw()
    M.frame(8, 8, theme.W - 16, theme.H - 16, f.name)
    for gi = 1, 4 do M.groupTable(f, gi, 14 + ((gi - 1) % 2) * 194, 42 + math.floor((gi - 1) / 2) * (M.GROUP_H + 6), 190) end
    M.bracket(f, 404, 42, 222, 300, T.small())
    gfx.textf("The top two of each group (green bar) reach the knockouts. A win is worth 3 points; goblet difference (PD) breaks ties.",
      T.body(), 16, 42 + 2 * (M.GROUP_H + 6) + 4, 378, "left", C.paper2)
  end
  G.openOverlay(ov)
end

-- ---------------------------------------------------------------- rules

local TABS = { "Bouts", "Cats", "Tricks", "Festival" }
local CAT_ABILITIES = { "none", "smite", "inspire", "hex", "litter", "pounce", "ninelives", "stray", "groom", "purr", "yowl", "muster" }
local TRICKS = { "sunbeam", "box", "hairball", "downpour", "moonfog", "warhorn" }

function M.help()
  local ov = { tab = 1 }
  function ov:draw()
    M.frame(8, 8, theme.W - 16, theme.H - 16, "How to play")
    for i, name in ipairs(TABS) do
      if widgets.button("h_t" .. i, 200 + (i - 1) * 84, 10, 80, 20, name, { font = T.body(), color = self.tab == i and C.red or C.ink3 }) then self.tab = i end
    end
    local x, y, w = 20, 42, 600
    local function para(t, col) y = y + gfx.textf(t, T.body(), x, y, w, "left", col or C.paper) + 5 end
    local function head(t) gfx.text(t, T.big(), x, y, C.gold); y = y + 22 end
    local function list(ids, cols)
      local colW = math.floor(w / cols)
      local ys = {}
      for c = 1, cols do ys[c] = y end
      for i, id in ipairs(ids) do
        local c = (i - 1) % cols + 1
        local ab = cards.ABILITIES[id]
        local cx = x + (c - 1) * colW
        icons.draw(icons.ABILITY_ICON[id] or "paw", cx + 5, ys[c] + 8, id == "none" and C.steel or C.cyan)
        gfx.text(ab.name, T.body(), cx + 14, ys[c], C.cyan)
        local desc = ab.desc:gsub("^Trick: ", ""):gsub("^Trick that fights: ", "Fights! ")
        ys[c] = ys[c] + 16
        ys[c] = ys[c] + gfx.textf(desc, T.body(), cx + 14, ys[c], colW - 22, "left", C.paper) + 6
      end
    end
    if self.tab == 1 then
      head("A bout")
      para("Each bout one side leads: it puts up to 3 cards face-down on its cushions. The other side answers, seeing only the card backs. Then everything flips over. The lead swaps every bout.")
      para("A card's back shows its coat. Ember, Tide and Gilt cats have coloured backs. Shadow cats and tricks share the same dark back, so a dark card could be either.")
      head("Duels and goblets")
      para("The two cards on each cushion duel. The higher Paws wins and swats a goblet off the loser's side of the table. A cat facing an empty cushion or a trick walks in unopposed and swats too. Ties go to the leader.")
      para("Coat edge: Ember beats Gilt, Gilt beats Tide, Tide beats Ember. The winning coat gets +" .. match.COAT_EDGE .. " Paws. Shadow has no edge either way.")
      para("Knock every goblet off the rival's side to win the match.", C.gold)
    elseif self.tab == 2 then
      head("Cat abilities")
      list(CAT_ABILITIES, 2)
    elseif self.tab == 3 then
      head("Tricks")
      para("Tricks sit on a cushion but never duel (except the Box), so the cat facing one walks in unopposed unless the trick stops it.", C.paper2)
      list(TRICKS, 2)
    else
      head("The festival")
      para("16 cats enter. You play 3 group matches: a win is worth 3 points, and goblet difference breaks ties. The top 2 of each group reach the knockouts: quarter-final, semi-final, final. Lose a knockout and you're out.")
      para("Between matches you visit ONE stall: the Mews Market, the Fortune Teller or the Training Yard.")
      head("The Four Hands")
      para("The Arena's four Warlords enter every festival and remember you. Their traits start hidden: beat strays, pay the rat, carry a Spyglass, or watch a trait fire mid-match to learn them.")
      para("A Hand who beats you grows stronger. Beat one and choose their fate: Slay (they forfeit, and may return), Recruit if you never lost a bout (they join your pride, and may betray you), or Brand (a weakness, and a grudge).")
      para("Keys: Enter to charge, 1 2 3 to place the card under the mouse, F11 fullscreen, F2 screen style, F3 sound, Esc menu.", C.muted)
    end
  end
  G.openOverlay(ov)
end

-- ---------------------------------------------------------------- pause / confirm / message

function M.pause()
  local ov = {}
  function ov:draw()
    M.frame(210, 60, 220, 240, "Paused")
    local y = 98
    local bx, bw = 226, 188
    if widgets.button("p_resume", bx, y, bw, 28, "Resume", { color = C.red }) then G.closeOverlay() end
    if widgets.button("p_help", bx, y + 34, bw, 28, "How to play") then M.help() end
    if widgets.button("p_crt", bx, y + 68, bw, 28, "Screen: " .. G.screenLabel()) then G.cycleScreen() end
    local sfx = require("src.ui.sfx")
    if widgets.button("p_snd", bx, y + 102, bw, 28, "Sound: " .. (sfx.muted and "off" or "on")) then
      G.settings.muted = sfx.toggleMute(); G.saveSettings()
    end
    if widgets.button("p_quit", bx, y + 136, bw, 28, "Save and quit") then
      G.persist(); G.closeOverlay(); G.go("title")
    end
  end
  G.openOverlay(ov)
end

function M.confirm(title, body, yes, onYes)
  local ov = {}
  function ov:draw()
    M.frame(160, 96, 320, 164, title)
    gfx.textf(body, T.body(), 174, 132, 292, "left", C.paper)
    if widgets.button("c_yes", 174, 220, 140, 28, yes, { color = C.red }) then G.closeOverlay(); onYes() end
    if widgets.button("c_no", 326, 220, 140, 28, "Cancel") then G.closeOverlay() end
  end
  G.openOverlay(ov)
end

function M.message(title, body, onClose, portrait)
  local ov = { dismissable = false }
  function ov:draw()
    M.frame(120, 80, 400, 200, title)
    local x = 134
    if portrait then
      gfx.box(133, 115, 98, 98, C.black)
      lg.setColor(1, 1, 1)
      lg.draw(portrait, 134, 116)
      x = 242
    end
    gfx.textf(body, T.body(), x, 116, 506 - x, "left", C.paper)
    if widgets.button("m_ok", 256, 240, 128, 28, "Continue", { color = C.red }) then
      G.closeOverlay()
      if onClose then onClose() end
    end
  end
  G.openOverlay(ov)
end

return M
