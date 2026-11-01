function love.conf(t)
  t.identity = "draft-four-hands"
  t.version = "11.4"
  t.window.title = "Draft - Four Hands. One Arena"
  t.window.width = 1600
  t.window.height = 900
  t.window.resizable = true
  t.window.minwidth = 800
  t.window.minheight = 450
  t.window.vsync = 1
  t.window.highdpi = true
  t.modules.joystick = false
  t.modules.physics = false
end
