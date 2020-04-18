#!/usr/bin/env bash

# Kicktoo base profile for Beaglebone, Pandaboard or some other creditcard-size
# computer running from an SD/MMC and requiring a specific geometry.
#
# Source this from a specific board profile, or expand this one.
#
# Because Kicktoo doesn't support cross-architecture installs and commands, you
# have to install the kernel and others programs yourself.
#
# http://processors.wiki.ti.com/index.php/SD/MMC_format_for_OMAP3_boot

# setting some variables
DISK="mmcblk0"
SIZE=$(fdisk -l /dev/$DISK | grep Disk | awk '{print $5}')
HEADS=255
SECTORS=63
CYLINDERS=$(echo "$SIZE"/$HEADS/$SECTORS/512 | bc)

# setting kicktoo config
geometry $HEADS $SECTORS "$CYLINDERS"

part $DISK 1 b 100M boot
part $DISK 2 83 +

format "/dev/${DISK}p1" fat32
format "/dev/${DISK}p2" ext3 "-T small"

mountfs /dev/${DISK}p2 ext3 /
mountfs /dev/${DISK}p1 vfat /boot

tree_type snapshot http://gentoo.mirrors.ovh.net/gentoo-distfiles/snapshots/portage-latest.tar.bz2
locale_set en_US.UTF-8
timezone UTC
