#
# Board config for the headless server pieces (see headless.mk). Include it
# from the device's BoardConfig.mk:
#
#   include vendor/headless/BoardConfigHeadless.mk
#

# headless_su (password-gated root daemon + su)
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += vendor/headless/headless_su/sepolicy
