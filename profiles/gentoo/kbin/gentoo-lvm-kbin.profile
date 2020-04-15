#!/usr/bin/env bash

part sda 1 83 100M
part sda 2 82 2G
part sda 3 83 8G
part sda 4 8e +      # linux lvm type

lvm_volgroup vg /dev/sda4

lvm_logvol vg 10G   usr
lvm_logvol vg 5G    home
lvm_logvol vg 5G    opt
lvm_logvol vg 10G   var
lvm_logvol vg 2G    tmp

format /dev/sda1    ext2
format /dev/sda2    swap
format /dev/sda3    ext4
format /dev/vg/usr  ext4
format /dev/vg/home ext4
format /dev/vg/opt  ext4
format /dev/vg/var  ext4
format /dev/vg/tmp  ext4

mountfs /dev/sda1    ext2 /boot
mountfs /dev/sda2    swap
mountfs /dev/sda3    ext4 /     noatime
mountfs /dev/vg/usr  ext4 /usr  noatime
mountfs /dev/vg/home ext4 /home noatime
mountfs /dev/vg/opt  ext4 /opt  noatime
mountfs /dev/vg/var  ext4 /var  noatime
mountfs /dev/vg/tmp  ext4 /tmp  noatime

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest "$(uname -m)"
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

# ship the binary kernel instead of compiling (faster)
kernel_binary           "$(pwd)"/kbin/kernel-genkernel-"${arch}"-3.7.10-gentoo
systemmap_binary        "$(pwd)"/kbin/System.map-genkernel-"${arch}"-3.7.10-gentoo
initramfs_binary        "$(pwd)"/kbin/initramfs-genkernel-"${arch}"-3.7.10-gentoo

timezone                UTC
rootpw                  a
bootloader              grub
bootloader_kernel_args  dolvm
keymap                  us # fr be-latin1
hostname                gentoo-lvm
extra_packages          lvm2 dhcpcd gentoo-sources genkernel # vim openssh vixie-cron syslog-ng

rcadd                   lvm            default
rcadd                   lvm-monitoring default
