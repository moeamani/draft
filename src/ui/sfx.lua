-- Synthesised sound effects and a generated ambient loop (no audio files needed).
local M = { muted = false, music = nil, enabled = true }

local RATE = 22050
local sounds = {}

local function wave(kind, ph)
  if kind == "sine" then return math.sin(ph * 2 * math.pi)
  elseif kind == "square" then return (ph % 1) < 0.5 and 1 or -1
  elseif kind == "saw" then return 2 * (ph % 1) - 1
  elseif kind == "noise" then return love.math.random() * 2 - 1
  end
  local p = ph % 1
  return p < 0.5 and (4 * p - 1) or (3 - 4 * p) -- triangle
end

-- notes: list of {freq, start, dur, kind, vol, slide}
local function synth(notes, total)
  local n = math.floor(total * RATE)
  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  local buf = {}
  for i = 0, n - 1 do buf[i] = 0 end
  for _, nt in ipairs(notes) do
    local f0, st, dur, kind, vol, slide = nt[1], nt[2], nt[3], nt[4] or "tri", nt[5] or 0.3, nt[6] or 0
    local s0 = math.floor(st * RATE)
    local len = math.floor(dur * RATE)
    local ph = 0
    for i = 0, len - 1 do
      local idx = s0 + i
      if idx >= n then break end
      local t = i / len
      local f = f0 + slide * t
      ph = ph + f / RATE
      local env = math.min(1, i / (RATE * 0.004)) * (1 - t) ^ 2
      buf[idx] = buf[idx] + wave(kind, ph) * vol * env
    end
  end
  for i = 0, n - 1 do sd:setSample(i, math.max(-1, math.min(1, buf[i]))) end
  return sd
end

local function make(name, notes, total)
  local ok, src = pcall(function() return love.audio.newSource(synth(notes, total), "static") end)
  if ok then sounds[name] = src end
end

local function ambient()
  -- slow pad: Dm - Bb - F - C, with a soft plucked arpeggio
  local chords = { { 146.8, 174.6, 220.0 }, { 116.5, 146.8, 174.6 }, { 174.6, 220.0, 261.6 }, { 130.8, 164.8, 196.0 } }
  local notes = {}
  local bar = 4
  for ci, ch in ipairs(chords) do
    local t0 = (ci - 1) * bar
    for _, f in ipairs(ch) do
      notes[#notes + 1] = { f, t0, bar + 0.6, "sine", 0.06 }
      notes[#notes + 1] = { f * 2, t0, bar + 0.4, "tri", 0.015 }
    end
    for k = 0, 7 do
      local f = ch[(k % 3) + 1] * (k >= 4 and 4 or 2)
      notes[#notes + 1] = { f, t0 + k * 0.5, 0.45, "tri", 0.035 }
    end
  end
  local ok, src = pcall(function() return love.audio.newSource(synth(notes, #chords * bar), "static") end)
  if ok then
    src:setLooping(true)
    src:setVolume(0.55)
    M.music = src
  end
end

function M.load()
  if not love.audio then M.enabled = false; return end
  local ok = pcall(function()
    make("click", { { 880, 0, 0.05, "sine", 0.25 } }, 0.06)
    make("hover", { { 1320, 0, 0.03, "sine", 0.08 } }, 0.04)
    make("card", { { 300, 0, 0.09, "noise", 0.12 }, { 520, 0, 0.12, "tri", 0.3, 260 } }, 0.14)
    make("enemy", { { 260, 0, 0.14, "tri", 0.3, -80 }, { 200, 0, 0.08, "noise", 0.1 } }, 0.16)
    make("pass", { { 220, 0, 0.22, "sine", 0.3, -90 } }, 0.24)
    make("hit", { { 160, 0, 0.2, "square", 0.18, -100 }, { 0, 0, 0.12, "noise", 0.2 } }, 0.22)
    make("burn", { { 90, 0, 0.5, "noise", 0.18 }, { 300, 0, 0.4, "saw", 0.08, -220 } }, 0.5)
    make("chip", { { 1046, 0, 0.06, "square", 0.08 }, { 1568, 0.03, 0.08, "sine", 0.12 } }, 0.12)
    make("reveal", { { 660, 0, 0.12, "sine", 0.22 }, { 990, 0.08, 0.2, "sine", 0.2 } }, 0.3)
    make("win", { { 523, 0, 0.25, "tri", 0.3 }, { 659, 0.11, 0.25, "tri", 0.3 }, { 784, 0.22, 0.45, "tri", 0.3 }, { 1046, 0.33, 0.6, "sine", 0.2 } }, 1.0)
    make("lose", { { 392, 0, 0.35, "sine", 0.3 }, { 330, 0.16, 0.35, "sine", 0.3 }, { 262, 0.32, 0.7, "sine", 0.3 } }, 1.05)
    make("round", { { 392, 0, 0.18, "square", 0.1 }, { 523, 0.09, 0.3, "square", 0.1 } }, 0.42)
    make("coin", { { 1318, 0, 0.07, "square", 0.08 }, { 1760, 0.05, 0.12, "square", 0.08 } }, 0.18)
    make("whoosh", { { 0, 0, 0.25, "noise", 0.14 } }, 0.26)
    make("tick", { { 1200, 0, 0.03, "square", 0.06 } }, 0.04)
    make("slam", { { 110, 0, 0.35, "square", 0.22, -60 }, { 0, 0, 0.2, "noise", 0.25 } }, 0.38)
    make("flip", { { 0, 0, 0.06, "noise", 0.1 }, { 700, 0.01, 0.05, "tri", 0.12, 300 } }, 0.08)
    make("select", { { 660, 0, 0.05, "tri", 0.18, 120 } }, 0.06)
    make("cheer", { { 0, 0, 0.6, "noise", 0.06 }, { 523, 0.05, 0.2, "tri", 0.1 }, { 784, 0.12, 0.3, "tri", 0.1 } }, 0.65)
    ambient()
  end)
  M.enabled = ok and sounds.click ~= nil
end

function M.play(name, pitch, vol)
  if M.muted or not M.enabled then return end
  local s = sounds[name]
  if not s then return end
  local c = s:clone()
  c:setPitch((pitch or 1) * (0.96 + love.math.random() * 0.08))
  c:setVolume(vol or 1)
  c:play()
end

function M.startMusic()
  if M.music and not M.muted and not M.music:isPlaying() then M.music:play() end
end

function M.toggleMute()
  M.muted = not M.muted
  if M.music then
    if M.muted then M.music:pause() else M.music:play() end
  end
  return M.muted
end

return M
