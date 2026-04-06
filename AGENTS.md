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
3. Make the uploaded artifact match the documented contract exactly.
4. Minimize changes and preserve the current repo layout unless a change is necessary.
5. Prefer small, reviewable commits and simple shell scripts.
6. Defer GUI integration until the base image path is stable.

## Current workflow contract

Primary workflow: `.github/workflows/build-arch-baguette.yml`

On push to `main`, pull requests, and manual dispatch, the workflow should:

1. Run `scripts/setup-host.sh` on `ubuntu-24.04`.
2. Build an Arch rootfs tarball with `scripts/build-rootfs-tarball.sh`.
3. Build a raw Btrfs image with `scripts/make-baguette-image.sh`.
4. Validate that all expected output files exist.
5. Upload a single artifact named `arch-baguette-image`.

Keep this sequence stable unless there is a concrete reason to change it.

## Current artifact contract

The uploaded artifact must contain exactly:

- `out/arch-rootfs.tar`
- `out/arch-rootfs.tar.zst`
- `out/arch-baguette.img`
- `out/arch-baguette.img.zst`

The GitHub Actions artifact is uploaded as:

- artifact name: `arch-baguette-image`
- artifact paths (explicit, no wildcard):
  - `out/arch-rootfs.tar`
  - `out/arch-rootfs.tar.zst`
  - `out/arch-baguette.img`
  - `out/arch-baguette.img.zst`

The image should be:

- a raw disk image
- formatted as Btrfs
- contain a `rootfs_subvol` subvolume
- have `rootfs_subvol` set as the default subvolume

The workflow should validate the presence of all four output files before artifact upload.

## ChromeOS/Baguette assumptions

Inside the guest image, preserve or improve the minimum integration path:

- mount `LABEL=cros-vm-tools` at `/opt/google/cros-containers`
- include/start `vshd`
- include/start `maitred`
- optionally include/start `port_listener` if safe and clearly available
- provide `/usr/sbin/usermod`
- preserve groups expected by the environment such as `kvm`, `netdev`, `sudo`, and `tss`

Do not assume full desktop integration yet. `garcon` and `sommelier` are out of scope for the first working artifact unless they become necessary for boot or shell access.

## Environment guidance

The build environment is an image based on **Ubuntu 24.04**.

Assume the only supported customization path is the repository setup script:

- `scripts/setup-host.sh`

When changing host dependencies:

- prefer editing `scripts/setup-host.sh` instead of scattering `apt-get` calls through workflows
- keep the package list as small and stable as possible
- only add packages that fix a concrete build or runtime issue
- treat the host as ephemeral and re-provisioned on each run

### Current host package contract

`scripts/setup-host.sh` currently installs:

- `docker.io`
- `btrfs-progs`
- `qemu-utils`
- `util-linux`
- `zstd`
- `rsync`
- `curl`
- `ca-certificates`
- `git`

Do not add heavier packages such as partitioning stacks, desktop stacks, or alternate build systems unless clearly required by a failing workflow or by the Baguette image contract.

## Repository guidance

### Workflows

The main workflow is under `.github/workflows/`.

Current primary workflow:

- `.github/workflows/build-arch-baguette.yml`
- triggers: `push` to `main`, `pull_request`, and `workflow_dispatch`
- runner: `ubuntu-24.04`
- required step order:
  1. setup host via `scripts/setup-host.sh`
  2. build rootfs via `scripts/build-rootfs-tarball.sh`
  3. build image via `scripts/make-baguette-image.sh`
  4. validate all four artifact files exist before upload
  5. upload `arch-baguette-image` artifact with explicit file list

When editing workflows:

- prefer `ubuntu-24.04`
- call `scripts/setup-host.sh` early in the workflow
- keep dependencies explicit
- keep artifact names stable unless there is a strong reason to rename them
- upload explicit artifact paths instead of broad globs when practical
- avoid unnecessary matrix complexity until the single-runner path is stable

### Scripts

Scripts live under `scripts/`.

When editing scripts:

- use `bash`
- use `set -euo pipefail`
- keep scripts composable and narrowly scoped
- prefer deterministic behavior over cleverness
- avoid hidden network dependencies beyond the explicit Arch bootstrap path

## Build-specific guidance

### `scripts/build-rootfs-tarball.sh`

Prefer a conservative Arch bootstrap flow.

Current expectations:

- initialize and populate pacman keys
- refresh `archlinux-keyring`
- install `arch-install-scripts` with `--needed`
- explicitly `docker pull archlinux:latest` before running the container
- create the rootfs with `pacstrap`

Avoid unnecessary full system upgrades in the bootstrap container unless a concrete issue requires one.

### `scripts/make-baguette-image.sh`

Current expectations:

- create `out/arch-baguette.img` as a raw image
- format it as Btrfs
- create `rootfs_subvol`
- extract `out/arch-rootfs.tar` into `rootfs_subvol` with xattrs and ACLs preserved
- set `rootfs_subvol` as the default subvolume
- verify that the default subvolume was actually set
- create `/etc/fstab` inside the extracted guest if needed
- compress the final image to `out/arch-baguette.img.zst`

Prefer explicit verification over silent assumptions.

## What to optimize first

If the build is failing, focus on these likely problem areas first:

1. host dependency setup through `scripts/setup-host.sh`
2. Arch bootstrap in Docker on GitHub Actions
3. `pacstrap` and related package setup
4. loop device and mount behavior when creating the raw image
5. Btrfs subvolume creation and default-subvolume selection
6. artifact validation and upload paths

## What not to do yet

- Do not redesign the repo into Nix or another build system.
- Do not add GUI packages just to make the image larger.
- Do not add speculative complexity unless it fixes a concrete failure.
- Do not replace the raw-image + Btrfs + `rootfs_subvol` model unless clearly required.

## Expected testing mindset

Assume the real acceptance path is:

1. GitHub Actions builds the artifact successfully.
2. The image is downloaded to ChromeOS.
3. The image is imported through the Baguette / `vmc create --vm-type BAGUETTE --source ...` flow.
4. The VM boots far enough for shell-level validation.

Optimize for reaching that milestone first.

Concrete ChromeOS flow to preserve in docs/tests:

1. `zstd -d arch-baguette.img.zst -o arch-baguette.img`
2. `vmc create --vm-type BAGUETTE --source /path/to/arch-baguette.img arch-baguette-arch`
3. `vmc start arch-baguette-arch`
4. `vsh --vm_name=arch-baguette-arch --owner_id=$(whoami)`

## Documentation expectations

If behavior changes, update `README.md` with:

- exact workflow behavior
- exact artifact names
- exact host setup requirements
- exact ChromeOS import/test steps
- any known limitations or open risks

## Known limitations / open risks

- Boot/runtime behavior may still vary by ChromeOS channel/build and Baguette feature maturity.
- `port_listener` should only be enabled when present at `/opt/google/cros-containers/bin/port_listener`.
- This repository currently targets first-pass shell-level bring-up, not GUI integration.
