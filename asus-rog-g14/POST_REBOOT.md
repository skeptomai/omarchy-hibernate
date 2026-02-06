# ASUS ROG G14 - Post-Reboot Checklist

## After rebooting, follow these steps to verify and test hibernate:

### Step 1: Verify Configuration
```bash
cd ~/Projects/omarchy-hibernate/asus-rog-g14
./collect-system-info.sh
```

**What to check:**
- Kernel cmdline should include `resume=/dev/mapper/root resume_offset=<number>`
- NVIDIA PreserveVideoMemoryAllocations should show `Y`
- Both zram and /swap/swapfile should be active
- NVIDIA modules should NOT be in early initramfs

### Step 2: Quick Verification Commands
```bash
# Check resume params in kernel cmdline
cat /proc/cmdline | grep resume

# Check NVIDIA hibernate param is active
cat /sys/module/nvidia/parameters/PreserveVideoMemoryAllocations
# Should output: Y

# Check swap is active
swapon --show
# Should show both zram and /swap/swapfile

# Verify nvidia NOT in early initramfs (should be empty/no output)
lsinitcpio /boot/omarchy.efi | grep nvidia
```

### Step 3: Test Hibernate (Progressive Testing)

#### Test 1: Safe Test Mode (doesn't actually hibernate)
```bash
echo test | sudo tee /sys/power/disk
sudo systemctl hibernate
```
**Expected**: System should immediately resume (kernel just verifies it can hibernate)

#### Test 2: Reboot Mode (hibernates then reboots)
```bash
echo reboot | sudo tee /sys/power/disk
sudo systemctl hibernate
```
**Expected**: System hibernates, then reboots and restores your session

#### Test 3: Full Hibernate (powers off)
```bash
echo platform | sudo tee /sys/power/disk
sudo systemctl hibernate
```
**Expected**: System powers off. On next boot, session is restored.

**OR simply:**
```bash
sudo systemctl hibernate
```
(Uses default platform mode)

### Step 4: Test Suspend-then-Hibernate
Close the lid and leave it closed for 30+ minutes.
**Expected**: Suspends immediately, hibernates after 30 minutes.

## ✅ Success Criteria

All of these should work:
- [ ] Kernel cmdline has resume params
- [ ] NVIDIA PreserveVideoMemoryAllocations = Y
- [ ] Swap is active (both zram and swapfile)
- [ ] Test mode hibernate works
- [ ] Reboot mode hibernate works and restores session
- [ ] Full hibernate works and restores session
- [ ] Suspend-then-hibernate works

## ❌ Troubleshooting

### Hibernate hangs on black screen
```bash
# Check journal for errors
journalctl -b -1 -u systemd-hibernate

# Verify resume offset matches
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
cat /proc/cmdline | grep resume_offset
# Numbers should match
```

### Session not restored after hibernate
```bash
# Check resume hook is present and before fsck
cat /etc/mkinitcpio.conf.d/omarchy_resume.conf
# Should show: ... filesystems resume fsck ...

# Check initramfs was rebuilt
ls -lh /boot/omarchy.efi
# Date should be recent (from when you ran the setup)
```

### NVIDIA issues after resume
```bash
# Check NVIDIA resume service
systemctl status nvidia-resume.service

# Verify VRAM preservation is enabled
cat /sys/module/nvidia/parameters/PreserveVideoMemoryAllocations
# Should be Y

# Verify nvidia NOT in early initramfs
lsinitcpio /boot/omarchy.efi | grep nvidia
# Should be empty
```

### Second hibernate fails after first resume
Known issue. Workaround:
```bash
sudo modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia
sudo modprobe nvidia nvidia_modeset nvidia_drm nvidia_uvm
```

## 📚 More Information

- Full docs: `ASUS_HIBERNATE_SETUP.md`
- Quick reference: `SETUP_SUMMARY.md`
- Installation guide: `QUICK_START.md`

## 🔄 Rollback (if needed)

If hibernate doesn't work and you want to undo:
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

---

**Remember**: Start with test mode, then reboot mode, then full hibernate. Don't skip steps!
