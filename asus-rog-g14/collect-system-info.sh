#!/bin/bash
# ASUS ROG G14 - System Information Collection Script
# Run this after installation to verify configuration

echo "=== ASUS ROG G14 System Info ==="
echo ""
echo "Date: $(date)"
echo "Kernel: $(uname -r)"
echo ""

echo "--- Hardware ---"
echo "GPU: $(lspci | grep VGA)"
echo "GPU Mode: $(supergfxctl -g 2>/dev/null || echo 'supergfxctl not available')"
echo "RAM: $(grep MemTotal /proc/meminfo)"
echo ""

echo "--- Storage ---"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | grep -E "NAME|nvme|zram|mapper"
echo ""

echo "--- Boot Config ---"
echo "LUKS PARTUUID: 625283df-e297-4a3c-bef9-15c498f54b02"
echo "Root: /dev/mapper/root"
echo ""
echo "Kernel cmdline:"
cat /proc/cmdline
echo ""

echo "--- Swap Status ---"
swapon --show
echo ""

echo "--- NVIDIA Config ---"
echo "modprobe.d/nvidia.conf:"
cat /etc/modprobe.d/nvidia.conf 2>/dev/null || echo "Not found"
echo ""
echo "PreserveVideoMemoryAllocations:"
cat /sys/module/nvidia/parameters/PreserveVideoMemoryAllocations 2>/dev/null || echo "Not loaded yet (check after reboot)"
echo ""

echo "--- NVIDIA Services ---"
systemctl list-unit-files | grep nvidia | grep enabled
echo ""

echo "--- mkinitcpio Config ---"
echo "Resume config:"
cat /etc/mkinitcpio.conf.d/omarchy_resume.conf 2>/dev/null || echo "Not configured"
echo ""
echo "NVIDIA early modules:"
cat /etc/mkinitcpio.conf.d/nvidia.conf 2>/dev/null || echo "Not found"
echo ""

echo "--- Hibernate Support ---"
echo "Supported states: $(cat /sys/power/state)"
echo "Disk modes: $(cat /sys/power/disk)"
echo ""

echo "=== Verification Complete ==="
echo "Save this output for troubleshooting if needed."
