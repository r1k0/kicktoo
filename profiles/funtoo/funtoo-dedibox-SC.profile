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
tree_type     snapshot  http://ftp.osuosl.org/pub/funtoo/funtoo-stable/snapshots/portage-latest.tar.xz

# compile kernel from sources using the right .config
kernel_config_file      $(pwd)/kconfig/dedibox-SC-${arch}.kconfig
kernel_sources          gentoo-sources
genkernel_kernel_opts    --loglevel=5
genkernel_initramfs_opts --loglevel=5

timezone                UTC
rootpw                  a
bootloader              grub
keymap                  fr
hostname                funtoo
extra_packages          openssh

rcadd                   netif.eth0 default
rcadd                   sshd       default

post_unpack_repo_tree() {
    # git style Funtoo portage
    spawn_chroot "cd /usr/portage && git checkout funtoo.org" || die "could not checkout funtoo git repo"
}
post_install_bootloader() {
    # $(echo ${device} | cut -c1-8) is like /dev/sdx
    spawn_chroot "grub-install $(echo ${device} | cut -c1-8)" || die "cannot grub-install $(echo ${device} | cut -c1-8)"
    spawn_chroot "boot-update"                                || die "boot-update failed"
}
skip configure_bootloader
post_install_extra_packages() {
    spawn_chroot "ln -s /etc/init.d/netif.tmpl /etc/init.d/netif.eth0"
    cat >> ${chroot_dir}/etc/conf.d/netif.eth0 <<EOF
template="interface"
ipaddr="88.191.xxx.xxx/24"
gateway="88.191.xxx.1"
nameservers="88.191.xxx.1"
domain=""
EOF
}
