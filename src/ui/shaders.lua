-- GLSL effects: the living halftone backdrop (`paper`, see src/ui/print.lua, which also bakes it
-- without shaders) and the CRT screen. Everything else is drawn without shaders, so LÖVE Potion
-- (Switch) only misses the backdrop's motion and the CRT.
local lg = love.graphics

local M = {}

M.src = {}

-- The backdrop. Each virtual pixel asks how much light falls on it (a pool of light, a slow
-- drifting swirl, a ring where something just hit the table, darker corners) and then whether
-- it lies inside a halftone dot of that size. The dots sit on a fixed 45 degree lattice, so the
-- picture breathes without shimmering. layer 1 draws only the table (the menu puts the Overseer
-- behind it).
M.src.paper = [[
// @emu paper
extern float pix;      // canvas pixels per virtual pixel
extern vec2 origin;    // where the 640x360 safe area starts, in virtual pixels
extern float horizon;  // 0, or where the table starts (0..1 of the safe area's height)
extern vec2 light;
extern float radius;
extern float power;
extern vec3 dark;
extern vec3 mid;
extern vec3 dotc;
extern float time;
extern float flow;     // 0..1: how much the light drifts
extern vec4 pulse;     // x, y (virtual pixels), radius, strength: a ring that swells the dots
extern float layer;    // 0: everything, 1: only the table
const float P = 6.0;
float dotAt(vec2 vp, float amount, float phase) {
  if (amount <= 0.0) return 0.0;
  vec2 c = vec2(mod(vp.x + vp.y + phase, P), mod(vp.x - vp.y, P)) - 0.5 * P;
  float r = 0.72 * P * sqrt(min(1.0, amount));
  return step(dot(c, c), r * r);
}
vec4 effect(vec4 color, Image tex, vec2 uv0, vec2 sc) {
  vec2 V = vec2(640.0, 360.0);
  vec2 vp = floor(sc / pix) - origin;
  vec2 uv = (vp + 0.5) / V;
  vec2 d = (uv - light) * vec2(V.x / V.y, 1.0);
  float L = clamp(power * (1.0 - smoothstep(0.0, radius, length(d))), 0.0, 1.0);
  if (flow > 0.0) {
    vec2 p = d * 2.4;
    float r = length(p);
    float a = atan(p.y, p.x) + r * 1.9 - time * 0.11;
    vec2 q = vec2(cos(a), sin(a)) * r;
    q += 0.5 * vec2(sin(q.y * 2.3 + time * 0.23), cos(q.x * 1.9 - time * 0.19));
    float band = 0.5 + 0.5 * sin(q.x * 3.0 + q.y * 2.2);
    L = clamp(L * (1.0 - 0.3 * flow) + (band - 0.35) * 0.42 * flow * (0.25 + 0.75 * L), 0.0, 1.0);
  }
  if (pulse.w > 0.0) {
    float ring = (length(vp - pulse.xy) - pulse.z) / 16.0;
    L = clamp(L + exp(-ring * ring) * pulse.w, 0.0, 1.0);
  }
  float ex = min(uv.x, 1.0 - uv.x) * V.x / V.y;
  float vig = smoothstep(-0.2, 0.25, min(ex, min(uv.y, 1.0 - uv.y)));
  float grain = (fract(sin(dot(vp, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.03;
  vec3 col = vec3(0.0);
  float hit = 0.0;
  if (horizon > 0.0 && uv.y >= horizon) {
    float t = (uv.y - horizon) / (1.0 - horizon);
    float halfw = mix(0.36, 0.8, t);
    float u = (uv.x - 0.5) / halfw;
    if (abs(u) <= 1.0) {
      hit = 1.0;
      float depth = (uv.y - horizon) * V.y;
      if (depth < 2.0 || abs(u) > 1.0 - 2.0 / (halfw * V.x)) col = vec3(0.369, 0.267, 0.063);
      else if (dotAt(vp, L * 0.42, 3.0) > 0.5) col = vec3(0.929, 0.824, 0.467);
      else if (dotAt(vp, (1.0 - L) * 0.5 + (1.0 - t) * 0.2, 0.0) > 0.5) col = vec3(0.588, 0.455, 0.122);
      else col = vec3(0.788, 0.643, 0.227);
    }
  }
  if (hit < 0.5) {
    if (layer > 0.5) return vec4(0.0);
    float tone = L * vig;
    if (dotAt(vp, smoothstep(0.55, 1.25, tone), 3.0) > 0.5) col = dotc;
    else if (dotAt(vp, smoothstep(0.0, 0.8, tone), 0.0) > 0.5) col = mid;
    else col = dark;
  }
  return vec4(clamp(col + grain, 0.0, 1.0), 1.0) * color;
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
extern float punch;   // 0..1: a burst of colour fringe on a big hit (the teaser's lens)
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
  vec2 off = vec2(px.x * fringe, 0.0) + (w - 0.5) * punch * 0.024;
  vec3 col;
  col.r = Texel(tex, w + off).r;
  col.g = Texel(tex, w).g;
  col.b = Texel(tex, w - off).b;
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
