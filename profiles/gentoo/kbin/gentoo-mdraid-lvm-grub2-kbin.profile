#!/usr/bin/env bash

part sda 1 83 128M
part sda 2 8e +

part sdb 1 83 128M
part sdb 2 8e +

mdraid md1 -l 1 -n 2 /dev/sda1 /dev/sdb1 -e 0.90
mdraid md2 -l 1 -n 2 /dev/sda2 /dev/sdb2 -e 0.90

lvm_volgroup system /dev/md2
lvm_logvol   system 2G swap
lvm_logvol   system 8G root
lvm_logvol   system 2G var
lvm_logvol   system 8G home

format /dev/md1         ext4 "-L _boot"
format /dev/system/swap swap "-L _swap"
format /dev/system/root ext4 "-L _root"
format /dev/system/var  ext4 "-L _var"
format /dev/system/home ext4 "-L _home"

# needs appropriate /etc/mdadm.conf added to initrd to properly map/keep /dev/mdX mappings
# set in profile, auto mappings (usually in the 126-127ish range) will suffice with genkernel
# 'domdadm' setup scripts
mountfs /dev/md1         ext4  /boot    noauto,noatime
mountfs /dev/system/swap swap
mountfs /dev/system/root ext4  /        noatime
mountfs /dev/system/var  ext4  /var     noatime,nodev,nosuid,async,nouser
mountfs /dev/system/home ext4  /home    noatime,nodev,nosuid,async,nouser
mountfs tmpfs            tmpfs /tmp     nodev,size=40%
mountfs tmpfs            tmpfs /var/tmp nodev

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest "$(uname -m)"
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

# ship the binary kernel instead of compiling (faster)
kernel_binary           "$(pwd)"/kbin/kernel-genkernel-"${arch}"-3.7.10-gentoo
systemmap_binary        "$(pwd)"/kbin/System.map-genkernel-"${arch}"-3.7.10-gentoo
initramfs_binary        "$(pwd)"/kbin/initramfs-genkernel-"${arch}"-3.7.10-gentoo

locale_set              "en en_US ISO-8859-1 en_US.UTF-8 UTF-8"
timezone                UTC
rootpw                  a
bootloader              grub:2
grub_install           /dev/sda
bootloader_kernel_args  "vga=0x317 domdadm dolvm"
keymap                  us
hostname                gentoo-mdraid
extra_packages          mdadm lvm2 dhcpcd # vixie-cron syslog-ng openssh gpm

rcadd                   mdadm            boot
rcadd                   lvm              boot
rcadd                   dhcpcd           default
#rcadd                   vixie-cron       default
#rcadd                   syslog-ng        default
#rcadd                   gpm              default

pre_build_kernel() {
    # NOTE we need lvm2 *before* the kernel to build the initramfs
    spawn_chroot "emerge lvm2 -q" || die "could not emerge lvm2"
}

pre_install_bootloader() {
    spawn_chroot "emerge grub:2 --autounmask-write" # FIXME check exit status
    spawn_chroot "etc-update --automode -5" || die "could not etc-update --automode -5"
}
