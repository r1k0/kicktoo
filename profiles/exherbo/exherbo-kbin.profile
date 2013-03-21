part sda 1 83 100M
part sda 2 83 +

format /dev/sda1 ext2
format /dev/sda2 ext4

mountfs /dev/sda1 ext2 /boot
mountfs /dev/sda2 ext4 / noatime

# don't compile kernel # systemd wants 3.5 or more
kernel_binary $(pwd)/kbin/kernel-genkernel-${arch}-3.7.10-gentoo
initramfs_binary $(pwd)/kbin/initramfs-genkernel-${arch}-3.7.10-gentoo
systemmap_binary $(pwd)/kbin/System.map-genkernel-${arch}-3.7.10-gentoo

stage_uri http://dev.exherbo.org/stages/exherbo-x86-current.tar.xz
rootpw    a
bootloader grub
#extra_packages vim

skip install_kernel_builder
skip install_initramfs_builder
skip build_kernel
skip setup_host
skip setup_keymap
skip install_bootloader
skip configure_bootloader
post_configure_bootloader() {
    spawn_chroot "cave sync"                                           || die "Could not sync exheres tree"
    spawn_chroot "cave fix-cache"                                      || die "Could not sync exheres tree"

    spawn_chroot "echo \"*/* systemd\" >> /etc/paludis/options.conf"   || die "Could not copy systemd config"
    spawn_chroot "cave resolve systemd -x"                             || die "Could not install systemd"
    spawn_chroot "eclectic init set systemd"                           || die "Could not init set systemd"
#    spawn_chroot "cave resolve world -x"                               || warn "Could not update world"

    spawn_chroot "echo exherbo > /etc/hostname"
    spawn_chroot "echo \"127.0.0.1 localhost exherbo\n::1 localhost\n\" > /etc/hosts"
    for p in ${extra_packages}; do
        spawn_chroot "cave resolve ${p} -x"                            || die "Could not install extra packages"
    done

    spawn_chroot "grub-install --force /dev/sda" || die "Could not install grub to /boot/grub"
    spawn_chroot "echo \"set timeout=10\nset default=0\nmenuentry Exherbo {\n  set root=(hd0,1)\n  linux /kernel-genkernel-${arch}-3.7.10-gentoo root=/dev/sda2\n  initrd /initramfs-genkernel-${arch}-3.7.10-gentoo\n}\" >  /boot/grub/grub.cfg"
}
