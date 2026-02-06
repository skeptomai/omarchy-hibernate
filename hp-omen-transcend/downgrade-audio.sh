#!/bin/bash
set -euo pipefail

# Downgrade kernel + audio packages to pre-regression versions
# Sound broke after Feb 6 upgrade: kernel 6.18.3->6.18.7, sof-firmware, alsa-ucm-conf
# SoundWire codec init fails on 6.18.7 (SCP Msg trf timed out)

CACHE=/var/cache/pacman/pkg

echo "=== Downgrading packages ==="
echo "  linux          6.18.7 -> 6.18.3"
echo "  linux-headers  6.18.7 -> 6.18.3"
echo "  sof-firmware   2025.12.2 -> 2025.12"
echo "  alsa-ucm-conf  1.2.15.3 -> 1.2.15.1"
echo

sudo pacman -U \
  "$CACHE/linux-6.18.3.arch1-1-x86_64.pkg.tar.zst" \
  "$CACHE/linux-headers-6.18.3.arch1-1-x86_64.pkg.tar.zst" \
  "$CACHE/sof-firmware-2025.12-1-x86_64.pkg.tar.zst" \
  "$CACHE/alsa-ucm-conf-1.2.15.1-1-any.pkg.tar.zst"

echo
echo "=== Regenerating initramfs/UKI ==="
sudo limine-mkinitcpio

echo
echo "=== Done. Reboot to test audio. ==="
echo "After reboot, check:"
echo "  uname -r                  # should be 6.18.3-arch1-1"
echo "  wpctl status              # should show Speaker/Headphone, not Pro"
echo "  speaker-test -c 2 -t wav  # should produce sound"
