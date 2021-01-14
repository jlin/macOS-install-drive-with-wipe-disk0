#!/bin/sh

# This Source Code Form is subject to the terms of the Mozilla Developer
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This script creates a bootable macOS USB install drive and downloads the wipe-disk0.sh and dinobuildr.sh script to the USB drive.

# WARNING: The wipe-disk0.sh script wipes disk0 if executed. It should only be executed under macOS Recovery from a bootable macOS USB install drive.

# Verify that the Install macOS app exists

echo "\nPlease enter the codename of the macbook's macOS version you want to wipe (e.g. \"Mojave\" or \"Catalina\" or \"Big Sur\"). Input is case-sensitive: \n"
read VERSION_NAME 

CODENAME=macOS\ $VERSION_NAME

MACOS_INSTALLER=$(ls /Applications| grep -s Install\ "$CODENAME" | sed 's/.app//')
if [[  "${MACOS_INSTALLER}" == "" ]] ; then
	CODENAME_CLEAN=$(echo "$CODENAME" | sed 's/\\//g')
	echo "\nPlease download the Install "$CODENAME_CLEAN" app from the App Store then run this script again."
	exit 134
fi

# List of attached drives
DRIVE_LIST=$(diskutil list | grep /dev/disk)

# Locate attached USB drives
USB_COUNT=0
for DRIVE in $DRIVE_LIST ; do
	CURRENT_DRIVE=$(diskutil info $DRIVE | grep Protocol | grep USB | awk '{print $2}')
	if [[ "${CURRENT_DRIVE}" == "USB" ]] ; then
		((USB_COUNT++))
		TARGET=$(echo $DRIVE)
	fi
done

# This script will exit if there isn't only one USB drive attached
case "$USB_COUNT" in
	0)
	echo "\nUSB drive not detected.\n"
	exit 135
	;;
	1)
	echo "\nDetected USB drive $TARGET\n"
	;;
	*)
	echo "\nPlease make sure there's only one USB drive attached then run this script again.\n"
	exit 136
	;;
esac

# Display the target USB drive name, size, and partitions
diskutil info $TARGET | grep -A 14 "Device / Media Name:" | sed '/Volume\ Name/,/SMART\ Status/d' | head -n 4 | awk '$1=$1' | sed G
diskutil list $TARGET | tail -n +2

# Confirm to proceed with formatting the target USB drive
echo "\nWARNING: Formatting will erase all data on $TARGET. Type \"YES\" to format this USB drive.\n"
read CONTINUE
if [[ "${CONTINUE}" == "YES" ]] ; then
	diskutil partitionDisk $TARGET GPT JHFS+ "wipe" 0b || {
		echo "Failed to format the target USB drive ${TARGET[$SELECT]}"
		exit 137
	}
	echo "Waiting for 2 minutes to let background tasks finish"
	sleep 120
	echo "\nTo proceed, enter your password.\n"
	sudo /Applications/Install\ "$CODENAME".app/Contents/Resources/createinstallmedia --nointeraction --volume /Volumes/wipe || {
		echo "\nFailed to create a bootable $CODENAME_CLEAN USB install drive. Please try again."
		exit 138
	}
	curl -s -o /Volumes/Install\ "$CODENAME"/wipe-disk0.sh https://raw.githubusercontent.com/mozilla/mac-wipe-disk0/master/wipe-disk0.sh || {
		echo "\nFailed to download the wipe-disk0.sh script. Please connect to the Internet then run this script again."
		exit 139
	}
	chmod +x /Volumes/Install\ "$CODENAME"/wipe-disk0.sh
	curl -s -o /Volumes/Install\ "$CODENAME"/dinobuildr.sh https://raw.githubusercontent.com/mozilla/dinobuildr/master/dinobuildr.sh || {
		echo "\nFailed to download the dinobuildr.sh script. Please connect to the Internet then run this script again."
		exit 140
	}
	chmod +x /Volumes/Install\ "$CODENAME"/dinobuildr.sh
else
	echo "\nA confirmation to proceed was not provided. The USB drive ${TARGET[$SELECT]} was not modified.\n"
	exit 141
fi
