#!/usr/bin/env bash
set -euo pipefail

ROOTFS="${1:?usage: install-overlay.sh <rootfs-dir>}"
MOUNT_UNIT='opt-google-cros\x2dcontainers.mount'
SYSTEMD_DIR="$ROOTFS/etc/systemd/system"
SYSTEMD_WANTS_DIR="$SYSTEMD_DIR/multi-user.target.wants"
SYSTEMD_LOCAL_FS_WANTS_DIR="$SYSTEMD_DIR/local-fs.target.wants"

mkdir -p \
  "$ROOTFS/opt/google/cros-containers" \
  "$SYSTEMD_DIR" \
  "$SYSTEMD_WANTS_DIR" \
  "$SYSTEMD_LOCAL_FS_WANTS_DIR" \
  "$ROOTFS/usr/sbin" \
  "$ROOTFS/usr/local/lib/baguette" \
  "$ROOTFS/etc"

cat > "$SYSTEMD_DIR/$MOUNT_UNIT" <<EOF
[Unit]
Description=ChromeOS cros-vm-tools mount
DefaultDependencies=no
Before=local-fs.target
Conflicts=umount.target

[Mount]
What=LABEL=cros-vm-tools
Where=/opt/google/cros-containers
Type=ext4
Options=ro,nofail,x-systemd.device-timeout=10s

[Install]
WantedBy=local-fs.target
EOF

cat > "$SYSTEMD_DIR/vshd.service" <<EOF
[Unit]
Description=ChromeOS vshd guest agent
Requires=$MOUNT_UNIT
After=$MOUNT_UNIT
ConditionPathExists=/opt/google/cros-containers/bin/vshd

[Service]
Type=simple
ExecStart=/opt/google/cros-containers/bin/vshd
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > "$SYSTEMD_DIR/maitred.service" <<EOF
[Unit]
Description=ChromeOS maitred guest agent
Requires=$MOUNT_UNIT
After=$MOUNT_UNIT
ConditionPathExists=/opt/google/cros-containers/bin/maitred

[Service]
Type=simple
Environment=PATH=/opt/google/cros-containers/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/opt/google/cros-containers/bin/maitred
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat > "$SYSTEMD_DIR/port-listener.service" <<EOF
[Unit]
Description=ChromeOS port listener
Requires=$MOUNT_UNIT
After=$MOUNT_UNIT
ConditionPathExists=/opt/google/cros-containers/bin/port_listener

[Service]
Type=simple
ExecStart=/opt/google/cros-containers/bin/port_listener
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

ln -sf "../$MOUNT_UNIT" "$SYSTEMD_LOCAL_FS_WANTS_DIR/$MOUNT_UNIT"
ln -sf ../vshd.service "$SYSTEMD_WANTS_DIR/vshd.service"
ln -sf ../maitred.service "$SYSTEMD_WANTS_DIR/maitred.service"
ln -sf ../port-listener.service "$SYSTEMD_WANTS_DIR/port-listener.service"
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
