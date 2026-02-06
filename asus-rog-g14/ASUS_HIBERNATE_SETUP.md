# ASUS ROG G14 Zephyrus GU603Z - Hibernate Setup

## System Information
- **Laptop**: ASUS ROG G14 Zephyrus GU603Z
- **OS**: Omarchy Linux (Arch Linux derivative)
- **Kernel**: 6.18.3-arch1-1
- **RAM**: 40 GB
- **GPU**: NVIDIA GeForce RTX 3070 Ti Laptop GPU
- **GPU Management**: supergfxctl (ASUS-specific, not envycontrol)
- **GPU Mode**: AsusMuxDgpu (MUX switch in discrete GPU mode)
- **Storage**: 954 GB NVMe, LUKS-encrypted btrfs root (`/dev/mapper/root`)
- **Bootloader**: Limine with Unified Kernel Images (UKI)
- **Root UUID**: To be determined
- **LUKS PARTUUID**: `625283df-e297-4a3c-bef9-15c498f54b02`

## Problem Statement
Omarchy's built-in `omarchy-hibernation-setup` has a known bug (Issue #4259) where it fails to add required `resume=` and `resume_offset=` kernel command line parameters to `/etc/default/limine`. This project aims to properly configure hibernate on the ASUS ROG G14, taking into account:
1. NVIDIA GPU hibernate requirements
2. supergfxctl integration (ASUS-specific GPU switching)
3. Proper kernel command line configuration
4. mkinitcpio hook ordering

## Current State (Before Setup)

### What Exists
- NVIDIA systemd services **already enabled**:
  - `nvidia-hibernate.service` - enabled
  - `nvidia-resume.service` - enabled
  - `nvidia-suspend.service` - enabled
  - `nvidia-suspend-then-hibernate.service` - enabled
- NVIDIA modules loaded in early initramfs via `/etc/mkinitcpio.conf.d/nvidia.conf`:
  ```
  MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
  ```
- Basic NVIDIA modprobe config at `/etc/modprobe.d/nvidia.conf`:
  ```
  options nvidia_drm modeset=1
  ```
- Only zram swap active (19.4 GB, priority 100) - **no on-disk swapfile yet**

### What's Missing
1. **Swapfile**: Need to create `/swap` btrfs subvolume with 41 GB swapfile (matching RAM)
2. **NVIDIA hibernate params**: Need to add to `/etc/modprobe.d/nvidia.conf`:
   - `NVreg_PreserveVideoMemoryAllocations=1` (saves/restores VRAM across hibernate)
   - `NVreg_TemporaryFilePath=/var/tmp` (VRAM snapshots; default `/tmp` is tmpfs and gets wiped)
3. **Early KMS conflict fix**: Remove nvidia modules from early initramfs (conflicts with `NVreg_PreserveVideoMemoryAllocations`)
4. **Resume kernel params**: Add to `/etc/default/limine`:
   - `resume=/dev/mapper/root`
   - `resume_offset=<calculated from btrfs>`
5. **Resume hook**: Add `resume` hook to mkinitcpio before `fsck`
6. **systemd sleep config**: Configure suspend-then-hibernate behavior
7. **logind config**: Configure lid switch behavior

### Current Kernel Cmdline
```
quiet splash cryptdevice=PARTUUID=625283df-e297-4a3c-bef9-15c498f54b02:root root=/dev/mapper/root zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs amdgpu.dc=0
```

Note: `amdgpu.dc=0` present but only NVIDIA GPU detected - may be legacy parameter.

## ASUS-Specific Considerations

### supergfxctl vs envycontrol
Unlike the HP OMEN which uses envycontrol, ASUS ROG laptops use **supergfxctl** for GPU management. Key differences:
- **MUX Switch Support**: G14 has hardware MUX switch (AsusMuxDgpu mode = discrete GPU only)
- **Modes**: Integrated, Hybrid, AsusMuxDgpu, Vfio, None, Compute
- **Current Mode**: AsusMuxDgpu (discrete GPU directly connected to display)
- **Configuration**: Managed via `/etc/supergfxctl.conf` and `supergfxd` daemon

