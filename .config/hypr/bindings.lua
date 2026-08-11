-- Personal bindings migrated from the legacy bindings.conf.
-- Omarchy's defaults are loaded first; replace() removes a conflicting
-- default before restoring the user's previous binding.

local function replace(keys, description, dispatcher, options)
  hl.unbind(keys)
  o.bind(keys, description, dispatcher, options)
end

-- Application bindings.
replace("SUPER + ALT + RETURN", "Tmux", 'uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" tmux new')
replace("SUPER + RETURN", "Terminal", 'uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)"')
replace("SUPER + SHIFT + RETURN", "Browser", "omarchy-launch-browser")
replace("SUPER + SHIFT + F", "File manager", "uwsm-app -- nautilus --new-window")
replace("SUPER + SHIFT + ALT + F", "File manager (cwd)", 'uwsm-app -- nautilus --new-window "$(omarchy-cmd-terminal-cwd)"')
replace("SUPER + SHIFT + B", "Browser", "omarchy-launch-browser")
replace("SUPER + SHIFT + ALT + B", "Browser (private)", "omarchy-launch-browser --private")
replace("SUPER + SHIFT + M", "Music", "omarchy-launch-or-focus netease-cloud-music-gtk4")
replace("SUPER + SHIFT + N", "Editor", "omarchy-launch-editor")
replace("SUPER + SHIFT + T", "Activity", "omarchy-launch-tui btop")
replace("SUPER + SHIFT + D", "Docker", "omarchy-launch-tui lazydocker")
replace("SUPER + SHIFT + O", "Obsidian", 'omarchy-launch-or-focus "^obsidian$" "uwsm-app -- obsidian"')
replace("SUPER + SHIFT + G", "Gemini", 'omarchy-launch-or-focus-webapp "Gemini" "https://gemini.google.com/app"')
replace("SUPER + SHIFT + P", "Onedrive", 'omarchy-launch-or-focus-webapp "Onedrive" "https://onedrive.live.com/?view=8"')

-- Personal utility shortcuts.
hl.unbind("SUPER + CTRL + V")
replace("SUPER + ALT + V", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")

-- Keep Omarchy's native background switcher on SUPER+CTRL+SPACE.

-- The old launcher shortcut leaves SUPER+SPACE available to Fcitx5.
hl.unbind("SUPER + SPACE")
replace("ALT + SPACE", "Launch apps", "omarchy-menu toggle apps")

-- Use the root Omarchy menu on SUPER+ALT+SPACE instead of the default Apps menu.
replace("SUPER + ALT + SPACE", "Omarchy menu", "omarchy-menu toggle")

-- The old configuration intentionally disabled the default monitor-scaling
-- shortcut on SUPER+SLASH.
hl.unbind("SUPER + SLASH")

-- Restore the old mouse and scrolling-layout behavior.
hl.unbind("SUPER + mouse:273")
replace("SUPER + ALT + mouse:272", "Resize window", hl.dsp.window.resize(), { mouse = true })
replace("SUPER + ALT + T", "Fit to screen", hl.dsp.layout("fit active"))

-- ScrollOverview (SUPER+Q; SUPER+G remains window grouping).
hl.unbind("SUPER + ALT + O")
hl.bind("SUPER + Q", function()
    hl.plugin.scrolloverview.overview("toggle all")
end)
