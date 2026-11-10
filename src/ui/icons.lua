-- Pixel icons, defined as ASCII grids and baked to images per tint.
-- x = tint, d = dark tint, w = white, k = black outline, . = transparent
local theme = require("src.ui.theme")
local lg = love.graphics

local M = {}

local S = {}
S.sword = {
  ".......kk", "......kwk", ".....kwk.", ".k..kwk..", ".kkkwk...", "..kxk....", "..kkxk...", ".kxk.kk..", ".kk......" }
S.orb = {
  "..kkkkk..", ".kwwxxxk.", "kwwxxxxxk", "kwxxxxxxk", "kxxxxxxdk", "kxxxxxddk", ".kxxxddk.", "..kkkkk..", "........." }
S.gem = {
  ".........", "..kkkkk..", ".kwxxxxk.", "kwwxxxxdk", "kxxxxxxdk", ".kxxxxdk.", "..kxxdk..", "...kdk...", "....k...." }
S.heart = {
  ".........", ".kk...kk.", "kwxk.kxxk", "kwxxkxxxk", "kxxxxxxdk", ".kxxxxdk.", "..kxxdk..", "...kdk...", "....k...." }
S.fish = {
  ".........", "...kkk...", ".kkxxxk.k", "kwkxxxxkk", "kxxxxxxxk", "kdxxxxxkk", ".kkdddk.k", "...kkk...", "........." }
S.crown = {
  ".........", "k...k...k", "kk.kxk.kk", "kxkxxxkxk", "kxxxwxxxk", "kxxxxxxxk", "kddddddxk", "kkkkkkkkk", "........." }
S.skull = {
  "..kkkkk..", ".kwwwwwk.", "kwwwwwwwk", "kwkkwkkwk", "kwkkwkkwk", "kwwwkwwwk", ".kwwwwwk.", "..kwkwk..", "..kkkkk.." }
S.star = {
  "....k....", "...kxk...", "kkkkwkkkk", "kxxxwxxxk", ".kxxxxxk.", "..kxxxk..", ".kxxkxxk.", ".kxk.kxk.", ".kk...kk." }
S.moon = {
  "...kkkk..", "..kxxxk..", ".kxxk....", ".kxk.....", ".kxk.....", ".kxk.....", ".kxxk....", "..kxxxk..", "...kkkk.." }
S.flower = {
  "...kkk...", "..kxxxk..", ".kkxxxkk.", "kxxkwkxxk", "kxxwwwxxk", "kxxkwkxxk", ".kkxxxkk.", "..kxxxk..", "...kkk..." }
S.arrow = {
  "....kkkkk", ".....kxxk", "....kxwxk", "...kxwkxk", "..kxwk.kk", ".kxwk....", "kxwk.....", "kxk......", ".k......." }
S.nine = {
  "..kkkkk..", ".kxxxxxk.", ".kxk.kxk.", ".kxk.kxk.", ".kxxxxxk.", "..kkkkxk.", ".....kxk.", ".kxxxxxk.", "..kkkkk.." }
S.eye = {
  ".........", "..kkkkk..", ".kwwwwwk.", "kwwkkkwwk", "kwkxxxkwk", "kwwkkkwwk", ".kwwwwwk.", "..kkkkk..", "........." }
S.cross = {
  "...kkk...", "...kxk...", "...kxk...", "kkkkxkkkk", "kxxxwxxxk", "kkkkxkkkk", "...kxk...", "...kxk...", "...kkk..." }
S.note = {
  "....kkkk.", "....kxxk.", "....kxk..", "....kxk..", "....kxk..", ".kkkkxk..", "kxxxkxk..", "kxxxk.k..", ".kkk....." }
S.medal = {
  "kk.....kk", "kxk...kxk", ".kxk.kxk.", "..kkkkk..", ".kwwxxxk.", "kwxxwxxdk", "kxxwwwxdk", ".kxxxxdk.", "..kkkkk.." }
S.notes = {
  "..kkkkkkk", "..kxxxxxk", "..kxkkkxk", "..kxk.kxk", "..kxk.kxk", "kkkxk.kxk", "kxxxkkkxk", "kxxk.kxxk", ".kk...kk." }
S.up = {
  "....k....", "...kxk...", "..kxwxk..", ".kxxkxxk.", "kkk.k.kkk", "...kxk...", "..kxwxk..", ".kxxkxxk.", "kkk...kkk" }
