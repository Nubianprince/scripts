#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

linebreak="-------------------------------------------------"

# Device
export FOX_BRANCH="fox_9.0"

# Device info
# ----------------------------------------
echo -e $P "What is your device codename?" $N; sleep 0.1;
read -r DEVICE
echo "$linebreak"
echo -e $P "What is your device vendor" $N; sleep 0.1;
read -r OEM
echo "$linebreak"
echo -e $P "What is  your name (Username)" $N; sleep 0.1;
read -r main
clear

#export DEVICE=$code
#export OEM=$vendor

# Build Target
## "recoveryimage" - for A-Only Devices without using Vendor Boot
## "bootimage" - for A/B devices without recovery partition (and without vendor boot)
## "vendorbootimage" - for devices Using vendor boot for the recovery ramdisk (Usually for devices shipped with Android 12 or higher)
export TARGET="recoveryimage"

export OUTPUT="OrangeFox*.zip"

# Additional Dependencies (eg: Kernel Source)
# Format: "repo dest"
DEPS=(
    "https://github.com/OrangeFoxRecovery/Avatar.git misc"
)


# Magisk
## Use the Latest Release of Magisk for the OrangeFox addon
export OF_USE_LATEST_MAGISK=true

# Not Recommended to Change
export SYNC_PATH=$SCRIPT_DIR # Full (absolute) path.

# Device Configs
# ----------------------------------------
echo  "Device Configuration Options
 1 : You already have a config file created by this script
 2 : You don't have a config file and now we will create it for you and will use it later when rebuilding Ofox
 -------------------------------------------------------------------------------------------------------------- "

 read Ans3

 if [ $Ans3 = 1 ]
 then
 source $SCRIPT_DIR/configs/"$DEVICE"_ofconfig
 echo " Done exporting your Device Specific settings "
echo "$linebreak"
 elif [ $Ans3 = 2 ]
 then
 echo " Lets create a config for you to use for you device export settings "
 nano $SCRIPT_DIR/configs/"$DEVICE"_ofconfig
 echo " Config file created "
 echo ""
 echo " Now i will open your config file and you just type the device specific export settings in it and save it "
 echo " That config file will be used now and will be user later if you want "
 echo " Dont Change the Name of the file, leave it as it is "
 echo " Press enter when ready "
 read enter
 cd
 nano scripts/Orangefox/configs/$code
 cd
 echo " Now your config file is saved "
 echo ""
 echo " Great then lets export your device settings "
 echo " Press enter when ready "
 read enter
 cd
 source ~/scripts/Orangefox/configs/$code
 echo " Done exporting your Device Specific settings "
 fi
clear

# Import Device Configuration
# ----------------------------------------
echo -e $C "Importing Device Configuration" $N
source $SCRIPT_DIR/configs/"${DEVICE}"_ofconfig; sleep 1;
if [ "$?" != "0" ]; then
  echo -e $RE "Import failed :(" $N
  exit
fi

# Export universal configuration
export ALLOW_MISSING_DEPENDENCIES=true
export TW_DEFAULT_LANGUAGE="en"
export LC_ALL="C"
export OF_MAINTAINER="${main}"
export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
export FOX_BUILD_TYPE=Unofficial
export FOX_EXTREME_SIZE_REDUCTION=1
export OF_DISABLE_MIUI_SPECIFIC_FEATURES=1
export OF_USE_LOCKSCREEN_BUTTON=1

if [ "$FOX_BRANCH" = "fox_11.0" ]; then
export FOX_R11=1
fi

# Sync Branch (will be used to fix legacy build system errors)
if [ -z "$SYNC_BRANCH" ]; then
    export SYNC_BRANCH=$(echo ${FOX_BRANCH} | cut -d_ -f2)
fi

# Empty the VTS Makefile
if [ "$FOX_BRANCH" = "fox_11.0" ]; then
    rm -rf frameworks/base/core/xsd/vts/Android.mk
    touch frameworks/base/core/xsd/vts/Android.mk 2>/dev/null || echo
fi

# Prepare the Build Environment
source build/envsetup.sh

# Set BRANCH_INT variable for future use
BRANCH_INT=$(echo $SYNC_BRANCH | cut -d. -f1)

# Magisk
if [[ $OF_USE_LATEST_MAGISK = "true" || $OF_USE_LATEST_MAGISK = "1" ]]; then
	echo "Downloading the Latest Release of Magisk..."
	LATEST_MAGISK_URL="$(curl -sL https://api.github.com/repos/topjohnwu/Magisk/releases/latest | jq -r . | grep browser_download_url | grep Magisk- | cut -d : -f 2,3 | sed 's/"//g')"
	mkdir -p ~/Magisk
	cd ~/Magisk
	aria2c $LATEST_MAGISK_URL 2>&1 || wget $LATEST_MAGISK_URL 2>&1
	echo "Magisk Downloaded Successfully"
	echo "Renaming .apk to .zip ..."
	#rename 's/.apk/.zip/' Magisk*
	mv $("ls" Magisk*.apk) $("ls" Magisk*.apk | sed 's/.apk/.zip/g')
	cd $SYNC_PATH >/dev/null
	echo "Done!"
fi

# Legacy Build Systems
if [ $BRANCH_INT -le 6 ]; then
    export OF_DISABLE_KEYMASTER2=1 # Disable Keymaster2
    export OF_LEGACY_SHAR512=1 # Fix Compilation on Legacy Build Systems
fi


#Is this a clean build
# ----------------------------------------
echo -e $Y " Is this a clean build
 1 : Yes
 2 : No
 -------------------------------------------------------------------------------------------------------------- " $N

read -r Ans1
if [[ "${Ans1}" = 1 ]]; then
  make clean
fi

# lunch the target
if [ "$BRANCH_INT" -ge 11 ]; then
    lunch twrp_${DEVICE}-eng || { echo "ERROR: Failed to lunch the target!" && exit 1; }
else
    lunch omni_${DEVICE}-eng || { echo "ERROR: Failed to lunch the target!" && exit 1; }
fi

# Build the Code
if [ -z "$J_VAL" ]; then
    mka -j$(nproc --all) $TARGET || { echo "ERROR: Failed to Build OrangeFox!" && exit 1; }
elif [ "$J_VAL"="0" ]; then
    mka $TARGET || { echo "ERROR: Failed to Build OrangeFox!" && exit 1; }
else
    mka -j${J_VAL} $TARGET || { echo "ERROR: Failed to Build OrangeFox!" && exit 1; }
fi

# Credits
# ----------------------------------------
echo ""
echo -e $B " credits :
Follow my Github Account : https://github.com/nubianprince " $N
sleep 3

# Exit
exit 0
