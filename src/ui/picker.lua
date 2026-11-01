-- A row/grid of interactive cards (draft, rewards, market, deck viewer).
local cards = require("src.core.cards")
local cardview = require("src.ui.cardview")
local gfx = require("src.ui.gfx")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")

local M = {}
M.__index = M

-- items: list of insts or {id=...}; opts: x, y, w (row width), scale, gap, cols, rowGap, style, dealFrom
function M.new(items, opts)
  local p = setmetatable({ items = items, opts = opts, views = {}, hover = nil, t = 0 }, M)
  p:layout(true)
  return p
end

function M:layout(initial)
  local o = self.opts
  local s = o.scale or 0.9
  local cw, ch = cardview.W * s, cardview.H * s
  local gap = o.gap or 28
  local cols = o.cols or #self.items
  for i, it in ipairs(self.items) do
    local inst = it.uid and it or { uid = "pick" .. i .. (it.id or ""), id = it.id, level = it.level or 1, xp = 0, def = it.def }
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    local n = math.min(cols, #self.items - row * cols)
    local rowW = n * cw + (n - 1) * gap
    local x0 = (o.x or theme.W / 2) - rowW / 2 + cw / 2
    local x = x0 + col * (cw + gap)
    local y = (o.y or 450) + row * (ch + (o.rowGap or 24))
    local v = self.views[i]
    if not v then
      v = cardview.new(inst, x, y, s)
      v.style = o.style or "full"
      if initial and o.dealFrom then
        v.x, v.y = o.dealFrom[1], o.dealFrom[2]
        v.rot = (love.math.random() - 0.5) * 1.2
        v.deal = (i - 1) * 0.08
      end
      self.views[i] = v
    end
    v.baseX, v.baseY, v.baseS = x, y, s
  end
end

function M:update(dt)
  self.t = self.t + dt
  self.hover = nil
  for i = #self.views, 1, -1 do
    local v = self.views[i]
    if not self.hover and widgets.layer == widgets.top and v:contains(widgets.mx, widgets.my) and not self.items[i].sold then
      self.hover = i
    end
  end
  for i, v in ipairs(self.views) do
    v.hovered = i == self.hover
    if v.deal and v.deal > 0 then
      v.deal = v.deal - dt
    else
      local lift = v.hovered and -18 or 0
      local bob = math.sin(self.t * 1.6 + i) * 3
      v:setTarget(v.baseX, v.baseY + lift + bob, v.baseS * (v.hovered and 1.08 or 1), 0)
    end
    v:update(dt)
  end
end

-- Draws cards; returns index clicked (or nil).
function M:draw(layer)
  local clicked
  for i, v in ipairs(self.views) do
    if i ~= self.hover then self:drawOne(i, v) end
  end
  if self.hover then self:drawOne(self.hover, self.views[self.hover]) end
  if self.hover and widgets.released and widgets.layer == widgets.top then
    clicked = self.hover
    require("src.ui.sfx").play("card")
  end
  if self.hover and not self.opts.noTooltip then
    local v = self.views[self.hover]
    local def = v.def
    local w = cardview.W * v.s
    local tx = v.x + w / 2 + 16
    if tx + 330 > theme.W then tx = v.x - w / 2 - 346 end
    widgets.tooltip(function() M.cardTooltip(def, v.inst, tx, v.y - 120) end)
  end
  return clicked
end

function M:drawOne(i, v)
  local it = self.items[i]
  if it.sold then
    v.alpha = 0.25
  end
  v:draw()
  if it.price and not it.sold then
    local font = theme.font("bold", 24)
    local y = v.y + cardview.H * v.s / 2 + 14
    gfx.panel(v.x - 46, y, 92, 38, theme.c.gold, { r = 12, depth = 4, sheen = false })
    gfx.text(it.price .. " fish", font, v.x, y + 4, theme.c.black, { align = "center", shadow = 0 })
  elseif it.sold then
    gfx.text("SOLD", theme.font("monoBold", 26), v.x, v.y - 14, theme.c.muted, { align = "center" })
  end
end

function M.cardTooltip(def, inst, x, y)
  local C = theme.c
  local ab = cards.ABILITIES[def.ability]
  local lines = {
    { text = def.name, font = theme.font("bold", 26), color = def.rarity == "legendary" and C.gold or C.paper },
    { text = (def.kind == "unit" and ((def.type == "magic" and "Magic - Arcane row" or "Physical - Vanguard row")) or "Special") .. "  |  " .. def.rarity, font = theme.font("mono", 13), color = C.muted },
    { text = ab.name, font = theme.font("bold", 20), color = C.cyan, gap = 2 },
    { text = ab.desc, font = theme.font("serif", 17) },
  }
  if def.coat ~= "none" then
    local coat = cards.COATS[def.coat]
    lines[#lines + 1] = { text = coat.name .. " coat. " .. coat.desc, font = theme.font("serif", 16), color = coat.color }
  end
  if inst and def.kind == "unit" and inst.xp then
    local lvl = inst.level or 1
    local txt = lvl >= 3 and "Level 3 - Paladin (max)" or ("Level " .. lvl .. (lvl == 2 and " - Knight" or "") .. "  |  XP " .. (inst.xp or 0) .. "/" .. cards.XP_FOR_LEVEL[lvl + 1])
    lines[#lines + 1] = { text = txt, font = theme.font("mono", 13), color = C.gold }
  end
  lines[#lines + 1] = { text = '"' .. def.flavor .. '"', font = theme.font("italic", 16), color = C.muted }
  widgets.infoBox(x, y, 330, lines)
end

return M
