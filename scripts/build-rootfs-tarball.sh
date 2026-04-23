#!/usr/bin/env bash
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
WORKDIR="$ROOT/work"
OUTDIR="$ROOT/out"
ROOTFS_DIR="$WORKDIR/rootfs"

mkdir -p "$WORKDIR" "$OUTDIR"
rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"

cat > "$WORKDIR/build-rootfs-in-docker.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm archlinux-keyring
pacman -S --noconfirm --needed arch-install-scripts

mkdir -p /work/rootfs
pacstrap -c -G -M /work/rootfs \
  base \
  bash \
  coreutils \
  filesystem \
  findutils \
  gawk \
  grep \
  iproute2 \
  less \
  nano \
  procps-ng \
  sed \
  shadow \
  sudo \
  systemd \
  tar \
  util-linux
EOF
chmod +x "$WORKDIR/build-rootfs-in-docker.sh"

sudo docker pull archlinux:latest

sudo docker run --rm \
  -v "$WORKDIR:/work" \
  archlinux:latest \
  /work/build-rootfs-in-docker.sh

./scripts/install-overlay.sh "$ROOTFS_DIR"

tar --numeric-owner --xattrs --acls -C "$ROOTFS_DIR" -cpf "$OUTDIR/arch-rootfs.tar" .
zstd -19 -T0 -f "$OUTDIR/arch-rootfs.tar" -o "$OUTDIR/arch-rootfs.tar.zst"

echo "Rootfs artifacts written to $OUTDIR"
