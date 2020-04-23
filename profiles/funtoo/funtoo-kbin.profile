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
stage_uri https://build.funtoo.org/1.4-release-std/x86-64bit/intel64-haswell/stage3-latest.tar.xz

timezone UTC
rootpw   a
keymap   us # be-latin1 en
hostname funtoo
#extra_packages vixie-cron syslog-ng openssh
#rcadd vixie-cron default
#rcadd syslog-ng default
#rcadd sshd default

post_fetch_repo_tree() {
    spawn_chroot "install -d /var/git -o 250 -g 250" || die
    spawn_chroot "ego sync"                          || die
    spawn_chroot "emerge linux-firmware"             || die
    spawn_chroot "emerge grub"                       || die
    spawn_chroot "grub-install /dev/sda"             || die
    spawn_chroot "ego boot update"                   || die
    spawn_chroot "emerge world -uDNq"                || die
}
