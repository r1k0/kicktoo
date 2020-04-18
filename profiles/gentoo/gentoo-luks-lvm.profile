part sda 1 83 500M
part sda 2 82 2G # swap
part sda 3 83 2G
part sda 4 8e +  # linux lvm type

luks bootpw a
luks /dev/sda2 swap aes cbc-plain sha256
luks /dev/sda4 root aes cbc-plain sha256

lvm_volgroup vg /dev/mapper/root

lvm_logvol vg 10G usr
lvm_logvol vg 5G home
lvm_logvol vg 5G opt
lvm_logvol vg 10G var
lvm_logvol vg 4G tmp

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
tree_type   snapshot    http://gentoo.mirrors.ovh.net/gentoo-distfiles/snapshots/portage-latest.tar.bz2

#cat /proc/config.gz | gzip -d > /dotconfig
#kernel_config_file       /dotconfig
kernel_sources           gentoo-sources
initramfs_builder
genkernel_kernel_opts    --loglevel=5
genkernel_initramfs_opts --loglevel=5 --luks --lvm

grub_install /dev/sda

timezone                UTC
rootpw                  a
bootloader              grub
bootloader_kernel_args  dolvm crypt_root=/dev/sda4
keymap                  us # fr be-latin1
hostname                luks-lvm
extra_packages          cryptsetup lvm2 net-misc/dhcpcd gentoo-sources genkernel # vim openssh vixie-cron syslog-ng

rcadd                   dmcrypt        default
rcadd                   lvm            default
rcadd                   lvm-monitoring default

pre_install_kernel_builder() {
    # NOTE distfiles.gentoo.org is overloaded
    spawn_chroot "echo GENTOO_MIRRORS=\"http://gentoo.mirrors.ovh.net/gentoo-distfiles/\" >> /etc/portage/make.conf"
}

pre_build_kernel() {
    # NOTE we need cryptsetup *before* the kernel
    spawn_chroot "mkdir /etc/portage/package.use/ && echo 'sys-fs/cryptsetup static >> /etc/portage/package.use/common'"
    spawn_chroot "emerge cryptsetup --autounmask-write" || die "could not autounmask cryptsetup"
    spawn_chroot "etc-update --automode -5" || die "could not etc-update --automode -5"
    spawn_chroot "emerge cryptsetup -q" || die "could not emerge cryptsetup"
}

post_install_extra_packages() {
    # this tells luks where to find the swap
    cat >> "${chroot_dir}"/etc/conf.d/dmcrypt <<EOF
swap=swap
source='/dev/sda2'
EOF
}
