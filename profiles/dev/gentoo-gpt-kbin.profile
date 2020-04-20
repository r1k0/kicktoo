#!/usr/bin/env bash

gptpart sda 1 8300 100M
gptpart sda 2 ef02 32M # for GPT/GUID only
gptpart sda 3 8200 2048M
gptpart sda 4 8300 +

format /dev/sda1 ext2
format /dev/sda3 swap
format /dev/sda4 ext4

mountfs /dev/sda1 ext2 /boot
mountfs /dev/sda3 swap
mountfs /dev/sda4 ext4 / noatime

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest "$(uname -m)"
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type   snapshot    http://gentoo.mirrors.ovh.net/gentoo-distfiles/snapshots/portage-latest.tar.bz2

# ship the binary kernel instead of compiling (faster)
kernel_binary           "$(pwd)"/kbin/kernel-genkernel-"${arch}"-3.7.10-gentoo
initramfs_binary        "$(pwd)"/kbin/initramfs-genkernel-"${arch}"-3.7.10-gentoo
systemmap_binary        "$(pwd)"/kbin/System.map-genkernel-"${arch}"-3.7.10-gentoo

timezone                UTC
rootpw                  a
bootloader              grub
keymap	                us # be-latin1 fr
hostname                gentoo
extra_packages          net-misc/dhcpcd # syslog-ng vim openssh

#rcadd                   sshd       default
#rcadd                   syslog-ng  default
