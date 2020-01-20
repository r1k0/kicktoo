#!/usr/bin/env bash

part sda 1 83 100M  # /boot
part sda 2 83 +     # /

luks bootpw    a    # CHANGE ME
luks /dev/sda2 root aes sha256

format /dev/sda1        ext2
format /dev/mapper/root ext4

mountfs /dev/sda1        ext2 /boot
mountfs /dev/mapper/root ext4 / noatime

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest "$(uname -m)"
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

# ship the binary kernel instead of compiling (faster)
kernel_binary           "$(pwd)"/kbin/kernel-genkernel-"${arch}"-3.7.10-gentoo
initramfs_binary        "$(pwd)"/kbin/initramfs-genkernel-"${arch}"-3.7.10-gentoo
systemmap_binary        "$(pwd)"/kbin/System.map-genkernel-"${arch}"-3.7.10-gentoo

timezone                UTC
bootloader              grub
bootloader_kernel_args  crypt_root=/dev/sda2 # should match root device in the $luks variable
rootpw                  a
keymap                  us # be-latin1 fr
hostname                gentoo-luks
extra_packages          dhcpcd cryptsetup gentoo-sources # openssh syslog-ng

rcadd                   dmcrypt default
