function love.conf(t)
  t.identity = "draft-four-hands"
  t.version = "11.4"
  t.window.title = "Draft - Four Hands. One Arena"
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.minwidth = 640
  t.window.minheight = 360
  t.window.vsync = 1
  t.window.highdpi = true
  t.modules.joystick = true -- controllers (and the Switch Joy-Cons)
  t.modules.physics = false
end
