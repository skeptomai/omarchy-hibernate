#!/bin/bash
echo "=== DMESG: SOF/SoundWire/Topology ==="
dmesg | grep -iE 'sof|soundwire|sdw|tplg|topology|snd_sof|function.topo|codec|rt711|rt1316|cs42l43|cs35l56' | tail -80

echo ""
echo "=== DMESG: Firmware loading ==="
dmesg | grep -iE 'firmware.*intel|intel.*firmware|firmware.*sof|sof.*firmware' | tail -20

echo ""
echo "=== ASOUND CARDS ==="
cat /proc/asound/card1/codec* 2>/dev/null || echo "(no codec files)"

echo ""
echo "=== ASOUND PCM ==="
cat /proc/asound/card1/pcm*/info 2>/dev/null | head -60

echo ""
echo "=== SOF FW VERSION ==="
cat /sys/kernel/debug/sof/fw_version 2>/dev/null || echo "(not available)"

echo ""
echo "=== SOF CHIP INFO ==="
cat /sys/kernel/debug/sof/chip_info 2>/dev/null || echo "(not available)"

echo ""
echo "=== SOUNDWIRE DEVICES ==="
find /sys/bus/soundwire/devices/ -maxdepth 2 -name 'modalias' -exec sh -c 'echo "--- $1 ---"; cat "$1"' _ {} \; 2>/dev/null || echo "(none)"

echo ""
echo "=== LOADED SOUND MODULES ==="
lsmod | grep -iE 'snd|sof|soundwire|sdw'

echo ""
echo "=== SOF MODULE PARAMS ==="
for f in /sys/module/snd_sof*/parameters/*; do echo "$f = $(cat "$f" 2>/dev/null)"; done 2>/dev/null

echo ""
echo "=== AMIXER CONTENTS (card 1) ==="
amixer -c1 contents 2>/dev/null || echo "(amixer not found or card1 not available)"

echo ""
echo "=== PACMAN LOG: recent audio package updates ==="
grep -iE 'sof-firmware|alsa-ucm|alsa-lib|pipewire|wireplumber|linux ' /var/log/pacman.log | tail -30

echo ""
echo "=== TOPOLOGY FILE LOADED ==="
dmesg | grep -i 'tplg' | grep -iE 'loaded|error|fail|not found'
