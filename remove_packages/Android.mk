# Apps the headless servers do without (the user's choice, 10-20): the
# LineageOS OTA Updater (it only checks for official builds), FM radio, backup
# (Seedvault and its contacts helper), wallpaper apps (Backgrounds, live
# wallpapers; ThemePicker stays, Settings and the launcher open it),
# Calculator and Recorder. Nothing in the framework, SystemUI, Settings or the
# launcher depends on them. 'overrides' drops them from the product; names a
# device does not have (RevampedFMRadio on dream2lte) are ignored.
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
    Recorder
LOCAL_UNINSTALLABLE_MODULE := true
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_SRC_FILES := /dev/null
include $(BUILD_PREBUILT)
