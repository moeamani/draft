-- All GLSL effects: animated swirl backdrop, CRT post-process, legendary foil, dissolve, dither, transitions.
local lg = love.graphics

local M = {}

local BAYER = [[
float b2(vec2 a) { a = floor(a); return fract(a.x / 2.0 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return b2(0.5 * a) * 0.25 + b2(a); }
float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + b2(a); }
]]

local NOISE = [[
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; } return v; }
]]

M.src = {}

M.src.background = BAYER .. [[
extern float time;
extern vec2 res;
extern vec3 colA;
extern vec3 colB;
extern vec3 colC;
extern float spin;
extern float pix;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec2 p = floor(sc / pix) * pix;
  vec2 c = (p - res * 0.5) / res.y;
  float r = length(c);
  float a = atan(c.y, c.x) + spin / (r + 0.4) + time * 0.04;
  vec2 q = vec2(cos(a), sin(a)) * r * 2.2;
  for (int i = 0; i < 4; i++) {
    float fi = float(i);
    q += 0.32 * vec2(sin(q.y * 2.3 + time * 0.21 + fi * 1.3), cos(q.x * 2.1 - time * 0.17 + fi * 2.1));
  }
  float v = 0.5 + 0.5 * sin(q.x * 2.4 + q.y * 1.7);
  float w = 0.5 + 0.5 * sin(length(q) * 3.2 - time * 0.35);
  float d = (bayer4(sc / pix) - 0.5) * 0.18;
  vec3 col = mix(colA, colB, step(0.55, v + d));
  col = mix(col, colC, step(0.86, w + d) * 0.85);
  col *= 1.0 - 0.45 * r * r;
  return vec4(col, 1.0) * color;
}
]]

M.src.crt = [[
extern vec2 res;
extern float time;
extern float strength;
extern float curvature;
extern float flash;
vec2 curve(vec2 uv) {
  // gentle barrel: curvature 1.0 is a mild tube, 0.0 is flat
  uv = uv * 2.0 - 1.0;
  vec2 off = abs(uv.yx) * vec2(0.11, 0.14) * curvature;
  uv = uv + uv * off * off;
  return uv * 0.5 + 0.5;
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec2 cuv = curve(uv);
  if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) return vec4(0.0, 0.0, 0.0, 1.0);
  vec2 px = 1.0 / res;
  float ca = 1.6 * px.x * strength;
  vec3 col;
  col.r = Texel(tex, cuv + vec2(ca, 0.0)).r;
  col.g = Texel(tex, cuv).g;
  col.b = Texel(tex, cuv - vec2(ca, 0.0)).b;
  vec3 glow = vec3(0.0);
  glow += Texel(tex, cuv + vec2(3.0, 0.0) * px).rgb;
  glow += Texel(tex, cuv - vec2(3.0, 0.0) * px).rgb;
  glow += Texel(tex, cuv + vec2(0.0, 3.0) * px).rgb;
  glow += Texel(tex, cuv - vec2(0.0, 3.0) * px).rgb;
  glow += Texel(tex, cuv + vec2(5.0, 5.0) * px).rgb;
  glow += Texel(tex, cuv - vec2(5.0, 5.0) * px).rgb;
  glow += Texel(tex, cuv + vec2(5.0, -5.0) * px).rgb;
  glow += Texel(tex, cuv - vec2(5.0, -5.0) * px).rgb;
  glow /= 8.0;
  col += max(glow - 0.5, 0.0) * 0.7 * strength;
  float scan = 0.5 + 0.5 * sin(sc.y * 2.0944);
  col *= mix(1.0, 0.86 + 0.14 * scan, strength);
  float m = mod(sc.x, 3.0);
  vec3 mask = vec3(m < 1.0 ? 1.0 : 0.94, (m >= 1.0 && m < 2.0) ? 1.0 : 0.94, m >= 2.0 ? 1.0 : 0.94);
  col *= mix(vec3(1.0), mask, strength);
  vec2 v = cuv * (1.0 - cuv.yx);
  float vig = pow(clamp(v.x * v.y * 30.0, 0.0, 1.0), 0.18);
  col *= mix(1.0, vig, strength * 0.8);
  float n = fract(sin(dot(sc + vec2(time * 37.0, time * 11.0), vec2(12.9898, 78.233))) * 43758.5453);
  col += (n - 0.5) * 0.035 * strength;
  col *= 1.0 + 0.012 * sin(time * 50.0) * strength;
  col += flash;
  return vec4(col, 1.0);
}
]]

M.src.foil = [[
extern float time;
extern vec2 tilt;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 base = Texel(tex, uv) * color;
  float band = sin((uv.x * 1.4 + uv.y * 0.8) * 8.0 - time * 1.6 + tilt.x * 5.0);
  vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + uv.x * 0.7 + uv.y * 0.5 + time * 0.12 + tilt.y * 0.6));
  float k = smoothstep(0.55, 1.0, band) * 0.42;
  base.rgb = mix(base.rgb, min(base.rgb + rainbow * 0.7, vec3(1.0)), k * base.a);
  return base;
}
]]

M.src.dissolve = NOISE .. [[
extern float t;
extern vec3 edge;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = Texel(tex, uv) * color;
  float n = fbm(uv * 6.0);
  if (n < t) discard;
  float e = smoothstep(t, t + 0.07, n);
  c.rgb = mix(edge * 1.6, c.rgb, e);
  return c;
}
]]

M.src.dither = BAYER .. [[
extern vec3 pal[24];
extern float count;
extern float spread;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = Texel(tex, uv);
  float t = (bayer4(sc) - 0.5) * spread;
  vec3 v = c.rgb + vec3(t);
  vec3 best = pal[0];
  float bd = 1e9;
  for (int i = 0; i < 24; i++) {
    if (float(i) >= count) break;
    vec3 d = v - pal[i];
    float dist = dot(d * d, vec3(0.3, 0.59, 0.11));
    if (dist < bd) { bd = dist; best = pal[i]; }
  }
  return vec4(best, 1.0);
}
]]

M.src.wipe = BAYER .. [[
extern float progress;
extern vec3 tint;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  float b = bayer8(sc / 6.0);
  float edge = progress * 1.15 - (1.0 - uv.y) * 0.15;
  if (b > edge) discard;
  return vec4(tint, 1.0);
}
]]

M.src.flash = [[
extern float amount;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = Texel(tex, uv) * color;
  c.rgb = mix(c.rgb, vec3(1.0), amount * c.a);
  return c;
}
]]

function M.load()
  for k, src in pairs(M.src) do
    local ok, sh = pcall(lg.newShader, src)
    if ok then M[k] = sh else print("shader " .. k .. " failed: " .. tostring(sh)) end
  end
end

return M
