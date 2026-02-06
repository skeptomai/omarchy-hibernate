#!/bin/bash
set -euo pipefail

# Upgrade packages back to current and apply the WirePlumber audio fix.
#
# Background: kernel + audio packages were downgraded from 6.18.7 to 6.18.3
# while debugging a SoundWire/WirePlumber issue. The real fix turned out to be
# clearing WirePlumber's cached pro-audio profile, not the downgrade. This
# script upgrades to current packages and pre-applies the fix.
#
# Usage:
#   sudo ./upgrade-and-fix-audio.sh
#   # then reboot
#   # after login, run: ./upgrade-and-fix-audio.sh --post-reboot

if [[ "${1:-}" == "--post-reboot" ]]; then
    # --- Post-reboot: fix WirePlumber and verify ---
    echo "=== Post-reboot: applying WirePlumber fix ==="

    WP_STATE="$HOME/.local/state/wireplumber/default-profile"

    echo "Clearing WirePlumber cached profile..."
    cat > "$WP_STATE" << 'WPEOF'
[default-profile]
WPEOF

    echo "Restarting audio stack..."
    systemctl --user restart wireplumber pipewire pipewire-pulse
    sleep 3

    echo ""
    echo "=== Audio device check ==="
    wpctl status | grep -A 20 'Sinks:'

    echo ""
    echo "=== Verification ==="
    if wpctl status | grep -q 'Speaker'; then
        echo "SUCCESS: Speaker output detected. Audio should be working."
        echo ""
        echo "Test with:  speaker-test -c 2 -t wav"
    else
        echo "WARNING: Speaker output not found. Still showing generic Pro profiles."
        echo ""
        echo "Check WirePlumber logs:"
        echo "  journalctl -b --user-unit wireplumber | grep -iE 'ucm|verb|hifi'"
        echo ""
        echo "If this is a real kernel regression, downgrade with:"
        echo "  ./downgrade-audio.sh"
        exit 1
    fi

    exit 0
fi

# --- Pre-reboot: upgrade packages ---
if [[ $EUID -ne 0 ]]; then
    echo "Error: pre-reboot steps require root. Run with sudo." >&2
    echo "Usage:" >&2
    echo "  sudo $0            # upgrade packages (pre-reboot)" >&2
    echo "  $0 --post-reboot   # fix audio (after reboot, no sudo)" >&2
    exit 1
fi

echo "=== Current package versions ==="
pacman -Q linux linux-headers sof-firmware alsa-ucm-conf

echo ""
echo "=== Available upgrades ==="
pacman -Si linux sof-firmware alsa-ucm-conf 2>/dev/null | grep -E '^(Name|Version)'

echo ""
echo "=== Upgrading all packages ==="
pacman -Syu

echo ""
echo "=== Regenerating initramfs/UKI ==="
limine-mkinitcpio

echo ""
echo "=== Updated package versions ==="
pacman -Q linux linux-headers sof-firmware alsa-ucm-conf

echo ""
echo "=== Done. Reboot now, then run: ==="
echo "  ./upgrade-and-fix-audio.sh --post-reboot"
