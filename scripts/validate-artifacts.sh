#!/usr/bin/env bash
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
OUTDIR="$ROOT/out"
ROOTFS_TAR="$OUTDIR/arch-rootfs.tar"
ROOTFS_TAR_ZST="$OUTDIR/arch-rootfs.tar.zst"
IMG="$OUTDIR/arch-baguette.img"
IMG_ZST="$OUTDIR/arch-baguette.img.zst"

for path in "$ROOTFS_TAR" "$ROOTFS_TAR_ZST" "$IMG" "$IMG_ZST"; do
  test -f "$path"
done

zstd -t "$ROOTFS_TAR_ZST"
zstd -t "$IMG_ZST"

for path in \
  "etc/fstab" \
  "etc/hostname" \
  "etc/systemd/system/opt-google-cros-containers.mount" \
  "etc/systemd/system/vshd.service" \
  "etc/systemd/system/maitred.service" \
  "etc/systemd/system/port-listener.service" \
  "usr/sbin/usermod"
do
  tar -tf "$ROOTFS_TAR" | grep -Fxq "./$path" || tar -tf "$ROOTFS_TAR" | grep -Fxq "$path"
done

echo "Artifact validation passed"
