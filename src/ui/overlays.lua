-- Modal overlays: deck, the Four Hands, standings, rules, pause, confirm, message.
local art = require("src.ui.art")
local cards = require("src.core.cards")
local festival = require("src.core.festival")
local gfx = require("src.ui.gfx")
local icons = require("src.ui.icons")
local match = require("src.core.match")
local nemesis = require("src.core.nemesis")
local picker = require("src.ui.picker")
local plates = require("src.ui.plates")
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

-- Overlay frame: an ink panel with a title card across the top (blue, with the mascot smear).
function M.frame(x, y, w, h, title, color)
  gfx.panel(x, y, w, h, C.ink)
  plates.header(x, y, w, 30, color or theme.hex("#2471fc"), title or "", { size = 22, streak = 0.43, pad = 12 })
  if widgets.button("ov_close", x + w - 26, y + 5, 20, 20, "x", { color = C.redDark }) then G.closeOverlay() end
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
  gfx.panel(x, y, w, h, C.deep)
  plates.header(x, y, w, 16, C.night, rank > 0 and nemesis.RANK_TITLES[rank] or n.status, { size = 13, streak = 1.0, pad = 6 })
  local p = art.nemesis(n, rank, 48)
  gfx.box(x + 5, y + 19, 50, 50, C.black)
  lg.setColor(1, 1, 1)
  lg.draw(p, x + 6, y + 20)
  local size = plates.textWidth(n.name, 20) <= w - 64 and 20 or 16
  plates.print(n.name, size, x + 60, y + 18, C.white)
  gfx.textf(n.epithet, T.body(), x + 60, y + 40, w - 64, "left", C.muted)
  local coat = cards.COATS[n.coat]
  gfx.text("Level " .. n.level, T.body(), x + 6, y + 71, C.paper)
  gfx.text(coat.name .. " coat", T.body(), x + 62, y + 71, coat.color)
  icons.draw("skull", x + w - 40, y + 8, C.paper)
  gfx.text(tostring(n.wins), T.small(), x + w - 33, y + 2, C.paper, { shadow = false })
  icons.draw("sword", x + w - 18, y + 8, C.paper)
  gfx.text(tostring(n.losses), T.small(), x + w - 11, y + 2, C.paper, { shadow = false })
  local cy = M.traitChips(n, x + 6, y + 90, w - 12)
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
  local pk = picker.new(list, { x = 320, y = 82, scale = 1, gap = 4, cols = 10, rowGap = 6, dealFrom = { 320, 420 } })
  local ov = {}
  function ov:update(dt) pk:update(dt) end
  function ov:draw()
    M.frame(12, 12, theme.W - 24, theme.H - 24, opts.title or ("Your Pride (" .. #deck .. ")"))
    if opts.hint then gfx.text(opts.hint, T.body(), theme.W - 46, 19, C.white, { align = "right" }) end
    lg.setScissor(G.scissor(14, 43, theme.W - 28, theme.H - 57))
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
    M.frame(8, 8, theme.W - 16, theme.H - 16, "The Four Hands", C.night)
    gfx.text("They enter every festival and remember every match.", T.body(), 600, 15, C.white, { align = "right" })
    for i, h in ipairs(save.hands) do M.nemesisCard(h, i, 14 + (i - 1) * 154, 44, 150, 194) end
    gfx.label("Chronicle", 16, 244, C.gold)
    local y = 254
    for i = #save.chronicle, math.max(1, #save.chronicle - 5), -1 do
      local c = save.chronicle[i]
      local th = gfx.wrapHeight(c.text, T.body(), 400)
      if y + th > 344 then break end
      gfx.text("Fest " .. c.run, T.body(), 16, y, C.muted)
      gfx.textf(c.text, T.body(), 62, y, 400, "left", C.paper)
      y = y + th + 1
    end
    gfx.label("Fallen and gone", 476, 244, C.gold)
    local fy, shown = 254, 0
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
  gfx.panel(x, y, w, M.GROUP_H, myGroup and C.ink2 or C.deep)
  plates.header(x, y, w, 18, myGroup and C.red or C.ink3, "Group " .. festival.GROUPS[gi], { size = 14, pad = 6 })
  local cols = { w - 70, w - 54, w - 30, w - 7 }
  for k, h in ipairs({ "W", "L", "PD", "PTS" }) do gfx.text(h, T.small(), x + cols[k], y + 3, C.white, { align = "right", shadow = false }) end
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
  gfx.panel(x, y, w, h, C.deep)
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
    for gi = 1, 4 do M.groupTable(f, gi, 14 + ((gi - 1) % 2) * 194, 44 + math.floor((gi - 1) / 2) * (M.GROUP_H + 6), 190) end
    M.bracket(f, 404, 44, 222, 298, T.small())
    gfx.textf("The top two of each group (green bar) reach the knockouts. A win is worth 3 points; goblet difference (PD) breaks ties.",
      T.body(), 16, 44 + 2 * (M.GROUP_H + 6) + 4, 378, "left", C.paper2)
  end
  G.openOverlay(ov)
end

-- ---------------------------------------------------------------- the Cattery

-- Every cat and trick you've owned or seen face up, with its illustration, story and bonds.
function M.cattery()
  local game = require("src.core.game")
  local art = require("src.ui.art")
  local list = cards.DRAFTABLE
  local ov = { sel = nil }
  local COLS, CW, CH = 9, 53, 51
  local GX, GY = 16, 44
  function ov:draw()
    local save = G.save
    local seen = (save and save.seen) or {}
    M.frame(8, 8, theme.W - 16, theme.H - 16, "The Cattery")
    local n, total = save and game.seenCount(save) or 0, #list
    gfx.text(("%d of %d found"):format(n, total), T.body(), 250, 13, C.paper)
    local hover
    for i, d in ipairs(list) do
      local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
      local x, y = GX + col * CW, GY + row * CH
      local clicked, over = widgets.click("cat_" .. d.id, x, y, 50, 48)
      if over then hover = d end
      if clicked then self.sel = d end
      local known = seen[d.id]
      gfx.box(x - 1, y - 1, 52, 50, (self.sel == d or over) and C.gold or (d.rarity == "legendary" and C.goldDark or C.black))
      if known then
        plates.draw(art.card(d), x, y)
      else
        gfx.box(x, y, 50, 48, C.deep)
        plates.print("?", 26, x + 25, y + 6, C.ink3, { align = "center" })
      end
    end
    -- the detail page
    local d = hover or self.sel
    local px, py, pw = 498, 40, 126
    gfx.panel(px, py, pw, 304, C.deep)
    if not d then
      gfx.textf("Every cat and trick you own, or see face up across the table, joins the Cattery. Hover one to read its story.", T.body(), px + 6, py + 6, pw - 12, "left", C.paper2)
      local found = 0
      for _, b in ipairs(cards.BONDS) do if seen[b[1]] and seen[b[2]] then found = found + 1 end end
      gfx.text(("Bonds found: %d of %d"):format(found, #cards.BONDS), T.body(), px + 6, py + 120, C.gold)
      return
    end
    if not seen[d.id] then
      gfx.textf("Not found yet. Win it as a reward, buy it at the market, or meet it in a match.", T.body(), px + 6, py + 6, pw - 12, "left", C.paper2)
      return
    end
    local pic = art.illustration(d)
    local iw = pic:getWidth()
    gfx.box(px + (pw - iw) / 2 - 1, py + 4, iw + 2, 98, C.black)
    plates.draw(pic, px + (pw - iw) / 2, py + 5)
    local y = py + 104
    local size = plates.textWidth(d.name, 16) <= pw - 10 and 16 or 13
    plates.print(d.name, size, px + 6, y, d.rarity == "legendary" and C.gold or C.white)
    y = y + 20
    local function line(t, c) y = y + gfx.textf(t, T.body(), px + 6, y, pw - 12, "left", c or C.paper) + 2 end
    if d.kind == "unit" then
      local coat = cards.COATS[d.coat]
      line(d.power .. " Paws, " .. coat.name .. " coat", coat.color)
    else
      line("Trick, " .. d.rarity, C.muted)
    end
    line(cards.ABILITIES[d.ability].name, C.cyan)
    for _, b in ipairs(cards.bondsOf(d.id)) do
      line("Bond: " .. cards.CARDS[b[1]].name .. (seen[b[1]] and "" or " (not found)"), C.gold)
    end
    line('"' .. d.flavor .. '"', C.muted)
  end
  G.openOverlay(ov)
end

-- ---------------------------------------------------------------- rules

local TABS = { "Bouts", "Cats", "Tricks", "Bonds", "Festival" }
local CAT_ABILITIES = { "none", "smite", "inspire", "hex", "litter", "pounce", "ninelives", "stray", "groom", "purr", "yowl", "muster" }
local TRICKS = { "sunbeam", "box", "hairball", "downpour", "moonfog", "warhorn" }

function M.help()
  local ov = { tab = 1 }
  function ov:draw()
    M.frame(8, 8, theme.W - 16, theme.H - 16, "How to play")
    for i, name in ipairs(TABS) do
      if widgets.button("h_t" .. i, 236 + (i - 1) * 72, 11, 68, 18, name, { color = self.tab == i and C.red or C.ink3 }) then self.tab = i end
    end
    local x, y, w = 20, 46, 600
    local function para(t, col) y = y + gfx.textf(t, T.body(), x, y, w, "left", col or C.paper) + 5 end
    local function head(t) plates.print(t, 20, x, y - 2, C.gold); y = y + 22 end
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
    elseif self.tab == 4 then
      head("Bonds")
      para("These pairs from the old stories get +" .. cards.BOND_PAWS .. " Paws each when they sit on cushions side by side. A gold link shows it. The rival's cats bond too.", C.paper2)
      local colW = math.floor(w / 3)
      for i, b in ipairs(cards.BONDS) do
        local c, r = (i - 1) % 3, math.floor((i - 1) / 3)
        gfx.text(cards.shortName(cards.CARDS[b[1]]) .. " + " .. cards.shortName(cards.CARDS[b[2]]), T.body(), x + c * colW, y + r * 16, C.gold)
      end
      y = y + math.ceil(#cards.BONDS / 3) * 16 + 6
      head("Cushions and omens")
      para("The market's upholsterer sells Velvet (+1 Paw), Thistle (the rival cat facing it loses 1) and Silk (you win ties there). They last the whole festival. The Hands bring their own as they rise.")
      para("Every festival has an omen, a rule twist for all its matches: Midsummer Sun (Ember cats +1), Long Naps (ties go to the side that answers) and more. It's shown on the festival grounds.")
    else
      head("The festival")
      para("16 cats enter. You play 3 group matches: a win is worth 3 points, and goblet difference breaks ties. The top 2 of each group reach the knockouts: quarter-final, semi-final, final. Lose a knockout and you're out.")
      para("Between matches you visit ONE stall: the Mews Market, the Fortune Teller or the Training Yard.")
      head("The Four Hands")
      para("The Arena's four Warlords enter every festival and remember you. Their traits start hidden: beat strays, pay the rat, carry a Spyglass, or watch a trait fire mid-match to learn them.")
      para("A Hand who beats you grows stronger. Beat one and choose their fate: Slay (they forfeit, and may return), Recruit if you never lost a bout (they join your pride, and may betray you), or Brand (a weakness, and a grudge).")
      if G.platform and G.platform.console then
        para("Controls: stick or d-pad moves the paw, A picks up and places, X charges, Y takes your cards back, B closes, + opens the menu, L and R scroll. You can also tap and drag on the touchscreen.", C.muted)
      else
        para("Keys: Enter to charge, 1 2 3 to place the card under the mouse, F11 fullscreen, F2 screen style, F3 sound, Esc menu.", C.muted)
      end
    end
  end
  G.openOverlay(ov)
end

-- ---------------------------------------------------------------- pause / confirm / message

function M.pause()
  local ov = {}
  function ov:draw()
    M.frame(210, 60, 220, 240, "Paused")
    local y = 100
    local bx, bw = 226, 188
    if widgets.button("p_resume", bx, y, bw, 28, "Resume", { color = C.red }) then G.closeOverlay() end
    if widgets.button("p_help", bx, y + 34, bw / 2 - 2, 28, "Rules") then M.help() end
    if widgets.button("p_cattery", bx + bw / 2 + 2, y + 34, bw / 2 - 2, 28, "Cattery") then M.cattery() end
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
    M.frame(160, 96, 320, 164, title, C.red)
    gfx.textf(body, T.body(), 174, 136, 292, "left", C.paper)
    if widgets.button("c_yes", 174, 220, 140, 28, yes, { color = C.red }) then G.closeOverlay(); onYes() end
    if widgets.button("c_no", 326, 220, 140, 28, "Cancel") then G.closeOverlay() end
  end
  G.openOverlay(ov)
end

function M.message(title, body, onClose, portrait)
  local ov = { dismissable = false }
  function ov:draw()
    M.frame(120, 80, 400, 200, title, C.night)
    local x = 134
    if portrait then
      gfx.box(133, 119, 98, 98, C.black)
      lg.setColor(1, 1, 1)
      lg.draw(portrait, 134, 120)
      x = 242
    end
    gfx.textf(body, T.body(), x, 120, 506 - x, "left", C.paper)
    if widgets.button("m_ok", 256, 240, 128, 28, "Continue", { color = C.red }) then
      G.closeOverlay()
      if onClose then onClose() end
    end
  end
  G.openOverlay(ov)
end

return M
