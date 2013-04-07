part sda 1 83 100M  # /boot
part sda 2 82 2048M # swap
part sda 3 83 +     # /

luks bootpw    a    # CHANGE ME
luks /dev/sda2 swap aes sha256
luks /dev/sda3 root aes sha256

format /dev/sda1        ext2
format /dev/mapper/swap swap
format /dev/mapper/root ext4

mountfs /dev/sda1        ext2 /boot
mountfs /dev/mapper/swap swap
mountfs /dev/mapper/root ext4 / noatime

# retrieve latest autobuild stage version for stage_uri
[ "${arch}" == "x86" ]   && stage_latest $(uname -m)
[ "${arch}" == "amd64" ] && stage_latest amd64
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

# ship the binary kernel instead of compiling (faster)
kernel_binary           $(pwd)/kbin/kernel-genkernel-${arch}-3.7.10-gentoo
initramfs_binary        $(pwd)/kbin/initramfs-genkernel-${arch}-3.7.10-gentoo
systemmap_binary        $(pwd)/kbin/System.map-genkernel-${arch}-3.7.10-gentoo

timezone                UTC
bootloader              grub
bootloader_kernel_args  crypt_root=/dev/sda3 # should match root device in the $luks variable
rootpw                  a # CHANGE ME
keymap                  us # fr be-latin1
hostname                gentoo-luks
extra_packages          dhcpcd cryptsetup gentoo-sources genkernel # openssh syslog-ng

rcadd                   dmcrypt default

post_install_extra_packages() {
    # this tells luks where to find the swap 
    cat >> ${chroot_dir}/etc/conf.d/dmcrypt <<EOF
swap=swap
source='/dev/sda2'
EOF
}
