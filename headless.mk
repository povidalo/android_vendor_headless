#
# Headless server pieces shared by our LineageOS 20 devices (S8+ dream2lte,
# Redmi Note 4 mido). A device uses them with
#
#   device.mk:       $(call inherit-product, vendor/headless/headless.mk)
#   BoardConfig.mk:  include vendor/headless/BoardConfigHeadless.mk
#
# and is built with WITH_ADB_INSECURE=true (vendor/headless/tools/build-in-vm.sh).
#

# Headless server: ADB must be on from first boot.
# ADB authorization is disabled (WITH_ADB_INSECURE=true in build.sh -> ro.adb.secure=0).
# PRODUCT_ADB_KEYS below is only a fallback if a build is made without it.
PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.usb.config=mtp,adb

# Pre-authorized ADB key(s) for the headless setup (installed as /adb_keys on userdebug/eng).
PRODUCT_ADB_KEYS := vendor/headless/adb/adb_keys.pub

# headless_su: password-gated root (Termux) without Magisk; replaces AOSP debug su.
# headless_boot runs the root boot scripts in /data/local/boot.d.
PRODUCT_PACKAGES += \
    headless_su \
    set_root_pwd \
    headless_boot

# ROM boot scripts run by headless_boot before /data/local/boot.d: stay awake
# (no Doze, battery saver or Wi-Fi power save, plus Wi-Fi/framework overlays;
# the CPU wakelock itself is taken in headless_su/sud.rc), bundled apps with
# all permissions, Termux SSH (sshd on 8022, key or password login) and USB
# snapshots after each boot (/data/local/usb-boot.log); plus the USB-C role
# watcher (init service headless_usb_role in headless_su/sud.rc).
PRODUCT_PACKAGES += \
    headless_boot_02-stay-awake \
    HeadlessWifiOverlay \
    HeadlessFrameworkOverlay \
    headless_boot_05-wifi-country \
    headless_boot_10-apps \
    headless_boot_20-termux \
    headless_boot_30-usb-report \
    headless_usb_role_watch \
    headless_termux_sshd \
    headless_termux_default_authinfo \
    headless_termux_first_login

# Server upkeep, more ROM boot scripts and a tool: a weekly fstrim (Android
# only trims when idle and charging), data disks mounted by UUID outside vold
# (/data/local/disks.conf), and headless_service, which keeps server programs
# running as supervised services from boot.d scripts.
PRODUCT_PACKAGES += \
    headless_boot_40-fstrim \
    headless_boot_50-data-disks \
    headless_service

# Apps a server does without: OTA Updater, FM radio, backup, wallpaper apps,
# Calculator, Recorder (see remove_packages/Android.mk).
PRODUCT_PACKAGES += \
    HeadlessRemovePackages

# No Rescue Party. After repeated crashes of a core process it escalates to a
# reboot into recovery with a factory-reset prompt; on userdebug it only stays
# off while USB is connected. An unattended server must not end up waiting
# in recovery.
PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.disable_rescue=true

# Persistent logs: logcatd writes all log buffers (main, system, crash,
# events, radio, kernel) to /data/misc/logd/logcat* and keeps them across
# reboots, 64 files of 1 MB at most; 'logpersist.stop' turns it off. The
# in-memory buffers grow from 256 KB to 2 MB each, for logcat -d; that is done
# in headless_su/sud.rc, because Android 13's logd ignores ro.logd.size.
PRODUCT_SYSTEM_PROPERTIES += \
    persist.logd.logpersistd=logcatd \
    persist.logd.logpersistd.size=64 \
    persist.logd.logpersistd.rotate_kbytes=1024

# Apps installed on first boot by 10-apps (Termux, its plugins, F-Droid): not
# in git (Termux alone is 109 MB), copied in by the Mac build script as
# headless_apps/prebuilt/<package>.apk. Shipped as .apk.bin because
# PRODUCT_COPY_FILES refuses .apk destinations.
PRODUCT_COPY_FILES += \
    $(foreach f,$(wildcard vendor/headless/headless_apps/prebuilt/*.apk),\
        $(f):$(TARGET_COPY_OUT_SYSTEM)/etc/headless/apps/$(notdir $(f)).bin)

# SSH public keys for Termux's sshd: not in git, copied in by the Mac build
# script before every build (the build host's key); installed only if present.
PRODUCT_COPY_FILES += \
    $(foreach f,$(wildcard vendor/headless/headless_apps/termux_authorized_keys),\
        $(f):$(TARGET_COPY_OUT_SYSTEM)/etc/headless/termux_authorized_keys)
