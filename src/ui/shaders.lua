-- All GLSL effects: the candle-lit table backdrop, the screen pass (lamplight or CRT), legendary foil,
-- dissolve, dither, transitions.
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

-- The shared backdrop: a dark room and a green baize card table under one flickering candle.
-- Everything is computed per virtual pixel and the light is quantised with ordered dithering,
-- so the lighting has the same chunky pixel grain as the art. horizon > 0 draws the table in
-- perspective (its far edge at that height); horizon <= 0 is a flat table top filling the screen.
M.src.table = BAYER .. [[
// @emu table
extern float time;
extern vec2 res;
extern float pix;
extern float horizon;
extern vec2 light;
extern float radius;
extern float power;
extern vec3 felt[5];
extern vec3 wood[4];
extern vec3 voidc[3];
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
// constant indexing only, for older GLSL
vec3 feltAt(float k) { if (k < 0.5) return felt[0]; if (k < 1.5) return felt[1]; if (k < 2.5) return felt[2]; if (k < 3.5) return felt[3]; return felt[4]; }
vec3 woodAt(float k) { if (k < 0.5) return wood[0]; if (k < 1.5) return wood[1]; if (k < 2.5) return wood[2]; return wood[3]; }
vec3 voidAt(float k) { if (k < 0.5) return voidc[0]; if (k < 1.5) return voidc[1]; return voidc[2]; }
vec4 effect(vec4 color, Image tex, vec2 uv0, vec2 sc) {
  vec2 V = res / pix;
  vec2 vp = floor(sc / pix);
  vec2 uv = (vp + 0.5) / V;
  float b = bayer4(vp) - 0.5;
  float flick = 0.035 * sin(time * 7.3) + 0.025 * sin(time * 13.1 + 1.7) + 0.015 * sin(time * 23.0 + 0.4);
  vec2 d = (uv - light) * vec2(V.x / V.y, 1.0);
  float L = clamp(power * (1.0 - smoothstep(0.0, radius, length(d))) + flick, 0.0, 1.0);
  if (horizon > 0.0 && uv.y < horizon) {
    float spill = L * smoothstep(horizon - 0.22, horizon, uv.y) * 0.9;
    return vec4(voidAt(clamp(floor(spill * 3.0 + b), 0.0, 2.0)), 1.0) * color;
  }
  float t = horizon > 0.0 ? (uv.y - horizon) / (1.0 - horizon) : 1.0;
  float halfw = horizon > 0.0 ? mix(0.33, 0.78, t) : 10.0;
  float u = (uv.x - 0.5) / halfw;
  if (abs(u) > 1.0) {
    return vec4(voidAt(clamp(floor(L * 0.8 * 3.0 + b), 0.0, 1.0)), 1.0) * color;
  }
  float depth = horizon > 0.0 ? 1.0 / (t + 0.12) : uv.y * 8.0;
  bool rim = horizon > 0.0 && (abs(u) > 0.93 || uv.y < horizon + 0.022);
  if (rim) {
    float grain = abs(u) > 0.93 ? sin(depth * 9.0 + h21(vec2(floor(u * 30.0), 0.0)) * 6.0) : sin(uv.x * 140.0 + sin(uv.x * 23.0) * 2.0);
    float lit = L * 3.2 + grain * 0.35 + b;
    if (abs(u) < 0.93 && uv.y > horizon + 0.017) lit -= 1.0;
    return vec4(woodAt(clamp(floor(lit), 0.0, 3.0)), 1.0) * color;
  }
  float nap = (h21(vec2(floor(u * 90.0), floor(depth * 14.0))) - 0.5) * 0.35;
  return vec4(feltAt(clamp(floor(L * 4.6 + b + nap), 0.0, 4.0)), 1.0) * color;
}
]]

-- The screen pass. mode 0: lamplight (soft vignette and film grain, text stays crisp).
-- mode 1: CRT (scanlines, slight curve and colour split).
M.src.post = [[
// @emu post
extern vec2 res;
extern float time;
extern float mode;
extern float curvature;
extern float flash;
extern float rows;
vec2 curve(vec2 uv) {
  uv = uv * 2.0 - 1.0;
  vec2 off = abs(uv.yx) * vec2(0.11, 0.14) * curvature;
  uv = uv + uv * off * off;
  return uv * 0.5 + 0.5;
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec2 cuv = mode > 0.5 ? curve(uv) : uv;
  if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) return vec4(0.0, 0.0, 0.0, 1.0);
  vec3 col;
  if (mode > 0.5) {
    float ca = 1.0 / res.x;
    col.r = Texel(tex, cuv + vec2(ca, 0.0)).r;
    col.g = Texel(tex, cuv).g;
    col.b = Texel(tex, cuv - vec2(ca, 0.0)).b;
    float scan = 0.5 + 0.5 * cos(cuv.y * rows * 6.28318);
    col *= 0.9 + 0.1 * scan;
  } else {
    col = Texel(tex, cuv).rgb;
  }
  vec2 v = cuv * (1.0 - cuv.yx);
  float vig = pow(clamp(v.x * v.y * 22.0, 0.0, 1.0), 0.3);
  col *= mix(1.0, vig, 0.55);
  float n = fract(sin(dot(sc + vec2(time * 37.0, time * 11.0), vec2(12.9898, 78.233))) * 43758.5453);
  col += (n - 0.5) * 0.03;
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
  return vec4(best, step(0.5, c.a));
}
]]

-- Bake smooth artwork to crisp pixels: snap to the palette, hard alpha edge.
M.src.bake = [[
extern vec3 pal[24];
extern float count;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = Texel(tex, uv);
  if (c.a < 0.5) discard;
  vec3 v = c.rgb / max(c.a, 0.001);
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
