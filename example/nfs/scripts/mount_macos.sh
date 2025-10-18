#!/bin/bash
# Mount NFS export on macOS
#
# Usage:
#   ./mount_macos.sh [mount_point] [host] [export]
#
# Examples:
#   ./mount_macos.sh                    # Use defaults
#   ./mount_macos.sh ~/my_nfs           # Custom mount point
#   ./mount_macos.sh ~/my_nfs server    # Custom host
#   ./mount_macos.sh ~/my_nfs server /data  # Custom export

set -e

# Default values
MOUNT_POINT=${1:-$HOME/nfs_mount}
HOST=${2:-localhost}
EXPORT=${3:-/}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NFS Mount Helper for macOS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Configuration:"
echo "  Host:        $HOST"
echo "  Export:      $EXPORT"
echo "  Mount Point: $MOUNT_POINT"
echo ""

# Create mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
  echo "Creating mount point..."
  mkdir -p "$MOUNT_POINT"
  echo "✓ Created: $MOUNT_POINT"
else
  echo "✓ Mount point exists: $MOUNT_POINT"
fi

echo ""
echo "Mounting NFS export..."
echo "(You may be prompted for your password)"
echo ""

# Mount with appropriate options for macOS
# - resvport: Use reserved port (required for many NFS servers)
# - nolocks: Disable file locking (NFSv3 without lockd)
# - vers=3: Force NFS version 3
# - tcp: Use TCP transport
sudo mount -t nfs \
  -o resvport,nolocks,vers=3,tcp \
  "$HOST:$EXPORT" "$MOUNT_POINT"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ Successfully mounted!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Mount Information:"
mount | grep "$MOUNT_POINT" || echo "  (mount info not available)"
echo ""
echo "Access your files:"
echo "  cd $MOUNT_POINT"
echo "  ls $MOUNT_POINT"
echo ""
echo "To unmount:"
echo "  sudo umount $MOUNT_POINT"
echo "  or run: ./unmount_macos.sh"
echo ""
