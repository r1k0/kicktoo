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
latest_stage_version=$(cat /tmp/stage3.version | grep tar.bz2)

stage_uri               http://distfiles.gentoo.org/releases/${arch}/autobuilds/${latest_stage_version}
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

# ship the binary kernel instead of compiling (faster)
kernel_binary           $(pwd)/kbin/kernel-genkernel-${arch}-3.7.10-gentoo
initramfs_binary        $(pwd)/kbin/initramfs-genkernel-${arch}-3.7.10-gentoo
systemmap_binary        $(pwd)/kbin/System.map-genkernel-${arch}-3.7.10-gentoo

timezone                UTC
rootpw                  a
bootloader              grub
keymap	                us # be-latin1 fr
hostname                gentoo
extra_packages          dhcpcd gentoo-sources genkernel # syslog-ng vim openssh

#rcadd                   sshd       default
#rcadd                   syslog-ng  default
