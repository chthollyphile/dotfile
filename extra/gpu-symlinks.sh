#!/bin/bash
# https://github.com/basecamp/omarchy/issues/1776

declare -A GPU_SYMLINKS=(
    ["Intel"]="intel-igpu"
    ["AMD"]="amd-igpu"
    ["NVIDIA"]="nvidia-dgpu"
)

UDEV_DIR="/etc/udev/rules.d"
GPU_LIST=$(lspci -d ::03xx)

if [ -z "$GPU_LIST" ]; then
    echo "No GPUs detected!"
    exit 1
fi

for VENDOR in "${!GPU_SYMLINKS[@]}"; do
    PCI_ID=$(echo "$GPU_LIST" | grep "$VENDOR" | head -n1 | cut -f1 -d' ')
    [ -z "$PCI_ID" ] && continue

    SYMLINK_NAME="${GPU_SYMLINKS[$VENDOR]}"
    RULE_PATH="$UDEV_DIR/${SYMLINK_NAME}-dev-path.rules"

    echo "Creating udev rule for $VENDOR GPU at $PCI_ID → /dev/dri/$SYMLINK_NAME"

    UDEV_RULE=$(cat <<EOF
KERNEL=="card*", \\
KERNELS=="0000:$PCI_ID", \\
SUBSYSTEM=="drm", \\
SUBSYSTEMS=="pci", \\
SYMLINK+="dri/$SYMLINK_NAME"
EOF
    )

    echo "$UDEV_RULE" | sudo tee "$RULE_PATH" > /dev/null
done

echo "Reloading udev rules..."
sudo udevadm control --reload
sudo udevadm trigger
