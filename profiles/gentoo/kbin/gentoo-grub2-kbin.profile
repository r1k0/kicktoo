part sda 1 83 100M
part sda 2 82 2048M
part sda 3 83 +

format /dev/sda1 ext2
format /dev/sda2 swap
format /dev/sda3 ext4

mountfs /dev/sda1 ext2 /boot
mountfs /dev/sda2 swap
mountfs /dev/sda3 ext4 / noatime

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest $(uname -m)
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

# ship the binary kernel instead of compiling (faster)
kernel_binary     $(pwd)/kbin/kernel-genkernel-${arch}-3.7.10-gentoo
initramfs_binary  $(pwd)/kbin/initramfs-genkernel-${arch}-3.7.10-gentoo
systemmap_binary  $(pwd)/kbin/System.map-genkernel-${arch}-3.7.10-gentoo

timezone           UTC
rootpw             a
keymap	           us # be-latin1 fr
hostname           gentoo
extra_packages     dhcpcd # syslog-ng vim openssh

bootloader         grub:2
grub2_install      /dev/sda

#rcadd              sshd       default
#rcadd              syslog-ng  default

pre_install_bootloader() {
    spawn_chroot "emerge grub:2 --autounmask-write" # FIXME check exit status
    spawn_chroot "etc-update --automode -5" || die "could not etc-update --automode -5"
}

