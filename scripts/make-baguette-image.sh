#!/usr/bin/env bash
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"

exec python3 "$ROOT/scripts/baguette.py" \
  --image-size 10G \
  "$ROOT/out/arch-rootfs.tar" \
  "$ROOT/out/arch-baguette.img"
