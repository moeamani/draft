-- A dialogue scene for story mode: the speaker's portrait, a name plate and the line, typed out.
-- Click, Enter, Space or A continues; a line can ask for the player's name.
-- params: lines (from story.lines), bg, title (an optional chapter card shown first), onDone
local art = require("src.ui.art")
local gfx = require("src.ui.gfx")
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
S.bg = { preset = "vs" }

local PLATES = { gold = C.goldDark, blue = C.blue, red = C.red, ink = C.ink3, night = C.night }

function S:enter(p)
  self.lines = p.lines or {}
  self.onDone = p.onDone
  self.title = p.title
  self.sub = p.sub
  self.titleT = p.title and 2.2 or 0
  S.bg = p.bg or { preset = "vs" }
  self.i, self.shown, self.t, self.lt = 1, 0, 0, 0
  self.asking = false
  self.done = false
end

function S:line() return self.lines[self.i] end

function S:update(dt)
  self.t = self.t + dt
  if self.titleT > 0 then self.titleT = self.titleT - dt return end
  self.lt = self.lt + dt
  local l = self:line()
  if l then
    local before = math.floor(self.shown)
    self.shown = math.min(#story.fill(G.save, l.text), self.shown + dt * 60)
    if math.floor(self.shown) > before and math.floor(self.shown) % 3 == 0 then sfx.play("tick", 1.4, 0.25) end
  end
end

function S:finish()
  if self.done then return end
  self.done = true
  if self.onDone then self.onDone() end
end

function S:advance()
  if self.asking then return end
  if self.titleT > 0 then self.titleT = 0 return end
  local l = self:line()
  if not l then return self:finish() end
  local text = story.fill(G.save, l.text)
  if self.shown < #text then self.shown = #text return end
  if l.ask == "name" and not G.save.story.named then
    self.asking = true
    require("src.scenes.menu").askName("Your name, knight", function(name)
      G.save.playerName = name
      G.save.story.named = true
      G.persist()
      self.asking = false
      self:next()
    end)
    return
  end
  self:next()
end

function S:next()
  self.i = self.i + 1
  self.shown, self.lt = 0, 0
  sfx.play("click", 1, 0.5)
  if not self:line() then self:finish() end
end

local function portraitFor(who, info, rank)
  if who == "bedimew" or who == "crier" then return art.character(who, 128, true) end
  if who == "you" then return art.player(G.save.playerName, 128, true) end
  if info then return art.nemesis(info, rank, 128, true) end
end

function S:draw()
  local t = self.t
  if self.titleT > 0 then
    local a = math.min(1, (2.2 - self.titleT) * 3, self.titleT * 3)
    plates.header(120, 120, 400, 52, C.red, self.title, { size = 32, streak = 0.43, align = "center" })
    if self.sub then gfx.text(self.sub, T.big(), 320, 182, C.goldText, { align = "center", alpha = a, bg = C.ink }) end
    return
  end
  local l = self:line()
  if not l then return end
  local name, plateKey, info, rank = story.speaker(G.save, l.who)
  local text = story.fill(G.save, l.text)
  local right = l.who == "you"
  -- the speaker, rising in as the line starts (the Overseer looms over the whole box)
  local p = portraitFor(l.who, info, rank)
  if l.who == "overseer" then
    local rise = math.max(0, 1 - self.lt * 3)
    overseer.draw(320, 262 + math.floor(rise * 40), 460, t)
  elseif p then
    local rise = math.max(0, 1 - self.lt * 5)
    local bob = math.floor(math.sin(t * 1.6) * 1.5 + 0.5)
    local x = right and 452 or 60
    lg.setColor(1, 1, 1)
    lg.draw(p, x, 238 - 128 + 8 + bob + math.floor(rise * 20))
  end
  -- the box
  local bx, by, bw, bh = 40, 246, 560, 96
  gfx.panel(bx, by, bw, bh, C.deep)
  if name then
    local pw = math.max(120, math.ceil(theme.serif(18):getWidth(name)) + 28)
    plates.header(right and (bx + bw - pw - 12) or (bx + 12), by - 14, pw, 24, PLATES[plateKey] or C.ink3, name, { size = 18, streak = 0.43 })
  end
  local font = l.who == "narrator" and theme.font("italic", 11.5) or theme.font("body", 11.5)
  gfx.textf(text:sub(1, math.floor(self.shown)), font, bx + 16, by + 18, bw - 32, l.who == "narrator" and "center" or "left", C.paper, { bg = C.deep })
  if self.shown >= #text and math.floor(t * 2) % 2 == 0 then
    gfx.text(G.platform.console and "A" or "Click", T.small(), bx + bw - 14, by + bh - 15, C.muted, { align = "right", bg = C.deep })
  end
  if widgets.button("cs_skip", 572, 8, 60, 20, "Skip", { color = C.ink3 }) then
    -- skipping still asks for a name if the story needs one
    for j = self.i, #self.lines do
      if self.lines[j].ask == "name" and not G.save.story.named then
        self.i, self.shown = j, #story.fill(G.save, self.lines[j].text)
        self:advance()
        return
      end
    end
    self:finish()
  end
  -- clicking anywhere else continues
  if widgets.released and widgets.layer == widgets.top and not widgets.inside(572, 8, 60, 20) then self:advance() end
end

function S:keypressed(k)
  if k == "return" or k == "space" or k == "kpenter" then self:advance()
  elseif k == "escape" then
    require("src.ui.overlays").pause()
  end
end

return S
