#!/usr/bin/env bash
set -euo pipefail

ROOTFS="${1:?usage: install-overlay.sh <rootfs-dir>}"

mkdir -p \
  "$ROOTFS/opt/google/cros-containers" \
  "$ROOTFS/etc/systemd/system" \
  "$ROOTFS/etc/systemd/system/basic.target.wants" \
  "$ROOTFS/etc/systemd/system/local-fs.target.wants" \
  "$ROOTFS/usr/sbin" \
  "$ROOTFS/usr/local/lib/baguette" \
  "$ROOTFS/etc"

cat > "$ROOTFS/etc/systemd/system/opt-google-cros-containers.mount" <<'EOF'
[Unit]
Description=ChromeOS guest tools mount
DefaultDependencies=no
Before=local-fs.target umount.target
Conflicts=umount.target

[Mount]
What=LABEL=cros-vm-tools
Where=/opt/google/cros-containers
Type=auto
Options=ro
TimeoutSec=10

[Install]
WantedBy=local-fs.target
EOF

cat > "$ROOTFS/etc/systemd/system/vshd.service" <<'EOF'
[Unit]
Description=ChromeOS vshd
Requires=opt-google-cros-containers.mount
After=opt-google-cros-containers.mount
ConditionPathExists=/opt/google/cros-containers/bin/vshd

[Service]
Type=simple
ExecStart=/opt/google/cros-containers/bin/vshd
Restart=on-failure

[Install]
WantedBy=basic.target
EOF

cat > "$ROOTFS/etc/systemd/system/maitred.service" <<'EOF'
[Unit]
Description=ChromeOS maitred
Requires=opt-google-cros-containers.mount
After=opt-google-cros-containers.mount
ConditionPathExists=/opt/google/cros-containers/bin/maitred

[Service]
Type=simple
Environment=PATH=/opt/google/cros-containers/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/opt/google/cros-containers/bin/maitred
Restart=on-failure

[Install]
WantedBy=basic.target
EOF

cat > "$ROOTFS/etc/systemd/system/port-listener.service" <<'EOF'
[Unit]
Description=ChromeOS port listener
Requires=opt-google-cros-containers.mount
After=opt-google-cros-containers.mount
ConditionPathExists=/opt/google/cros-containers/bin/port_listener

[Service]
Type=simple
ExecStart=/opt/google/cros-containers/bin/port_listener
Restart=on-failure

[Install]
WantedBy=basic.target
EOF

ln -sf ../opt-google-cros-containers.mount "$ROOTFS/etc/systemd/system/local-fs.target.wants/opt-google-cros-containers.mount"
ln -sf ../vshd.service "$ROOTFS/etc/systemd/system/basic.target.wants/vshd.service"
ln -sf ../maitred.service "$ROOTFS/etc/systemd/system/basic.target.wants/maitred.service"
ln -sf ../port-listener.service "$ROOTFS/etc/systemd/system/basic.target.wants/port-listener.service"
ln -sf ../bin/usermod "$ROOTFS/usr/sbin/usermod"

cat > "$ROOTFS/etc/hosts" <<'EOF'
127.0.0.1 localhost
::1 localhost
EOF

cat > "$ROOTFS/etc/hostname" <<'EOF'
baguette-arch
EOF

cat > "$ROOTFS/etc/resolv.conf" <<'EOF'
# overwritten dynamically when networking comes up
nameserver 1.1.1.1
EOF

if command -v arch-chroot >/dev/null 2>&1; then
  arch-chroot "$ROOTFS" groupadd -f kvm || true
  arch-chroot "$ROOTFS" groupadd -f netdev || true
  arch-chroot "$ROOTFS" groupadd -f sudo || true
  arch-chroot "$ROOTFS" groupadd -f tss || true
else
  echo 'kvm:x:992:' >> "$ROOTFS/etc/group"
  echo 'netdev:x:991:' >> "$ROOTFS/etc/group"
  echo 'sudo:x:990:' >> "$ROOTFS/etc/group"
  echo 'tss:x:989:' >> "$ROOTFS/etc/group"
fi
