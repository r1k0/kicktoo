part sda 1 83 100M
part sda 2 82 2048M
part sda 3 83 +

format /dev/sda1 ext2
format /dev/sda2 swap
format /dev/sda3 ext4

mountfs /dev/sda1 ext2 /boot
mountfs /dev/sda2 swap
mountfs /dev/sda3 ext4 / noatime

# NOTE find what arch is your CPU and get the relevant stage at https://www.funtoo.org/Subarches
stage_uri          https://build.funtoo.org/1.4-release-std/x86-64bit/intel64-haswell/stage3-latest.tar.xz
#tree_type snapshot https://build.funtoo.org/1.4-release-std/snapshots/portage-2020-04-14.tar.xz

#cat "$(pwd)"/kconfig/livedvd-x86-amd64-32ul-2012.1.kconfig > /dotconfig
#kernel_config_file      /dotconfig
#kernel_sources          gentoo-sources

timezone		UTC
rootpw 			a
#bootloader 		grub
keymap			us # be-latin1 en
hostname		funtoo
#extra_packages         vixie-cron syslog-ng openssh
#rcadd			vixie-cron default
#rcadd			syslog-ng default
#rcadd			sshd default

#do_tree=yes # fixme move do_vars into runsteps functions

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

pre_fetch_repo_tree() {
    spawn_chroot "install -d /var/git -o 250 -g 250" || die
    spawn_chroot "ego sync" || die
    spawn_chroot "emerge linux-firmware" || die
    spawn_chroot "emerge grub" || die
    spawn_chroot "grub-install /dev/sda" || die
    spawn_chroot "ego boot update" || die
    spawn_chroot "emerge world -uDNq" || die
    spawn_chroot "emerge networkmanager -q" || die
}
skip fetch_repo_tree
# post_fetch_repo_tree() {
# }

# pre_unpack_repo_tree() {
# }
skip unpack_repo_tree
#post_unpack_repo_tree() {
#}

# pre_install_cryptsetup() {
# }
# skip install_cryptsetup
# post_install_cryptsetup() {
# }

# pre_copy_kernel() {
# }
# skip copy_kernel
# post_copy_kernel() {
# }

# pre_build_kernel() {
# }
skip build_kernel
#post_build_kernel() {
#}

# pre_setup_network_post() {
# }
# skip setup_network_post
# post_setup_network_post() {
# }

#pre_setup_root_password() {
#      spawn_chroot "install -d /var/git -o 250 -g 250" || die
#      spawn_chroot "ego sync" || die
#      spawn_chroot "emerge linux-firmware" || die
#      spawn_chroot "emerge grub" || die
#      spawn_chroot "grub-install /dev/sda" || die
#      spawn_chroot "ego boot update" || die
#      spawn_chroot "emerge world -uDNq" || die
#      spawn_chroot "emerge networkmanager -q" || die
#}
#skip setup_root_password
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
skip install_bootloader
# post_install_bootloader() {
# }

#pre_configure_bootloader() {
#}
skip configure_bootloader
# post_configure_bootloader() {
# }

# pre_install_extra_packages() {
# }
# skip install_extra_packages
# post_install_extra_packages() {
# }

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
