part sda 1 83 +

format /dev/sda1 ext4

mountfs /dev/sda1 ext4 / noatime

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest "$(uname -m)"
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type   snapshot    http://gentoo.mirrors.ovh.net/gentoo-distfiles/snapshots/portage-latest.tar.bz2

#cat /proc/config.gz | gzip -d > /dotconfig
#kernel_config_file       /dotconfig
kernel_sources	         gentoo-sources
initramfs_builder
genkernel_kernel_opts    --loglevel=5
genkernel_initramfs_opts --loglevel=5

grub_install /dev/sda

timezone                UTC
rootpw                  a
bootloader              grub
keymap	                us # be-latin1 fr
hostname                gentoo
extra_packages          net-misc/dhcpcd # syslog-ng vim openssh

#rcadd                   sshd       default
#rcadd                   syslog-ng  default

pre_install_kernel_builder() {
    # NOTE distfiles.gentoo.org is overloaded
    spawn_chroot "echo GENTOO_MIRRORS=\"http://gentoo.mirrors.ovh.net/gentoo-distfiles/\" >> /etc/portage/make.conf"
}
