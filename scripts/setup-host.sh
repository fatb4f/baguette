COMMON_PACKAGES=(
  btrfs-progs
  qemu-utils
  util-linux
  zstd
  rsync
  curl
  ca-certificates
  git
)

sudo apt-get update
sudo apt-get install -y --no-install-recommends "${COMMON_PACKAGES[@]}"

if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get install -y --no-install-recommends docker.io
fi