### NVIDIA Hibernate Compatibility
Research findings ([NVIDIA Forums](https://forums.developer.nvidia.com/t/preservevideomemoryallocations-systemd-services-causes-resume-from-hibernate-to-fail/233643), [Arch Forums](https://bbs.archlinux.org/viewtopic.php?id=285508)):
- **NVreg_PreserveVideoMemoryAllocations=1** is required to save/restore VRAM
- **Early KMS conflict**: Having nvidia modules in initramfs conflicts with VRAM preservation
- **Solution**: Remove nvidia from early MODULES, let them load later during boot
- **VRAM storage**: Must use `/var/tmp` not `/tmp` (tmpfs gets wiped)

### Tested Configurations
Based on community research:
- ASUS ROG laptops with NVIDIA successfully hibernate with proper configuration
- supergfxctl modes generally don't interfere with hibernate (GPU state saved regardless)
- Main requirement: proper NVIDIA driver configuration + correct resume params

## Implementation Plan

### Phase 1: Create Swapfile
1. Create `/swap` btrfs subvolume with `chattr +C` (nocow)
2. Create 41 GB swapfile (matching 40 GB RAM + overhead)
3. Add to `/etc/fstab` with `pri=0`
4. Activate swap
5. Get swap offset: `sudo btrfs inspect-internal map-swapfile -r /swap/swapfile`

### Phase 2: Configure NVIDIA for Hibernate
1. Update `/etc/modprobe.d/nvidia.conf`:
   - Add `NVreg_PreserveVideoMemoryAllocations=1`
   - Add `NVreg_TemporaryFilePath=/var/tmp`
   - Keep existing modeset and other params
2. Comment out nvidia modules in `/etc/mkinitcpio.conf.d/nvidia.conf`
   - Prevents early KMS conflict with VRAM preservation

### Phase 3: Configure Resume
1. Add resume params to `/etc/default/limine`:
   ```bash
   KERNEL_CMDLINE[default]+=" resume=/dev/mapper/root resume_offset=<offset>"
   ```
2. Create `/etc/mkinitcpio.conf.d/omarchy_resume.conf`:
   ```bash
   HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems resume fsck btrfs-overlayfs)
   ```
   - Preserves all Omarchy hooks (plymouth, btrfs-overlayfs)
   - Adds `resume` before `fsck`

### Phase 4: Configure systemd Sleep/Logind
1. Create `/etc/systemd/sleep.conf.d/hibernate.conf`:
   ```ini
   [Sleep]
   HibernateDelaySec=30min
   HibernateOnACPower=no
   ```
2. Create `/etc/systemd/logind.conf.d/lid.conf`:
   ```ini
   [Login]
   HandleLidSwitch=suspend-then-hibernate
   ```

### Phase 5: Build and Test
1. Regenerate initramfs/UKI: `sudo limine-mkinitcpio`
2. Reboot and verify `/proc/cmdline` has resume params
3. Test hibernate progressively:
   - Test mode: `echo test | sudo tee /sys/power/disk && sudo systemctl hibernate`
   - Reboot mode: `echo reboot | sudo tee /sys/power/disk && sudo systemctl hibernate`
   - Platform mode: `echo platform | sudo tee /sys/power/disk && sudo systemctl hibernate`

## Scripts Provided

1. **1-create-swapfile.sh** - Creates swap subvolume and swapfile
2. **2-configure-nvidia-hibernate.sh** - Configures NVIDIA for hibernate
3. **3-configure-resume.sh** - Sets up resume params and hooks
4. **4-configure-systemd-sleep.sh** - Configures systemd sleep/logind
5. **5-build-and-verify.sh** - Regenerates initramfs and shows verification commands
6. **setup-hibernate.sh** - Master script that runs all steps (requires sudo)

## Testing Checklist

After running setup:
- [ ] Reboot
- [ ] Verify `/proc/cmdline` shows `resume=/dev/mapper/root resume_offset=<offset>`
- [ ] Verify nvidia modules NOT in early initramfs: `lsinitcpio /boot/omarchy.efi | grep nvidia` should be empty
- [ ] Verify NVIDIA params: `cat /sys/module/nvidia/parameters/PreserveVideoMemoryAllocations` should show `Y`
- [ ] Test hibernate (test mode): `echo test | sudo tee /sys/power/disk && sudo systemctl hibernate`
- [ ] Test hibernate (reboot mode): `echo reboot | sudo tee /sys/power/disk && sudo systemctl hibernate`
- [ ] Test full hibernate: `sudo systemctl hibernate` (should restore session)
- [ ] Test suspend-then-hibernate: Close lid for 30 min

## Rollback Plan

If anything goes wrong:
1. Boot normally (kernel ignores stale hibernate image)
2. Remove resume params from `/etc/default/limine`
3. Restore nvidia modules to `/etc/mkinitcpio.conf.d/nvidia.conf`
4. Run `sudo limine-mkinitcpio`
5. Reboot
6. To fully undo: run `omarchy-hibernation-remove` (removes swapfile too)

## Known Issues & Workarounds

### Issue: Second Hibernate Hangs
**Symptom**: First hibernate works, but after resuming, second hibernate attempt hangs.
**Cause**: GPU not properly released after resume.
**Workaround**: Module reload: `sudo modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia && sudo modprobe nvidia nvidia_modeset nvidia_drm nvidia_uvm`

### Issue: Hibernate Works But Resume Fails
**Symptom**: System hibernates but doesn't restore session on boot.
**Cause**: Resume params not in kernel cmdline or wrong offset.
**Solution**: Verify `/proc/cmdline` has correct params and offset matches `btrfs inspect-internal map-swapfile`.

### Issue: NVIDIA Driver Fails to Load After Resume
**Symptom**: Black screen or nouveau fallback after resume.
**Cause**: Early KMS conflict or missing systemd services.
**Solution**: Ensure nvidia modules NOT in initramfs and all nvidia systemd services enabled.

## Sources & References

- [NVIDIA Developer Forums - PreserveVideoMemoryAllocations + systemd services causes resume from hibernate to fail](https://forums.developer.nvidia.com/t/preservevideomemoryallocations-systemd-services-causes-resume-from-hibernate-to-fail/233643)
- [Arch Linux Forums - nvidia-resume from hibernation not working with early KMS enabled](https://bbs.archlinux.org/viewtopic.php?id=285508)
- [Arch Linux Forums - Hibernate hangs and sleep instantly wakes with AMD+NVIDIA gpu](https://bbs.archlinux.org/viewtopic.php?id=311112)
- [ASUS Linux - Official FAQ](https://asus-linux.org/faq/)
- [NVIDIA Power Management Documentation](https://download.nvidia.com/XFree86/Linux-x86_64/435.17/README/powermanagement.html)
- [Omarchy GitHub Issue #4259](https://github.com/basecamp/omarchy/issues/4259)
