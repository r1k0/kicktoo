part sda 1 83 100M  # /boot
part sda 2 83 +     # /

luks bootpw    a    # CHANGE ME
luks /dev/sda2 root aes sha256

format /dev/sda1        ext2
format /dev/mapper/root ext4

mountfs /dev/sda1        ext2 /boot
mountfs /dev/mapper/root ext4 / noatime

# retrieve latest autobuild stage version for stage_uri
wget -q http://distfiles.gentoo.org/releases/x86/autobuilds/latest-stage3-i486.txt -O /tmp/stage3.version
latest_stage_version=$(cat /tmp/stage3.version | grep tar.bz2)

stage_uri               http://distfiles.gentoo.org/releases/x86/autobuilds/${latest_stage_version}
tree_type   snapshot    http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2

# get kernel dotconfig from running kernel
cat $(pwd)/kconfig/livedvd-x86-amd64-32ul-2012.1.kconfig > /dotconfig

kernel_config_file      /dotconfig
rootpw                  a
genkernel_initramfs_opts --luks # required
kernel_sources          gentoo-sources
timezone                UTC
bootloader              grub
bootloader_kernel_args  crypt_root=/dev/sda2 # should match root device in the $luks variable
keymap                  fr # be-latin1 us
hostname                gentoo-luks
#extra_packages         openssh syslog-ng
#rcadd                  sshd default
#rcadd                  syslog-ng default
#rcadd                  vixie-cron default

# get kernel dotconfig from running kernel
cat $(pwd)/kconfig/livedvd-x86-amd64-32ul-2012.1.kconfig > /dotconfig
