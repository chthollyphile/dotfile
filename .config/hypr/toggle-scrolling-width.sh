#!/usr/bin/env bash
set -euo pipefail

current="$(hyprctl getoption scrolling:column_width -j | jq -r '.float')"

if awk -v value="$current" 'BEGIN { exit !(value >= 0.999) }'; then
  next="0.8"
  label="80%"
else
  next="1.0"
  label="100%"
fi

# Hyprland 0.55+ uses the Lua parser; `hyprctl keyword` only works with
# legacy hyprlang configs. Apply the Lua setting through the runtime evaluator.
hyprctl eval "hl.config({ scrolling = { column_width = $next } })"

if command -v notify-send >/dev/null 2>&1; then
  notify-send -u low -t 1200 "Scrolling layout" "New windows: $label" || true
fi
