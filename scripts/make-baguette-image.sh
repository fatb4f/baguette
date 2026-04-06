#!/usr/bin/env bash
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
OUTDIR="$ROOT/out"
WORKDIR="$ROOT/work/image"
IMG="$OUTDIR/arch-baguette.img"
MNT="$WORKDIR/mnt"
LOOP=""

cleanup() {
  set +e
  if mountpoint -q "$MNT/rootfs_subvol"; then
    umount "$MNT/rootfs_subvol"
  fi
  if mountpoint -q "$MNT"; then
    umount "$MNT"
  fi
  if [[ -n "$LOOP" ]]; then
    losetup -d "$LOOP"
  fi
}
trap cleanup EXIT

mkdir -p "$OUTDIR" "$WORKDIR" "$MNT"
rm -f "$IMG" "$IMG.zst"

qemu-img create -f raw "$IMG" 10G
LOOP=$(losetup --show -fP "$IMG")
mkfs.btrfs -f "$LOOP"
mount "$LOOP" "$MNT"
btrfs subvolume create "$MNT/rootfs_subvol"
tar -C "$MNT/rootfs_subvol" -xpf "$OUTDIR/arch-rootfs.tar" --xattrs --acls
sync
ROOT_SUBVOL_ID=$(btrfs subvolume list "$MNT" | awk '$NF == "rootfs_subvol" { print $2; exit }')
if [[ -z "$ROOT_SUBVOL_ID" ]]; then
  echo "Failed to resolve rootfs_subvol ID" >&2
  exit 1
fi
btrfs subvolume set-default "$ROOT_SUBVOL_ID" "$MNT"
DEFAULT_SUBVOL_ID="$(btrfs subvolume get-default "$MNT" | awk '{print $2}')"
if [[ "$DEFAULT_SUBVOL_ID" != "$ROOT_SUBVOL_ID" ]]; then
  echo "Failed to set rootfs_subvol as default subvolume" >&2
  exit 1
fi

mkdir -p "$MNT/rootfs_subvol/etc"
cat > "$MNT/rootfs_subvol/etc/fstab" <<'EOF'
/dev/vdb / btrfs defaults 0 0
LABEL=cros-vm-tools /opt/google/cros-containers auto ro,nofail 0 0
EOF

umount "$MNT"
losetup -d "$LOOP"
LOOP=""
zstd -19 -T0 -f "$IMG" -o "$IMG.zst"

echo "Image artifacts written to $OUTDIR"
