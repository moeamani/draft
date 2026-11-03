-- All GLSL effects. The look comes from the Figma file: every surface is quantised with the same
-- ordered dither (Bayer 16x16, 8 levels per channel, one virtual pixel per cell), and title cards
-- carry the mascot silhouette smeared by an anamorphic chromatic lens (a port of the Figma
-- "Lens distortion" effect). Also: the stage backdrop, the optional CRT pass, foil, dissolve, wipes.
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

-- The backdrop behind every scene: ink green with a soft pool of light, dithered exactly like the
-- Figma frames. horizon > 0 adds a table top in perspective (match and VS); the light never moves,
-- so the dither pattern stays still.
M.src.stage = BAYER .. [[
// @emu stage
extern vec2 res;
extern float pix;
extern float horizon;
extern vec2 light;
extern float radius;
extern float power;
extern vec3 voidc;
extern vec3 baseA;
extern vec3 baseB;
extern vec3 edge;
vec4 effect(vec4 color, Image tex, vec2 uv0, vec2 sc) {
  vec2 V = res / pix;
  vec2 vp = floor(sc / pix);
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

-- Bake pass: quantise a premultiplied canvas with the Figma dither. Output is straight alpha, so
-- draw it with setBlendMode("replace", "premultiplied"). alphaCut 1 gives hard silhouette edges.
M.src.fdither = BAYER .. [[
// @emu fdither
extern float alphaCut;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = Texel(tex, uv);
  vec3 rgb = c.a > 0.0 ? c.rgb / c.a : vec3(0.0);
  vec2 cell = floor(sc);
  float a;
  if (alphaCut > 0.5) a = step(0.5, c.a);
  else {
    float t = bayer16(cell) + 0.5 / 256.0;
    a = clamp(floor((c.a + (t - 0.5) / 7.0) * 7.0 + 0.5) / 7.0, 0.0, 1.0);
  }
  return vec4(fdither(rgb, cell), a);
}
]]

-- Port of Figma's "Lens distortion" effect in anamorphic chromatic mode, run on a square canvas
-- holding the mascot silhouette. Samples that miss the shape read as white, which is what paints
-- the cyan / pink / white streaks. Output is premultiplied.
M.src.smear = [[
// @emu smear
extern vec2 size;
extern float amount;
extern float aberration;
vec4 sampleZ(Image tex, vec2 p) {
  vec2 uv = p / size;
  if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
  return Texel(tex, uv);
}
vec2 lens(vec2 p) {
  vec2 c = size * 0.5;
  vec2 q = p - c;
  vec2 n = q / (length(size) * 0.5);
  float d2 = dot(n, n);
  return q * (1.0 + amount * (d2 + d2 * d2)) + c;
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec2 local = uv * size;
  float span = (1.0 + abs(amount)) * aberration * size.x * 0.15;
  vec4 acc = vec4(0.0);
  for (int j = 0; j < 4; j++) {
    vec2 jit = vec2(0.0);
    if (j == 1) jit = vec2(0.5, -0.333333);
    if (j == 2) jit = vec2(-0.25, 0.333333);
    if (j == 3) jit = vec2(0.25, -0.111111);
    vec2 tp = local + jit * 1.4;
    vec4 tc = vec4(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 32; i++) {
      float fi = float(i) / 31.0 - 0.5;
      float w = 1.0 - abs(fi * 2.0);
      vec4 rS = sampleZ(tex, lens(tp + vec2((fi + 0.5) * span, 0.0)));
      vec4 gS = sampleZ(tex, lens(tp + vec2(fi * span, 0.0)));
      vec4 bS = sampleZ(tex, lens(tp + vec2((fi - 0.5) * span, 0.0)));
      float rs = rS.a > 0.01 ? rS.r / max(0.001, rS.a) : 1.0;
      float gs = gS.a > 0.01 ? gS.g / max(0.001, gS.a) : 1.0;
      float bs = bS.a > 0.01 ? bS.b / max(0.001, bS.a) : 1.0;
      float al = max(max(rS.a, gS.a), bS.a);
      tc += vec4(rs * al, gs * al, bs * al, al) * w;
      wsum += w;
    }
    acc += tc / max(wsum, 0.0001);
  }
  return acc / 4.0;
}
]]

-- Optional CRT screen pass (F2). Off by default so the dither stays crisp.
M.src.post = [[
// @emu post
extern vec2 res;
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
  vec2 cuv = curve(uv);
  if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) return vec4(0.0, 0.0, 0.0, 1.0);
  float ca = 1.0 / res.x;
  vec3 col;
  col.r = Texel(tex, cuv + vec2(ca, 0.0)).r;
  col.g = Texel(tex, cuv).g;
  col.b = Texel(tex, cuv - vec2(ca, 0.0)).b;
  float scan = 0.5 + 0.5 * cos(cuv.y * rows * 6.28318);
  col *= 0.9 + 0.1 * scan;
  vec2 v = cuv * (1.0 - cuv.yx);
  col *= mix(1.0, pow(clamp(v.x * v.y * 22.0, 0.0, 1.0), 0.3), 0.5);
  col += flash;
  return vec4(col, 1.0);
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
