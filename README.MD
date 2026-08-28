# Omarchy Quattro Dotfiles

![preview](/img/preview-q.png)

Personal dotfiles for the current Omarchy Quattro setup.

Tested on Omarchy 4.0.0

The active configuration uses the Lua-based Hyprland layout and the native
Omarchy Quickshell shell. The three maintained themes are `azure-dream`,
`azure-reality`, and `menhera-noise`.

## Machine-specific settings

The monitor and input settings under [hypr](/.config/hypr/) are tailored to
the current laptop. Review them before applying this archive to different
hardware.


## External dependencies

- cava
- fish
- waylyrics
- toilet
- lolcat
- mpvpaper

Wallpaper switching is handled by Omarchy's native `omarchy theme bg`
commands.

## Synchronization

Review changes first, then mirror the selected current configuration into this
repository:

```bash
./.config/sync_selective.sh --dry-run
./.config/sync_selective.sh
```

The sync script excludes generated state, backups, archives, legacy files,
disabled wallpaper archives, and the old Waybar/Elephant configuration.
