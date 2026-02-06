#!/bin/bash
set -euo pipefail

echo "=== 1/3 Adding NVreg hibernate params to /etc/modprobe.d/nvidia.conf ==="
sed -i 's/^options nvidia NVreg_UsePageAttributeTable=1 NVreg_InitializeSystemMemoryAllocations=0$/options nvidia NVreg_UsePageAttributeTable=1 NVreg_InitializeSystemMemoryAllocations=0 NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=\/var\/tmp/' /etc/modprobe.d/nvidia.conf
echo "Done. Contents:"
cat /etc/modprobe.d/nvidia.conf

echo ""
echo "=== 2/3 Removing nvidia from early MODULES in /etc/mkinitcpio.conf.d/nvidia.conf ==="
cat > /etc/mkinitcpio.conf.d/nvidia.conf << "EOF"
# Removed for hibernate compatibility -- early KMS conflicts with NVreg_PreserveVideoMemoryAllocations
# MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF
echo "Done. Contents:"
cat /etc/mkinitcpio.conf.d/nvidia.conf

echo ""
echo "=== 3/3 Regenerating initramfs/UKI ==="
limine-mkinitcpio

echo ""
echo "=== All done. Reboot to apply changes. ==="
