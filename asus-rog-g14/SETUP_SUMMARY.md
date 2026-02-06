# ASUS ROG G14 Hibernate Setup - Summary

## Repository Structure

```
omarchy-hibernate/
├── README.md ........................... Main documentation
├── asus-rog-g14/ ....................... ASUS ROG G14 (CURRENT)
│   ├── ASUS_HIBERNATE_SETUP.md ......... Full technical docs
│   ├── QUICK_START.md .................. Quick installation guide
│   ├── SETUP_SUMMARY.md ................ This file
│   ├── setup-hibernate.sh .............. MASTER SETUP SCRIPT ★
│   ├── 1-create-swapfile.sh ............ Creates 41GB swap
│   ├── 2-configure-nvidia-hibernate.sh . NVIDIA VRAM preservation
│   ├── 3-configure-resume.sh ........... Resume params & hooks
│   ├── 4-configure-systemd-sleep.sh .... Suspend-then-hibernate
│   ├── 5-build-and-verify.sh ........... Build initramfs
│   ├── collect-system-info.sh .......... Post-install verification
│   └── system-info.txt ................. Pre-install snapshot
└── hp-omen-transcend/ .................. HP OMEN (REFERENCE)
    ├── CLAUDE.md ....................... HP OMEN full docs
    ├── AUDIO_FIX.md .................... Audio-specific fixes
    ├── fix-*.sh ........................ HP OMEN scripts
    └── (audio scripts)
```

## Key Differences: ASUS vs HP OMEN

| Feature | ASUS ROG G14 | HP OMEN Transcend 14 |
|---------|--------------|----------------------|
| GPU | RTX 3070 Ti Laptop | Intel Arc + NVIDIA |
| GPU Tool | supergfxctl | envycontrol |
| MUX Switch | Yes (AsusMuxDgpu) | No |
| RAM | 40 GB | 30 GB |
| Swapfile | 41 GB | 30.7 GB |
| Status | Ready to install | Fully configured ✓ |

## Quick Start (ASUS ROG G14)

### 1. Read the docs
```bash
cd /home/cb/Projects/omarchy-hibernate/asus-rog-g14
less QUICK_START.md
```

### 2. Run the setup (takes ~5 minutes)
```bash
sudo ./setup-hibernate.sh
```

### 3. Reboot
```bash
sudo reboot
```

### 4. Verify
```bash
./collect-system-info.sh
```

### 5. Test
```bash
# Test mode (safe - just verifies)
echo test | sudo tee /sys/power/disk
sudo systemctl hibernate

# Reboot mode (hibernates then reboots)
echo reboot | sudo tee /sys/power/disk
sudo systemctl hibernate

# Full hibernate (powers off, restores on next boot)
sudo systemctl hibernate
```

## What the Setup Does

✓ **Creates 41GB swapfile** on btrfs /swap subvolume
✓ **Configures NVIDIA for VRAM preservation**:
  - `NVreg_PreserveVideoMemoryAllocations=1`
  - `NVreg_TemporaryFilePath=/var/tmp`
✓ **Removes nvidia from early initramfs** (prevents KMS conflict)
✓ **Adds resume kernel params**: `resume=/dev/mapper/root resume_offset=<offset>`
✓ **Adds resume hook** to mkinitcpio (before fsck)
✓ **Configures suspend-then-hibernate** (30min delay)
✓ **Sets lid close** to trigger suspend-then-hibernate
✓ **Rebuilds initramfs and bootloader**

## System Modifications

### Files Created
- `/swap/swapfile` (41 GB)
- `/etc/systemd/sleep.conf.d/hibernate.conf`
- `/etc/systemd/logind.conf.d/lid.conf`
- `/etc/mkinitcpio.conf.d/omarchy_resume.conf`

### Files Modified (with backups)
- `/etc/fstab` (swapfile entry added)
- `/etc/default/limine` (resume params added) → `.backup` created
- `/etc/modprobe.d/nvidia.conf` (hibernate params added) → `.backup` created
- `/etc/mkinitcpio.conf.d/nvidia.conf` (early KMS removed) → `.backup` created
- `/boot/omarchy.efi` (rebuilt with new config)

## Research-Backed Configuration

