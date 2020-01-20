#!/usr/bin/env bash

part sda 1 L 100M
part sda 2 S 2048M
part sda 3 L 2G
part sda 4 E 
part sda 5 L 1G
part sda 6 L 1G

format /dev/sda1 ext2
format /dev/sda2 swap
format /dev/sda3 ext4
format /dev/sda5 ext4
format /dev/sda6 ext4

mountfs /dev/sda1 ext2 /boot
mountfs /dev/sda2 swap
mountfs /dev/sda3 ext4 / noatime

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest "$(uname -m)"
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

#cat /proc/config.gz | gzip -d > /dotconfig
#kernel_config_file       /dotconfig
kernel_sources	         gentoo-sources
initramfs_builder               
genkernel_kernel_opts    --loglevel=5
genkernel_initramfs_opts --loglevel=5

timezone                UTC
rootpw                  a
bootloader              grub
keymap	                us # be-latin1 fr
hostname                gentoo
extra_packages          dhcpcd # syslog-ng vim openssh

#rcadd                   sshd       default
#rcadd                   syslog-ng  default
