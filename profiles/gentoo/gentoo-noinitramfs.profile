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
cat /proc/config.gz | gzip -d > /dotconfig
grep -v CONFIG_EXTRA_FIRMWARE   /dotconfig > /dotconfig2 ; mv /dotconfig2 /dotconfig
grep -v LZO                     /dotconfig > /dotconfig2 ; mv /dotconfig2 /dotconfig
grep -v BLK_DEV_INITRD          /dotconfig > /dotconfig2 ; mv /dotconfig2 /dotconfig
kernel_config_file      /dotconfig
kernel_sources	        gentoo-sources
kernel_builder          kigen
kigen_kernel_opts       -d --localyesconfig

timezone                UTC
rootpw                  a
bootloader              grub
keymap	                us # be-latin1 fr
hostname                gentoo
extra_packages          dhcpcd # syslog-ng vim openssh

#rcadd                   sshd       default
#rcadd                   syslog-ng  default

pre_install_kernel_builder() {
    # install kigen ebuild
    spawn_chroot "mkdir -p /usr/local/portage/sys-kernel/kigen /etc/portage"
    spawn_chroot "wget -q https://github.com/downloads/r1k0/kigen/kigen-9999.ebuild -O /usr/local/portage/sys-kernel/kigen/kigen-9999.ebuild"
    spawn_chroot "echo PORTDIR_OVERLAY=\"/usr/local/portage\" >> /etc/portage/make.conf"
    spawn_chroot "ebuild /usr/local/portage/sys-kernel/kigen/kigen-9999.ebuild digest"
    spawn_chroot "echo \>=sys-kernel/kigen-9999 ~x86 >> /etc/portage/package.accept_keywords"

    # install git
    spawn_chroot "emerge git -q"
}
pre_configure_bootloader() {
    # this is needed since kigen mounts/umounts automatically
    spawn_chroot "mount /boot"
}
