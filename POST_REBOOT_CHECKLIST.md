# Post-Reboot Checklist

## Step 7: Verify Plymouth Boot Fix

1. **Plymouth graphical LUKS prompt** — Did you see the graphical password prompt (not text-mode)?
2. **No double prompts** — Only one password prompt, not two?

## Verify Config Survived Reboot

3. **Kernel cmdline has resume params:**
   ```
   cat /proc/cmdline
   ```
   Should contain: `resume=/dev/mapper/root resume_offset=4368046`

4. **Swap is active:**
   ```
   swapon --show
   ```
   Should show `/swap/swapfile` (30.7G, pri=0) and `/dev/zram0`

5. **NVIDIA services running:**
   ```
   systemctl status nvidia-hibernate.service nvidia-resume.service nvidia-suspend.service
   ```

## Step 8: Test Hibernate Progressively

Once the above checks pass, test in order:

### 8a. Suspend (safest baseline)
```
sudo systemctl suspend
```
Wake with power button or lid open. Confirm desktop restored.

### 8b. Hibernate reboot-mode (safer hibernate test)
```
echo reboot | sudo tee /sys/power/disk && sudo systemctl hibernate
```
System should hibernate, then reboot and restore session. Confirm desktop restored.

### 8c. Full hibernate
```
sudo systemctl hibernate
```
System should power off. Press power button to boot, should restore session.

### 8d. Suspend-then-hibernate (end goal)
Close laptop lid. Wait 30+ minutes. Open lid. Should restore from hibernate.

## Rollback Plan (If Something Goes Wrong)

1. Boot normally (kernel ignores stale hibernate image)
2. Remove resume params: edit `/etc/default/limine`, remove the `resume=` line
3. Regenerate: `sudo limine-mkinitcpio`
4. Reboot
5. Full undo: `omarchy-hibernation-remove`
