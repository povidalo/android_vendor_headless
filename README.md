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
  (no Doze, no Wi-Fi suspend optimizations).
- `adb/adb_keys.pub`: fallback ADB key (builds run with `WITH_ADB_INSECURE=true`).
- `tools/build-in-vm.sh DEVICE TARGET...`: the build, as run in the build VM.

Not in git (copied in by the build host before every build, see `.gitignore`):
the APKs bundled into the ROM (`headless_apps/prebuilt/`) and the SSH public key
allowed to log in to Termux's sshd (`headless_apps/termux_authorized_keys`).
