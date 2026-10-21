# Apps the headless servers do without (the user's choice, 10-20): the
# LineageOS OTA Updater (it only checks for official builds), FM radio, backup
# (Seedvault and its contacts helper), wallpaper apps (Backgrounds, live
# wallpapers; ThemePicker stays, Settings and the launcher open it),
# Calculator and Recorder. Nothing in the framework, SystemUI, Settings or the
# launcher depends on them. 'overrides' drops them from the product; names a
# device does not have (RevampedFMRadio on dream2lte) are ignored.
# Since 10-21, to save memory (persistent processes, ~17 MB on mido): AudioFX
# and mido's Dolby apps (daxService, MotoDolbyV3: audio effect controllers;
# the effect libraries stay), and SecureElement (OMAPI for eSE/UICC applets,
# NFC payments; mido has no NFC).
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := HeadlessRemovePackages
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_TAGS := optional
LOCAL_OVERRIDES_PACKAGES := \
    Updater \
    RevampedFMRadio \
    Seedvault \
    LocalContactsBackup \
    Backgrounds \
    LiveWallpapersPicker \
    ExactCalculator \
    Recorder \
    AudioFX \
    daxService \
    MotoDolbyV3 \
    SecureElement
LOCAL_UNINSTALLABLE_MODULE := true
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_SRC_FILES := /dev/null
include $(BUILD_PREBUILT)
