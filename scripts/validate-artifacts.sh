#!/usr/bin/env bash
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
OUTDIR="$ROOT/out"
ROOTFS_TAR="$OUTDIR/arch-rootfs.tar"
ROOTFS_TAR_ZST="$OUTDIR/arch-rootfs.tar.zst"
IMG="$OUTDIR/arch-baguette.img"
IMG_ZST="$OUTDIR/arch-baguette.img.zst"
MOUNT_UNIT='opt-google-cros\x2dcontainers.mount'
TAR_MOUNT_UNIT="${MOUNT_UNIT//\\/\\\\}"

ROOTFS_LIST="$(mktemp)"
trap 'rm -f "$ROOTFS_LIST"' EXIT
VERIFY_DIR="$(mktemp -d)"
trap 'rm -rf "$VERIFY_DIR"' EXIT

for path in "$ROOTFS_TAR" "$ROOTFS_TAR_ZST" "$IMG" "$IMG_ZST"; do
  test -f "$path"
done

zstd -t "$ROOTFS_TAR_ZST"
zstd -t "$IMG_ZST"
tar -tf "$ROOTFS_TAR" > "$ROOTFS_LIST"

for path in \
  "etc/hostname" \
  "etc/systemd/system/$TAR_MOUNT_UNIT" \
  "etc/systemd/system/vshd.service" \
  "etc/systemd/system/maitred.service" \
  "usr/sbin/usermod" \
  "usr/bin/usermod"
do
  if ! grep -Fxq "./$path" "$ROOTFS_LIST" && ! grep -Fxq "$path" "$ROOTFS_LIST"; then
    echo "missing rootfs entry: $path" >&2
    exit 1
  fi
done

tar -xf "$ROOTFS_TAR" -C "$VERIFY_DIR"
systemd-analyze verify \
  "$VERIFY_DIR/etc/systemd/system/$MOUNT_UNIT" \
  "$VERIFY_DIR/etc/systemd/system/vshd.service" \
  "$VERIFY_DIR/etc/systemd/system/maitred.service" \
  "$VERIFY_DIR/etc/systemd/system/port-listener.service"

echo "Artifact validation passed"
