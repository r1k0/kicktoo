#!/usr/bin/env bash

# comment out if encrypted partitions are not required
mode luks
# if mode=luks, is the key stored on USB key? comment out if using EFI partition instead
key_on usb

# overriding defaults
export emerge_global_opts="--getbinpkgonly"
export distfiles_url="http://mirror.ovh.net/gentoo-distfiles"


gptspart sda 1 ef02 2048 4095
gptspart sda 2 ef00 4096 413695
gptspart sda 3 fd00 413696 +

gptspart sdb 1 ef02 2048 4095
gptspart sdb 2 ef00 4096 413695
gptspart sdb 3 fd00 413696 +

 if [ "${key_on}" == "usb" ]; then
part sdc 8064 c +
 fi

mdraid md0 -l 1 -n 2 --name=0 /dev/sda3 /dev/sdb3
mduuid md0 a7e6fe0e:767aa055:faa3979c:7cc317eb

lvm_volgroup vg0 /dev/md0
lvm_logvol vg0 100M  boot
lvm_logvol vg0 20G   home
lvm_logvol vg0 5G    portage
lvm_logvol vg0 10G   root
lvm_logvol vg0 10G   usr
lvm_logvol vg0 20G   var
lvm_logvol vg0 5G    log
lvm_logvol vg0 2G    swap

 if [ "${mode}" == "luks" ]; then
#luks bootpw a
  if [ "${key_on}" == "usb" ]; then
luks key /dev/sdc1 /k1
  else
luks key /dev/sda2 /k1
  fi
luks /dev/vg0/root   root   aes cbc-plain sha256
luks /dev/vg0/home   home   aes cbc-plain sha256
luks /dev/vg0/var    var    aes cbc-plain sha256
luks /dev/vg0/log    log    aes cbc-plain sha256
luks /dev/vg0/swap   swap   aes cbc-plain sha256
 fi

format /dev/sda2            fat32
format /dev/sdb2            fat32
 if [ "${key_on}" == "usb" ]; then
format /dev/sdc1            fat32
 fi
format /dev/vg0/boot        ext4
format /dev/vg0/portage     ext4
format /dev/vg0/usr         ext4
 if [ "${mode}" == "luks" ]; then
format /dev/mapper/home     ext4
format /dev/mapper/root     ext4
format /dev/mapper/var      ext4
format /dev/mapper/log      ext4
format /dev/mapper/swap     swap
 else
format /dev/vg0/home        ext4
format /dev/vg0/root        ext4
format /dev/vg0/var         ext4
format /dev/vg0/log         ext4
format /dev/vg0/swap        swap
 fi

 if [ "${mode}" == "luks" ]; then
mountfs /dev/mapper/root    ext4   /              noatime
mountfs /dev/mapper/home    ext4   /home          noatime
mountfs /dev/mapper/var     ext4   /var           noatime
mountfs /dev/mapper/log     ext4   /var/log       noatime
mountfs /dev/mapper/swap    swap
 else
mountfs /dev/vg0/root       ext4   /              noatime
mountfs /dev/vg0/home       ext4   /home          noatime
mountfs /dev/vg0/var        ext4   /var           noatime
mountfs /dev/vg0/log        ext4   /var/log       noatime
mountfs /dev/vg0/swap       swap
 fi
mountfs /dev/vg0/boot       ext4   /boot          noatime
mountfs /dev/vg0/usr        ext4   /usr           noatime
mountfs /dev/vg0/portage    ext4   /usr/portage   noatime
mountfs tmpfs               tmpfs /tmp           nodev,size=40%
mountfs tmpfs               tmpfs /var/tmp       nodev


# retrieve latest autobuild stage version for stage_uri
#[ "${arch}" == "x86" ]   && stage_latest $(uname -m)
#[ "${arch}" == "amd64" ] && stage_latest amd64
stage_uri  http://mirror.ovh.net/gentoo-distfiles/releases/amd64/autobuilds/current-stage3/stage3-amd64-20130425.tar.bz2

tree_type  snapshot       http://mirror.ovh.net/gentoo-distfiles/snapshots/portage-latest.tar.bz2

makeconf_line             FEATURES="getbinpkg"
makeconf_line             PORTAGE_BINHOST="http://distfiles.phenry.name/gentoo-packages"

eselect_profile           default/linux/amd64/13.0

# fetch the precompiled kernel package
kernel_uri                http://distfiles.phenry.name/kernels/linux-3.9.0-gentoo.tbz2

locale_set               "en_US.UTF-8 UTF-8 en_US.ISO-8859-1 ISO-8859-1 en_US.ISO-8859-15 ISO-8859-15"
timezone                  UTC
#rootpw                   a
rootpw_crypt              LJLyqAh6aHkyo
#keymap                   us
hostname                  localhost
extra_packages            linux-firmware lvm2 cryptsetup mdadm net-misc/dhcpcd xfsprogs rsyslog openssh vixie-cron

#net                      eth0 dhcp

bootloader                grub:2
grub_install  /dev/sda   --modules="part_gpt mdraid1x lvm ext2 xfs"
grub_install  /dev/sdb   --modules="part_gpt mdraid1x lvm ext2 xfs"
 if [ "${mode}" == "luks" ]; then
bootloader_kernel_args    "domdadm dolvm crypt_root=/dev/vg0/root root=/dev/mapper/root root_keydev=UUID={{root_keydev_uuid}} root_key={{root_key}} key_timeout=10"
 else
bootloader_kernel_args    "domdadm dolvm"
 fi

rcadd                     mdraid           boot
rcadd                     lvm              boot
rcadd                     dmcrypt          boot
rcadd                     rsyslog          default
rcadd                     net-misc/dhcpcd           default
rcadd                     sshd             default
rcadd                     vixie-cron       default

