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

-- The screen: a Balatro-style CRT. Gentle barrel curvature, one scanline per virtual pixel row,
-- a soft bloom on bright pixels, a chromatic fringe that grows towards the edges, a vignette and
-- a little grain. Drawn when the finished frame goes to the window; Settings turns it off.
M.src.crt = [[
// @emu crtpost
extern vec2 screen;   // window size in pixels
extern float rows;    // virtual pixel rows on screen (one scanline each)
extern float time;
extern float curve;   // barrel strength
extern float amount;  // 0..1
vec2 warp(vec2 uv) {
  vec2 c = uv * 2.0 - 1.0;
  c *= 1.0 + (c.yx * c.yx) * curve;
  return c * 0.5 + 0.5;
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec2 w = warp(uv);
  if (w.x < 0.0 || w.x > 1.0 || w.y < 0.0 || w.y > 1.0) return vec4(0.012, 0.03, 0.022, 1.0);
  vec2 px = 1.0 / screen;
  float fringe = (0.5 + length(w - 0.5) * 2.2) * amount;
  vec3 col;
  col.r = Texel(tex, w + vec2(px.x * fringe, 0.0)).r;
  col.g = Texel(tex, w).g;
  col.b = Texel(tex, w - vec2(px.x * fringe, 0.0)).b;
  vec2 g = px * (screen.y / rows) * 1.5;
  vec3 glow = Texel(tex, w + vec2(g.x, 0.0)).rgb + Texel(tex, w - vec2(g.x, 0.0)).rgb
    + Texel(tex, w + vec2(0.0, g.y)).rgb + Texel(tex, w - vec2(0.0, g.y)).rgb
    + Texel(tex, w + g).rgb + Texel(tex, w - g).rgb
    + Texel(tex, w + vec2(g.x, -g.y)).rgb + Texel(tex, w + vec2(-g.x, g.y)).rgb;
  glow /= 8.0;
  col += max(glow - 0.3, 0.0) * 0.45 * amount;
  float line = sin(w.y * rows * 6.2831853) * 0.5 + 0.5;
  col *= mix(1.0, 0.84 + 0.16 * line, amount);
  vec2 v = w * (1.0 - w);
  float vig = pow(clamp(v.x * v.y * 20.0, 0.0, 1.0), 0.22);
  col *= mix(1.0, vig, amount);
  float n = fract(sin(dot(sc + vec2(time * 61.0, time * 17.0), vec2(12.9898, 78.233))) * 43758.5453);
  col += (n - 0.5) * 0.022 * amount;
  col *= 1.0 + sin(time * 47.0) * 0.004 * amount;
  return vec4(col, 1.0) * color;
}
]]

-- The same curvature on the CPU, so the mouse lands where the curved picture shows it.
function M.warp(u, v, curve)
  local cx, cy = u * 2 - 1, v * 2 - 1
  cx, cy = cx * (1 + cy * cy * curve), cy * (1 + cx * cx * curve)
  return cx * 0.5 + 0.5, cy * 0.5 + 0.5
end

function M.load()
  for k, src in pairs(M.src) do
    local ok, sh = pcall(lg.newShader, src)
    if ok then M[k] = sh else print("shader " .. k .. " failed: " .. tostring(sh)) end
  end
end

return M
