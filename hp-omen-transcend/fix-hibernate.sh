#!/bin/bash
set -euo pipefail

echo "=== Step 1: Adding resume params to /etc/default/limine ==="
sed -i 's|^KERNEL_CMDLINE\[default\]+="quiet splash"|KERNEL_CMDLINE[default]+=" resume=/dev/mapper/root resume_offset=4368046"\nKERNEL_CMDLINE[default]+=" quiet splash"|' /etc/default/limine
echo "Done."

echo "=== Step 2: Fixing resume hook ordering (before fsck) ==="
echo 'HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems resume fsck)' > /etc/mkinitcpio.conf.d/omarchy_resume.conf
echo "Done."

echo "=== Step 3: Regenerating initramfs/UKI ==="
limine-mkinitcpio
echo "Done."

echo ""
echo "=== Verification ==="
echo "--- /etc/default/limine ---"
cat /etc/default/limine
echo ""
echo "--- /etc/mkinitcpio.conf.d/omarchy_resume.conf ---"
cat /etc/mkinitcpio.conf.d/omarchy_resume.conf
echo ""
echo "All done. Reboot, then verify with: cat /proc/cmdline"
