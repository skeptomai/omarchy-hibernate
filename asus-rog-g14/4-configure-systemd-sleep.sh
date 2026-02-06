#!/bin/bash
set -euo pipefail

echo "=== ASUS ROG G14 - Step 4: Configure systemd Sleep and Logind ==="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (use sudo)"
   exit 1
fi

echo "Step 1/2: Creating /etc/systemd/sleep.conf.d/hibernate.conf..."
mkdir -p /etc/systemd/sleep.conf.d

cat > /etc/systemd/sleep.conf.d/hibernate.conf << 'EOF'
[Sleep]
# Suspend for 30 minutes, then hibernate (saves battery)
HibernateDelaySec=30min

# Don't hibernate when on AC power (only on battery)
# Change to 'yes' if you want hibernate even when plugged in
HibernateOnACPower=no
EOF

echo "Created:"
cat /etc/systemd/sleep.conf.d/hibernate.conf

echo ""
echo "Step 2/2: Creating /etc/systemd/logind.conf.d/lid.conf..."
mkdir -p /etc/systemd/logind.conf.d

cat > /etc/systemd/logind.conf.d/lid.conf << 'EOF'
[Login]
# When lid is closed, suspend-then-hibernate
# After 30 min (from HibernateDelaySec), will hibernate
HandleLidSwitch=suspend-then-hibernate
EOF

echo "Created:"
cat /etc/systemd/logind.conf.d/lid.conf

echo ""
echo "=== Summary ==="
echo "✓ systemd sleep configured for suspend-then-hibernate"
echo "✓ Lid close will trigger suspend-then-hibernate"
echo "✓ After 30 minutes of suspend, system will hibernate (on battery only)"
echo ""
echo "Created files:"
echo "  /etc/systemd/sleep.conf.d/hibernate.conf"
echo "  /etc/systemd/logind.conf.d/lid.conf"
echo ""
echo "Step 4 complete. Continue with step 5 to build."