S.umbrella = {
  "...kkk...", ".kkxxxkk.", "kxxwxxxxk", "kxwxxxxxk", "kkkkxkkkk", "....kk...", "....kk...", ".k..kk...", "..kkk...." }
S.cloud = {
  ".........", "...kkk...", "..kwwwk..", ".kkwwwkk.", "kwwwwwwwk", "kwwwwwwdk", ".kkkkkkk.", ".x.x.x.x.", "x.x.x.x.." }
S.sun = {
  "k...k...k", ".k..x..k.", "...kkk...", "..kxwxk..", "kxkxxxkxk", "..kxxdk..", "...kkk...", ".k..x..k.", "k...k...k" }
S.box = {
  ".kk...kk.", ".kxk.kxk.", "kkkkkkkkk", "kxxxxxxxk", "kxwxxxxdk", "kxxxxxxdk", "kxxxxxxdk", "kddddddxk", "kkkkkkkkk" }
S.burst = {
  "k...k...k", ".kk.k.kk.", ".kxkxkxk.", "..kxwxk..", "kkxwwwxkk", "..kxwxk..", ".kxkxkxk.", ".kk.k.kk.", "k...k...k" }
S.cup = {
  ".x..x....", "..x..x...", "kkkkkkk..", "kwxxxxkkk", "kxxxxxk.k", "kxxxxxkkk", "kxxxxdk..", ".kdddk...", "..kkk...." }
S.bell = {
  "....k....", "...kxk...", "..kwxxk..", "..kwxxk..", ".kwxxxxk.", ".kxxxxxk.", "kxxxxxxdk", "kkkkkkkkk", "....kk..." }
S.diamond = {
  "....k....", "...kwk...", "..kwxxk..", ".kwxxxxk.", "kxxxxxxdk", ".kxxxxdk.", "..kxxdk..", "...kdk...", "....k...." }
S.leaf = {
  "......kkk", "....kkxxk", "...kxxwxk", "..kxxwxxk", ".kxxwxxk.", ".kxwxxk..", "kxwkkk...", "kwk......", "kk......." }
S.yarn = {
  "..kkkkk..", ".kxxwxxk.", "kxwxxxwxk", "kxxwxwxxk", "kxwxxxwxk", "kxxwxwxxk", ".kxxwxxk.", "..kkkkkx.", "........x" }
S.banner = {
  "kk.......", "kxkkkkkkk", "kxkxxxxxk", "kxkxwxxxk", "kxkxxxxk.", "kxkxxxxxk", "kxkkkkkkk", "kxk......", "kkk......" }
S.cream = {
  ".........", "...www...", "..wwwww..", "kkkkkkkkk", "kxwwwwwxk", ".kxxxxxk.", "..kkkkk..", ".........", "........." }
S.tally = {
  ".........", "k.k.k.k..", "kxkxkxkx.", "kxkxkkkxk", "kxkxkxkxk", "kxkxkxkxk", "kxkxkxkxk", "kkkkkkkkk", "........." }
S.seal = {
  "..kkkkk..", ".kxxxxxk.", "kxxkkkxxk", "kxkwwwkxk", "kxkwwwkxk", "kxxkkkxxk", ".kxxxxxk.", ".kxkkkxk.", ".kk...kk." }
S.drum = {
  "k.......k", ".k.....k.", "..kkkkk..", ".kwwwwwk.", "kxkkkkkxk", "kxxwxwxxk", "kxwxwxwxk", ".kxxxxxk.", "..kkkkk.." }
S.candle = {
  "....x....", "...xwx...", "....k....", "...kwk...", "...kxk...", "...kxk...", "...kxk...", ".kkkxkkk.", "kxxxxxxxk" }
S.trophy = {
  "kkkkkkkkk", "kxwxxxxxk", "kxwxxxxdk", ".kxxxxxk.", "..kxxdk..", "...kxk...", "...kxk...", "..kkxkk..", ".kxxxxxk." }
S.tent = {
  "....k....", "...kxk...", "..kxwxk..", ".kxwxxxk.", ".kwxxxxk.", "kxxxkxxxk", "kxxkkkxxk", "kxxkkkxxk", "kkkkkkkkk" }
S.scroll = {
  ".kkkkkkk.", "kwxxxxxwk", ".kxkkkxk.", ".kxxxxxk.", ".kxkkkxk.", ".kxxxxxk.", ".kxkkxxk.", "kwxxxxxwk", ".kkkkkkk." }
