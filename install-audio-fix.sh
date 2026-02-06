#!/bin/bash
#
# install-audio-fix.sh — Install the SoundWire profile fix service
#
# Installs:
#   /usr/local/bin/fix-soundwire-profile          (main script)
#   /etc/systemd/system/fix-soundwire-profile.service  (systemd unit)
#   /usr/lib/systemd/system-sleep/fix-soundwire-profile (sleep hook)
#
# Must be run as root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root (try: sudo $0)" >&2
    exit 1
fi

echo "Installing SoundWire profile fix..."

# 1. Main script
echo "  -> /usr/local/bin/fix-soundwire-profile"
install -Dm755 "$SCRIPT_DIR/fix-soundwire-profile" /usr/local/bin/fix-soundwire-profile

# 2. systemd service
echo "  -> /etc/systemd/system/fix-soundwire-profile.service"
install -Dm644 "$SCRIPT_DIR/fix-soundwire-profile.service" /etc/systemd/system/fix-soundwire-profile.service
systemctl daemon-reload
systemctl enable fix-soundwire-profile.service

# 3. Sleep hook
echo "  -> /usr/lib/systemd/system-sleep/fix-soundwire-profile"
install -Dm755 "$SCRIPT_DIR/fix-soundwire-profile-sleep" /usr/lib/systemd/system-sleep/fix-soundwire-profile

echo ""
echo "Done! Service status:"
systemctl status fix-soundwire-profile.service --no-pager || true
echo ""
echo "Test with: sudo systemctl start fix-soundwire-profile.service"
echo "Logs:      journalctl -u fix-soundwire-profile -n 20"
