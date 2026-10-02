#
# Copyright (C) 2018 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

COMMON_PATH := device/samsung/universal8895-common

BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
# Cuttlefish host tools (pulled in via platform_testing) require prebuilts we do
# not sync; they are never built for this device.
BUILD_BROKEN_MISSING_REQUIRED_MODULES := true

# Include path
$(call soong_config_set,samsungVars,target_specific_header_path,device/samsung/universal8895-common/include)

# Verified Boot
BOARD_AVB_ENABLE := false

# Bluetooth
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := $(COMMON_PATH)/bluetooth
BOARD_HAVE_BLUETOOTH_BCM := true

## Camera
$(call soong_config_set_bool,samsungCameraVars,usage_64bit,true)

# Display
TARGET_SCREEN_DENSITY := 480
# Mali gralloc blob only provides mapper/allocator 2.0
$(call soong_config_set_bool,libui,legacy_gralloc,true)

# Fingerprint
TARGET_SEC_FP_HAS_FINGERPRINT_GESTURES := true

# Firmware
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true

# Properties
TARGET_SYSTEM_PROP += $(COMMON_PATH)/system.prop
TARGET_VENDOR_PROP += $(COMMON_PATH)/vendor.prop
TARGET_PRODUCT_PROP += $(COMMON_PATH)/product.prop

# Platform
TARGET_BOARD_PLATFORM := exynos5
TARGET_SOC := exynos8895
TARGET_BOOTLOADER_BOARD_NAME := universal8895
BOARD_VENDOR := samsung

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic

# Secondary Architecture
TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53.a57

# Boot image
# S-Boot needs a Samsung DTBH dt.img appended to a v0 boot image, with its size
# in header offset 40 (where AOSP's mkbootimg writes header_version). AOSP builds
# a plain v0 boot.img; tools/mkbootimg_dtbh.py then injects the DTBH image.
BOARD_BOOT_HEADER_VERSION := 0
BOARD_MKBOOTIMG_ARGS := --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100
BOARD_KERNEL_BASE := 0x10000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_KERNEL_CMDLINE := androidboot.hardware=samsungexynos8895
BOARD_ROOT_EXTRA_FOLDERS += efs cpefs
BOARD_RAMDISK_USE_XZ := true
# Kernel (prebuilt, built from the universal8895 4.4 kernel; see device/samsung/<device>-kernel)
TARGET_NO_KERNEL := false

# Use these flags if the board has a ext4 partition larger than 2gb
BOARD_HAS_LARGE_FILESYSTEM := true
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4

# Partitions (Treble-style layout as left on the device by HadesROM's PIT)
BOARD_BOOTIMAGE_PARTITION_SIZE     := 41943040     # BOOT     sda7
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 48234496     # RECOVERY sda8 (TWRP)
BOARD_SYSTEMIMAGE_PARTITION_SIZE   := 6815744000   # SYSTEM   sda17
BOARD_VENDORIMAGE_PARTITION_SIZE   := 629145600    # VENDOR   sda18
BOARD_CACHEIMAGE_PARTITION_SIZE    := 157286400    # CACHE    sda21
BOARD_USERDATAIMAGE_PARTITION_SIZE := 55248924672  # USERDATA sda27
BOARD_FLASH_BLOCK_SIZE := 4096
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_VENDOR := vendor
# HIDDEN (Samsung preload, sda22) is used as /metadata (aconfig flag storage etc.)
BOARD_USES_METADATA_PARTITION := true
TARGET_NO_RECOVERY := true

# Manifest
PRODUCT_ENFORCE_VINTF_MANIFEST_OVERRIDE := true
DEVICE_MANIFEST_FILE := $(COMMON_PATH)/manifest.xml
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE := \
    $(COMMON_PATH)/framework_compatibility_matrix.xml \
    hardware/samsung/vintf/samsung_framework_compatibility_matrix.xml

# Device Tree
BOARD_USES_DT := true

# Renderscript
OVERRIDE_RS_DRIVER := libRSDriverArm.so

# Samsung HALs
TARGET_POWERHAL_VARIANT := samsung

# OTA package
TARGET_OTA_ALLOW_NON_AB := true
AB_OTA_UPDATER := false

# Bluetooth
BOARD_CUSTOM_BT_CONFIG := $(COMMON_PATH)/bluetooth/libbt_vndcfg.txt
BOARD_HAVE_BLUETOOTH := true

# Backlight
BACKLIGHT_PATH := "/sys/class/backlight/panel/brightness"


# Wifi
TARGET_USES_64_BIT_BCMDHD        := true
BOARD_WLAN_DEVICE                := bcmdhd
WPA_SUPPLICANT_VERSION           := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER      := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_bcmdhd
WPA_SUPPLICANT_USE_HIDL          := true
BOARD_HOSTAPD_DRIVER             := NL80211
BOARD_HOSTAPD_PRIVATE_LIB        := lib_driver_cmd_bcmdhd
WIFI_DRIVER_FW_PATH_PARAM        := "/sys/module/dhd/parameters/firmware_path"
WIFI_DRIVER_NVRAM_PATH_PARAM     := "/sys/module/dhd/parameters/nvram_path"
WIFI_DRIVER_NVRAM_PATH           := "/vendor/etc/wifi/nvram_net.txt"
WIFI_DRIVER_FW_PATH_STA          := "/vendor/etc/wifi/bcmdhd_sta.bin"
WIFI_DRIVER_FW_PATH_AP           := "/vendor/etc/wifi/bcmdhd_apsta.bin"
WIFI_BAND                        := 802_11_ABG
WIFI_HIDL_FEATURE_DUAL_INTERFACE := true
WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := true

# MACLOADER
BOARD_HAVE_SAMSUNG_WIFI          := true

# Sepolicy
BOARD_SEPOLICY_TEE_FLAVOR := mobicore
include device/samsung_slsi/sepolicy/sepolicy.mk
SELINUX_IGNORE_NEVERALLOWS := true
BOARD_VENDOR_SEPOLICY_DIRS += $(COMMON_PATH)/sepolicy/vendor
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += $(COMMON_PATH)/sepolicy/private

# Ril
ENABLE_VENDOR_RIL_SERVICE := true

