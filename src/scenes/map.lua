local art = require("src.ui.art")
local cards = require("src.core.cards")
local game = require("src.core.game")
local gfx = require("src.ui.gfx")
local hud = require("src.ui.hud")
local icons = require("src.ui.icons")
local overlays = require("src.ui.overlays")
local theme = require("src.ui.theme")
local widgets = require("src.ui.widgets")
local lg = love.graphics

local S = {}
local C = theme.c
S.bg = { C.ink, C.ink3, C.blue, spin = 0.7 }

local INFO = {
  skirmish = { icon = "sword", title = "Skirmish", color = C.red, desc = "Win for fish, a new cat, and intel on a Warlord." },
  pit = { icon = "skull", title = "The Pit", color = C.red, desc = "A veteran fighter. Harder duel, rarer cats." },
  market = { icon = "fish", title = "Mews Market", color = C.gold, desc = "Buy cats and charms, train a cat, or send one home." },
  shrine = { icon = "star", title = "Shrine", color = C.cyan, desc = "Something strange is happening down this alley." },
  tavern = { icon = "cup", title = "The Sleeping Fox", color = C.gold, desc = "Rest (+3 lives) or train a cat." },
  warlord = { icon = "crown", title = "Warlord", color = C.red, desc = "One of the Four Hands. They will remember how this goes." },
}

function S:enter()
  self.t = 0
  local run = G.save.run
  if run.phase == "over" then return G.go("summary") end
  if #run.options == 0 then run.options = game.genOptions(G.save) end
  self.anim = {}
  S.bg = game.atWarlord(run) and { C.black, { 0.3, 0.05, 0.04 }, C.red, spin = 2.2 } or { C.ink, C.ink3, C.blue, spin = 0.7 }
end

function S:update(dt)
  self.t = self.t + dt
end

local function enterNode(n)
  if n.kind == "skirmish" or n.kind == "pit" then
    G.go("duel", { node = n })
  elseif n.kind == "warlord" then
    G.go("encounter", { node = n })
  elseif n.kind == "market" then
    G.go("market")
  elseif n.kind == "shrine" then
    G.go("event", { event = n.event })
  elseif n.kind == "tavern" then
    G.go("event", { tavern = true })
  end
end

function S:draw()
  local save = G.save
  local run = save.run
  if not run or run.phase ~= "map" then return end
  hud.draw(run)
  gfx.label("Ring " .. hud.roman(run.ring) .. " of IV", 70, 108)
  gfx.wavy(game.RING_NAMES[run.ring], theme.font("bold", 72), 70 + theme.font("bold", 72):getWidth(game.RING_NAMES[run.ring]) / 2, 126, C.paper, self.t, 3)
  local boss = game.currentBoss(save)
  if run.detour and boss then
    gfx.panel(70, 222, 900, 46, { 0.35, 0.08, 0.06, 0.8 }, { r = 10, depth = 3, border = C.red, lw = 2, sheen = false })
    gfx.text(boss.name .. " beat you. Regroup with one more stop before the rematch.", theme.font("serif", 21), 90, 232, C.paper, { shadow = 0 })
  end
  gfx.label(run.options[1] and run.options[1].kind == "warlord" and "The Warlord awaits" or "Choose your path", 70, 290, C.muted)

  local n = #run.options
  local w = n == 1 and 520 or 320
  for i, node in ipairs(run.options) do
    local x = 70 + (i - 1) * (w + 26)
    local y = 326
    local id = "node" .. i
    local clicked, over = widgets.click(id, x, y, w, 380)
    self.anim[i] = (self.anim[i] or 0) + ((over and 1 or 0) - (self.anim[i] or 0)) * 0.2
    local a = self.anim[i]
    local info = INFO[node.kind]
    local title = info.title
    if node.kind == "shrine" then title = game.EVENTS[node.event].title end
    if node.kind == "warlord" and boss then title = "Face " .. boss.name end
    local bob = math.sin(self.t * 1.5 + i * 1.3) * 4
    lg.push()
    lg.translate(x + w / 2, y + 190 + bob - a * 12)
    lg.rotate(math.sin(self.t * 1.1 + i) * 0.01 + a * math.sin(self.t * 8) * 0.008)
    lg.scale(1 + a * 0.03)
    local bgc = node.kind == "warlord" and { 0.2, 0.05, 0.04 } or node.kind == "pit" and { 0.16, 0.07, 0.06 } or C.ink2
    gfx.panel(-w / 2, -190, w, 380, bgc, { border = theme.mix(info.color, C.paper, a * 0.5), lw = 3, r = 20, depth = 10 })
    icons.draw(info.icon, -w / 2 + 64, -120, 70, info.color, math.sin(self.t * 2 + i) * 0.08)
    gfx.textf(title, theme.font("bold", 34), -w / 2 + 28, -60, w - 56, "left", C.paper)
    local desc = info.desc
    if node.foe then desc = node.foe.name .. " the " .. node.foe.title .. ". " .. desc end
    gfx.textf(desc, theme.font("serif", 20), -w / 2 + 28, 30, w - 56, "left", C.paper2, { shadow = false })
    if node.foe then
      local p = art.stray(node.foe)
      p:setFilter("nearest", "nearest")
      lg.setColor(1, 1, 1)
      lg.draw(p, w / 2 - 128, -170, 0, 100 / 64, 100 / 64)
      local coat = cards.COATS[node.foe.coat]
      gfx.text((coat.name .. " coat" .. (node.foe.elite and "  -  elite" or "")):upper(), theme.font("monoBold", 15), -w / 2 + 28, 150, coat.color, { shadow = 0 })
    end
    if node.kind == "warlord" and boss then
      local p = art.nemesis(boss, game.rankOf(save, boss))
      p:setFilter("nearest", "nearest")
      lg.setColor(1, 1, 1)
      lg.draw(p, w / 2 - 170, -175, 0, 140 / 64, 140 / 64)
    end
    lg.pop()
    if clicked then enterNode(node) end
  end

  if boss then
    gfx.label("Warlord of this ring", 1200, 108, C.red)
    overlays.nemesisCard(boss, game.rankOf(save, boss), 1200, 132, 360, {})
    gfx.textf("Beat strays to interrogate them and reveal Warlord traits.", theme.font("serif", 17), 1200, 572, 360, "left", C.muted, { shadow = false })
  end
end

function S:keypressed(k)
  if k == "escape" then overlays.pause() end
end

return S
