#!/bin/bash
# Build one of our headless LineageOS 20 devices in the OrbStack VM (Ubuntu
# amd64 under Rosetta). The Mac's ./build.sh runs this in the VM's tmux
# session 'build'; by hand:
#
#   vendor/headless/tools/build-in-vm.sh DEVICE TARGET...
#   e.g. build-in-vm.sh dream2lte bacon | build-in-vm.sh mido kernel
#
# All devices share one out/ (host tools are built once; each device has its
# own out/target/product/DEVICE). Switching devices regenerates the Soong and
# Kati ninja files once.
if [ $# -lt 2 ]; then
    sed -n '6,7s/^# *//p' "$0" >&2
    exit 2
fi
DEVICE=$1
shift
cd "$(dirname "$0")/../../.." || exit 1 # the source tree

export WITH_DEXPREOPT=false   # dex2oat crashes under Rosetta
export WITH_ADB_INSECURE=true # ro.adb.secure=0: no ADB key authorization (headless)
export LC_ALL=C
source build/envsetup.sh >/dev/null
lunch "lineage_$DEVICE-userdebug" || exit 1
time m -j"$(nproc)" "$@"
