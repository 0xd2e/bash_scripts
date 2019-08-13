#!/bin/bash

set -o pipefail # The whole pipeline fails when any command fails
set -u; # Exit when uninitialised variable is used
set -e; # Exit when any command fails

# Create temporary 512MB RAM disk

# Mount options info: http://man7.org/linux/man-pages/man8/mount.8.html#FILESYSTEM-INDEPENDENT_MOUNT_OPTIONS


readonly MOUNT_POINT='/mnt/ramdisk';
readonly MOUNT_OPTIONS='async,noauto,nodev,nodiratime,noexec,nofail,nosuid,rw,nouser,size=512M,huge=never';
declare -r -i STATUS=$(df | grep $MOUNT_POINT | wc --bytes);

if [ $STATUS -eq 0 ]
then
    ACTION='mount';
else
    ACTION='unmount';
fi

read -r -p "Do you want to $ACTION RAM disk in $MOUNT_POINT (y/n)? " ACTION;

# Convert character(s) to lowercase
ACTION=${ACTION,,};

# Proceed only when the input is y[es]
[[ ! $ACTION =~ ^y(es)?$ ]] && exit 0;

# Create directory if doesn't exist
[ ! -d $MOUNT_POINT ] && sudo mkdir --parents --verbose $MOUNT_POINT;

if [ $STATUS -eq 0 ]
then
    sudo mount --no-mtab --verbose --types tmpfs --options $MOUNT_OPTIONS tmpfs $MOUNT_POINT;
    df --human-readable --print-type $MOUNT_POINT;
else
    sudo umount --no-mtab --verbose $MOUNT_POINT;
fi
