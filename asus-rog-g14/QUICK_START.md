# ASUS ROG G14 - Hibernate Quick Start

## Prerequisites
- Running Omarchy Linux on ASUS ROG G14 Zephyrus GU603Z
- NVIDIA RTX 3070 Ti Laptop GPU
- supergfxctl installed and configured
- 40 GB RAM (will create 41 GB swapfile)

## Installation (5 minutes)

### Option 1: Automated (Recommended)
```bash
cd /home/cb/Projects/omarchy-hibernate/asus-rog-g14
sudo ./setup-hibernate.sh
```

Follow the prompts. The script will:
1. Create 41 GB swapfile
2. Configure NVIDIA for hibernate
3. Add resume parameters
4. Configure systemd sleep/logind
5. Rebuild initramfs

### Option 2: Manual (Step by Step)
```bash
cd /home/cb/Projects/omarchy-hibernate/asus-rog-g14
sudo ./1-create-swapfile.sh       # Creates swap
sudo ./2-configure-nvidia-hibernate.sh  # NVIDIA config
sudo ./3-configure-resume.sh      # Resume params
sudo ./4-configure-systemd-sleep.sh     # systemd config
sudo ./5-build-and-verify.sh      # Build & show verify commands
```

## After Installation

1. **Reboot**:
   ```bash
   sudo reboot
   ```

2. **Verify** (after reboot):
   ```bash
   # Check kernel cmdline has resume params
   cat /proc/cmdline | grep resume

   # Check NVIDIA hibernate param
   cat /sys/module/nvidia/parameters/PreserveVideoMemoryAllocations
   # Should show: Y

   # Check swap active
   swapon --show
   # Should show both zram and /swap/swapfile
   ```

3. **Test** (progressively):
   ```bash
   # Test mode (safe - just verifies, doesn't actually hibernate)
   echo test | sudo tee /sys/power/disk
   sudo systemctl hibernate
   # System should resume immediately

   # Reboot mode (hibernates then reboots)
   echo reboot | sudo tee /sys/power/disk
   sudo systemctl hibernate
   # System reboots and restores session

   # Full hibernate (powers off, restores on next boot)
   sudo systemctl hibernate
   # System powers off, session restored on next boot
   ```

## What Gets Modified

- `/swap/swapfile` - Created (41 GB)
- `/etc/fstab` - Swapfile entry added
- `/etc/default/limine` - Resume params added
- `/etc/modprobe.d/nvidia.conf` - Hibernate params added
- `/etc/mkinitcpio.conf.d/nvidia.conf` - Early KMS removed
- `/etc/mkinitcpio.conf.d/omarchy_resume.conf` - Resume hook added
- `/etc/systemd/sleep.conf.d/hibernate.conf` - Created
- `/etc/systemd/logind.conf.d/lid.conf` - Created
- `/boot/omarchy.efi` - Rebuilt with new config

## Backups

All modified files are backed up with `.backup` extension:
- `/etc/default/limine.backup`
- `/etc/modprobe.d/nvidia.conf.backup`
- `/etc/mkinitcpio.conf.d/nvidia.conf.backup`

## Rollback

If something goes wrong:
```bash
# Restore backups
sudo cp /etc/default/limine.backup /etc/default/limine
sudo cp /etc/modprobe.d/nvidia.conf.backup /etc/modprobe.d/nvidia.conf
sudo cp /etc/mkinitcpio.conf.d/nvidia.conf.backup /etc/mkinitcpio.conf.d/nvidia.conf

# Remove resume config
sudo rm /etc/mkinitcpio.conf.d/omarchy_resume.conf

# Rebuild
sudo limine-mkinitcpio

# Reboot
sudo reboot
```

Or use Omarchy's removal tool:
```bash
sudo omarchy-hibernation-remove
```

## Troubleshooting

### Hibernate hangs on black screen
- Check `/var/log/journal`: `journalctl -b -1 -u systemd-hibernate`
- Verify resume params in `/proc/cmdline`
- Check swap offset matches: `sudo btrfs inspect-internal map-swapfile -r /swap/swapfile`

### Session not restored after resume
- Verify resume hook is before fsck: `cat /etc/mkinitcpio.conf.d/omarchy_resume.conf`
- Check initramfs was rebuilt: `ls -lh /boot/omarchy.efi`

### NVIDIA driver issues after resume
- Check NVIDIA services: `systemctl status nvidia-resume.service`
- Verify VRAM preservation param: `cat /sys/module/nvidia/parameters/PreserveVideoMemoryAllocations`
- Check nvidia NOT in early initramfs: `lsinitcpio /boot/omarchy.efi | grep nvidia` (should be empty)

### Second hibernate fails
- Known issue with NVIDIA+supergfxctl
- Workaround: `sudo modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia && sudo modprobe nvidia nvidia_modeset nvidia_drm nvidia_uvm`

## Usage

### Manual Hibernate
```bash
sudo systemctl hibernate
```

### Suspend-then-Hibernate
Close lid - will suspend, then hibernate after 30 minutes (on battery only).

### Change Hibernate Delay
Edit `/etc/systemd/sleep.conf.d/hibernate.conf`:
```ini
[Sleep]
HibernateDelaySec=60min  # Change to desired delay
```

## More Information

- Full documentation: [ASUS_HIBERNATE_SETUP.md](ASUS_HIBERNATE_SETUP.md)
- System info: [system-info.txt](system-info.txt)
- Repository root: [../README.md](../README.md)
