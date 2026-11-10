-- A row/grid of interactive cards (rewards, market, deck viewer).
local cards = require("src.core.cards")
local cardview = require("src.ui.cardview")
local gfx = require("src.ui.gfx")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local M = {}
M.__index = M
local C = theme.c

-- items: insts or { id = }; opts: x, y, scale, gap, cols, rowGap, dealFrom, noTooltip
function M.new(items, opts)
  local p = setmetatable({ items = items, opts = opts, views = {}, hover = nil, t = 0, scroll = 0 }, M)
  local s = opts.scale or 1
  local cw, ch = cardview.W * s, cardview.H * s
  local gap = opts.gap or 10
  local cols = opts.cols or #items
  for i, it in ipairs(items) do
    local inst = it.uid and it or { uid = "pick" .. i .. (it.id or ""), id = it.id, level = it.level or 1, xp = 0, def = it.def,
      print = it.print, fakeBack = it.fakeBack }
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    local n = math.min(cols, #items - row * cols)
    local rowW = n * cw + (n - 1) * gap
    local x = math.floor((opts.x or theme.W / 2) - rowW / 2 + cw / 2 + col * (cw + gap))
    local y = math.floor((opts.y or 180) + row * (ch + (opts.rowGap or 8)))
    local v = cardview.new(inst, x, y, s)
    if opts.dealFrom then
      v.x, v.y = opts.dealFrom[1], opts.dealFrom[2]
      v.rot = (love.math.random() - 0.5) * 1.2
      v.deal = (i - 1) * 0.06
    end
    v.baseX, v.baseY, v.baseS = x, y, s
    p.views[i] = v
  end
  return p
end

function M:update(dt)
  self.t = self.t + dt
  self.hover = nil
  for i = #self.views, 1, -1 do
    local v = self.views[i]
    if not self.hover and widgets.layer == widgets.top and v:contains(widgets.mx, widgets.my) and not self.items[i].sold then self.hover = i end
  end
  for i, v in ipairs(self.views) do
    v.hovered = i == self.hover
    if v.deal and v.deal > 0 then v.deal = v.deal - dt
    else
      local lift = v.hovered and -6 or 0
      v:setTarget(v.baseX, v.baseY - self.scroll + lift, v.baseS, 0)
    end
    v:update(dt)
  end
end

function M:draw()
  for i, v in ipairs(self.views) do if i ~= self.hover then self:drawOne(i, v) end end
  if self.hover then self:drawOne(self.hover, self.views[self.hover]) end
  local clicked
  if self.hover and widgets.released and widgets.layer == widgets.top then
    clicked = self.hover
    require("src.audio").play("card")
  end
  if self.hover and not self.opts.noTooltip then
    local v = self.views[self.hover]
    local w = cardview.W * v.s
    local tx = v.x + w / 2 + 6
    if tx + 190 > theme.W then tx = v.x - w / 2 - 196 end
    widgets.tooltip(function() M.cardTooltip(v.def, v.inst, tx, v.y - 40) end)
  end
  return clicked
end

function M:drawOne(i, v)
  local it = self.items[i]
  v.alpha = it.sold and 0.25 or 1
  v:draw()
  if it.price and not it.sold then
    local y = math.floor(v.y + cardview.H * v.s / 2 + 4)
    local label = it.price .. " fish"
    local pw = theme.T.body():getWidth(label) + 10
    gfx.panel(v.x - pw / 2, y, pw, 16, C.gold)
    gfx.text(label, theme.T.body(), v.x, y - 1, C.black, { align = "center", shadow = false })
  elseif it.sold then
    gfx.outlined("SOLD", theme.T.big(), v.x, v.y - 10, C.paper2, { align = "center" })
  end
end

local function signed(n) return (n >= 0 and "+" or "") .. n end

-- The readable description of a card: used by tooltips and the match's inspect panel.
-- inf (optional): the card's numbers in the current bout, from match.compute.
function M.cardLines(def, inst, inf)
  local T = theme.T
  local ab = cards.ABILITIES[def.ability]
  local lines = { { text = def.name, font = T.big(), color = def.rarity == "legendary" and C.gold or C.paper } }
  if def.kind == "unit" then
    local coat = cards.COATS[def.coat]
    local p = inst and cards.paws(inst) or def.power
    lines[#lines + 1] = { text = p .. " Paws   " .. coat.name .. " coat", color = coat.color, gap = 0 }
    lines[#lines + 1] = { text = (def.type == "magic" and "Magic" or "Physical") .. ", " .. def.rarity, color = C.muted }
    if coat.beats then
      local by
      for _, cc in pairs(cards.COATS) do if cc.beats == def.coat then by = cc.name end end
      lines[#lines + 1] = { text = "Beats " .. cards.COATS[coat.beats].name .. ", loses to " .. by, color = C.paper2 }
    else
      lines[#lines + 1] = { text = "No coat edge either way", color = C.paper2 }
    end
  else
    lines[#lines + 1] = { text = "Trick, " .. def.rarity, color = C.muted }
  end
  lines[#lines + 1] = { text = ab.name, color = C.cyan, gap = 0 }
  lines[#lines + 1] = { text = ab.desc, color = C.paper }
  if inst and inst.print and cards.PRINTS[inst.print] then
    local pr = cards.PRINTS[inst.print]
    local extra = ""
    if inst.print == "misprint" and inst.fakeBack then
      extra = " (" .. (inst.fakeBack == "dark" and "a dark back" or (cards.COATS[inst.fakeBack].name .. " back")) .. ")"
    end
    lines[#lines + 1] = { text = pr.name .. ": " .. pr.desc .. extra, color = C.pink }
  end
  for _, b in ipairs(cards.bondsOf(def.id)) do
    local partner = cards.CARDS[b[1]]
    lines[#lines + 1] = { text = "Bond with " .. partner.name .. ": +" .. cards.BOND_PAWS .. " each side by side", color = C.gold }
  end
  if inf and inf.mods and #inf.mods > 0 and (inf.kind == "cat" or inf.kind == "box") then
    local parts = {}
    for _, m in ipairs(inf.mods) do parts[#parts + 1] = signed(m.amount) .. " " .. m.text end
    lines[#lines + 1] = { text = table.concat(parts, ", ") .. " = " .. math.max(0, inf.paws) .. " Paws", color = C.green }
  end
  if inst and (inst.warmth or 0) > 0 then
    local match = require("src.core.match")
    lines[#lines + 1] = { text = ("Seated: Warmth %d (+%d Paws).%s"):format(inst.warmth, inst.warmth,
      inst.warmth >= match.HOT and " Hot Seat: every swat knocks off an extra goblet." or (" Hot Seat at " .. match.HOT .. ".")), color = C.goldText }
  end
  if def.kind == "unit" then
    local max = inst and cards.livesOf(inst) or cards.maxLives(def)
    if def.ability == "ninelives" then
      lines[#lines + 1] = { text = "Can't be captured.", color = C.pale }
    elseif inst and inst.captive then
      lines[#lines + 1] = { text = "Your cat, captured by the rival. It's down to 1 life: beat it and it comes home.", color = C.redText }
    else
      local left = inst and inst.lives or max
      lines[#lines + 1] = { text = ("Lives %d/%d. A lost duel costs 1, a crushing loss (by %d+) costs 2. At 0 the rival captures it."):format(left, max, require("src.core.match").CRUSH), color = C.pale }
    end
  end
  if inst and inst.level and inst.level > 1 then
    lines[#lines + 1] = { text = cards.LEVEL_TITLES[inst.level] .. " (level " .. inst.level .. ")", color = C.pale }
  end
  return lines
end

function M.cardTooltip(def, inst, x, y)
  local lines = M.cardLines(def, inst)
  if inst and inst.xp and def.kind == "unit" then
    local lvl = inst.level or 1
    if lvl < 3 then lines[#lines + 1] = { text = "XP " .. (inst.xp or 0) .. "/" .. cards.XP_FOR_LEVEL[lvl + 1] .. " to the next level", color = C.pale } end
  end
  lines[#lines + 1] = { text = '"' .. def.flavor .. '"', color = C.muted }
  widgets.infoBox(x, y, 190, lines, require("src.ui.art").illustration(def))
end

return M
