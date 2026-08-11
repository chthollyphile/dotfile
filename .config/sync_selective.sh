#!/usr/bin/env bash

# Selectively mirror the current user configuration into this dotfile repo.
#
# The source is ~/.config and the destination is the .config directory that
# contains this script. The mirror is intentionally allow-listed: application
# caches and unrelated ~/.config entries must not enter the dotfile archive.
#
# Use --dry-run to review changes before writing them.

set -euo pipefail

SOURCE_DIR="${HOME:?}/.config"
DEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    printf 'Usage: %s [--dry-run]\n' "$(basename -- "${BASH_SOURCE[0]}")"
}

DRY_RUN_ARGS=()
case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN_ARGS=(--dry-run) ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

command -v rsync >/dev/null 2>&1 || {
    echo "Error: rsync is required." >&2
    exit 1
}

# Only configuration that belongs to the current setup is allow-listed here.
# In particular, Waybar is intentionally absent: the new Omarchy shell uses
# Quickshell instead.
ITEMS_TO_SYNC=(
    "chromium-flags.conf"
    "electron-flags.conf"
    "starship.toml"
    "fish"
    "hypr"
    "hyprlock-script"
    "omarchy"
    "pipewire"
    "uwsm"
    "waylyrics"
    "cava"
    "fcitx5"
    "rofi"
    "mpv"
    "btop"
    "fastfetch"
    "alacritty"
    "foot"
    "ghostty"
    "kitty"
)

# These patterns apply to every directory mirror. --delete-excluded keeps
# stale historical files out of the repository when the script is run after a
# migration. The user themes themselves are handled separately below.
RSYNC_OPTIONS=(
    --archive
    --delete
    --delete-excluded
    --human-readable
    --exclude='*.gif'
    --exclude='legacy/'
    --exclude='*legacy*'
    --exclude='archive/'
    --exclude='theme-backups*/'
    --exclude='boot-backups*/'
    --exclude='bg-disable/'
    --exclude='current/'
    --exclude='current.theme'
    --exclude='*.bak*'
    --exclude='*.old'
    --exclude='*.orig'
    --exclude='*.before-*'
    --exclude='*.swp'
    --exclude='*~'
    --exclude='.DS_Store'
)

# These roots belonged to the pre-Quickshell setup. Remove stale copies from
# the repository when this script is run; they are not copied from the source.
OBSOLETE_DEST_ITEMS=(
    "waybar"
    "elephant"
)

echo "Stage: Starting selective synchronization from $SOURCE_DIR"
echo "Target directory: $DEST_DIR"
if ((${#DRY_RUN_ARGS[@]})); then
    echo "Mode: dry run (no files will be changed)"
fi
echo "================================================================="

for item in "${OBSOLETE_DEST_ITEMS[@]}"; do
    DEST_PATH="$DEST_DIR/$item"
    if [[ -e "$DEST_PATH" || -L "$DEST_PATH" ]]; then
        if ((${#DRY_RUN_ARGS[@]})); then
            echo "-> Would remove obsolete '$DEST_PATH'"
        else
            echo "-> Removing obsolete '$DEST_PATH'"
            rm -rf -- "$DEST_PATH"
        fi
    fi
done

for item in "${ITEMS_TO_SYNC[@]}"; do
    SOURCE_PATH="$SOURCE_DIR/$item"
    DEST_PATH="$DEST_DIR/$item"

    if [[ ! -e "$SOURCE_PATH" && ! -L "$SOURCE_PATH" ]]; then
        echo "-> WARNING: Source '$SOURCE_PATH' does not exist. Skipping."
        continue
    fi

    echo "-> Syncing '$item'..."

    if [[ -d "$SOURCE_PATH" && ! -L "$SOURCE_PATH" ]]; then
        if [[ "$item" == "omarchy" ]]; then
            echo "   -> Omarchy: excluding generated state, backups, and legacy files"

            # Keep the source themes out of this pass so only the selected
            # user themes are mirrored in the dedicated pass below.
            rsync \
                "${RSYNC_OPTIONS[@]}" \
                "${DRY_RUN_ARGS[@]}" \
                --exclude='themes/' \
                "$SOURCE_PATH/" "$DEST_PATH/"

            if [[ -d "$SOURCE_PATH/themes" ]]; then
                if ((${#DRY_RUN_ARGS[@]} == 0)); then
                    mkdir -p "$DEST_PATH/themes"
                fi

                # Keep only the three maintained custom themes. The final
                # exclude also removes obsolete theme directories from the
                # destination when --delete-excluded is active.
                rsync \
                    "${RSYNC_OPTIONS[@]}" \
                    "${DRY_RUN_ARGS[@]}" \
                    --include='azure-dream/' \
                    --include='azure-dream/***' \
                    --include='azure-reality/' \
                    --include='azure-reality/***' \
                    --include='menhera-noise/' \
                    --include='menhera-noise/***' \
                    --exclude='*' \
                    "$SOURCE_PATH/themes/" "$DEST_PATH/themes/"
            else
                echo "   -> WARNING: source themes directory is missing"
            fi
        else
            rsync \
                "${RSYNC_OPTIONS[@]}" \
                "${DRY_RUN_ARGS[@]}" \
                "$SOURCE_PATH/" "$DEST_PATH/"
        fi
    else
        rsync \
            "${RSYNC_OPTIONS[@]}" \
            "${DRY_RUN_ARGS[@]}" \
            "$SOURCE_PATH" "$DEST_DIR/"
    fi
done

echo "================================================================="
echo "Synchronization complete."
