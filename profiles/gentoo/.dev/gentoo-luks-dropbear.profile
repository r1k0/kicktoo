#!/usr/bin/env bash

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
if [ "${arch}" == "x86" ]; then
    wget -q http://distfiles.gentoo.org/releases/"${arch}"/autobuilds/latest-stage3-"$(uname -m)".txt -O /tmp/stage3.version
elif [ "${arch}" == "amd64" ]; then
    wget -q http://distfiles.gentoo.org/releases/"${arch}"/autobuilds/latest-stage3-"${arch}".txt -O /tmp/stage3.version
fi
latest_stage_version=$(grep tar.bz2 /tmp/stage3.version)

stage_uri               http://distfiles.gentoo.org/releases/"${arch}"/autobuilds/"${latest_stage_version}"
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

# get kernel dotconfig from running kernel
cat "$(pwd)"/kconfig/livedvd-x86-amd64-32ul-2012.1.kconfig > /dotconfig
# get rid of Gentoo official firmware .config
grep -v CONFIG_EXTRA_FIRMWARE /dotconfig > /dotconfig2 ; mv /dotconfig2 /dotconfig
grep -v LZO                   /dotconfig > /dotconfig2 ; mv /dotconfig2 /dotconfig
grep -v CONFIG_CRYPTO_AES     /dotconfig > /dotconfig2 ; mv /dotconfig2 /dotconfig
grep -v CONFIG_CRYPTO_CBC     /dotconfig > /dotconfig2 ; mv /dotconfig2 /dotconfig
grep -v CONFIG_CRYPTO_SHA256  /dotconfig > /dotconfig2 ; mv /dotconfig2 /dotconfig
# enable the required ones
echo "CONFIG_CRYPTO_AES=y";echo "CONFIG_CRYPTO_CBC=y";echo "CONFIG_CRYPTO_SHA256=y" >> /dotconfig

kernel_config_file      /dotconfig
kernel_sources          gentoo-sources

kernel_builder          kigen
initramfs_builder       kigen
kigen_kernel_opts       -d 
kigen_initramfs_opts    --host-dropbear --source-ttyecho --source-luks --source-disklabel --dynlibs --rootpasswd=a # CHANGEME

# ship the binary kernel instead of compiling (faster)
#kernel_binary           $(pwd)/kbin/luks/kernel-genkernel-${arch}-3.2.1-gentoo-r2
#initramfs_binary        $(pwd)/kbin/luks/initramfs-genkernel-${arch}-3.2.1-gentoo-r2
#systemmap_binary        $(pwd)/kbin/luks/System.map-genkernel-${arch}-3.2.1-gentoo-r2

timezone                UTC
bootloader              grub
bootloader_kernel_args  dodropbear ip=dhcp crypt_root=/dev/sda3 # should match root device in the $luks variable
rootpw                  a # CHANGE ME
keymap                  us # fr be-latin1
hostname                gentoo-luks
extra_packages          dhcpcd openssh syslog-ng

rcadd                   sshd default
rcadd                   syslog-ng default

#############################################################################
# 1. commented skip runsteps are actually running!                          #
# 2. put your custom code if any in pre_ or post_ functions                 #
#############################################################################

# pre_partition() {
# }
# skip partition
# post_partition() {
# }

# pre_setup_mdraid() {
# }
# skip setup_mdraid
# post_setup_mdraid() {
# }

# pre_setup_lvm() {
# }
# skip setup_lvm
# post_setup_lvm() {
# }

# pre_luks_devices() {
# }
# skip luks_devices
# post_luks_devices() {
# }

# pre_format_devices() {
# }
# skip format_devices
# post_format_devices() {
# }

# pre_mount_local_partitions() {
# }
# skip mount_local_partitions
# post_mount_local_partitions() {
# }

# pre_mount_network_shares() {
# }
# skip mount_network_shares
# post_mount_network_shares() {
# }

# pre_fetch_stage_tarball() {
# }
# skip fetch_stage_tarball
# post_fetch_stage_tarball() {
# }

