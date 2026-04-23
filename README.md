# baguette

First-pass Arch Baguette image builder for ChromeOS.

## GitHub Actions workflow

Workflow: `.github/workflows/build-arch-baguette.yml`

On push to `main`, pull requests, and manual dispatch, the workflow:

1. Runs `scripts/setup-host.sh` on `ubuntu-24.04`.
2. Builds an Arch rootfs tarball with `scripts/build-rootfs-tarball.sh`.
3. Builds a raw Btrfs image with `scripts/baguette.py` via `scripts/make-baguette-image.sh`.
4. Validates artifact presence, compression integrity, and the expected guest integration files.
5. Uploads a single artifact named `arch-baguette-image`.

## Artifact contract

The uploaded artifact contains exactly:

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
- creates a raw Btrfs image with the Python `scripts/baguette.py` entrypoint
- creates `rootfs_subvol`
- sets `rootfs_subvol` as the default subvolume
- compresses the resulting artifacts with `zstd`

## ChromeOS Baguette import / test steps

On ChromeOS (Developer shell), after downloading `arch-baguette.img.zst` from the Actions artifact:

1. Decompress the image:
   - `zstd -d arch-baguette.img.zst -o arch-baguette.img`
2. Import/create the VM:
   - `vmc create --vm-type BAGUETTE --source /path/to/arch-baguette.img arch-baguette-arch`
3. Start and open a shell:
   - `vmc start arch-baguette-arch`
   - `vsh --vm_name=arch-baguette-arch --owner_id=$(whoami)`
4. Basic validation inside the guest:
   - Confirm `/` is Btrfs on the `rootfs_subvol` default subvolume.
   - Confirm `/opt/google/cros-containers` mount unit is present.
   - Confirm `vshd` and `maitred` services are available.

## Known limitations / open risks

- Boot/runtime behavior may still vary by ChromeOS channel/build and Baguette feature maturity.
- `port_listener` is enabled only when present at `/opt/google/cros-containers/bin/port_listener`.
- This repository currently targets first-pass shell-level bring-up, not GUI integration.
