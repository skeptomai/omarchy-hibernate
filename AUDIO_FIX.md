# Audio Fix: HP OMEN Transcend 14 (Arrow Lake / SoundWire)

## Summary

Sound stopped working after a package upgrade. Outputs appeared as generic "Pro" ports in PipeWire/pavucontrol instead of real hardware names (Speaker, Headphone). No audio from speakers or headphones despite playback meters showing activity.

**Root cause**: A race condition between SoundWire codec initialization and WirePlumber's UCM profile setup. WirePlumber tried to activate the UCM "HiFi" verb before the SoundWire codecs finished initializing, failed, fell back to the `pro-audio` profile, and **cached that fallback permanently** in its state file.

**Fix**: Clear the WirePlumber cached profile and restart the audio stack.

## Hardware

| Component | Detail |
|-----------|--------|
| Audio controller | Intel Arrow Lake cAVS (`00:1f.3`) |
| Headphone codec | RT711-SDCA (SoundWire link 0) |
| Speaker amp | RT1316 (SoundWire link 3) |
| SOF driver | `sof-audio-pci-intel-mtl` |
| Topology | `sof-arl-rt711-l0-rt1316-l3-2ch.tplg` |
| SOF firmware | 2.14.1.1 |
| ALSA card | card 1: `sof-soundwire` |

## Symptoms

1. **pavucontrol / wpctl**: Outputs listed as "Arrow Lake cAVS Pro", "Pro 2", "Pro 5", etc. instead of "Speaker", "Headphones", "Digital Microphone"
2. **No sound**: Playback meters move but no audio reaches speakers or headphones
3. **dmesg** shows SoundWire timeout during early boot:
   ```
   soundwire_intel soundwire_intel.link.0: SCP Msg trf timed out
   soundwire sdw-master-0-0: trf on Slave 6 failed:-5 write addr 8789 count 0
   ```
4. **WirePlumber log** shows UCM failure:
   ```
   spa.alsa: Failed to get the verb HiFi
   spa.alsa: No UCM verb is valid for <<<SplitPCM=1>>>hw:1
   ```

## Root Cause Analysis

### The race condition

1. During boot, the SOF driver initializes and the SoundWire bus enumerates the codecs (RT711-SDCA, RT1316)
2. SoundWire codec initialization involves SCP (SoundWire Configuration Port) message transfers, which can take several seconds
3. WirePlumber starts and tries to configure audio devices using ALSA UCM (Use Case Manager)
4. UCM tries to activate the "HiFi" verb, which requires ALSA mixer controls that only exist after the codec fully initializes
5. If the codec hasn't finished initializing, UCM fails to find the required controls and the HiFi verb fails
6. WirePlumber falls back to the `pro-audio` profile (generic, no UCM, no proper port routing)

### The caching problem

WirePlumber saves the active profile for each device in:
```
~/.local/state/wireplumber/default-profile
```

When it falls back to `pro-audio`, it writes:
```ini
[default-profile]
alsa_card.pci-0000_00_1f.3-platform-sof_sdw=pro-audio
```

On subsequent restarts (including `systemctl --user restart wireplumber`), WirePlumber reads this cached profile and applies `pro-audio` directly **without re-probing UCM**. This means even though the codec eventually finishes initializing and the ALSA mixer controls become available, WirePlumber never retries HiFi.

### Key evidence

The ALSA mixer controls **do exist** after the codec finishes initializing (even during the same boot):
```bash
$ amixer -c 1 scontrols
Simple mixer control 'Headphone',0
Simple mixer control 'Speaker',0
Simple mixer control 'rt1316-1 DAC',0
# ... etc
```

And `alsaucm` can activate HiFi just fine:
```bash
$ alsaucm -c sof-soundwire list _verbs
  0: HiFi
    Play HiFi quality Music
```

But WirePlumber's cached `pro-audio` selection prevents it from trying.

## Fix

### Quick fix (no reboot needed)

Clear the cached profile and restart the audio stack:

```bash
# Clear WirePlumber's cached profile selection
cat > ~/.local/state/wireplumber/default-profile << 'EOF'
[default-profile]
EOF

# Restart the audio stack
systemctl --user restart wireplumber pipewire pipewire-pulse

# Verify (should show Speaker, Headphones, Digital Microphone)
sleep 3 && wpctl status
```

### Verify it worked

