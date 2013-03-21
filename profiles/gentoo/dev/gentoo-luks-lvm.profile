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
if [ "${arch}" == "x86" ]; then
    wget -q http://distfiles.gentoo.org/releases/${arch}/autobuilds/latest-stage3-$(uname -m).txt -O /tmp/stage3.version
elif [ "${arch}" == "amd64" ]; then
    wget -q http://distfiles.gentoo.org/releases/${arch}/autobuilds/latest-stage3-${arch}.txt -O /tmp/stage3.version
fi
latest_stage_version=$(cat /tmp/stage3.version | grep tar.bz2)

stage_uri               http://distfiles.gentoo.org/releases/${arch}/autobuilds/${latest_stage_version}
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

# get kernel dotconfig from running kernel
cat $(pwd)/kconfig/livedvd-x86-amd64-32ul-2012.1.kconfig > /dotconfig
# get rid of Gentoo official firmware .config..
grep -v CONFIG_EXTRA_FIRMWARE /dotconfig > /dotconfig2 ; mv /dotconfig2 /dotconfig
# ..and lzo compression
grep -v LZO /dotconfig > /dotconfig2 ; mv /dotconfig2 /dotconfig

kernel_config_file      /dotconfig
genkernel_kernel_opts    --loglevel=5
genkernel_initramfs_opts --loglevel=5 --lvm
kernel_sources          gentoo-sources

# ship the binary kernel instead of compiling (faster)
#kernel_binary           $(pwd)/kbin/lvm/kernel-genkernel-${arch}-3.2.1-gentoo-r2
#initramfs_binary        $(pwd)/kbin/lvm/initramfs-genkernel-${arch}-3.2.1-gentoo-r2
#systemmap_binary        $(pwd)/kbin/lvm/System.map-genkernel-${arch}-3.2.1-gentoo-r2

timezone                UTC
rootpw                  a
bootloader              grub
bootloader_kernel_args  dolvm
keymap                  us # fr be-latin1
hostname                gentoo-lvm
extra_packages          lvm2 dhcpcd # vim openssh vixie-cron syslog-ng

rcadd        lvm        default
rcadd        lvm-monitoring         default
#rcadd                   sshd       default
#rcadd                   vixie-cron default
#rcadd                   syslog-ng  default

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

# pre_install_kernel_builder() {
# }
# skip install_kernel_builder
# post_install_kernel_builder() {
# }

# pre_install_initramfs_builder() {
# }
# skip install_initramfs_builder
# post_install_initramfs_builder() {
# }

# pre_build_kernel() {
# }
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