Based on:
- [NVIDIA Developer Forums](https://forums.developer.nvidia.com/t/preservevideomemoryallocations-systemd-services-causes-resume-from-hibernate-to-fail/233643) - PreserveVideoMemoryAllocations issues
- [Arch Linux Forums](https://bbs.archlinux.org/viewtopic.php?id=285508) - hibernate + NVIDIA + early KMS conflicts
- [Arch Linux Forums](https://bbs.archlinux.org/viewtopic.php?id=311112) - AMD+NVIDIA GPU hibernate issues
- [ASUS Linux](https://asus-linux.org/faq/) - supergfxctl + hibernate compatibility
- [Omarchy Issue #4259](https://github.com/basecamp/omarchy/issues/4259) - hibernation-setup bug

## Key Technical Details

### Why Remove NVIDIA from Early initramfs?
**Problem**: Loading nvidia modules in initramfs (early KMS) conflicts with `NVreg_PreserveVideoMemoryAllocations=1`. The driver tries to restore VRAM state before the hibernate image is available, causing failures.

**Solution**: Comment out `MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)` in `/etc/mkinitcpio.conf.d/nvidia.conf`. The modules load later during normal boot, which is fine for hibernate/resume.

### Why Use /var/tmp Not /tmp?
**Problem**: `/tmp` is mounted as tmpfs (RAM-based) and gets wiped on reboot. NVIDIA stores VRAM snapshots in `NVreg_TemporaryFilePath`, which must survive across reboots.

**Solution**: Set `NVreg_TemporaryFilePath=/var/tmp` which is on persistent storage.

### Why Add resume Before fsck?
**Problem**: If `fsck` runs before `resume`, the filesystem gets modified, invalidating the hibernate image signature, causing resume to fail.

**Solution**: Hook order must be: `... filesystems resume fsck ...`

### supergfxctl Compatibility
**Good news**: supergfxctl GPU modes (Integrated, Hybrid, AsusMuxDgpu, etc.) don't interfere with hibernate. The GPU state is saved/restored regardless of mode. The NVIDIA hibernate configuration works across all modes.

## Rollback Plan

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

Or use Omarchy's built-in removal tool:
```bash
sudo omarchy-hibernation-remove
```

## Troubleshooting

### Hibernate hangs on black screen
- Check journal: `journalctl -b -1 -u systemd-hibernate`
- Verify resume params in `/proc/cmdline`
- Check swap offset: `sudo btrfs inspect-internal map-swapfile -r /swap/swapfile`

### Session not restored after resume
- Verify resume hook: `cat /etc/mkinitcpio.conf.d/omarchy_resume.conf`
- Check initramfs rebuild date: `ls -lh /boot/omarchy.efi`

### NVIDIA driver issues after resume
- Check services: `systemctl status nvidia-resume.service`
- Verify param: `cat /sys/module/nvidia/parameters/PreserveVideoMemoryAllocations` (should be Y)
- Verify no early nvidia: `lsinitcpio /boot/omarchy.efi | grep nvidia` (should be empty)

### Second hibernate fails
Known issue with NVIDIA+supergfxctl. Workaround:
```bash
sudo modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia
sudo modprobe nvidia nvidia_modeset nvidia_drm nvidia_uvm
```

## Post-Setup Usage

### Manual Hibernate
```bash
sudo systemctl hibernate
```

### Suspend-then-Hibernate
Close lid - will suspend immediately, then hibernate after 30 minutes (on battery only).

### Change Hibernate Delay
Edit `/etc/systemd/sleep.conf.d/hibernate.conf`:
```ini
[Sleep]
HibernateDelaySec=60min  # Change to desired delay
```

Then restart logind:
```bash
sudo systemctl restart systemd-logind.service
```

## Documentation Index

- **SETUP_SUMMARY.md** (this file) - Quick overview and reference
- **QUICK_START.md** - Step-by-step installation guide
- **ASUS_HIBERNATE_SETUP.md** - Complete technical documentation
- **../README.md** - Repository overview (both laptops)

## Ready to Install?

```bash
cd /home/cb/Projects/omarchy-hibernate/asus-rog-g14
sudo ./setup-hibernate.sh
```

The script is interactive and will:
1. Explain each step before running it
2. Create backups of all modified files
3. Prompt for confirmation before proceeding
4. Provide clear error messages if anything fails
5. Give you post-reboot verification commands

**Estimated time**: 5 minutes
**Requires**: Reboot after completion
