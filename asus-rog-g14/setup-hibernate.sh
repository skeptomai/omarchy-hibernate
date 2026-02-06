#!/bin/bash
set -euo pipefail

echo "=============================================="
echo "ASUS ROG G14 Zephyrus - Hibernate Setup"
echo "=============================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root"
   echo "Usage: sudo ./setup-hibernate.sh"
   exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "This script will configure hibernate on your ASUS ROG G14."
echo "It will perform the following steps:"
echo ""
echo "  1. Create 41 GB swapfile on btrfs /swap subvolume"
echo "  2. Configure NVIDIA driver for hibernate (VRAM preservation)"
echo "  3. Add resume kernel params to bootloader config"
echo "  4. Configure mkinitcpio hooks for resume"
echo "  5. Configure systemd sleep and logind behavior"
echo "  6. Rebuild initramfs and bootloader"
echo ""
echo "WARNING: This will modify system files. Backups will be created."
echo ""
read -p "Continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "=== Starting hibernate setup ==="
echo ""

# Run each step
for step in 1 2 3 4 5; do
    # Find the script matching this step number
    script=$(find "${SCRIPT_DIR}" -maxdepth 1 -name "${step}-*.sh" -type f | head -1)

    if [[ -z "$script" ]]; then
        echo "ERROR: Script not found for step $step"
        echo "Looking for: ${SCRIPT_DIR}/${step}-*.sh"
        exit 1
    fi

    echo ""
    echo "----------------------------------------"
    bash "$script"

    if [[ $? -ne 0 ]]; then
        echo ""
        echo "ERROR: Step $step failed. Aborting."
        echo "Check the output above for details."
        exit 1
    fi

    echo "----------------------------------------"
    echo ""

    if [[ $step -lt 5 ]]; then
        read -p "Step $step complete. Press Enter to continue to step $((step+1))..."
    fi
done

echo ""
echo "=============================================="
echo "=== ALL STEPS COMPLETE ==="
echo "=============================================="
echo ""
echo "Hibernate has been configured on your ASUS ROG G14."
echo ""
echo "NEXT STEPS:"
echo "1. REBOOT your system"
echo "2. After reboot, run verification commands (see output above)"
echo "3. Test hibernate progressively:"
echo "   - Test mode: echo test | sudo tee /sys/power/disk && sudo systemctl hibernate"
echo "   - Reboot mode: echo reboot | sudo tee /sys/power/disk && sudo systemctl hibernate"
echo "   - Full mode: sudo systemctl hibernate"
echo ""
echo "For detailed documentation, see: ASUS_HIBERNATE_SETUP.md"
echo ""
echo "If you encounter issues:"
echo "- Check /var/log/journal for errors"
echo "- See rollback instructions in ASUS_HIBERNATE_SETUP.md"
echo "- Restore backups from /etc/*.backup files"
echo ""
