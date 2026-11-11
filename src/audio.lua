-- Sound. Everything is tuned to the teaser's music (a G sharp drone, and the five-note scale
-- G# A# C# D# F#): the looping soundtrack, the effects, and the scoring ladder, whose bell climbs
-- that scale one step per event. Files are rendered by tools/audio/make_audio.py; the teaser's
-- own music plays over the intro.
--
-- Music crossfades between tracks ("menu", "table", "high"); effects are cloned so they overlap.
-- Without love.audio (or with a file missing) every call is a quiet no-op.
local M = { enabled = false, muted = false, musicVol = 0.7, sfxVol = 0.8, track = nil }

local sounds = {}   -- name -> static Source
local streams = {}  -- name -> { src, vol (current 0..1), target }
local FADE = 1.2    -- seconds for a crossfade

-- the scale as pitch ratios over two octaves: step 0 is the sample's own pitch (G#4), step 10 G#6
local SCALE = { 0, 2, 5, 7, 10 }
local function ratio(step)
  step = math.max(0, math.min(10, math.floor(step)))
  local oct, deg = math.floor(step / 5), step % 5
  return 2 ^ ((oct * 12 + SCALE[deg + 1]) / 12)
end
M.ratio = ratio

local function try(f, ...)
  local ok, a = pcall(f, ...)
  if ok then return a end
  return nil
end

function M.load()
  if not (love.audio and love.audio.newSource and love.filesystem) then return end
  local dir = "assets/audio/sfx"
  for _, file in ipairs(try(love.filesystem.getDirectoryItems, dir) or {}) do
    local name = file:match("^(.+)%.wav$")
    if name then sounds[name] = try(love.audio.newSource, dir .. "/" .. file, "static") end
  end
  M.enabled = next(sounds) ~= nil
end

local function stream(name)
  local s = streams[name]
  if s == nil then
    local src = M.enabled and try(love.audio.newSource, "assets/audio/music/" .. name .. ".ogg", "stream") or nil
    s = src and { src = src, vol = 0, target = 0 } or false
    streams[name] = s
  end
  return s or nil
end

local function gain() return M.muted and 0 or M.musicVol end

-- One effect. pitch multiplies its speed (with a little random drift), vol its loudness.
function M.play(name, pitch, vol)
  if not M.enabled or M.muted or M.sfxVol <= 0 then return end
  local s = sounds[name]
  if not s then return end
  local c = try(s.clone, s) or s
  local p = (pitch or 1) * (0.97 + love.math.random() * 0.06)
  try(c.setPitch, c, math.max(0.1, math.min(4, p)))
  try(c.setVolume, c, math.max(0, math.min(1, (vol or 1) * M.sfxVol)))
  try(c.play, c)
end

-- A bell on the scale: step 0, 1, 2... climbs G# A# C# D# F# G#... No random drift, so a run of
-- them is a clean arpeggio.
function M.note(step, vol, name)
  if not M.enabled or M.muted or M.sfxVol <= 0 then return end
  local s = sounds[name or "note"]
  if not s then return end
  local c = try(s.clone, s) or s
  try(c.setPitch, c, ratio(step or 0))
  try(c.setVolume, c, math.max(0, math.min(1, (vol or 0.8) * M.sfxVol)))
  try(c.play, c)
end

-- Crossfade to a looping track (nil fades the music out). instant skips the fade.
function M.music(name, instant)
  if M.track == name then return end
  M.track = name
  for n, s in pairs(streams) do
    if s and n ~= name then s.target = 0 end
  end
  if not name then return end
  local s = stream(name)
  if not s then return end
  try(s.src.setLooping, s.src, true)
  s.target = 1
  if instant then s.vol = 1 end
  try(s.src.setVolume, s.src, s.vol * gain())
  if not try(s.src.isPlaying, s.src) then try(s.src.play, s.src) end
end

-- Play a track once from its start (the teaser over the intro). Returns its length in seconds.
function M.sting(name)
  M.track = name
  for n, s in pairs(streams) do
    if s and n ~= name then s.target = 0 end
  end
  local s = stream(name)
  if not s then return 0 end
  try(s.src.setLooping, s.src, false)
  try(s.src.stop, s.src)
  s.vol, s.target = 1, 1
  try(s.src.setVolume, s.src, gain())
  try(s.src.play, s.src)
  return try(s.src.getDuration, s.src) or 0
end

function M.update(dt)
  for _, s in pairs(streams) do
    if s then
      if s.vol ~= s.target then
        local step = dt / FADE
        s.vol = s.vol < s.target and math.min(s.target, s.vol + step) or math.max(s.target, s.vol - step)
        if s.vol <= 0 and s.target <= 0 then try(s.src.pause, s.src) end
      end
      try(s.src.setVolume, s.src, s.vol * gain())
    end
  end
end

-- Volumes are 0..1. Older settings files stored on/off switches here: true means the default
-- level, false means silent, anything else keeps the current volume.
local function level(v, current, default)
  if v == true then return default end
  if v == false then return 0 end
  if type(v) ~= "number" or v ~= v then return current end
  return math.max(0, math.min(1, v))
end

function M.setVolumes(music, sfx)
  M.musicVol = level(music, M.musicVol, 0.7)
  M.sfxVol = level(sfx, M.sfxVol, 0.8)
end

function M.toggleMute()
  M.muted = not M.muted
  return M.muted
end

return M
