#!/bin/bash
set -euo pipefail

echo "=== ASUS ROG G14 - Step 1: Create Swapfile ==="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (use sudo)"
   exit 1
fi

# Check if swap already exists
if [[ -d /swap ]]; then
    echo "WARNING: /swap already exists"
    if [[ -f /swap/swapfile ]]; then
        echo "ERROR: /swap/swapfile already exists. Aborting."
        echo "If you want to recreate, manually remove it first:"
        echo "  sudo swapoff /swap/swapfile"
        echo "  sudo rm /swap/swapfile"
        echo "  sudo btrfs subvolume delete /swap"
        exit 1
    fi
fi

echo "Step 1/5: Creating /swap btrfs subvolume..."
if [[ ! -d /swap ]]; then
    btrfs subvolume create /swap
    chattr +C /swap  # nocow for swap performance
fi

echo "Step 2/5: Creating 41 GB swapfile (matching 40 GB RAM)..."
truncate -s 0 /swap/swapfile
chattr +C /swap/swapfile
fallocate -l 41G /swap/swapfile
chmod 600 /swap/swapfile
mkswap /swap/swapfile

echo "Step 3/5: Adding to /etc/fstab..."
if grep -q "/swap/swapfile" /etc/fstab; then
    echo "  Already in fstab, skipping"
else
    echo "/swap/swapfile none swap defaults,pri=0 0 0" >> /etc/fstab
    echo "  Added to fstab"
fi

echo "Step 4/5: Activating swap..."
swapon /swap/swapfile

echo "Step 5/5: Getting swap offset..."
OFFSET=$(btrfs inspect-internal map-swapfile -r /swap/swapfile)
echo "  Swap offset: $OFFSET"

echo ""
echo "=== Current swap status ==="
swapon --show

echo ""
echo "=== IMPORTANT: Save this offset for step 3 ==="
echo "SWAP_OFFSET=$OFFSET"
echo ""
echo "You can also retrieve it later with:"
echo "  sudo btrfs inspect-internal map-swapfile -r /swap/swapfile"
echo ""
echo "Step 1 complete. Swapfile created and active."
