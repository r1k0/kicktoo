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

# get kernel dotconfig from the official running kernel
cat $(pwd)/kconfig/livedvd-x86-amd64-32ul-2012.1.kconfig > /dotconfig
grep -v CONFIG_EXTRA_FIRMWARE /dotconfig > /dotconfig2 ; mv /dotconfig2 /dotconfig
grep -v LZO                   /dotconfig > /dotconfig2 ; mv /dotconfig2 /dotconfig
kernel_config_file       /dotconfig
kernel_sources	         gentoo-sources
initramfs_builder               
genkernel_kernel_opts    --loglevel=5
genkernel_initramfs_opts --loglevel=5

timezone                UTC
rootpw                  a
bootloader              grub:2
keymap	                us # be-latin1 fr
hostname                gentoo
extra_packages          dhcpcd # syslog-ng vim openssh

#rcadd                   sshd       default
#rcadd                   syslog-ng  default

pre_build_kernel() {
    spawn_chroot "emerge grub:2 --autounmask-write" # FIXME check exit status
    spawn_chroot "etc-update --automode -5" || die "could not etc-update --automode -5"
}

