#!/usr/bin/env bash

part sda 1 82 2048M 
part sda 2 83 +

format /dev/sda1 swap
format /dev/sda2 ext4

mountfs /dev/sda1 swap
mountfs /dev/sda2 ext4 / noatime

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest "$(uname -m)"
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

# ship the binary kernel instead of compiling (faster)
kernel_binary           "$(pwd)"/kbin/kernel-genkernel-"${arch}"-3.7.10-gentoo
initramfs_binary        "$(pwd)"/kbin/initramfs-genkernel-"${arch}"-3.7.10-gentoo
systemmap_binary        "$(pwd)"/kbin/System.map-genkernel-"${arch}"-3.7.10-gentoo

timezone                UTC
rootpw                  a
bootloader              grub
keymap                  us # be-latin1 fr
hostname                gentoo
extra_packages          dhcpcd gentoo-sources genkernel # syslog-ng vim openssh

#rcadd                   sshd       default
#rcadd                   syslog-ng  default
