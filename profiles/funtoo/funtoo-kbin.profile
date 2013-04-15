gptpart sda 1 8300 100M
gptpart sda 2 ef02 32M # for GPT/GUID only
gptpart sda 3 8200 2048M
gptpart sda 4 8300 +

format /dev/sda1 ext2
format /dev/sda3 swap
format /dev/sda4 ext4

mountfs /dev/sda1 ext2 /boot
mountfs /dev/sda3 swap
mountfs /dev/sda4 ext4 / noatime

[ "${arch}" == "x86" ]   && stage_uri http://ftp.osuosl.org/pub/funtoo/funtoo-stable/x86-32bit/$(uname -m)/stage3-latest.tar.xz
[ "${arch}" == "amd64" ] && stage_uri http://ftp.osuosl.org/pub/funtoo/funtoo-stable/x86-64bit/generic_64/stage3-latest.tar.xz
tree_type   snapshot    http://ftp.osuosl.org/pub/funtoo/funtoo-stable/snapshots/portage-latest.tar.xz

# ship the binary kernel instead of compiling (faster)
kernel_binary $(pwd)/kbin/kernel-genkernel-${arch}-3.7.10-gentoo
initramfs_binary $(pwd)/kbin/initramfs-genkernel-${arch}-3.7.10-gentoo
systemmap_binary $(pwd)/kbin/System.map-genkernel-${arch}-3.7.10-gentoo

timezone		UTC
rootpw 			a
bootloader 		grub
keymap			fr # be-latin1 en
hostname		funtoo
extra_packages  gentoo-sources # syslog-ng openssh

#rcadd			syslog-ng default
#rcadd			sshd default

post_unpack_repo_tree() {
    # git style Funtoo portage
    spawn_chroot "cd /usr/portage && git checkout funtoo.org" || die "could not checkout funtoo git repo"
}
post_install_bootloader() {
    # make sure /boot is NOT mounted, boot-update breaks otherwise (lol...)
    check_chroot_fstab /boot && spawn_chroot "[ -z \"\$(mount | grep /boot)\" ] && umount /boot"            
    # $(echo ${device} | cut -c1-8) is like /dev/sdx
    spawn_chroot "grub-install $(echo ${device} | cut -c1-8)" || die "cannot grub-install $(echo ${device} | cut -c1-8)"
    spawn_chroot "boot-update"                                || die "boot-update failed"
}
skip configure_bootloader