# pre_unpack_stage_tarball() {
# }
# skip unpack_stage_tarball
# post_unpack_stage_tarball() {
# }

# pre_prepare_chroot() {
# }
# skip prepare_chroot
# post_prepare_chroot() { 
# }

# pre_setup_fstab() {
# }
# skip setup_fstab
# post_setup_fstab() { 
# }

# pre_fetch_repo_tree() {
# }
# skip fetch_repo_tree
# post_fetch_repo_tree() {
# }

# pre_unpack_repo_tree() {
# }
# skip unpack_repo_tree
# post_unpack_repo_tree() {
# }

# pre_copy_kernel() {
# }
# skip copy_kernel
# post_copy_kernel() {
# }

pre_install_kernel_builder() {
    # install kigen ebuild
    spawn_chroot "echo PORTDIR_OVERLAY=\"/usr/local/portage\" >> /etc/portage/make.conf"
    spawn_chroot "mkdir -p /usr/local/portage/sys-kernel/kigen"
    spawn_chroot "wget -q https://github.com/downloads/r1k0/kigen/kigen-9999.ebuild -O /usr/local/portage/sys-kernel/kigen/kigen-9999.ebuild"
    spawn_chroot "ebuild /usr/local/portage/sys-kernel/kigen/kigen-9999.ebuild digest"
    spawn_chroot "mkdir -p /etc/portage"
    spawn_chroot "echo \>=sys-kernel/kigen-9999 ~x86 >> /etc/portage/package.accept_keywords"

    # install git
    spawn_chroot "emerge dev-vcs/git"
}
# skip install_kernel_builder
# post_install_kernel_builder() {
# }

# pre_install_initramfs_builder() {
# }
# skip install_initramfs_builder
# post_install_initramfs_builder() {
# }

pre_build_kernel() {
    # install cryptsetup and dropbear
    # FIXME for some reason "emerge cryptsetup dropbear --autounmask-write" returns 1 as it ran OK
#    spawn_chroot "emerge cryptsetup dropbear --autounmask-write" || die "could not autounmask cryptsetup and dropbear"
    spawn_chroot "emerge cryptsetup dropbear --autounmask-write" 
    spawn_chroot "etc-update --automode -5" || die "could not etc-update --automode -5"
    spawn_chroot "emerge cryptsetup dropbear" || die "could not emerge cryptsetup and dropbear"
}
# skip build_kernel
# post_build_kernel() {
# }

# pre_build_initramfs() {
# }
# skip build_initramfs
# post_build_initramfs() {
# }

# pre_setup_network_post() {
# }
# skip setup_network_post
# post_setup_network_post() {
# }

# pre_setup_root_password() {
# }
# skip setup_root_password
# post_setup_root_password() {
# }

# pre_setup_timezone() {
# }
# skip setup_timezone
# post_setup_timezone() {
# }

# pre_setup_keymap() {
# }
# skip setup_keymap
# post_setup_keymap() {
# }

# pre_setup_host() {
# }
# skip setup_host
# post_setup_host() {
# }

# pre_install_bootloader() {
# }
# skip install_bootloader
# post_install_bootloader() {
# }

# pre_configure_bootloader() {
# }
# skip configure_bootloader
# post_configure_bootloader() {
# }

# pre_install_extra_packages() {
# }
# skip install_extra_packages
post_install_extra_packages() {
    # this tells where to find the swap to encrypt
    cat >> "${chroot_dir}"/etc/conf.d/dmcrypt <<EOF
swap=swap
source='/dev/sda2'
EOF
    # this will activate the encrypted swap on boot
    cat >> "${chroot_dir}"/etc/conf.d/local <<EOF
mkswap /dev/sda2
swapon /dev/sda2
EOF
}

# pre_add_and_remove_services() {
# }
# skip add_and_remove_services
# post_add_and_remove_services() {
# }

# pre_run_post_install_script() { 
# }
# skip run_post_install_script
# post_run_post_install_script() {
# }