`wpctl status` should show:
```
 ├─ Sinks:
 │      Arrow Lake cAVS HDMI / DisplayPort 3 Output
 │      Arrow Lake cAVS HDMI / DisplayPort 2 Output
 │      Arrow Lake cAVS HDMI / DisplayPort 1 Output
 │      Arrow Lake cAVS Headphones
 │  *   Arrow Lake cAVS Speaker              ← default sink
 │
 ├─ Sources:
 │      Arrow Lake cAVS Headset Microphone
 │  *   Arrow Lake cAVS Digital Microphone   ← default source
```

Test audio:
```bash
speaker-test -c 2 -t wav
```

### Persistent fix (survive future reboots)

The race condition can recur on any boot where the SoundWire codec is slow to initialize. If it happens again, just re-run the quick fix above.

To make WirePlumber more resilient, you could add a WirePlumber rule to prefer HiFi over pro-audio for this card. Create `~/.config/wireplumber/wireplumber.conf.d/prefer-hifi.conf`:

```
monitor.alsa.rules = [
  {
    matches = [
      { device.name = "alsa_card.pci-0000_00_1f.3-platform-sof_sdw" }
    ]
    actions = {
      update-props = {
        api.acp.auto-profile = true
      }
    }
  }
]
```

## What the kernel downgrade did (and didn't do)

A kernel downgrade from 6.18.7 to 6.18.3 was performed as a troubleshooting step (along with sof-firmware and alsa-ucm-conf). **The downgrade did not fix audio by itself** because the root cause was WirePlumber's cached profile, not a kernel regression.

However, kernel 6.18.7 may independently have SoundWire issues (see related bugs below). The SoundWire timeout occurs on both kernels, but it's transient -- the codec does eventually initialize.

### Packages after downgrade

| Package | Before | After |
|---------|--------|-------|
| linux | 6.18.7-arch1-1 | 6.18.3-arch1-1 |
| linux-headers | 6.18.7-arch1-1 | 6.18.3-arch1-1 |
| sof-firmware | 2025.12.2-1 | 2025.12-1 |
| alsa-ucm-conf | 1.2.15.3-1 | 1.2.15.1-1 |

### The `disable_function_topology` workaround

The file `/etc/modprobe.d/sof-workaround.conf` was created with:
```
options snd_sof disable_function_topology=1
```

This was applied as a speculative fix for kernel 6.18.7 based on [thesofproject/linux#5526](https://github.com/thesofproject/linux/issues/5526). On kernel 6.18.3, this parameter may be unnecessary. It can be removed:
```bash
sudo rm /etc/modprobe.d/sof-workaround.conf
```

## Diagnostic commands

```bash
# Check current audio profile and devices
wpctl status

# Check SoundWire device status
cat /sys/bus/soundwire/devices/sdw:*/status

# Check ALSA mixer controls exist (card 1 = sof-soundwire)
amixer -c 1 scontrols

# Check UCM verbs are accessible
alsaucm -c sof-soundwire list _verbs

# Check WirePlumber's cached profile
cat ~/.local/state/wireplumber/default-profile

# Check kernel log for SoundWire errors
journalctl -b -k | grep -iE 'soundwire|sdw|sof|rt711|rt1316'

# Check WirePlumber log for UCM errors
journalctl -b --user-unit wireplumber | grep -iE 'ucm|verb|hifi'
```

## Related bugs and references

- [thesofproject/linux#5526](https://github.com/thesofproject/linux/issues/5526) -- kernel 6.16+ function topology change breaks SoundWire devices
- [thesofproject/sof#10201](https://github.com/thesofproject/sof/issues/10201) -- HP OMEN Transcend 14 ARL topology issues
- [Arch forums #310227](https://bbs.archlinux.org/viewtopic.php?id=310227) -- kernel 6.17.8+ GPIO regression breaks SoundWire codec init
- UCM profiles: `/usr/share/alsa/ucm2/sof-soundwire/` (rt711-sdca.conf, rt1316.conf)
- WirePlumber state: `~/.local/state/wireplumber/default-profile`

## Timeline

1. **Feb 5**: Omarchy installed, sound working (kernel 6.18.3, sof-firmware 2025.12, alsa-ucm-conf 1.2.15.1)
2. **Feb 6 ~6am**: Package upgrade (kernel 6.18.7, sof-firmware 2025.12.2, alsa-ucm-conf 1.2.15.3)
3. **Feb 6**: Sound found broken -- SoundWire timeout at boot, WirePlumber falls back to pro-audio and caches it
4. **Feb 6**: Attempted fixes: module reload (no help), `disable_function_topology=1` (no help)
5. **Feb 6**: Kernel downgrade to 6.18.3 -- SoundWire timeout still occurs, audio still broken (cached profile)
6. **Feb 6**: Cleared `~/.local/state/wireplumber/default-profile`, restarted audio stack -- **fixed**
