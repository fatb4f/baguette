#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  docker.io \
  btrfs-progs \
  qemu-utils \
  util-linux \
  zstd \
  rsync \
  curl \
  ca-certificates \
  git

docker --version
qemu-img --version
mkfs.btrfs --version
losetup --version
zstd --version
git --version
