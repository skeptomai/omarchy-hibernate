# Omarchy Hibernate Setup

## System Information
- **Laptop**: HP OMEN Transcend 14"
- **OS**: Omarchy Linux (opinionated Arch Linux derivative, https://github.com/basecamp/omarchy)
- **Kernel**: 6.18.7-arch1-1
- **RAM**: 30 GB
- **GPUs**: Intel Arc Pro 130T/140T (integrated) + NVIDIA (discrete, hybrid mode via envycontrol)
- **Storage**: NVMe, LUKS-encrypted btrfs root (`/dev/mapper/root`)
- **Bootloader**: Limine with Unified Kernel Images (UKI)
- **Root UUID**: `007590d7-17ab-4882-b4d4-2467bf9b9cd2`
- **LUKS PARTUUID**: `4dfc1934-1779-4ea8-9b8f-012aab2e767e`

## Problem Statement
The built-in `omarchy-hibernation-setup` (menu: Setup > System Sleep > Enable Hibernate, added in Omarchy v3.3.0) was run but hibernation does not work. The script has a **known bug** ([Issue #4259](https://github.com/basecamp/omarchy/issues/4259)): it fails to add the required `resume=` and `resume_offset=` kernel command line parameters to `/etc/default/limine`.

## Research Findings

### What `omarchy-hibernation-setup` Already Did (Successfully)
These steps completed correctly and do NOT need to be redone:
1. Created `/swap` btrfs subvolume with `chattr +C` (nocow)
2. Created `/swap/swapfile` (30.7 GB, matches RAM)
3. Added swapfile to `/etc/fstab` with `pri=0`
4. Activated swap (`swapon` confirms it's active at priority 0)
5. Added `HOOKS+=(resume)` to `/etc/mkinitcpio.conf.d/omarchy_resume.conf`
6. Configured systemd sleep: `HibernateDelaySec=30min`, `HandleLidSwitch=suspend-then-hibernate`
7. Ran `limine-mkinitcpio` to regenerate initramfs/UKI

### What Is Missing (The Bug)
The kernel command line (`cat /proc/cmdline`) was missing resume params. **This has been fixed.** Current cmdline:
```
quiet splash  resume=/dev/mapper/root resume_offset=4368046 cryptdevice=PARTUUID=4dfc1934-1779-4ea8-9b8f-012aab2e767e:root root=/dev/mapper/root zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs
```

The `resume=` and `resume_offset=` parameters are now present.

### Current mkinitcpio Hook Order
Drop-in files in `/etc/mkinitcpio.conf.d/` are processed alphabetically. Files using `HOOKS=` (not `HOOKS+=`) fully override prior values.

**Base** (`/etc/mkinitcpio.conf`):
```
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
```

**Omarchy override** (`omarchy_hooks.conf`) -- the stock Omarchy hooks:
```
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
```
Key additions vs base: `plymouth` (graphical boot/LUKS prompt), `keyboard` moved early, `btrfs-overlayfs`.

**Hibernate override** (`omarchy_resume.conf`) -- our file, comes last alphabetically so is the effective config:
```
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems resume fsck btrfs-overlayfs)
```
Adds `resume` before `fsck`, preserves all Omarchy hooks.

**Previous bug**: `omarchy_resume.conf` initially contained only the base hooks + `resume`, accidentally dropping `plymouth` and `btrfs-overlayfs` from `omarchy_hooks.conf`. This caused a boot regression (text-mode LUKS password prompt instead of Plymouth graphical boot). Fixed by `fix-resume-hooks.sh`.

### NVIDIA GPU Configuration (envycontrol)
NVIDIA is now in **hybrid mode** (`envycontrol -s hybrid`). Audit completed, fixes applied:

- `nvidia-hibernate.service`, `nvidia-resume.service`, `nvidia-suspend.service` -- all **enabled**
- `/etc/modprobe.d/nvidia.conf` -- now includes:
  - `NVreg_PreserveVideoMemoryAllocations=1` (saves/restores VRAM across hibernate)
  - `NVreg_TemporaryFilePath=/var/tmp` (VRAM snapshots stored here; default `/tmp` is tmpfs and gets wiped)
  - `NVreg_UsePageAttributeTable=1`, `NVreg_InitializeSystemMemoryAllocations=0` (pre-existing)
  - `nvidia-drm modeset=1` (pre-existing)
- `/etc/mkinitcpio.conf.d/nvidia.conf` -- nvidia MODULES **removed** (commented out) to avoid early KMS conflicting with hibernate resume
- Note: if GSP firmware causes timeouts on resume, may need `NVreg_EnableGpuFirmware=0`

### Hardware-Specific Notes
- **HP OMEN DSDT issues**: Some HP OMEN Transcend models need DSDT/ACPI patches for sleep to work. However, `noapic` is NOT in the current kernel cmdline, suggesting this system may not be affected or was already patched.
- **Secure Boot**: Disabled (confirmed). Not a blocker.
- **zram conflict**: zram0 runs at priority 100, swapfile at priority 0. The kernel fills zram first. Since zram cannot persist across reboots, this is handled by the hibernate image writer which writes all of RAM to the on-disk swap, not just what's in zram.

### Key Omarchy/Limine Details
- Kernel params go in `/etc/default/limine` in the `KERNEL_CMDLINE[default]` variable
- Do NOT edit `/boot/limine.conf` directly (overwritten by `limine-mkinitcpio`)
- Regenerate with `sudo limine-mkinitcpio`
- The swap offset must be obtained via `sudo btrfs inspect-internal map-swapfile -r /swap/swapfile`

### Current Config Files (Snapshots)

**/etc/default/limine:**
```bash
TARGET_OS_NAME="Omarchy"
ESP_PATH="/boot"
KERNEL_CMDLINE[default]="cryptdevice=PARTUUID=4dfc1934-1779-4ea8-9b8f-012aab2e767e:root root=/dev/mapper/root zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs"
KERNEL_CMDLINE[default]+=" resume=/dev/mapper/root resume_offset=4368046"
KERNEL_CMDLINE[default]+=" quiet splash"
ENABLE_UKI=yes
CUSTOM_UKI_NAME="omarchy"
ENABLE_LIMINE_FALLBACK=yes
FIND_BOOTLOADERS=yes
BOOT_ORDER="*, *fallback, Snapshots"
MAX_SNAPSHOT_ENTRIES=5
SNAPSHOT_FORMAT_CHOICE=5
```

**/etc/mkinitcpio.conf (HOOKS and MODULES lines):**
```
MODULES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
```

**/etc/mkinitcpio.conf.d/omarchy_hooks.conf (stock Omarchy):**
```
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
```

**/etc/mkinitcpio.conf.d/omarchy_resume.conf (our hibernate addition):**
```
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems resume fsck btrfs-overlayfs)
```

**/etc/fstab (swap entry):**
```
/swap/swapfile none swap defaults,pri=0 0 0
```

**/etc/modprobe.d/nvidia.conf:**
```
# Automatically generated by EnvyControl
options nvidia-drm modeset=1
options nvidia NVreg_UsePageAttributeTable=1 NVreg_InitializeSystemMemoryAllocations=0 NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
```

**/etc/mkinitcpio.conf.d/nvidia.conf:**
```
# Removed for hibernate compatibility -- early KMS conflicts with NVreg_PreserveVideoMemoryAllocations
# MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

**systemd sleep/logind overrides:**
- `/etc/systemd/sleep.conf.d/hibernate.conf`: `HibernateDelaySec=30min`, `HibernateOnACPower=no`
- `/etc/systemd/logind.conf.d/lid.conf`: `HandleLidSwitch=suspend-then-hibernate`

**Block device layout:**
```
nvme0n1
├─nvme0n1p1  vfat FAT32  /boot  (UUID: 3B46-B039)
└─nvme0n1p2  crypto_LUKS
  └─root     btrfs       /      (UUID: 007590d7-17ab-4882-b4d4-2467bf9b9cd2)
```

**Swap status:**
```
/swap/swapfile  file  30.7G  pri=0
/dev/zram0      partition  15.4G  pri=100
```

**Kernel power support:**
```
/sys/power/state: freeze mem disk
/sys/power/disk: [platform] shutdown reboot suspend test_resume
/sys/power/image_size: 13107146752
```

## Next Steps (Before Implementation)

### TODO: Pre-implementation checklist
1. [x] **Re-enable NVIDIA GPU**: `sudo envycontrol -s hybrid` -- **done, rebooted into hybrid mode**
2. [x] **Get swap offset**: `resume_offset=4368046`
3. [x] **Audit NVIDIA config post-reboot**: Audited modprobe.d, module params, systemd services -- all fixed
4. [x] **Check Secure Boot status**: Disabled (confirmed via `bootctl status`)

### Remaining implementation steps:
1. [x] Add `resume=/dev/mapper/root resume_offset=4368046` to `/etc/default/limine` -- **done, confirmed in /proc/cmdline**
2. [x] Fix `resume` hook ordering (move before `fsck` in mkinitcpio) -- **done** in omarchy_resume.conf
3. [x] Audit NVIDIA config post-reboot -- **done**: added `NVreg_PreserveVideoMemoryAllocations=1` + `NVreg_TemporaryFilePath=/var/tmp`, removed nvidia from early MODULES
4. [x] Regenerate initramfs/UKI with `sudo limine-mkinitcpio` -- **done** via `fix-nvidia-hibernate.sh`
5. [x] Reboot and verify `cat /proc/cmdline` + nvidia params -- **done**, resume params confirmed in /proc/cmdline
6. [x] Fix boot regression: `omarchy_resume.conf` was dropping `plymouth` and `btrfs-overlayfs` hooks from Omarchy's `omarchy_hooks.conf`, causing text-mode LUKS password prompt. Fixed by `fix-resume-hooks.sh` -- **done, verified**
7. [x] Reboot and verify Plymouth graphical boot is restored (no extra password prompt) -- **done, working**
8. [x] Test hibernate progressively -- **done**: reboot-mode and full platform hibernate both successful, session restores correctly

### Rollback Plan
If anything goes wrong:
1. Boot normally (kernel ignores stale hibernate image without resume params)
2. Remove resume params from `/etc/default/limine`
3. Run `sudo limine-mkinitcpio`
4. Reboot
5. To fully undo: run `omarchy-hibernation-remove`

---

## Audio Issue: No Sound from Speakers

### Problem
Sound was working previously but stopped. pavucontrol shows playback activity but no actual audio. Output devices show as generic "sof-soundwire Pro" ports instead of real hardware names (Speaker, Headphone).

### Hardware
- **Audio controller**: Intel Arrow Lake cAVS (`00:1f.3`)
- **Codecs**: RT711-SDCA (headphone, SoundWire link 0) + RT1316 (speaker amp, SoundWire link 3)
- **SOF driver**: `sof-audio-pci-intel-mtl`
- **Topology**: `sof-arl-rt711-l0-rt1316-l3-2ch.tplg` (loads successfully)
- **SOF firmware**: 2.14.1.1 (boots successfully)
- **ALSA card 1**: `sof-soundwire` -- PCM devices: Jack Out, Speaker, DMIC Raw, Amp feedback, Deepbuffer Jack Out

### Root Cause Analysis
1. **SoundWire communication failure** in dmesg:
   ```
   soundwire_intel soundwire_intel.link.0: SCP Msg trf timed out
   soundwire sdw-master-0-0: trf on Slave 6 failed:-5 write addr 8789 count 0
   ```
   The codec hardware isn't responding to the SoundWire controller.

2. **UCM HiFi verb fails** (WirePlumber log):
   ```
   spa.alsa: Failed to get the verb HiFi
   spa.alsa: No UCM verb is valid for <<<SplitPCM=1>>>hw:1
   ```
   Because the codec didn't initialize, the mixer controls UCM needs don't exist. Falls back to "Pro" profile with generic port names and no proper speaker routing.

### Package Timeline (from pacman.log)
- **Feb 5**: Omarchy installed -- kernel 6.18.3, alsa-ucm-conf 1.2.15.1, pipewire 1.4.9, sof-firmware 2025.12
- **Feb 6 ~6am**: Upgraded -- kernel **6.18.7**, alsa-ucm-conf **1.2.15.3**, pipewire **1.4.10**, sof-firmware **2025.12.2**
- Sound worked before but timing of breakage vs upgrade is uncertain

### Installed Audio Packages
- `sof-firmware` 2025.12.2-1
- `alsa-ucm-conf` 1.2.15.3-1
- `alsa-lib` 1.2.15.3-2
- `alsa-utils` (installed during debugging)
- `pipewire` 1.4.10-2
- `wireplumber` 0.5.13-1

### Fixes Applied So Far
1. [x] Installed `alsa-utils` for diagnostic tools
2. [x] Tried module reload (`modprobe -r/modprobe snd_sof_pci_intel_mtl`) -- did not help
3. [x] Added `disable_function_topology=1` workaround -- did not help (not the root cause)
4. [x] Downgraded kernel 6.18.7 -> 6.18.3 (+ sof-firmware 2025.12, alsa-ucm-conf 1.2.15.1) -- SoundWire timeout persisted, audio still broken
5. [x] **FIXED**: Cleared WirePlumber cached profile (`~/.local/state/wireplumber/default-profile` had `pro-audio` cached), restarted audio stack -- Speaker/Headphone/Mic all working

### Root Cause (Resolved)
**Race condition + cached fallback**: SoundWire codec init is slow (SCP timeout at boot), WirePlumber tries UCM HiFi before codec is ready, fails, falls back to `pro-audio`, and caches that choice in `~/.local/state/wireplumber/default-profile`. Even after codec finishes initializing, WirePlumber never retries HiFi. Clearing the cache and restarting fixes it. See `AUDIO_FIX.md` for full details.

### Cleanup TODO
- [x] Removed `/etc/modprobe.d/sof-workaround.conf` (`disable_function_topology=1`) -- unnecessary on kernel 6.18.3
- [x] Upgraded packages back to current (kernel 6.18.7, sof-firmware 2025.12.2, alsa-ucm-conf 1.2.15.3) -- audio works

### Relevant Research
- [thesofproject/linux#5526](https://github.com/thesofproject/linux/issues/5526) -- kernel 6.16+ function topology change breaks SoundWire devices
- [thesofproject/sof#10201](https://github.com/thesofproject/sof/issues/10201) -- HP OMEN Transcend 14 ARL topology issues
- [Arch forums #310227](https://bbs.archlinux.org/viewtopic.php?id=310227) -- kernel 6.17.8+ GPIO regression breaks SoundWire codec init
- UCM profiles exist at `/usr/share/alsa/ucm2/sof-soundwire/` with rt711-sdca.conf and rt1316.conf

### Rollback (if needed)
```bash
sudo rm /etc/modprobe.d/sof-workaround.conf
# If kernel was downgraded:
sudo pacman -S linux linux-headers
```
