#!/bin/bash
set -euo pipefail

echo "=== ASUS ROG G14 - Step 5: Build and Verify ==="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (use sudo)"
   exit 1
fi

echo "Step 1/2: Regenerating initramfs and UKI with limine-mkinitcpio..."
echo "This will:"
echo "  - Rebuild initramfs with new hooks (resume)"
echo "  - Create new Unified Kernel Image with updated cmdline"
echo "  - Update Limine bootloader config"
echo ""
limine-mkinitcpio

echo ""
echo "Step 2/2: Verification commands (run AFTER reboot)..."
echo ""
echo "=== POST-REBOOT VERIFICATION ==="
cat << 'EOF'

1. Verify kernel command line has resume params:
   cat /proc/cmdline

   Should include: resume=/dev/mapper/root resume_offset=<number>

2. Verify NVIDIA hibernate params loaded:
   cat /sys/module/nvidia/parameters/PreserveVideoMemoryAllocations

   Should show: Y

3. Verify NVIDIA temporary file path:
   cat /sys/module/nvidia/parameters/TemporaryFilePath

   Should show: /var/tmp

4. Verify nvidia modules NOT in early initramfs:
   lsinitcpio /boot/omarchy.efi | grep -i nvidia

   Should be empty (no output)

5. Check swap status:
   swapon --show

   Should show both zram and /swap/swapfile

6. Check supported hibernate modes:
   cat /sys/power/disk

   Should show: [platform] shutdown reboot suspend test_resume

7. Test hibernate in test mode (safe, doesn't actually hibernate):
   echo test | sudo tee /sys/power/disk
   sudo systemctl hibernate

   System should immediately resume (kernel verifies it can hibernate)

8. Test hibernate in reboot mode (hibernates but reboots instead of powering off):
   echo reboot | sudo tee /sys/power/disk
   sudo systemctl hibernate

   System should reboot and restore session

9. Test full hibernate (actually powers off and resumes):
   echo platform | sudo tee /sys/power/disk
   sudo systemctl hibernate

   System should power off, then restore session on next boot

10. Test suspend-then-hibernate:
    Close lid and wait 30+ minutes

    Should suspend immediately, then hibernate after 30 min

EOF

echo ""
echo "=== Summary ==="
echo "✓ Initramfs and UKI rebuilt with new configuration"
echo "✓ Ready to reboot"
echo ""
echo "NEXT STEPS:"
echo "1. Reboot the system"
echo "2. Run the verification commands above"
echo "3. Test hibernate progressively (test -> reboot -> platform)"
echo ""
echo "If anything goes wrong, see ASUS_HIBERNATE_SETUP.md for rollback instructions."
