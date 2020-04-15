#!/usr/bin/env bash

part sdb 1 83 100M  # /boot
part sdb 2 82 2048M # swap
part sdb 3 83 +     # /

luks bootpw    a # CHANGE ME
luks /dev/sdb2 swap aes sha256
luks /dev/sdb3 root aes sha256

format /dev/sdb1        ext2
format /dev/mapper/swap swap
format /dev/mapper/root ext4

mountfs /dev/sdb1        ext2 /boot
mountfs /dev/mapper/swap swap
mountfs /dev/mapper/root ext4 / noatime

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest "$(uname -m)"
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

grep -v v86d /kconf > /kconf2 ; mv /kconf2 /kconf
kernel_config_file       /kconf
kernel_sources           gentoo-sources
initramfs_builder
genkernel_kernel_opts    --loglevel=5
genkernel_initramfs_opts --loglevel=5 --luks

timezone                 UTC
grub_install            /dev/sda
bootloader               grub
bootloader_kernel_args   crypt_root=/dev/sdb3 # should match root device in the $luks variable
rootpw                   a # CHANGE ME
keymap                   be-latin1 # fr be-latin1
hostname                 gentoo-luks
extra_packages           dhcpcd # openssh syslog-ng

rcadd                    dmcrypt default
#rcadd                    sshd default
#rcadd                    syslog-ng default

pre_build_kernel() {
    # NOTE we need cryptsetup *before* the kernel 
    spawn_chroot "emerge cryptsetup --autounmask-write" || die "could not autounmask cryptsetup"
    spawn_chroot "etc-update --automode -5" || die "could not etc-update --automode -5"
    spawn_chroot "emerge cryptsetup -q" || die "could not emerge cryptsetup"
}

post_install_extra_packages() {
    # this tells where to find the swap to encrypt
    cat >> "${chroot_dir}"/etc/conf.d/dmcrypt <<EOF
swap=swap
source='/dev/sdb2'
EOF
}
