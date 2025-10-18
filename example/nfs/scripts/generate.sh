#!/bin/bash
# Generate Dart code from NFS and MOUNT protocol definitions

set -e

cd "$(dirname "$0")/.."

echo "Generating NFS types from protocol definitions..."

# Generate Dart code from .x files
dart ../../bin/rpcgen.dart \
  -t \
  --no-dart-conventions \
  -o lib/nfs_types.dart \
  protocol/nfs.x protocol/mount.x

# The generator creates lib/nfs.dart, so rename it to nfs_types.dart
if [ -f lib/nfs.dart ]; then
  mv lib/nfs.dart lib/nfs_types.dart
fi

echo "✓ Generated lib/nfs_types.dart"
echo ""
echo "Code generation complete!"
