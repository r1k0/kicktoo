#!/usr/bin/env bash

part sda 1 83 100M
part sda 2 82 4096M
part sda 3 83 +

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
tree_type     snapshot  http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2
#tree_type     sync

kernel_sources          gentoo-sources

kernel_builder          kigen
kigen_kernel_opts       --debug # --nocolor
kernel_config_file      "$(pwd)"/kconfig/dedibox-SC-"${arch}".kconfig

initramfs_builder       kigen
kigen_initramfs_opts    --debug --source-luks --bin-dropbear --dynlibs --source-ttyecho --source-strace --source-screen --rootpasswd=dedi

timezone                UTC
rootpw                  a
bootloader              grub
bootloader_kernel_args  crypt_root=/dev/sda3 docrypt dokeymap keymap=fr dodropbear ip=dhcp # should match root device in the $luks variable
keymap                  fr
hostname                dediluks
extra_packages          openssh # dhcpcd syslog-ng vim

rcadd                   network     default
rcadd                   sshd        default

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

kigen_version=9999
pre_install_kernel_builder() {
    # fetching and unmasking kigen-${kigen_version}.ebuild
    spawn_chroot "mkdir /usr/local/portage/sys-kernel/kigen -p" || die "cannot mkdir /usr/local/portage/sys-kernel/kigen"
    spawn_chroot "wget https://github.com/downloads/r1k0/kigen/kigen-${kigen_version}.ebuild -O /usr/local/portage/sys-kernel/kigen/kigen-${kigen_version}.ebuild" || die "cannot fetch kigen-${kigen_version}.ebuild"
    spawn_chroot "echo -e PORTDIR_OVERLAY=\"/usr/local/portage\" >> /etc/portage/make.conf" || die "cannot append PORTDIR_OVERLAY to make.conf"
    spawn_chroot "echo sys-kernel/kigen >> /etc/portage/package.keywords" || die "cannot add keyword for kigen"

    spawn_chroot "ebuild /usr/local/portage/sys-kernel/kigen/kigen-${kigen_version}.ebuild digest" || die "cannot digest kigen-${kigen_version}.ebuild"
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
    for i in dev-libs/libgcrypt    \
             dev-libs/popt         \
	     dev-libs/libgpg-error \
	     sys-apps/util-linux   \
	     sys-fs/cryptsetup
    do
        spawn_chroot "echo $i static-libs >> /etc/portage/package.use" || die "cannot append $i to package.use"
    done
    spawn_chroot "emerge cryptsetup"    || die "could not emerge cryptsetup"
}
skip build_kernel
post_build_kernel() {
    # rewrite build_kernel
    spawn_chroot "emerge ${kernel_sources}" || die "could not emerge kernel sources"

    # build kernel w/ KIGen
    if [ "${kernel_builder}" == "kigen" ]; then
        if [ -n "${kernel_config_uri}" ]; then
            fetch "${kernel_config_uri}" "${chroot_dir}/tmp/kconfig" || die "could not fetch kernel config"
        elif [ -n "${kernel_config_file}" ]; then
            cp "${kernel_config_file}" "${chroot_dir}/tmp/kconfig"   || die "could not copy kernel config"
        fi

        # FIXME in KIGen: make sure oldconfig pass ok
        spawn_chroot "cp ${chroot_dir}/tmp/kconfig /usr/src/linux/.config" || die "could not cp kernel config"
        spawn_chroot "cd /usr/src/linux && yes '' | make oldconfig "       || die "cannot make oldconfig before running KIGen"
        spawn_chroot "kigen ${kigen_kernel_opts} kernel"                   || die "could not build custom kernel"
    fi
}

pre_build_initramfs() {
    # if we call for --bin-dropbear and/or ----bin-busybox
    # we need to have them installed priorly
    spawn_chroot "emerge dropbear" || die "could not emerge dropbear required for kigen"
    spawn_chroot "emerge busybox" || die "could not emerge busybox required for kigen"
}
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

pre_install_bootloader() {
    spawn_chroot "mount /boot" || die "cannot mount /boot in chroot"
}
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
    cat >> "${chroot_dir}/etc/conf.d/network" <<EOF
ifconfig_eth0="88.191.122.122 netmask 255.255.255.0 brd 88.191.122.255"
defaultroute="gw 88.191.122.1"
EOF
    # this tells where to find the swap to encrypt
    cat >> "${chroot_dir}/etc/conf.d/dmcrypt" <<EOF
swap=swap
source='/dev/sda2'
EOF
    # this will activate the encrypted swap on boot
    cat >> "${chroot_dir}/etc/conf.d/local" <<EOF
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
