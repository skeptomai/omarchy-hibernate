#!/bin/bash
set -euo pipefail

CONF="/etc/mkinitcpio.conf.d/omarchy_resume.conf"

echo "=== Current $CONF ==="
cat "$CONF"

echo ""
echo "=== Updating to include plymouth, btrfs-overlayfs, and resume ==="

cat > "$CONF" <<'EOF'
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems resume fsck btrfs-overlayfs)
EOF

echo "=== New $CONF ==="
cat "$CONF"

echo ""
echo "=== Regenerating initramfs/UKI ==="
limine-mkinitcpio

echo ""
echo "Done. Reboot to verify."
