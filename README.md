# vendor/headless

Headless server pieces shared by our LineageOS 20 (Android 13) builds:

| Device | Codename | Device tree |
|---|---|---|
| Samsung Galaxy S8+ (SM-G955F) | `dream2lte` | `povidalo/android_device_samsung_dream2lte` |
| Xiaomi Redmi Note 4 (Snapdragon) | `mido` | `povidalo/android_device_xiaomi_mido` |

A device uses them with

```make
# device.mk
$(call inherit-product, vendor/headless/headless.mk)
# BoardConfig.mk
include vendor/headless/BoardConfigHeadless.mk
```

## Contents

- `headless_su/`: password-gated root without Magisk. `su` (client + daemon `sud`,
  installed as `/system/bin/su`), `set_root_pwd`, the permissive `sud` sepolicy
  domain, and `headless_boot`, which runs the ROM's boot scripts and then the
  user's `/data/local/boot.d` as root. `sud.rc` also takes the kernel wakelock
  `headless_server` on boot: the phone never suspends.
- `headless_apps/`: the ROM boot scripts in `/system/etc/headless/boot.d`
  (stay awake, Wi-Fi country, bundled apps with all permissions, Termux sshd,
  USB snapshots), the USB watcher (USB-C role fix where there is a Type-C port;
  keeps USB devices from autosuspending everywhere), and two static overlays
  (no Doze, no PinnerService pinning, no Wi-Fi suspend optimizations).
- More ROM boot scripts:
  - `40-fstrim`: a weekly `sm fstrim`. Android only trims in idle maintenance, which needs the device idle and charging.
  - `50-data-disks`: data disks listed in `/data/local/disks.conf` (`UUID NAME [options]`), mounted by UUID at `/data/local/disks/NAME`, outside vold (no auto-mount, no media scanning). USB disks, SD cards and loop devices only, never internal storage or a disk mounted elsewhere (found by device number, since vold mounts its own nodes). Log: `/data/local/disks.log`.
- `headless_service` (`/system/bin`): keeps server programs running from `/data/local/boot.d` scripts. `headless_service start NAME [-u termux|root] -- 'command line'` starts a supervised service. It restarts the program when it exits, logs to `/data/local/services/NAME.log`, and runs outside any app, so Android's low-memory killer leaves it alone. Also `stop`, `restart`, `status` and `log`.
- `remove_packages/`: drops apps a server does without (OTA Updater, FM radio, backup, wallpaper apps, Calculator, Recorder), and to save memory AudioFX, mido's Dolby apps and SecureElement.
- Memory: PinnerService pins nothing (it mlock()ed ~240 MB on mido: framework, SystemUI, graphics libraries, the launcher).
- Stability: Rescue Party is off (`persist.sys.disable_rescue`), so repeated crashes never end in a factory-reset prompt in recovery. Logs persist across reboots in `/data/misc/logd` (logcatd, 64 MB at most; `logpersist.stop` turns it off). In-memory log buffers are 2 MB, set by `logcat -G` from `sud.rc`, because Android 13's logd ignores `ro.logd.size`.
- `adb/adb_keys.pub`: fallback ADB key (builds run with `WITH_ADB_INSECURE=true`).
- `tools/build-in-vm.sh DEVICE TARGET...`: the build, as run in the build VM.

Not in git (copied in by the build host before every build, see `.gitignore`):
the APKs bundled into the ROM (`headless_apps/prebuilt/`) and the SSH public key
allowed to log in to Termux's sshd (`headless_apps/termux_authorized_keys`).
