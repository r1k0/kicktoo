#!/usr/bin/env bash

part sda 1 83 800M
part sda 2 82 1024M
part sda 3 83 +

format /dev/sda1 ext2
format /dev/sda2 swap
format /dev/sda3 ext4

mountfs /dev/sda1 ext2 /boot
mountfs /dev/sda2 swap
mountfs /dev/sda3 ext4 / noatime

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest "$(uname -m)"
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type     snapshot  http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2
#tree_type               sync

# compile kernel from sources using the right .config
kernel_config_file      "$(pwd)"/kconfig/laurent-dedi-SC-"${arch}".kconfig
kernel_sources          gentoo-sources
genkernel_kernel_opts --loglevel=5
genkernel_initramfs_opts --loglevel=5

timezone                Europe/Paris
rootpw                  azerty
bootloader              grub
keymap                  fr
hostname                tigrou
extra_packages          openssh # dhcpcd syslog-ng vim

#rcadd                   network     default
rcadd                   net.enp2s0     default
#rcadd                   net.lo0     boot
rcadd                   sshd       default
#rcadd                   syslog-ng  default

post_install_extra_packages() {
    cat >> "${chroot_dir}"/etc/conf.d/network <<EOF
ifconfig_enp2s0="195.154.108.158 netmask 255.255.255.0 brd 195.154.108.255"
defaultroute="gw 195.154.108.1"
EOF
}