S.paw = {
  ".kk...kk.", "kxxk.kxxk", ".kk.k.kk.", "...kxk...", ".kkxxxkk.", "kxxxxxxxk", "kxxxxxxxk", ".kxxxxxk.", "..kkkkk.." }
S.shield = {
  "kkkkkkkkk", "kxwxxxxxk", "kxwxxxxxk", "kxxxxxxxk", "kxxxxxxdk", ".kxxxxdk.", "..kxxdk..", "...kdk...", "....k...." }
S.goblet = {
  "kkkkkkkkk", "kwwxxxxdk", "kwxxxxxdk", "kxxxxxxdk", ".kxxxxdk.", "..kxxdk..", "...kxk...", "...kxk...", "..kxxxk..", ".kxxxxdk.", ".kkkkkkk." }
S.flame = {
  "..k...k..", ".kxk.kxk.", ".kxxkxxk.", "kxxxxxxxk", "kxxwxwxxk", "kxwwwwwxk", "kxwwwwwxk", ".kxwwwxk.", "..kkkkk.." }
S.drop = {
  "....k....", "...kxk...", "...kxk...", "..kxxxk..", ".kxwxxxk.", ".kwxxxxk.", ".kxxxxdk.", "..kxxdk..", "...kkk..." }
S.zzz = {
  "kkkkk....", "kwwwk....", "kkwkk....", ".kwk.kkkk", "kwkkkkwwk", "kwwwkkkwk", "kkkkkkwkk", ".....kwwk", ".....kkkk" }
S.pointer = {
  "k........", "kwk......", "kwwk.....", "kwwwk....", "kwwwwk...", "kwwwwwk..", "kwwwwwwk.", "kwwwwkkkk", "kwkkwk...", "kk..kwk..", ".....kk.." }
S.dagger = S.sword
S.market, S.shrine, S.training = S.fish, S.star, S.shield

-- The coats as shapes, so a coat reads without its colour: flame, drop, crown, moon.
M.COAT_ICON = { ember = "flame", tide = "drop", gilt = "crown", shadow = "moon", dark = "moon" }

M.ABILITY_ICON = {
  smite = "sword", inspire = "orb", hex = "moon", litter = "flower", pounce = "arrow", ninelives = "nine",
  stray = "eye", groom = "cross", purr = "note", yowl = "notes", muster = "up", downpour = "umbrella",
  moonfog = "cloud", sunbeam = "sun", warhorn = "notes", box = "box", hairball = "burst", none = "paw",
}

local cache = {}

local function bake(name, tint)
  local rows = S[name]
  if not rows then return nil end
  local key = name .. ":" .. tint[1] .. tint[2] .. tint[3]
  if cache[key] then return cache[key] end
  local h, w = #rows, #rows[1]
  local dark = theme.darken(tint, 0.55)
  local function colour(ch)
    if ch == "x" then return tint elseif ch == "d" then return dark elseif ch == "w" then return theme.mix(tint, theme.c.paper, 0.75)
    elseif ch == "k" then return theme.c.black end
  end
  local ok, img = pcall(function()
    local data = love.image.newImageData(w, h)
    for y = 1, h do
      for x = 1, w do
        local c = colour(rows[y]:sub(x, x))
        if c then data:setPixel(x - 1, y - 1, c[1], c[2], c[3], 1) else data:setPixel(x - 1, y - 1, 0, 0, 0, 0) end
      end
    end
    return lg.newImage(data)
  end)
  if not ok then -- no ImageData on this platform: paint the pixels into a canvas instead
    img = lg.newCanvas(w, h)
    lg.push("all")
    lg.origin()
    lg.setScissor()
    lg.setCanvas(img)
    lg.clear(0, 0, 0, 0)
    for y = 1, h do
      for x = 1, w do
        local c = colour(rows[y]:sub(x, x))
        if c then lg.setColor(c[1], c[2], c[3], 1); lg.rectangle("fill", x - 1, y - 1, 1, 1) end
      end
    end
    lg.pop()
  end
  img:setFilter("nearest", "nearest")
  cache[key] = img
  return img
end

-- Draw centred on (x, y). scale is an integer pixel multiplier.
function M.draw(name, x, y, tint, scale, rot)
  local img = bake(name, tint or theme.c.paper)
  if not img then return end
  scale = scale or 1
  lg.setColor(1, 1, 1, (tint and tint[4]) or 1)
  local w, h = img:getDimensions()
  lg.draw(img, math.floor(x), math.floor(y), rot or 0, scale, scale, math.floor(w / 2), math.floor(h / 2))
end

M.SIZE = 9

return M
