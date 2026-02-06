# Omarchy Hibernate Configuration

Multi-laptop hibernate setup repository for Omarchy Linux systems.

## Repository Structure

```
omarchy-hibernate/
├── README.md                 # This file
├── CLAUDE.md                 # HP OMEN documentation (historical reference)
├── asus-rog-g14/             # ASUS ROG G14 Zephyrus GU603Z configuration
│   ├── ASUS_HIBERNATE_SETUP.md
│   ├── setup-hibernate.sh    # Master setup script
│   ├── 1-create-swapfile.sh
│   ├── 2-configure-nvidia-hibernate.sh
│   ├── 3-configure-resume.sh
│   ├── 4-configure-systemd-sleep.sh
│   └── 5-build-and-verify.sh
└── hp-omen-transcend/        # HP OMEN Transcend 14 configuration
    ├── CLAUDE.md             # Linked from root (for context)
    ├── AUDIO_FIX.md
    ├── POST_REBOOT_CHECKLIST.md
    ├── fix-hibernate.sh
    ├── fix-nvidia-hibernate.sh
    ├── fix-resume-hooks.sh
    └── (audio-related scripts)
```

## Laptops Configured

### ASUS ROG G14 Zephyrus GU603Z (Current)
- **GPU**: NVIDIA RTX 3070 Ti Laptop
- **GPU Management**: supergfxctl (MUX switch, AsusMuxDgpu mode)
- **RAM**: 40 GB
- **Status**: Scripts ready, not yet run
- **Documentation**: [asus-rog-g14/ASUS_HIBERNATE_SETUP.md](asus-rog-g14/ASUS_HIBERNATE_SETUP.md)

### HP OMEN Transcend 14 (Previous)
- **GPU**: Intel Arc Pro 130T/140T + NVIDIA (hybrid via envycontrol)
- **RAM**: 30 GB
- **Status**: Fully configured and tested
- **Documentation**: [CLAUDE.md](CLAUDE.md) (root) and [hp-omen-transcend/](hp-omen-transcend/)

## Quick Start

### For ASUS ROG G14

1. Navigate to the ASUS directory:
   ```bash
   cd asus-rog-g14
   ```

2. Read the documentation:
   ```bash
   less ASUS_HIBERNATE_SETUP.md
   ```

3. Run the master setup script:
   ```bash
   sudo ./setup-hibernate.sh
   ```

   Or run steps individually:
   ```bash
   sudo ./1-create-swapfile.sh
   sudo ./2-configure-nvidia-hibernate.sh
   sudo ./3-configure-resume.sh
   sudo ./4-configure-systemd-sleep.sh
   sudo ./5-build-and-verify.sh
   ```

4. Reboot and verify

### For HP OMEN (Reference)

Scripts in `hp-omen-transcend/` are kept for reference. The HP OMEN setup is complete and documented in `CLAUDE.md`.

## Key Differences Between Laptops

| Feature | ASUS ROG G14 | HP OMEN Transcend 14 |
|---------|--------------|----------------------|
| GPU | NVIDIA RTX 3070 Ti | Intel Arc + NVIDIA |
| GPU Tool | supergfxctl | envycontrol |
| MUX Switch | Yes (AsusMuxDgpu) | No |
| RAM | 40 GB | 30 GB |
| Swapfile Size | 41 GB | 30.7 GB |
| Early KMS | Removed for hibernate | Removed for hibernate |
| Audio Issues | None | SoundWire race condition |

## Common Omarchy Hibernate Issues

Both laptops address the same Omarchy bug (Issue #4259):
- `omarchy-hibernation-setup` fails to add `resume=` and `resume_offset=` to kernel cmdline
- Scripts in this repo properly configure `/etc/default/limine`
- Both require NVIDIA hibernate params and early KMS removal

## NVIDIA Hibernate Configuration

Both laptops use similar NVIDIA configuration:
```bash
# /etc/modprobe.d/nvidia.conf
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
```

And both remove nvidia modules from early initramfs:
```bash
# /etc/mkinitcpio.conf.d/nvidia.conf (commented out)
# MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

## Testing Hibernate

After setup, test progressively:

1. **Test mode** (safe, just verifies):
   ```bash
   echo test | sudo tee /sys/power/disk
   sudo systemctl hibernate
   ```

2. **Reboot mode** (hibernates but reboots):
   ```bash
   echo reboot | sudo tee /sys/power/disk
   sudo systemctl hibernate
   ```

3. **Platform mode** (full hibernate):
   ```bash
   echo platform | sudo tee /sys/power/disk
   sudo systemctl hibernate
   ```

4. **Suspend-then-hibernate**:
   ```bash
   # Close lid for 30+ minutes
   ```

## Rollback

If anything goes wrong:
1. Boot normally (kernel ignores stale hibernate image)
2. Restore backups from `/etc/*.backup`
3. Remove resume params from `/etc/default/limine`
4. Run `sudo limine-mkinitcpio`
5. Reboot

Or use Omarchy's built-in removal:
```bash
sudo omarchy-hibernation-remove
```

## References

- [Omarchy GitHub Issue #4259](https://github.com/basecamp/omarchy/issues/4259) - hibernate setup bug
- [NVIDIA Power Management](https://download.nvidia.com/XFree86/Linux-x86_64/435.17/README/powermanagement.html)
- [Arch Wiki - Power Management/Suspend and Hibernate](https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate)
- [ASUS Linux](https://asus-linux.org/) - supergfxctl documentation

## License

These scripts are provided as-is for personal use. Modify as needed for your system.
