# Azure Reality

![preview](/img/preview.png)

Dotfile for my Omarchy Linux setup.

tested in Omarchy 3.2

## Warning

> Do not copy [envs.conf](/.config/hypr/envs.conf) and [env-hyprland](/.config/uwsm/env-hyprland) into your setup unless you fully understand the changes it contains.

The [envs.conf](/.config/hypr/envs.conf) and [env-hyprland](/.config/uwsm/env-hyprland) files include fixes for some GPU-related issues. These fixes are tailored specifically for my current machine (i7-12800H + 3070 Ti laptop). However, you can reference them to help adjust your own setup.

## External dependencies

- cava
- fish
- waylyrics
- toilet
- lolcat
- mpvpaper
- awww

## awww

I use `awww` instead of the default `swaybg` for background switching.

To set up the awww daemon, please refer to the instructions in the [awww repository](https://codeberg.org/LGFae/awww) and follow its documentation.  

After setup, copy `extra/omarchy-theme-bg-next-aw` to `/home/your-username/.local/share/omarchy/bin` for it to work.

> **Note:** Replace `your-username` with your actual username in the path above to avoid errors.

