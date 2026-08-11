-- Personal input settings migrated from the legacy input.conf.

hl.config({
  input = {
    kb_layout = "us",
    kb_options = "compose:ralt",
    repeat_rate = 40,
    repeat_delay = 600,
    numlock_by_default = true,

    touchpad = {
      natural_scroll = true,
      scroll_factor = 0.1,
    },
  },
})

-- Scroll nicely in terminal windows.
o.window("(Alacritty|kitty)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Three-finger workspace and scrolling-layout gestures.
hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
hl.gesture({ fingers = 3, direction = "horizontal", scale = 1.5, action = "scroll_move" })
hl.config({
  gestures = {
    scrolling = {
      move_snap_to_grid = false,
    },
  },
})

-- Preserve the old workspace animation.
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default", style = "slidevert" })
