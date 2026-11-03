-- Where are we running? Desktop LÖVE 11, or LÖVE Potion (the LÖVE port for Nintendo Switch homebrew).
-- LÖVE Potion has no runtime GLSL (Switch shaders are precompiled deko3d binaries), no
-- captureScreenshot and no mouse, so this module fills those gaps with harmless stand-ins and tells
-- the rest of the game which render and input paths to use. It must be required before anything
-- else touches love.graphics.
local M = {}

M.potion = love._potion_version ~= nil or love._console ~= nil
M.name = love._console or "Desktop"

-- `love . --console` runs the console code paths on a desktop (no shaders, controller cursor).
function M.init(args)
  for _, a in ipairs(args or {}) do
    if a == "--console" then M.simulated = true end
  end
  M.console = M.potion or M.simulated or false
end
M.console = M.potion

local lg = love.graphics
local function stub(tbl, name, fn) if tbl and tbl[name] == nil then tbl[name] = fn end end

stub(lg, "setShader", function() end)
stub(lg, "getShader", function() return nil end)
stub(lg, "newShader", function() error("custom shaders are not available on this platform") end)
stub(lg, "captureScreenshot", function() end)
if not love.mouse then
  love.mouse = { getPosition = function() return -100, -100 end, isDown = function() return false end, setVisible = function() end }
end
if love.keyboard then
  stub(love.keyboard, "setKeyRepeat", function() end)
  stub(love.keyboard, "isDown", function() return false end)
end
if not love.window then love.window = {} end
stub(love.window, "setIcon", function() end)
stub(love.window, "getFullscreen", function() return true end)
stub(love.window, "setFullscreen", function() end)

-- Shaders only where they can be compiled from source.
function M.shaders() return not M.console end

-- Load an image, preferring mipmaps where the platform supports them.
function M.image(path, mipmaps)
  local ok, img = pcall(lg.newImage, path, mipmaps and { mipmaps = true } or nil)
  if not ok then img = lg.newImage(path) end
  if mipmaps then pcall(function() img:setMipmapFilter("linear") end) end
  return img
end

return M
