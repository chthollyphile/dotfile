-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Input method environment. Keep this in the active Lua entrypoint; the
-- legacy ~/.config/hypr/envs.conf is no longer loaded after the Quattro
-- migration.
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("INPUT_METHOD", "fcitx")
hl.env("SDL_IM_MODULE", "fcitx")

-- Other personal environment overrides from the legacy envs.conf.
hl.env("VK_ICD_FILENAMES", "/usr/share/vulkan/icd.d/intel_icd.x86_64.json:/usr/share/vulkan/icd.d/nvidia_icd.json")
hl.env("LIBVA_DRIVER_NAME", "iHD")
hl.env("OMARCHY_SCREENSHOT_DIR", (os.getenv("HOME") or "") .. "/Pictures/screenshots")
hl.env("AQ_DRM_DEVICES", "/dev/dri/intel-igpu:/dev/dri/nvidia-dgpu")

-- ScrollOverview: a niri-style scrolling workspace overview.
hl.config({
	plugin = {
		scrolloverview = {
			gesture_distance = 300,
			scale = 0.5,
			workspace_gap = 100,
			layout = "vertical",
			wallpaper = 2,
			blur = true,
			input = {
				-- The global touchpad scroll_factor is 0.1; compensate here
				-- so overview scrolling has a usable 1.5x effective factor.
				touchpad_scroll_factor = 10,
			},
			shadow = {
				enabled = true,
				range = 50,
			},
		},
	},
})

-- Four-finger vertical swipe opens/closes ScrollOverview.
-- Three-finger vertical swipe remains workspace switching in input.lua.
hl.plugin.scrolloverview.gesture({
	fingers = 4,
	direction = "vertical",
	scale = 1.5,
})

-- ALT+Tab: visual window switcher backed by ScrollOverview.
local altTab = require("scripts.alttab")
-- Remove Omarchy's default ALT+TAB actions (focus next + bring to top).
hl.unbind("ALT + Tab")
hl.bind("ALT + Tab", altTab.next, { submap_universal = true })
hl.bind("ALT + Alt_L", altTab.close, { release = true, transparent = true })
hl.bind("ALT + Alt_R", altTab.close, { release = true, transparent = true })
