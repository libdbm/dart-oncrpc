#!/bin/bash
# Unmount NFS export on macOS
#
# Usage:
#   ./unmount_macos.sh [mount_point]
#
# Examples:
#   ./unmount_macos.sh              # Use default mount point
#   ./unmount_macos.sh ~/my_nfs     # Custom mount point

set -e

MOUNT_POINT=${1:-$HOME/nfs_mount}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NFS Unmount Helper for macOS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Mount Point: $MOUNT_POINT"
echo ""

# Check if mount point exists and is mounted
if [ ! -d "$MOUNT_POINT" ]; then
  echo "✗ Mount point does not exist: $MOUNT_POINT"
  exit 1
fi

# Check if actually mounted
if ! mount | grep -q "$MOUNT_POINT"; then
  echo "ℹ Mount point is not currently mounted"
  echo ""
  echo "Active NFS mounts:"
  mount | grep "type nfs" || echo "  (none found)"
  exit 0
fi

echo "Unmounting..."
echo "(You may be prompted for your password)"
echo ""

# Unmount
sudo umount "$MOUNT_POINT"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ Successfully unmounted!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Optionally remove mount point directory if empty
if [ -d "$MOUNT_POINT" ] && [ -z "$(ls -A "$MOUNT_POINT")" ]; then
  read -p "Remove empty mount point directory? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rmdir "$MOUNT_POINT"
    echo "✓ Removed: $MOUNT_POINT"
  fi
fi

echo ""
