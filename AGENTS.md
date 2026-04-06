# AGENTS.md

## Goal

This repository builds a first-pass **Arch Baguette image** for ChromeOS containerless Crostini/Baguette.

The target artifact is a **raw Btrfs disk image** that:

- contains an Arch root filesystem
- uses `rootfs_subvol` as the default Btrfs subvolume
- includes the minimum ChromeOS guest integration needed for Baguette
- is compressed and uploaded as a GitHub Actions artifact

## Priorities

Work in this order:

1. Make the GitHub Actions workflow complete successfully.
2. Make the produced artifact structurally correct.
3. Minimize changes and preserve the current repo layout unless a change is necessary.
4. Prefer small, reviewable commits and simple shell scripts.
5. Defer GUI integration until the base image path is stable.

## Current artifact contract

The intended outputs are:

- `out/arch-rootfs.tar`
- `out/arch-rootfs.tar.zst`
- `out/arch-baguette.img`
- `out/arch-baguette.img.zst`

The image should be:

- raw disk image
- Btrfs filesystem
- `rootfs_subvol` created
- `rootfs_subvol` set as the default subvolume

## ChromeOS/Baguette assumptions

Inside the guest image, preserve or improve the minimum integration path:

- mount `LABEL=cros-vm-tools` at `/opt/google/cros-containers`
- include/start `vshd`
- include/start `maitred`
- optionally include/start `port_listener` if safe and clearly available
- provide `/usr/sbin/usermod`
- preserve groups expected by the environment such as `kvm`, `netdev`, `sudo`, and `tss`

Do not assume full desktop integration yet. `garcon`/`sommelier` are out of scope for the first working artifact unless they become necessary for boot or shell access.

## Repository guidance

### Workflow

The main workflow is under `.github/workflows/`.

When editing workflows:

- prefer `ubuntu-24.04`
- keep dependencies explicit
- keep artifact names stable unless there is a strong reason to rename them
- avoid adding unnecessary matrix complexity until the single-runner path is stable

### Scripts

Scripts live under `scripts/`.

When editing scripts:

- use `bash`
- use `set -euo pipefail`
- keep scripts composable and narrowly scoped
- prefer deterministic behavior over cleverness
- avoid hidden network dependencies beyond the explicit Arch bootstrap path

## What to optimize first

If the build is failing, focus on these likely problem areas first:

1. Arch bootstrap in Docker on GitHub Actions
2. use of `pacstrap` and related packages
3. loop device and mount behavior when creating the raw image
4. Btrfs subvolume creation and default-subvolume selection
5. artifact generation and upload paths

## What not to do yet

- Do not redesign the repo into Nix or another build system.
- Do not add GUI packages just to make the image larger.
- Do not add speculative complexity unless it fixes a concrete failure.
- Do not replace the raw-image + Btrfs + `rootfs_subvol` model unless clearly required.

## Expected testing mindset

Assume the real acceptance path is:

1. GitHub Actions builds the artifact successfully.
2. The image is downloaded to ChromeOS.
3. The image is imported through the Baguette/`vmc create --vm-type BAGUETTE --source ...` flow.
4. The VM boots far enough for shell-level validation.

Optimize for reaching that milestone first.

## Documentation expectations

If behavior changes, update `README.md` with:

- exact artifact names
- exact workflow behavior
- exact ChromeOS import/test steps
- any known limitations or open risks
