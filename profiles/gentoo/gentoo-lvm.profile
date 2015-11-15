part sda 1 83 100M
part sda 2 82 2G
part sda 3 83 8G
part sda 4 8e +      # linux lvm type

lvm_volgroup vg /dev/sda4

lvm_logvol vg 10G   usr
lvm_logvol vg 5G    home
lvm_logvol vg 5G    opt
lvm_logvol vg 10G   var
lvm_logvol vg 2G    tmp

format /dev/sda1    ext2
format /dev/sda2    swap
format /dev/sda3    ext4
format /dev/vg/usr  ext4
format /dev/vg/home ext4
format /dev/vg/opt  ext4
format /dev/vg/var  ext4
format /dev/vg/tmp  ext4

mountfs /dev/sda1    ext2 /boot
mountfs /dev/sda2    swap
mountfs /dev/sda3    ext4 /     noatime
mountfs /dev/vg/usr  ext4 /usr  noatime
mountfs /dev/vg/home ext4 /home noatime
mountfs /dev/vg/opt  ext4 /opt  noatime
mountfs /dev/vg/var  ext4 /var  noatime
mountfs /dev/vg/tmp  ext4 /tmp  noatime

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest $(uname -m)
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

#cat /proc/config.gz | gzip -d > /dotconfig
#kernel_config_file       /dotconfig
kernel_sources           gentoo-sources
initramfs_builder
genkernel_kernel_opts    --loglevel=5
genkernel_initramfs_opts --lvm

grub2_install /dev/sda

timezone                 UTC
rootpw                   a
bootloader               grub
bootloader_kernel_args   dolvm
keymap                   us # fr be-latin1
hostname                 gentoo-lvm
extra_packages           lvm2 dhcpcd # vim openssh vixie-cron syslog-ng

rcadd                    lvm            default
rcadd                    lvm-monitoring default

pre_build_kernel() {
    # NOTE we need lvm2 *before* the kernel
    spawn_chroot "emerge lvm2 --autounmask-write" || die "could not autounmask lvm2"
    spawn_chroot "etc-update --automode -5" || die "could not etc-update --automode -5"
    spawn_chroot "emerge lvm2 -q" || die "could not emerge lvm2"
}

