-- Data shared by the live shaders and by tools/switch/bake_assets.py, which pre-renders the same
-- effects to PNG for platforms without runtime shaders (LÖVE Potion on Switch). Pure data: no
-- love.* calls, so the Python baker can read it. Re-run the baker after changing anything here.
local M = {}

-- Backdrop presets. Every scene uses one of these. `room` presets are painted as pixel art by
-- src/ui/room.lua (a table in perspective, a table from above, a panelled wall); the others use
-- the `stage` shader, where `swirl` animates a slow paint swirl. The baked PNGs (no shaders, no
-- ImageData) cover every preset as a fallback.
M.STAGES = {
  menu = { horizon = 0, light = { 0.5, 0.4 }, radius = 0.95, power = 0.95, swirl = 1.0 },
  vs = { horizon = 0, light = { 0.3, 0.45 }, radius = 0.8, power = 1.0, swirl = 0, room = "wall" },
  match = { horizon = 100 / 360, light = { 0.5, 0.62 }, radius = 0.72, power = 1.0, swirl = 0, room = "table3d" },
  table = { horizon = 0, light = { 0.5, 0.45 }, radius = 0.85, power = 1.0, swirl = 0, room = "felt" },
}

-- Colour ramps: ink green for the room and table, blood red for Hand matches and defeats.
M.RAMPS = {
  felt = { voidc = "#08140f", baseA = "#0e2119", baseB = "#1d4434", edge = "#2f6a4f" },
  blood = { voidc = "#120809", baseA = "#2a0f0d", baseB = "#5a1f19", edge = "#9e2a20" },
}

function M.stageFile(preset, ramp) return ("assets/switch/stage-%s-%s.png"):format(preset, ramp) end

-- Pre-baked mascot smears (the Figma lens effect) for title cards, square, one per plate colour.
M.SMEAR_SIDE = 320
M.SMEARS = {
  { name = "blue", tint = "#2471fc", aberration = 0.43 },
  { name = "red", tint = "#e8483b", aberration = 0.43 },
  { name = "gold", tint = "#d3a200", aberration = 0.43 },
  { name = "golddark", tint = "#8a6a00", aberration = 0.43 },
  { name = "ink", tint = "#24503c", aberration = 0.43 },
  { name = "night", tint = "#020403", aberration = 1.0 },
}

function M.smearFile(name) return ("assets/switch/smear-%s.png"):format(name) end

return M
