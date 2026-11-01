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
    local inst = it.uid and it or { uid = "pick" .. i .. (it.id or ""), id = it.id, level = it.level or 1, xp = 0, def = it.def }
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
      v:setTarget(v.baseX, v.baseY - self.scroll + lift + math.floor(math.sin(self.t * 1.6 + i) * 1.5 + 0.5), v.baseS * (v.hovered and 1.1 or 1), 0)
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
    require("src.ui.sfx").play("card")
  end
  if self.hover and not self.opts.noTooltip then
    local v = self.views[self.hover]
    local w = cardview.W * v.s
    local tx = v.x + w / 2 + 6
    if tx + 150 > theme.W then tx = v.x - w / 2 - 156 end
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
    gfx.panel(v.x - 18, y, 36, 12, C.gold)
    gfx.text(it.price .. " fish", theme.T.tiny(), v.x, y + 2, C.black, { align = "center", shadow = false })
  elseif it.sold then
    gfx.outlined("SOLD", theme.T.num(), v.x, v.y - 6, C.muted, { align = "center" })
  end
end

function M.cardTooltip(def, inst, x, y)
  local ab = cards.ABILITIES[def.ability]
  local sub = def.kind == "unit" and ((def.type == "magic" and "Magic" or "Physical") .. " - " .. cards.COATS[def.coat].name .. " - " .. def.rarity) or ("Trick - " .. def.rarity)
  local lines = {
    { text = def.name, font = theme.T.big(), color = def.rarity == "legendary" and C.gold or C.paper },
    { text = sub, color = C.muted },
    { text = ab.name, color = C.cyan, gap = 1 },
    { text = ab.desc },
  }
  if def.kind == "unit" then
    local p = inst and cards.paws(inst) or def.power
    lines[#lines + 1] = { text = p .. " Paws", color = C.gold }
    if inst and inst.xp then
      local lvl = inst.level or 1
      lines[#lines + 1] = { text = lvl >= 3 and "Level 3 Paladin (max)" or ("Level " .. lvl .. (lvl == 2 and " Knight" or "") .. " - XP " .. (inst.xp or 0) .. "/" .. cards.XP_FOR_LEVEL[lvl + 1]), color = C.pale }
    end
  end
  lines[#lines + 1] = { text = '"' .. def.flavor .. '"', color = C.muted }
  widgets.infoBox(x, y, 150, lines)
end

return M
