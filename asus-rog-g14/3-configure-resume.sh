#!/bin/bash
set -euo pipefail

echo "=== ASUS ROG G14 - Step 3: Configure Resume ==="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (use sudo)"
   exit 1
fi

# Get swap offset
if [[ ! -f /swap/swapfile ]]; then
    echo "ERROR: /swap/swapfile not found. Run step 1 first."
    exit 1
fi

OFFSET=$(btrfs inspect-internal map-swapfile -r /swap/swapfile)
echo "Detected swap offset: $OFFSET"
echo ""

echo "Step 1/3: Adding resume params to /etc/default/limine..."
echo "Current config:"
cat /etc/default/limine

# Backup
cp /etc/default/limine /etc/default/limine.backup

# Check if resume params already exist
if grep -q "resume=" /etc/default/limine; then
    echo ""
    echo "WARNING: resume params already exist in /etc/default/limine"
    echo "Please manually update the offset if needed. Current file:"
    cat /etc/default/limine
    exit 1
fi

# Add resume params after the main KERNEL_CMDLINE line and before quiet splash
sed -i "/^KERNEL_CMDLINE\[default\]=\"cryptdevice=/a KERNEL_CMDLINE[default]+=\" resume=/dev/mapper/root resume_offset=$OFFSET\"" /etc/default/limine

echo ""
echo "Updated config:"
cat /etc/default/limine

echo ""
echo "Step 2/3: Creating /etc/mkinitcpio.conf.d/omarchy_resume.conf..."

# Check if already exists
if [[ -f /etc/mkinitcpio.conf.d/omarchy_resume.conf ]]; then
    echo "WARNING: omarchy_resume.conf already exists"
    cp /etc/mkinitcpio.conf.d/omarchy_resume.conf /etc/mkinitcpio.conf.d/omarchy_resume.conf.backup
fi

# Create resume hook config
# IMPORTANT: Must include all Omarchy hooks (plymouth, btrfs-overlayfs) + resume before fsck
cat > /etc/mkinitcpio.conf.d/omarchy_resume.conf << 'EOF'
# Omarchy hibernate configuration
# Preserves all Omarchy hooks (plymouth, btrfs-overlayfs) and adds resume before fsck
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems resume fsck btrfs-overlayfs)
EOF

echo "Created omarchy_resume.conf:"
cat /etc/mkinitcpio.conf.d/omarchy_resume.conf

echo ""
echo "Step 3/3: Verifying hook order..."
echo ""
echo "Base hooks (from /etc/mkinitcpio.conf):"
grep "^HOOKS=" /etc/mkinitcpio.conf
echo ""
echo "Omarchy hooks (from omarchy_hooks.conf):"
cat /etc/mkinitcpio.conf.d/omarchy_hooks.conf
echo ""
echo "Final hooks with resume (from omarchy_resume.conf - this takes precedence):"
cat /etc/mkinitcpio.conf.d/omarchy_resume.conf

echo ""
echo "=== Summary ==="
echo "✓ Resume params added to /etc/default/limine"
echo "✓ Resume hook added to mkinitcpio (preserving Omarchy hooks)"
echo ""
echo "Backups saved:"
echo "  /etc/default/limine.backup"
if [[ -f /etc/mkinitcpio.conf.d/omarchy_resume.conf.backup ]]; then
    echo "  /etc/mkinitcpio.conf.d/omarchy_resume.conf.backup"
fi
echo ""
echo "Step 3 complete. Continue with step 4."
