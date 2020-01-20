#!/usr/bin/env bash

KV="3.16" # systemd wants 3.8 or more

part sda 1 83 100M
part sda 2 83 +

format /dev/sda1 ext2
format /dev/sda2 ext4

mountfs /dev/sda1 ext2 /boot
mountfs /dev/sda2 ext4 / noatime

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
    spawn_chroot "cave sync"                                           || die "Could not sync tree"
    spawn_chroot "cave fix-cache"                                      || die "Could not fix cache"

    spawn_chroot "echo \"*/* systemd\" >> /etc/paludis/options.conf"   || die "Could not copy systemd config"
    spawn_chroot "cave resolve systemd -x"                             || die "Could not install systemd"
    spawn_chroot "eclectic init set systemd"                           || die "Could not init set systemd"
#    spawn_chroot "cave resolve world -x"                               || warn "Could not update world"

    # compile kernel
    fetch "http://www.kernel.org/pub/linux/kernel/v3.x/linux-${KV}.tar.gz" "${chroot_dir}/usr/src/linux-${KV}.tar.gz" || die "Could not fetch kernel source"
    spawn_chroot "tar zxpf /usr/src/linux-${KV}.tar.gz -C /usr/src/"                                                  || die "Could not untar kernel tarball"
    spawn_chroot "ln -sf /usr/src/linux-${KV} /usr/src/linux"                                                         || die "Could not symlink source"
    spawn "cat $(pwd)/kconfig/livedvd-x86-amd64-32ul-2012.1.kconfig | grep -v CONFIG_EXTRA_FIRMWARE | grep -v LZO > ${chroot_dir}/usr/src/linux-${KV}/.config" || die "Could not copy kernel config"
    spawn_chroot "cd /usr/src/linux && yes '' |  make -s oldconfig && make && make modules_install"                   || die "Could not build the kernel"
    spawn_chroot "mount /boot"
    spawn_chroot "cp /usr/src/linux/arch/x86/boot/bzImage /boot/kernel-${arch}-${KV}" || die "Could not copy the kernel"

    # creating initramfs
    spawn_chroot "cave resolve dracut -x" || die "Could not install dracut"
    spawn_chroot "dracut --kver ${KV} -H /boot/initramfs-${KV}" || die "Could not create initramfs"

    spawn_chroot "echo exherbo > /etc/hostname"
    spawn_chroot "echo \"127.0.0.1 localhost exherbo\n::1 localhost\n\" > /etc/hosts"
    for p in ${extra_packages}; do
        spawn_chroot "cave resolve ${p} -x" || die "Could not install extra packages"
    done

    spawn_chroot "grub-install --force /dev/sda" || die "Could not install grub to /boot/grub"
    spawn_chroot "echo \"set timeout=10\nset default=0\nmenuentry Exherbo {\n    set root=(hd0,1)\n    linux /kernel-${arch}-${KV} root=/dev/sda2\n    initrd /initramfs-${KV}}\n\" >  /boot/grub/grub.cfg"
}
