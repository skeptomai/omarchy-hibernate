#!/bin/bash
set -euo pipefail

echo "=== ASUS ROG G14 - Step 2: Configure NVIDIA for Hibernate ==="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (use sudo)"
   exit 1
fi

echo "Step 1/3: Updating /etc/modprobe.d/nvidia.conf with hibernate params..."
echo "Current config:"
cat /etc/modprobe.d/nvidia.conf

# Backup current config
cp /etc/modprobe.d/nvidia.conf /etc/modprobe.d/nvidia.conf.backup

# Add hibernate params to existing modeset line
# Current: options nvidia_drm modeset=1
# Target: options nvidia_drm modeset=1
#         options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp

cat > /etc/modprobe.d/nvidia.conf << 'EOF'
# NVIDIA modeset for Wayland/KMS
options nvidia_drm modeset=1

# Hibernate support - save/restore VRAM across suspend
# NVreg_PreserveVideoMemoryAllocations: saves VRAM state
# NVreg_TemporaryFilePath: must be on persistent storage (not /tmp which is tmpfs)
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
EOF

echo ""
echo "New config:"
cat /etc/modprobe.d/nvidia.conf

echo ""
echo "Step 2/3: Removing nvidia from early initramfs MODULES..."
echo "Current /etc/mkinitcpio.conf.d/nvidia.conf:"
cat /etc/mkinitcpio.conf.d/nvidia.conf

# Backup
cp /etc/mkinitcpio.conf.d/nvidia.conf /etc/mkinitcpio.conf.d/nvidia.conf.backup

cat > /etc/mkinitcpio.conf.d/nvidia.conf << 'EOF'
# Removed for hibernate compatibility
# Early KMS (loading nvidia in initramfs) conflicts with NVreg_PreserveVideoMemoryAllocations
# The driver will load later during normal boot, which is fine for hibernate/resume
# MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF

echo ""
echo "New config:"
cat /etc/mkinitcpio.conf.d/nvidia.conf

echo ""
echo "Step 3/3: Verifying NVIDIA systemd services are enabled..."
for service in nvidia-hibernate nvidia-resume nvidia-suspend nvidia-suspend-then-hibernate; do
    if systemctl is-enabled ${service}.service &>/dev/null; then
        echo "  ✓ ${service}.service is enabled"
    else
        echo "  ✗ ${service}.service is NOT enabled - enabling now..."
        systemctl enable ${service}.service
    fi
done

echo ""
echo "=== Summary ==="
echo "✓ NVIDIA modprobe config updated with hibernate params"
echo "✓ NVIDIA modules removed from early initramfs"
echo "✓ NVIDIA systemd services verified"
echo ""
echo "Backups saved:"
echo "  /etc/modprobe.d/nvidia.conf.backup"
echo "  /etc/mkinitcpio.conf.d/nvidia.conf.backup"
echo ""
echo "Step 2 complete. Continue with step 3."
