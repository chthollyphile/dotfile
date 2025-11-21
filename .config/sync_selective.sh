#!/bin/bash

# This script performs a selective one-way synchronization.
# It syncs only the files and directories specified in the ITEMS_TO_SYNC array
# from the source directory (~/.config) to the destination directory (where this script is located).
# The --delete flag ensures that files deleted from the source are also deleted from the destination,
# keeping the backup a clean mirror of the selected items.

set -e # Exit immediately if a command exits with a non-zero status.

SOURCE_DIR="$HOME/.config"
# Get the absolute path of the directory where the script is located.
DEST_DIR="$(cd "$(dirname "$0")" && pwd)"

# Array of files and directories to be synchronized, based on the existing backup structure.
ITEMS_TO_SYNC=(
    "autostart.conf"
    "chromium-flags.conf"
    "electron-flags.conf"
    "starship.toml"
    "fish"
    "hypr"
    "hyprlock-script"
    "omarchy"
    "pipewire"
    "uwsm"
    "waybar"
    "waylyrics"
    "cava"
)

echo "Stage: Starting selective synchronization from $SOURCE_DIR"
echo "Target directory: $DEST_DIR"
echo "================================================================="

for item in "${ITEMS_TO_SYNC[@]}"; do
    SOURCE_PATH="$SOURCE_DIR/$item"
    DEST_PATH="$DEST_DIR/$item"

    if [ ! -e "$SOURCE_PATH" ]; then
        echo "-> WARNING: Source '$SOURCE_PATH' does not exist. Skipping."
        continue
    fi

    echo "-> Syncing '$item'..."
    # -a: archive mode (recursive, preserves permissions, etc.)
    # -v: verbose
    # -h: human-readable
    # --delete: delete files in destination that are not in the source
    if [ -d "$SOURCE_PATH" ]; then
        # Special handling for omarchy: sync everything except themes, then
        # inside themes only sync azure-dream and azure-reality.
        if [ "$item" = "omarchy" ]; then
            echo "   -> Special-case: syncing 'omarchy' but only selected themes"
            # Sync omarchy root but exclude the themes directory so we can handle it separately.
            rsync -avh --delete --exclude 'themes/' "$SOURCE_PATH/" "$DEST_PATH/"

            # Handle themes: only include the two allowed themes and delete others in destination.
            if [ -d "$SOURCE_PATH/themes" ]; then
                mkdir -p "$DEST_PATH/themes"
                rsync -avh --delete \
                    --include='azure-dream/***' \
                    --include='azure-reality/***' \
                    --exclude='*' \
                    "$SOURCE_PATH/themes/" "$DEST_PATH/themes/"
            else
                # If source has no themes, ensure destination themes are removed to keep mirror.
                if [ -d "$DEST_PATH/themes" ]; then
                    echo "   -> Source themes directory missing; removing destination themes"
                    rm -rf "$DEST_PATH/themes"
                fi
            fi
        else
            # For directories, sync contents and add a trailing slash to source and destination.
            rsync -avh --delete "$SOURCE_PATH/" "$DEST_PATH/"
        fi
    else
        # For files, sync the file directly into the destination directory.
        rsync -avh "$SOURCE_PATH" "$DEST_DIR/"
    fi
done

echo "================================================================="
echo "Synchronization complete."
