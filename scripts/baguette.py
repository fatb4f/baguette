#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


def run(cmd: list[str], *, capture_output: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        check=True,
        text=True,
        capture_output=capture_output,
    )


def mountpoint_is_active(path: Path) -> bool:
    return subprocess.run(
        ["mountpoint", "-q", str(path)],
        check=False,
    ).returncode == 0


def losetup_image(image_path: Path) -> str:
    return run(["losetup", "--find", "--show", str(image_path)], capture_output=True).stdout.strip()


def parse_subvolume_id(output: str) -> int:
    match = re.search(r"Subvolume ID:\s*(\d+)", output)
    if not match:
        raise RuntimeError("could not determine subvolume id")
    return int(match.group(1))


def parse_default_subvolume_id(output: str) -> int:
    match = re.search(r"Default subvolume ID:\s*(\d+)", output)
    if not match:
        match = re.search(r"ID\s+(\d+)", output)
    if not match:
        raise RuntimeError("could not determine default subvolume id")
    return int(match.group(1))


def build_image(rootfs_tar: Path, image_path: Path, image_size: str, compression_level: int) -> Path:
    image_path.parent.mkdir(parents=True, exist_ok=True)
    compressed_path = Path(f"{image_path}.zst")
    workdir = image_path.parent / ".baguette-work"
    mount_dir = workdir / "mnt"
    root_subvol = mount_dir / "rootfs_subvol"
    loop_device = ""

    if image_path.exists():
        image_path.unlink()
    if compressed_path.exists():
        compressed_path.unlink()

    workdir.mkdir(parents=True, exist_ok=True)
    mount_dir.mkdir(parents=True, exist_ok=True)

    try:
        run(["qemu-img", "create", "-f", "raw", str(image_path), image_size])
        loop_device = losetup_image(image_path)
        run(["mkfs.btrfs", "-f", loop_device])
        run(["mount", loop_device, str(mount_dir)])
        run(["btrfs", "subvolume", "create", str(root_subvol)])
        run([
            "tar",
            "--xattrs",
            "--acls",
            "-C",
            str(root_subvol),
            "-xpf",
            str(rootfs_tar),
        ])
        (root_subvol / "etc").mkdir(parents=True, exist_ok=True)
        (root_subvol / "opt/google/cros-containers").mkdir(parents=True, exist_ok=True)
        (root_subvol / "etc/fstab").write_text(
            "/dev/vdb / btrfs defaults 0 0\n"
            "LABEL=cros-vm-tools /opt/google/cros-containers auto ro,nofail 0 0\n",
            encoding="utf-8",
        )
        run(["sync"])

        subvol_info = run(
            ["btrfs", "subvolume", "show", str(root_subvol)],
            capture_output=True,
        ).stdout
        subvol_id = parse_subvolume_id(subvol_info)
        run(["btrfs", "subvolume", "set-default", str(subvol_id), str(mount_dir)])

        default_info = run(
            ["btrfs", "subvolume", "get-default", str(mount_dir)],
            capture_output=True,
        ).stdout
        default_id = parse_default_subvolume_id(default_info)
        if default_id != subvol_id:
            raise RuntimeError("failed to set rootfs_subvol as the default subvolume")

        run(["sync"])
    finally:
        if mountpoint_is_active(mount_dir):
            subprocess.run(["umount", str(mount_dir)], check=False)
        if loop_device:
            subprocess.run(["losetup", "-d", loop_device], check=False)

    run(
        [
            "zstd",
            f"-{compression_level}",
            "-T0",
            str(image_path),
            "-o",
            str(compressed_path),
        ]
    )
    return compressed_path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a raw Btrfs Baguette image and compress it with zstd."
    )
    parser.add_argument("rootfs_tar", type=Path, help="Path to the rootfs tarball")
    parser.add_argument("image_path", type=Path, help="Path to the raw image to create")
    parser.add_argument(
        "--image-size",
        default="10G",
        help="Raw image size passed to qemu-img (default: 10G)",
    )
    parser.add_argument(
        "--compression-level",
        type=int,
        default=19,
        help="zstd compression level (default: 19)",
    )
    args = parser.parse_args()

    if not args.rootfs_tar.is_file():
        print(f"missing rootfs tarball: {args.rootfs_tar}", file=sys.stderr)
        return 1

    compressed_path = build_image(
        args.rootfs_tar,
        args.image_path,
        args.image_size,
        args.compression_level,
    )
    print(f"Image artifacts written to {args.image_path} and {compressed_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
