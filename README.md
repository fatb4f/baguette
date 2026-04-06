# baguette

First-pass Arch Baguette image builder for ChromeOS.

## Current output

The GitHub Actions workflow builds:

- `out/arch-rootfs.tar`
- `out/arch-rootfs.tar.zst`
- `out/arch-baguette.img`
- `out/arch-baguette.img.zst`

## Host setup

The workflow uses `scripts/setup-host.sh` to prepare the Ubuntu 24.04 host with:

- `docker.io`
- `btrfs-progs`
- `qemu-utils`
- `util-linux`
- `zstd`
- `rsync`
- `curl`
- `ca-certificates`
- `git`

## Current shape

This is an initial builder that:

- bootstraps a minimal Arch rootfs inside Docker
- adds ChromeOS Baguette integration units for `vshd`, `maitred`, and `port_listener`
- creates a raw Btrfs image
- creates `rootfs_subvol`
- sets `rootfs_subvol` as the default subvolume
- compresses the resulting artifacts with `zstd`

## Expected next iteration

Once the first artifact is confirmed to build cleanly in Actions, the next step is to test the image on ChromeOS with the Baguette import flow and then tighten anything the guest contract still requires.
