-- GLSL effects. Only one is left: the stage backdrop, dithered with the Figma Dither effect
-- (Bayer 16x16, 8 levels per channel, one virtual pixel per cell). Everything else (plates,
-- cards, cats, text) is clean pixel art or native-resolution type, with no shader.
-- Without shaders (LÖVE Potion) the same backdrop is drawn from the PNGs baked by
-- tools/switch/bake_assets.py.
local lg = love.graphics

local M = {}

local BAYER = [[
float b2(vec2 a) { a = floor(a); return fract(a.x / 2.0 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return b2(0.5 * a) * 0.25 + b2(a); }
float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + b2(a); }
float bayer16(vec2 a) { return bayer8(0.5 * a) * 0.25 + b2(a); }
// Figma's Dither effect: Bayer 16x16, 8 levels per channel
vec3 fdither(vec3 c, vec2 cell) {
  float t = bayer16(cell) + 0.5 / 256.0;
  float off = (t - 0.5) / 7.0;
  return clamp(floor((c + off) * 7.0 + 0.5) / 7.0, 0.0, 1.0);
}
]]

M.src = {}

-- The backdrop behind every scene: ink green (or blood red) with a soft pool of light. horizon > 0
-- adds a table top in perspective (match and VS); the light never moves, so the dither stays still.
M.src.stage = BAYER .. [[
// @emu stage
extern float pix;
extern float horizon;
extern vec2 light;
extern float radius;
extern float power;
extern vec3 voidc;
extern vec3 baseA;
extern vec3 baseB;
extern vec3 edge;
extern vec2 origin; // where the 640x360 safe area starts, in virtual pixels
vec4 effect(vec4 color, Image tex, vec2 uv0, vec2 sc) {
  vec2 V = vec2(640.0, 360.0);
  vec2 vp = floor(sc / pix) - origin;
  vec2 uv = (vp + 0.5) / V;
  vec2 d = (uv - light) * vec2(V.x / V.y, 1.0);
  float L = clamp(power * (1.0 - smoothstep(0.0, radius, length(d))), 0.0, 1.0);
  vec3 col = mix(baseA, baseB, L);
  if (horizon > 0.0) {
    if (uv.y < horizon) {
      col = voidc;
    } else {
      float t = (uv.y - horizon) / (1.0 - horizon);
      float halfw = mix(0.36, 0.8, t);
      float u = (uv.x - 0.5) / halfw;
      float px = 1.0 / (halfw * V.x);
      if (abs(u) > 1.0) col = voidc;
      else if (vp.y - floor(horizon * V.y) < 1.5 || abs(u) > 1.0 - 2.0 * px) col = edge;
    }
  }
  return vec4(fdither(col, vp), 1.0) * color;
}
]]

function M.load()
  for k, src in pairs(M.src) do
    local ok, sh = pcall(lg.newShader, src)
    if ok then M[k] = sh else print("shader " .. k .. " failed: " .. tostring(sh)) end
  end
end

return M
