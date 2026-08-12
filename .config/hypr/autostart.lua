-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Load plugins enabled through hyprpm after Hyprland starts.
hl.on("hyprland.start", function()
  hl.exec_cmd("hyprpm reload")
end)
