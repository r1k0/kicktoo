#!/usr/bin/env bash

part sda 1 83 100M
part sda 2 82 2G # swap
part sda 3 83 2G
part sda 4 8e +  # linux lvm type

luks bootpw a
luks /dev/sda2 swap aes sha256
luks /dev/sda4 root aes sha256

lvm_volgroup vg /dev/mapper/root

lvm_logvol vg 5G usr
lvm_logvol vg 5G home
lvm_logvol vg 5G opt
lvm_logvol vg 5G var
lvm_logvol vg 2G tmp

format /dev/sda1        ext2
format /dev/mapper/swap swap
format /dev/sda3        ext4
format /dev/vg/usr      ext4
format /dev/vg/home     ext4
format /dev/vg/opt      ext4
format /dev/vg/var      ext4
format /dev/vg/tmp      ext4

mountfs /dev/sda1         ext2 /boot
mountfs /dev/mapper/swap  swap
mountfs /dev/sda3         ext4 /     noatime
mountfs /dev/vg/usr       ext4 /usr  noatime
mountfs /dev/vg/home      ext4 /home noatime
mountfs /dev/vg/opt       ext4 /opt  noatime
mountfs /dev/vg/var       ext4 /var  noatime
mountfs /dev/vg/tmp       ext4 /tmp  noatime

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
bootloader_kernel_args  dolvm crypt_root=/dev/sda4
keymap                  us # fr be-latin1
hostname                luks-lvm
extra_packages          cryptsetup lvm2 dhcpcd gentoo-sources genkernel # vim openssh vixie-cron syslog-ng

rcadd                   dmcrypt        default
rcadd                   lvm            default
rcadd                   lvm-monitoring default

post_install_extra_packages() {
    # this tells luks where to find the swap
    cat >> "${chroot_dir}"/etc/conf.d/dmcrypt <<EOF
swap=swap
source='/dev/sda2'
EOF
}

