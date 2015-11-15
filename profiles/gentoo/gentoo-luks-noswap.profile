part sda 1 83 100M  # /boot
part sda 2 83 +     # /

luks bootpw    a    # CHANGE ME
luks /dev/sda2 root aes sha256

format /dev/sda1        ext2
format /dev/mapper/root ext4

mountfs /dev/sda1        ext2 /boot
mountfs /dev/mapper/root ext4 / noatime

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest $(uname -m)
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

#cat /proc/config.gz | gzip -d > /dotconfig
#kernel_config_file       /dotconfig
kernel_sources           gentoo-sources
initramfs_builder
genkernel_kernel_opts    --loglevel=5
genkernel_initramfs_opts --luks

grub2_install /dev/sda

timezone                 UTC
bootloader               grub
bootloader_kernel_args   crypt_root=/dev/sda2 # should match root device in the $luks variable
rootpw                   a
keymap                   fr # be-latin1 us
hostname                 gentoo-luks
extra_packages           dhcpcd # openssh syslog-ng

rcadd                    dmcrypt default
#rcadd                    sshd default
#rcadd                    syslog-ng default

pre_build_kernel() {
    # NOTE we need cryptsetup *before* the kernel
    spawn_chroot "emerge cryptsetup --autounmask-write" || die "could not autounmask cryptsetup"
    spawn_chroot "etc-update --automode -5" || die "could not etc-update --automode -5"
    spawn_chroot "emerge cryptsetup" || die "could not emerge cryptsetup"
}
