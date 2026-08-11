-- Personal appearance, layout, and window rules migrated from the legacy
-- looknfeel.conf and hyprland.conf.

hl.config({
  general = {
    layout = "scrolling",
  },

  scrolling = {
    focus_fit_method = 1,
    follow_min_visible = 0.85,
    column_width = 0.8,
  },

  decoration = {
    rounding = 4,
    active_opacity = 1,
    inactive_opacity = 0.95,

    blur = {
      enabled = true,
      size = 2,
      passes = 3,
      new_optimizations = true,
    },
  },
})

-- Restore the opacity transition when focus moves between windows.
-- Keep the current Omarchy fade curve and timing.
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 3.03, bezier = "quick" })

-- Terminal and cava opacity rules.
o.window("Alacritty|com.mitchellh.ghostty", {
  opacity = "0.85 override 0.7 override 0.95 override",
})
o.window({
  class = "Alacritty|com.mitchellh.ghostty",
  title = "cava",
}, {
  opacity = "0.6 override 0.45 override 0.65 override",
})

-- Waylyrics overlay.
o.window("^(io.github.waylyrics.Waylyrics)$", {
  float = true,
  size = { 1440, 40 },
  move = { 100, 840 },
  no_blur = true,
  border_size = 0,
  pin = true,
  no_shadow = true,
})

-- Folia remote window.
o.window({
  class = "^(folia-major)$",
  title = "^(Folia Remote)$",
}, {
  float = true,
  size = { 520, 315 },
  center = true,
  pin = true,
  no_blur = true,
  border_size = 0,
  no_shadow = true,
})
